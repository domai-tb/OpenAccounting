# Route smoke settlement lifecycle diagnosis

Date: 2026-09-29  
Checkout: `dev` at `70ec70c`  
Flutter: 3.47.2 / Dart 3.13.2 through FVM 4.3.0  
Status: diagnosis and repair proposal only; no production or test implementation was made.

## Result

The two VM failures share one route-owned lifecycle. Both tests navigate through the real
`GoRouter`/`ShellRoute` graph and call `pumpAndSettle()` after each navigation. The final route
that keeps scheduling frames is `/settings`.

`SettingsPage` creates `_SettingsContentState` in
`lib/core/router/app_router.dart:640-669`. Its `_profiles` future calls
`ProfileManager.getActiveProfile()` and `ProfileManager.listProfiles()`, which perform local
filesystem reads at `lib/core/db/profile_manager.dart:49-123`. While that future is pending,
`lib/core/router/app_router.dart:787-792` mounts an indeterminate `LinearProgressIndicator`.
That ticker means `WidgetTester.pumpAndSettle()` cannot observe a settled frame. In the widget
test fake-async zone, the in-flight `dart:io` future does not complete during the settle loop.

This is a test-triggered production lifecycle gap. The app has an error branch but no deadline,
so a real profile read that stalls can leave the route in an indefinite loading state. A direct
real-async probe of the same `ProfileManager` completed with `active=Default` and
`profiles=[Default]`; the Linux startup smoke also reaches readiness. The evidence does not show
a GoRouter or AppShell reachability defect.

## Reproduction

The baseline command failed with two named timeouts:

```text
fvm flutter test --dart-define=platform=vm
```

- `test/app/app_shell_test.dart:59` in `test_shell_renders_on_every_primary_route`.
- `test/integration/audit/analyzer-and-integration-test-gates_test.dart:75` in
  `test_analyzer_and_integration_test_gates_2_1_route_smoke_tests_prove_reachability`.

The two focused commands reproduce the failures independently. Re-running the focused shell
test produced the same timeout. A temporary diagnostic test manually pumped each route in
100 ms steps: `/`, `/invoices`, `/receipts`, and `/taxes` had no scheduled frame by approximately
300 ms; `/settings` still had one `LinearProgressIndicator` and
`hasScheduledFrame == true` after 3 seconds. Wrapping the same profile future in a temporary
one-second `Future.timeout` probe allowed `pumpAndSettle()` to complete and rendered the existing
error branch.

Wrapping the existing route test body in `tester.runAsync` did not make the `/settings`
`pumpAndSettle()` return. A separate `FutureBuilder` probe whose profile future was created
before the widget pump did complete, so a blanket `runAsync` wrapper is not a reliable repair for
the current production widget lifecycle.

The acceptance record also mentions a separate `750/750` broad run. No command or log for that
run is preserved. The current checkout's exact baseline artifact reports `748` completed tests
and the two failures, and both focused reproductions fail. Treat `750/750` as unreconciled
evidence from a different invocation or state, not as a green result for this checkout.

## Minimal repair proposal

Preserve `pumpAndSettle()` in both route tests. Bound the one-shot `_loadProfiles()` future in
`_SettingsContentState` with a local filesystem deadline shorter than the test settle timeout
(for example, two seconds), and route timeout/failure through the existing `snapshot.hasError`
state. Keep `_reloadProfiles()` on the same bounded path. A retry action can be added to the
existing error state if the product contract requires recovery; the minimum gate repair only
requires a terminal, visible error state.

The regression scenario should navigate from a configured in-memory database to `/settings`,
retain `await tester.pumpAndSettle()`, and assert that:

1. `router.state.matchedLocation` is `/settings`.
2. `AppShell` and the `AppPage` surface remain present.
3. The profile loading indicator is replaced by the explicit profile-load error state when the
   profile future does not complete within the deadline.

The existing shell-route and route-smoke assertions then continue to cover all other canonical
routes. Do not increase `pumpAndSettle`'s timeout, replace it with an unbounded sequence of
`pump()` calls, disable animations globally, or skip `/settings`; those changes would hide the
route lifecycle contract.

## Scope and migration

Affected production path: `lib/core/router/app_router.dart`. Affected regression coverage:
`test/app/app_shell_test.dart` and
`test/integration/audit/analyzer-and-integration-test-gates_test.dart`.

No database, profile-directory, or serialized-data format changes are required. The change is
limited to route loading lifetime/error behavior and its widget-test evidence. Implementation
must remain blocked until a fresh independent Anvil review approves the proposal and its red
regression scenario.
