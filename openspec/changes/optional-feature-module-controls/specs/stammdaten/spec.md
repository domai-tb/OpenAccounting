## MODIFIED Requirements

### Requirement: Unternehmen — Profilmanager

The active business's Profile Manager preference SHALL be stored in the module catalog's `unternehmen.feature_modules_json` entry `profile_manager`. `unternehmen.profilmanager_aktiv` SHALL be read only as a migration input and SHALL NOT be a separate runtime state source. When the preference is enabled, the Profile Manager menu item is visible for a single profile. When disabled, it is hidden for a single profile unless more than one profile exists. Profile switching requires a process restart.

#### Scenario: Single profile hides menu

- **GIVEN** the catalog preference `profile_manager` is disabled and only one profile exists
- **WHEN** navigation is rendered
- **THEN** the Profile menu item is not shown

#### Scenario: Multiple profiles force menu visible

- **GIVEN** the catalog preference `profile_manager` is disabled and two profiles exist
- **WHEN** navigation is rendered
- **THEN** the Profile menu item is shown because multiple profiles override the saved preference

### Requirement: Unternehmen — Durable optional module state

The Unternehmen row SHALL store `feature_modules_json` as the canonical versioned JSON module-state object. Catalog version 1 SHALL initialize its `enabled` map with `profile_manager`, `inventory`, and `guv`, defaulting to false for a new profile. On an existing profile, the additive schema migration SHALL copy valid boolean values from `profilmanager_aktiv`, `lagerfuehrung_aktiv`, and `guv_aktiv` when each legacy column exists; absent or invalid values SHALL default to false. The migration SHALL preserve existing module state when the canonical JSON value already exists and is valid. Legacy columns SHALL remain intact as migration inputs but SHALL NOT be written or read as runtime state after backfill. Module-state reads and writes SHALL use the catalog application service and SHALL NOT alter module-owned business records.

#### Scenario: Existing profile flags are backfilled

- **GIVEN** an existing profile has valid legacy module columns and no canonical module state
- **WHEN** the coordinated additive migration runs
- **THEN** it persists the corresponding three values in `feature_modules_json` in the same transaction as the schema change
- **AND** it preserves all legacy values and unrelated company data

#### Scenario: Missing legacy flag receives catalog default

- **GIVEN** an existing profile has no `guv_aktiv` legacy column
- **WHEN** module state is backfilled
- **THEN** `guv` starts disabled unless the maintained accounting threshold subsequently auto-activates it
