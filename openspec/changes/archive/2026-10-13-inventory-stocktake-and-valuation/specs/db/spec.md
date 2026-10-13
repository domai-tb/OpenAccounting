## MODIFIED Requirements

### Requirement: Table Definitions

At schema v18, the declared base registry SHALL contain exactly 41 tables: `unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`, `inventarbewegungen`, `inventuren`, `inventur_positionen`. This is the 39-table pre-stocktake base plus the two named stocktake tables. A fresh schema SHALL also include the seven required migration-owned tables `forderung_zahlungen`, `category_mapping_history`, `feature_table_state`, `mileage_trips`, `mileage_trip_corrections`, `master_data_import_templates`, and `anlage_afa_jahreswerte`, for exactly 48 application tables. Optional lazy tables SHALL exist only when their feature marker is initialized. The schema inventory SHALL match the version-specific table set after each ordered migration; no migration may silently drop an existing table or create an undeclared table.

#### Scenario: All Tables Created on Fresh Install

GIVEN the app runs for the first time with an empty database through schema v18
WHEN schema creation completes at user_version 18
THEN the 41 base tables and seven required migration-owned tables SHALL exist, for exactly 48 application tables
AND each table SHALL have its expected columns and constraints.

#### Scenario: Pre-v13 profile is valid before the coordinated feature migration

- **GIVEN** a profile at schema version 12 has the 39 existing base tables, a valid forderung_zahlungen table, and category_mapping_history
- **AND** feature_table_state, mileage_trips, and mileage_trip_corrections are absent
- **WHEN** schema health is checked before migration
- **THEN** those not-yet-required v13 tables SHALL NOT make the version-12 profile unhealthy
- **AND** the profile SHALL remain ineligible for a complete version-13 export until normal sequential migrations succeed

#### Scenario: Pre-v9 profile is valid before later feature migrations

- **GIVEN** a profile at schema version 8 has the 39 existing base tables and a valid forderung_zahlungen table
- **AND** feature_table_state, mileage_trips, and mileage_trip_corrections are absent
- **WHEN** schema health is checked before migration
- **THEN** those not-yet-required v9 tables SHALL NOT make the version-8 profile unhealthy
- **AND** the profile SHALL remain ineligible for a complete version-10 export until normal sequential migrations succeed

#### Scenario: Missing v7 payment table is created by the v7-to-v8 migration

- **GIVEN** a profile below schema version 8 has no forderung_zahlungen table
- **WHEN** the normal v7-to-v8 migration runs
- **THEN** it SHALL create and verify forderung_zahlungen in its migration transaction
- **AND** it SHALL preserve all other profile rows and increment user_version only after successful verification

#### Scenario: Missing payment table at v8 or later preserves the incomplete signal

- **GIVEN** PRAGMA user_version is 8 or greater and forderung_zahlungen is absent
- **WHEN** startup health checks run before any current-version repair or later migration
- **THEN** profile initialization SHALL stop before repair and leave the profile unavailable for complete export
- **AND** the original database SHALL remain unchanged with the table absent
- **AND** no empty replacement table SHALL be created automatically

#### Scenario: Current payment table repair preserves existing rows

- **GIVEN** a profile at v8 or later has forderung_zahlungen present but is missing a repairable column or required constraint
- **WHEN** the accepted feature repair runs
- **THEN** repair SHALL be transactional and preserve every existing payment row and value
- **AND** schema health SHALL pass only after the declared columns and constraints are verified

#### Scenario: V12-to-v13 migration adds shared markers and mileage tables

- **GIVEN** a valid profile is at schema version 12 with forderung_zahlungen and category_mapping_history present
- **WHEN** the next sequential migration runs
- **THEN** it SHALL create and verify feature_table_state and both mileage tables in the coordinated v13 transaction
- **AND** it SHALL mark existing valid lazy occurrence tables initialized and absent lazy tables unknown
- **AND** it SHALL increment user_version to 13 only after successful verification

#### Scenario: V8-to-v9 migration adds shared markers and mileage tables

