# route-smoke-settlement-lifecycle Specification

## Purpose
TBD - created by archiving change route-smoke-settlement-lifecycle. Update Purpose after archive.

## Requirements

### Requirement: Settings profile loading is injectable and bounded

SettingsPage SHALL resolve the existing concrete `ProfileManager` through an injectable Riverpod provider, using a default production manager when no override is supplied. The combined future that awaits the active-profile read and profile-list read SHALL use one named deadline constant declared exactly as `const Duration(seconds: 2)` on both the initial `_loadProfiles()` call and every `_reloadProfiles()` call. A completed load SHALL replace the progress indicator with the profile controls. The route regression SHALL prove that the provider override controls the page by using a unique injected profile marker, read call counters, and a fake assertion that throws when either read was unused.

#### Scenario: Injected profile manager settles the settings route with profile controls

- **GIVEN** a configured in-memory database and an injected `ProfileManager` whose active-profile and profile-list calls complete with the unique marker `__settings_injected_profile__`, record each read call, and expose an assertion that throws if either read was unused
- **WHEN** the real router navigates to `/settings` and the test calls `pumpAndSettle()`
- **THEN** `router.state.matchedLocation` SHALL be `/settings`, `AppShell` and `AppPage` SHALL each be present, the `__settings_injected_profile__` profile control SHALL be visible, each read counter SHALL equal one, the fake unused assertion SHALL not throw, and no profile-loading indicator SHALL remain

#### Scenario: Never-completing profile manager reaches a terminal error state

- **GIVEN** a configured in-memory database and an injected `ProfileManager` whose combined profile-load future never completes
- **WHEN** the real router navigates to `/settings` and the test calls `pumpAndSettle()`
- **THEN** the route SHALL remain `/settings`, `AppShell` and `AppPage` SHALL each be present, the localized profile-load error SHALL be visible, and no `LinearProgressIndicator` SHALL remain after the exact two-second deadline

### Requirement: Settings profile-load failure is recoverable

When the bounded profile load fails or reaches its deadline, SettingsPage SHALL show the localized profile-load error together with an actionable retry control using the existing `retry` ARB key. Activating that control SHALL invoke `_reloadProfiles()` through the same injectable, bounded profile-loading path and SHALL replace the error and retry control with profile controls if the source becomes available.

#### Scenario: Retry recovers after the profile source becomes available

- **GIVEN** SettingsPage displays the localized profile-load error and retry control after an injected manager timed out, and the injected manager will complete on its next load
- **WHEN** the user activates the localized retry control and the test calls `pumpAndSettle()`
- **THEN** the error and retry control SHALL disappear, the returned `Default` profile control SHALL be visible, the route SHALL remain `/settings`, `AppShell` and `AppPage` SHALL remain present, and no loading indicator SHALL remain

#### Scenario: Retry remains bounded when the profile source is still unavailable

- **GIVEN** SettingsPage displays the localized profile-load error and retry control and the injected manager still never completes
- **WHEN** the user activates the localized retry control and the test calls `pumpAndSettle()`
- **THEN** the same localized error and retry control SHALL return after another exact two-second deadline, the route SHALL remain `/settings`, `AppShell` and `AppPage` SHALL remain present, and no `LinearProgressIndicator` SHALL remain

### Requirement: Settings profile-load state uses the active locale

The visible profile-load error SHALL use a new generated `profileLoadError` ARB key in both supported locales, with German text `Profile konnten nicht geladen werden` and English text `Profiles could not be loaded`. The retry control SHALL use the existing generated `retry` ARB key, with German text `Erneut versuchen` and English text `Retry`. The profile-load error SHALL not interpolate a raw exception or infrastructure path into the user-facing message. Every route-smoke wrapper SHALL configure `MaterialApp.router` with the selected `locale`, `AppLocalizations.localizationsDelegates`, and `AppLocalizations.supportedLocales`; a partial delegate list or an implicit fallback is not an acceptable test setup.

#### Scenario: German locale renders the profile-load error and retry action

- **GIVEN** the active locale is German, the route-smoke wrapper passes `AppLocalizations.localizationsDelegates` and `AppLocalizations.supportedLocales`, and an injected profile manager never completes
- **WHEN** the real router navigates to `/settings` and the test calls `pumpAndSettle()`
- **THEN** `/settings`, `AppShell`, and `AppPage` SHALL remain present, `Profile konnten nicht geladen werden` and `Erneut versuchen` SHALL be visible, the `Default` profile control SHALL be absent, and no `LinearProgressIndicator` SHALL remain

#### Scenario: English locale renders English profile-load state

- **GIVEN** the active locale is English, the route-smoke wrapper passes `AppLocalizations.localizationsDelegates` and `AppLocalizations.supportedLocales`, and an injected profile manager never completes
- **WHEN** the real router navigates to `/settings` and the test calls `pumpAndSettle()`
- **THEN** `/settings`, `AppShell`, and `AppPage` SHALL remain present, `Profiles could not be loaded` and `Retry` SHALL be visible, German profile-load and retry strings SHALL be absent, and no `LinearProgressIndicator` SHALL remain
