## Context

The current VM baseline has two route-smoke failures at `pumpAndSettle()` after navigation. Both traverse the production `GoRouter`/`ShellRoute` graph; `/settings` is the route that keeps scheduling frames. `SettingsPage` currently constructs `ProfileManager` directly, starts `_loadProfiles()` from a state-field initializer, and mounts an indeterminate `LinearProgressIndicator` while the local active-profile and profile-list reads are pending (`lib/core/router/app_router.dart:640-795`). The existing error branch is terminal only in the error case and has no deadline or recovery action. `ProfileManager` is already the concrete owner of those reads and has constructor seams for its base directory and database initialization; a second profile-loader interface would add no behavior. The focused route-smoke wrapper must also supply the generated localization contract explicitly: `locale: locale`, `supportedLocales: AppLocalizations.supportedLocales`, `localizationsDelegates: AppLocalizations.localizationsDelegates`, and the real `routerConfig`.

The maintained `profile-workspace-lifecycle` contract says an unavailable or corrupt profile must report the failure and offer a safe retry or removal path. This bounded route change chooses the safe retry path. It does not resolve the separate profile retention/path contradictions recorded by the audit.

## Goals / Non-Goals

**Goals:**

- Make the SettingsPage profile read injectable through the existing Riverpod composition used by the real app and tests.
- Apply one finite `const Duration(seconds: 2)` deadline to the combined active-profile/profile-list load, including reloads.
- Make a stalled or failed read settle into a localized `profileLoadError` message with the existing localized `retry` action.
- Prove the behavior with a deterministic never-completing `ProfileManager` fake while retaining production route navigation and `pumpAndSettle()`.
- Keep the existing AppShell, AppPage, route location, profile storage, and database behavior intact.

**Non-Goals:**

- Do not change `ProfileManager` persistence, profile deletion, profile switching, database schema, or path conventions.
- Do not add a new abstract interface, service hierarchy, cancellation framework, or dependency.
- Do not increase the `pumpAndSettle()` timeout, replace it with manual pumping, disable animations, skip `/settings`, or weaken route assertions.
- Do not broaden localization beyond the new `profileLoadError` key in both ARB locales and the existing `retry` key, or implement the broader settings/profile workspace backlog.
- Do not claim that this one route fix closes the full audit or proves macOS/Windows runtime behavior.

## Decisions

### Reuse `ProfileManager` through a Riverpod provider

Add a `profileManagerProvider` at the router/composition boundary with a default value that constructs the existing `ProfileManager`. Change `_SettingsContentState` to read that provider during `initState`, then start its initial future. Tests override the provider with a `ProfileManager` subclass whose methods return controlled futures. The injection fixture SHALL return the unique marker `__settings_injected_profile__`, increment separate `getActiveProfile` and `listProfiles` counters, and expose `assertUsed()` that throws `StateError('injected ProfileManager was not used')` when either counter is zero. The route test asserts the marker, both counters, and `assertUsed()` after settlement. This reuses the current manager and Riverpod `ProviderScope` overrides already used by route tests; it avoids an interface with one implementation and ensures the test fake actually controls SettingsPage.

Passing a manager through a new `SettingsPage` constructor was rejected because the route currently creates a const page inside `ShellRoute`, and it would add a parallel dependency path beside the app's existing Riverpod composition. Adding a new `ProfileLoader` interface was rejected because the existing concrete manager already exposes the two operations required by the page.

### Use one two-second deadline for initial and reload loads

Define one private `const Duration _profileLoadTimeout = Duration(seconds: 2)`. `_loadProfiles()` SHALL apply that exact constant to the combined future that awaits both the active-profile and profile-list reads. `_reloadProfiles()` SHALL assign `_profiles = _loadProfiles()` and therefore reuse the same bounded path rather than duplicating timeout logic. The combined future is bounded so a stall in either read reaches the terminal UI state.

The implementation plan chooses an executable static contract check instead of advancing the widget clock by hand. The focused test SHALL read `lib/core/router/app_router.dart` and fail unless it finds exactly one declaration matching `const Duration _profileLoadTimeout = Duration(seconds: 2)`, a `.timeout(_profileLoadTimeout)` on the combined `_loadProfiles()` future, and `_reloadProfiles()` delegating to `_loadProfiles()` without a second duration or timeout expression. That check proves the exact two-second policy is shared by the initial and retry paths while the route acceptance remains a default `pumpAndSettle()` assertion.

Two seconds follows the route-timeout diagnosis, which demonstrated that a one-second bounded probe lets `pumpAndSettle()` complete while allowing ordinary local reads to finish. A finite constant keeps the production policy explicit and makes the test deterministic without changing the test harness timeout.

### Localize the error and reuse the existing retry key