- **GIVEN** a valid profile is at schema version 8 with forderung_zahlungen present
- **WHEN** the next sequential migration runs
- **THEN** it SHALL create and verify feature_table_state and both mileage tables in the coordinated v9 transaction
- **AND** it SHALL mark existing valid lazy occurrence tables initialized and absent lazy tables unknown
- **AND** it SHALL increment user_version to 9 only after successful verification

#### Scenario: V9 migration adds category history

- **GIVEN** a valid profile is at schema version 8
- **WHEN** the accounting-catalog-provenance v9 migration runs
- **THEN** it SHALL create and verify category_mapping_history at schema version 9
- **AND** schema health SHALL require the table at version 9 or later

#### Scenario: Unknown lazy-table state is not repaired by initialization

- **GIVEN** a lazy occurrence table is absent and its marker state is unknown
- **WHEN** its feature is opened or initialized
- **THEN** the feature SHALL remain unavailable pending explicit integrity reconciliation
- **AND** no empty replacement table SHALL be created

#### Scenario: Table Count Verification

- **GIVEN** a migration runs against an existing profile
- **WHEN** the migration completes
- **THEN** its application-table set SHALL equal the declared base tables and migration-required feature tables for that version, and only those lazy tables whose marker is initialized
- **AND** no existing table SHALL be silently dropped or recreated
- **AND** all table-state pairs SHALL satisfy their declared presence rules

#### Scenario: Unknown or malformed application tables fail schema health

- **GIVEN** a required table is absent at its required schema version, a declared schema is invalid, or an undeclared application table is present
- **WHEN** schema health is checked
- **THEN** the database SHALL be marked unhealthy before an exporter can claim completeness
- **AND** no migration or feature initializer SHALL silently replace data-bearing tables

#### Scenario: Version-aware table count verification

GIVEN a supported database is upgraded through schema v18
WHEN its declared table set is checked
THEN the v18 base registry SHALL contain exactly 41 tables
AND no table SHALL be silently dropped or created outside the version-specific inventory.

#### Scenario: Missing Table Detection

GIVEN a migration should create one of the declared stocktake tables
WHEN the CREATE TABLE statement fails
THEN the migration SHALL roll back
AND the schema version SHALL NOT be incremented.

### Requirement: Explicit feature-table migrations

Feature migrations SHALL declare every table they add, including its columns, constraints, and schema-version change. The existing inventory movement migration SHALL add the named `inventarbewegungen` table defined in the inventory specification. A separate physical stocktake migration SHALL add exactly `inventuren` and `inventur_positionen` with the columns, constraints, and foreign key defined in the inventory specification. These stocktake tables SHALL store count evidence only; this change SHALL NOT add an inventory valuation or journal table. No other unspecified movement or log table SHALL be created.

#### Scenario: Named inventory table migration

GIVEN the existing inventory movement migration is enabled
WHEN that migration completes
THEN `inventarbewegungen` SHALL exist with the columns and constraints specified by the inventory capability
AND the pre-inventory base tables SHALL remain present
AND the v18 base registry SHALL contain 41 tables after the stocktake migration.

#### Scenario: Named stocktake table migration

GIVEN the physical stocktake migration is enabled
WHEN that migration completes
THEN `inventuren` and `inventur_positionen` SHALL exist with the columns and constraints specified by the inventory capability
AND existing article and movement rows SHALL retain their values
AND the v18 base registry SHALL increase from 39 to 41.

#### Scenario: Empty recorded header insert is rejected by the database

GIVEN the stocktake tables are installed and no positions exist for a new header
WHEN direct SQL inserts an `inventuren` row with status `erfasst`
THEN the database guard SHALL reject the insert
AND no empty recorded stocktake SHALL persist.

#### Scenario: Recorded count immutability is enforced by the database

GIVEN the stocktake tables are installed and a header has status `erfasst`
WHEN direct SQL attempts to update or delete that header or mutate one of its positions
THEN the database guard SHALL reject the mutation
AND the recorded count evidence SHALL remain unchanged.

#### Scenario: Failed stocktake migration leaves prior schema intact

GIVEN the physical stocktake migration fails while creating a declared constraint
WHEN migration error handling completes
THEN neither stocktake table SHALL remain
AND the schema version and pre-existing article and movement rows SHALL retain their pre-migration values.
