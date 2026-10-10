# feature-modules Specification

## Purpose
TBD - created by archiving change optional-feature-module-controls. Update Purpose after archive.

## Requirements

### Requirement: Optional modules use the owned catalog and durable state

Catalog version 1 SHALL contain exactly these optional module IDs: `profile_manager`, `inventory`, and `guv`. Each catalog entry SHALL declare localized German and English labels, owning provider, dependencies, availability rule, default, and activation rule. `profile_manager` SHALL require the profile workspace provider. `inventory` SHALL require the article catalog and invoice stock providers. `guv` SHALL require the accounting journal and GuV calculator providers. Each entry SHALL have no optional-module dependency. A missing provider or dependency SHALL make the module unavailable with a localized reason. Other flags shown only in legacy documentation SHALL NOT be exposed as supported modules by this catalog version.

The system SHALL persist these preferences for the active business in `unternehmen.feature_modules_json` as versioned JSON with this version-1 shape: `{"version":1,"enabled":{"profile_manager":false,"inventory":false,"guv":false}}`. Fresh profiles SHALL initialize all three preferences to `false`. Existing profiles SHALL backfill each value from its corresponding legacy column (`profilmanager_aktiv`, `lagerfuehrung_aktiv`, or `guv_aktiv`) when that column exists and contains a valid boolean; an absent or invalid legacy value SHALL default to `false`. The additive migration SHALL add the canonical column and perform backfill transactionally, only when the canonical value is absent. It SHALL preserve a valid canonical value and all legacy values. Legacy columns SHALL be migration-only inputs and SHALL NOT be read or written as runtime module state after backfill. If no earlier accepted migration changes the baseline, the migration SHALL be schema version 9 from version 8; it SHALL merge with any other accepted migration at that version rather than create a competing version bump.

The module service SHALL be the sole reader and writer of enabled state. Unknown IDs, unavailable modules, and dependency-blocked modules SHALL resolve to effectively disabled even if their saved preference is true. Invalid or unreadable canonical JSON SHALL resolve to each catalog entry's declared default without rewriting the stored value or changing business records. Failed writes SHALL leave the prior canonical value and effective state in force.

| ID | English / German label | Default | Availability and dependencies | Special activation rule |
| --- | --- | --- | --- | --- |
| `profile_manager` | Profile Manager / Profilverwaltung | disabled | Available when the profile workspace provider is registered; no optional dependency | The navigation entry remains visible whenever more than one profile exists, regardless of saved preference. |
| `inventory` | Inventory / Lagerverwaltung | disabled | Available when article catalog and invoice stock providers are registered; no optional dependency | Disabling hides inventory entry points but does not stop stock effects required by invoice finalization or storno. |
| `guv` | Profit and loss / GuV | disabled | Available when the journal and GuV calculator providers are registered; no optional dependency | The maintained accounting threshold auto-activation persists `true` through the catalog state writer. |

#### Scenario: Fresh and upgraded profiles receive defined defaults
- **GIVEN** a new profile is initialized, or an existing profile has no canonical module state
- **WHEN** module state is initialized
- **THEN** each catalog entry receives the declared default unless a valid legacy value exists for that module
- **AND** the resulting versioned state is persisted without changing module-owned records

#### Scenario: Available module state is restored
- **GIVEN** a known module is available and enabled for the active business
- **WHEN** the application starts and loads module state
- **THEN** the module remains enabled and its saved state is unchanged

#### Scenario: Unknown or unavailable module cannot be enabled
- **GIVEN** saved state requests an unknown or unavailable module
- **WHEN** the application resolves module availability
- **THEN** the module is treated as disabled and no module action can mutate its records

#### Scenario: Invalid state uses defaults without rewriting stored data
- **GIVEN** the canonical module state is unreadable or malformed
- **WHEN** the application resolves module availability
- **THEN** each module uses its declared default and remains unavailable when a provider or dependency is missing
- **AND** the malformed value and all business records remain unchanged

#### Scenario: Threshold activates GuV through the catalog
- **GIVEN** the maintained accounting GuV threshold condition is met and the GuV provider is available
- **WHEN** the accounting module evaluates the threshold
- **THEN** the catalog state writer persists `guv=true` and reports the threshold activation reason
- **AND** no separate `guv_aktiv` runtime flag is read or written

#### Scenario: GuV cannot be disabled while threshold auto-activation applies
- **GIVEN** the maintained accounting GuV threshold condition is met
- **WHEN** the user attempts to disable `guv`
- **THEN** the canonical preference remains enabled and the Settings section explains the threshold activation

### Requirement: Disabling a module hides its entry points without deleting data

The system SHALL apply module state consistently to sidebar navigation, dashboard widgets and quick links, and module-specific create actions. Disabling a module SHALL preserve its database records and files. A direct route or stale shortcut into a disabled module SHALL show a localized unavailable state and SHALL NOT perform a write.

#### Scenario: Module is disabled while it has existing records
- **GIVEN** an enabled module has business records
- **WHEN** the user disables the module in Settings
- **THEN** its navigation, dashboard widgets, shortcuts, and create actions are hidden or disabled, its existing records remain byte-for-byte unchanged, and the updated state is visible without restarting the app

#### Scenario: Direct navigation reaches a safe unavailable state
- **GIVEN** a module is disabled and an old deep link points to one of its routes
- **WHEN** the route is opened
- **THEN** the application displays a localized unavailable state and performs no database write

### Requirement: Module controls follow the Settings and accessibility design

The module controls SHALL be available from the Settings workspace and use the shared desktop design system. Every module name, status, explanation, and failure state SHALL be localized in German and English. Controls SHALL support keyboard navigation, visible focus, screen-reader labels, and text scaling without clipping.

#### Scenario: User changes a supported module
- **GIVEN** the user can reach the module section in Settings
- **WHEN** the user enables or disables an available module using keyboard or pointer input
- **THEN** the persisted setting changes, the affected entry points update, and an accessible localized status confirms the result

#### Scenario: Module setting cannot be saved
- **GIVEN** persistence fails while the user changes a module
- **WHEN** the save operation returns an error
- **THEN** the previous enabled state remains in effect and a localized retryable error is announced
