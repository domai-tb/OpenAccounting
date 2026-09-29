## Why

The VM route smoke reaches `/settings` through the real `GoRouter` and `ShellRoute`, but the settings profile future can remain pending while an indeterminate `LinearProgressIndicator` keeps scheduling frames. `pumpAndSettle()` then times out before the test can assert route reachability, leaving the current gate nondeterministic and leaving users without a terminal state when local profile reads stall.

## What Changes

- Resolve the existing concrete `ProfileManager` through a Riverpod provider so SettingsPage tests can inject a deterministic profile loader without introducing a new interface.
- Bound the settings profile load with one finite timeout constant shared by the initial `_loadProfiles()` path and `_reloadProfiles()` retry path.
- Replace the indefinite profile spinner with a localized `profileLoadError` message and an actionable retry control using the existing `retry` ARB key after the deadline.
- Add the `profileLoadError` copy to both supported ARB locales during implementation and regenerate localization output; assert German and English route behavior.
- Add a route regression using a never-completing injected loader; its red probe is bounded or seam-focused, while final acceptance preserves default `pumpAndSettle()` and asserts `/settings`, `AppShell`, `AppPage`, visible error, retry action, and no loading indicator.
- Build the route-smoke wrapper with the selected `locale`, `AppLocalizations.localizationsDelegates`, and `AppLocalizations.supportedLocales`, and prove the provider seam with the unique `__settings_injected_profile__` marker, read counters, and a throw-on-unused fake assertion.
- Add an executable source-contract check proving exactly one `const Duration(seconds: 2)` is reused by initial and retry loading paths.
- Keep profile storage, database schema, router topology, and animation-test settings unchanged.

## Capabilities

### New Capabilities

- `route-smoke-settlement-lifecycle`: Settings profile loading reaches a bounded, recoverable terminal state so real route smoke can settle.

### Modified Capabilities

- None. The new route lifecycle capability makes the existing safe-recovery expectation in `profile-workspace-lifecycle` executable at the settings route without changing profile persistence semantics.

## Impact

- Production path: `lib/core/router/app_router.dart` (provider seam, timeout, reload/error UI).
- Localization path during implementation: `assets/l10n/l10n_de.arb`, `assets/l10n/l10n_en.arb`, and generated `lib/l10n/` output. No ARB or generated files are changed in this planning stage.
- Planned regression coverage: a focused settings route widget test plus the existing route-smoke assertions in `test/app/app_shell_test.dart` and `test/integration/audit/analyzer-and-integration-test-gates_test.dart`.
- Unaffected callers: startup profile selection in `lib/main.dart:56-80` and setup profile selection in `lib/features/setup/wizard_page.dart:404-417` continue using their direct `ProfileManager` paths.
- No dependency, database, profile-directory, or serialized-data changes.
- The change remains Linux/VM test scoped; it does not claim native macOS or Windows runtime evidence.