Add a `profileLoadError` key to both `assets/l10n/l10n_de.arb` and `assets/l10n/l10n_en.arb`, with values `Profile konnten nicht geladen werden` and `Profiles could not be loaded`. Use the existing generated `retry` key for the action, which already resolves to `Erneut versuchen` and `Retry`. The implementation SHALL regenerate `lib/l10n/` with `fvm flutter gen-l10n` after the ARB change and SHALL obtain both strings through `AppLocalizations.of(context)`. The route-smoke wrapper SHALL be constructed with the exact generated lists, for example:

```dart
MaterialApp.router(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  routerConfig: router,
)
```

The retry button invokes `_reloadProfiles()`. A retry is required by the existing profile-workspace recoverability contract; a removal action would expand into the unresolved profile deletion/retention contract and is out of scope. A text-only error and hardcoded German/English literals were therefore rejected.

The new error message is intentionally static and does not interpolate `snapshot.error`; this preserves a localized, stable user-facing state without leaking raw exception text or local filesystem paths. Tests SHALL assert the German strings under `Locale('de')` and the English strings under `Locale('en')`.

### Preserve real route and settle assertions

The focused regression will build the real router with a configured in-memory database, override only `profileManagerProvider`, navigate to `/settings`, and call `await tester.pumpAndSettle()` with no timeout override. It will assert the route location, `AppShell`, `AppPage`, the visible error/retry state, and absence of `LinearProgressIndicator`. Separate scripted-manager cases will prove a successful initial load, recovery after retry, and a second bounded failure. Red TDD probes may use `pumpAndSettle(timeout: const Duration(milliseconds: 250))` to fail quickly before the lifecycle behavior exists, or the injection test may use the marker/counter seam assertion without settlement. Those short probes are replaced by the final default `pumpAndSettle()` acceptance after the implementation is present; no manual `pump()` loop or animation override is part of the acceptance contract.

### Leave startup and setup profile callers unchanged

The provider is a SettingsPage composition seam only. `lib/main.dart:56-80` continues to construct `ProfileManager` directly for startup active-profile selection and database opening. `lib/features/setup/wizard_page.dart:404-417` continues to construct `ProfileManager` directly for setup profile selection and restart messaging. Neither caller uses the settings load timeout or retry UI, and neither is modified by this change.

## Risks / Trade-offs

- **[Risk]** `Future.timeout` bounds the UI future but does not cancel an underlying filesystem future. → **Mitigation:** The profile operation is read-only; after timeout no callback updates the disposed route, and the route owns only the bounded future observed by `FutureBuilder`. Cancellation remains a separate concern if the data source later gains cancellable I/O.
- **[Risk]** A two-second deadline could surface an error on an unusually slow local filesystem. → **Mitigation:** Keep the value in one named constant, preserve the retry path, and use the same value in the deterministic widget test so a later evidence-based adjustment changes one policy point.
- **[Risk]** Other route-owned async surfaces may have independent settlement problems. → **Mitigation:** Scope this change to the reproduced `/settings` lifecycle and retain the existing all-route smoke assertions; do not claim broader repair without new evidence.
- **[Risk]** A new ARB key requires generated localization output to stay in sync. → **Mitigation:** Add the same `profileLoadError` key to `l10n_de.arb` and `l10n_en.arb`, run `fvm flutter gen-l10n`, and include a locale-parity check with the focused widget tests.
- **[Risk]** The visible error previously included the thrown error value. → **Mitigation:** Replace that unstable/raw detail with the localized static `profileLoadError` message; the retry action remains available for recovery and the route remains unchanged.

## Migration Plan

1. Declare the provider seam without consuming it, write the red injection test with the unique marker/counters/throw-on-unused assertion, and then wire SettingsPage to the provider without changing default manager behavior.
2. Write the red timeout test and the red static source-contract check, implement the exact two-second bound for initial and reload loads, and refactor while preserving the final default `pumpAndSettle()` assertion.
3. Write both red retry recovery/failure tests before adding the retry action; add the localized ARB key, regenerate l10n, implement the retry action, and refactor.
4. Run the focused tests, the two existing route-smoke tests, `fvm flutter analyze`, `fvm flutter gen-l10n` after ARB changes, and the full VM suite. Keep `pumpAndSettle()` in every route assertion.
5. If the change is rolled back, remove the provider override, timeout, retry UI, and new ARB key/generated output together; no profile files or databases require migration.

## Open Questions

- A fresh independent Anvil reviewer must re-read this exact proposal, spec, and design. The current review artifact is evidence of the blocked gate, not an approval.
- The broader audit remains blocked by its independent provenance and product-contract findings; this change may be implemented only as a separately approved bounded repair.
