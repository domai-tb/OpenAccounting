## ADDED Requirements

### Requirement: Company feature module state schema and migration

The `unternehmen` table SHALL include a nullable `feature_modules_json TEXT` column in fresh schemas and after migration. The stored value SHALL use the versioned catalog shape defined by the `feature-modules` capability. Profile initialization SHALL persist the version-1 defaults when no canonical value or valid legacy preference exists.

The additive migration SHALL add the column when absent and backfill only rows whose canonical value is `NULL`. It SHALL read `profilmanager_aktiv`, `lagerfuehrung_aktiv`, and `guv_aktiv` only when each legacy column exists; only integer boolean values `0` and `1` are valid, and an absent or invalid value SHALL become `false`. The migration SHALL preserve all legacy columns and values, every non-NULL canonical value, unrelated company data, and the existing table count. It SHALL NOT add, remove, or rewrite module-owned business records.

The migration SHALL run in the next sequential schema version. With the maintained version-8 baseline, it SHALL be version 9 if no other accepted migration changes that baseline first; it SHALL merge its column and backfill work into any other accepted version-9 migration instead of introducing a competing version increment. Column creation, backfill, and schema-version update SHALL commit atomically. On failure, they SHALL roll back together and leave the prior schema version in place.

#### Scenario: Fresh schema includes canonical state column

- **GIVEN** a new profile database is created
- **WHEN** the database schema is initialized
- **THEN** `unternehmen.feature_modules_json` exists as a `TEXT` column
- **AND** profile initialization persists the catalog's version-1 default state

#### Scenario: Existing profile receives legacy preferences

- **GIVEN** an existing profile is at schema version 8, its canonical value is `NULL`, and any subset of legacy module columns exists
- **WHEN** the coordinated additive migration runs
- **THEN** it adds `feature_modules_json` and stores all three catalog IDs, using each valid legacy value and `false` for each absent or invalid value
- **AND** legacy columns and values, unrelated company data, and the table count remain unchanged
- **AND** `PRAGMA user_version` advances by exactly one after the migration commits

#### Scenario: Existing canonical value is preserved

- **GIVEN** an existing company row has a non-NULL `feature_modules_json` value
- **WHEN** the additive migration runs
- **THEN** the migration leaves that value and every legacy value unchanged

#### Scenario: Same-version migration work is coordinated

- **GIVEN** another accepted change also requires a schema-version-9 migration from the version-8 baseline
- **WHEN** both migrations are incorporated
- **THEN** the column and backfill work are included in the single version-9 migration
- **AND** `PRAGMA user_version` advances from 8 to 9 only once

#### Scenario: Feature module migration failure rolls back

- **GIVEN** the feature module column and backfill migration has begun
- **WHEN** adding the column or backfilling a row fails
- **THEN** the transaction rolls back the schema and value changes
- **AND** `PRAGMA user_version` remains at its prior value
