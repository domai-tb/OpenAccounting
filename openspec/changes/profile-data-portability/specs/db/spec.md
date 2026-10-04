## MODIFIED Requirements

### Requirement: Table Definitions

The application database SHALL define one auditable inventory of 43 known application tables. Its 40 required base tables SHALL be `unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`, `inventarbewegungen`, and `feature_table_state`. The three feature-owned tables SHALL be `forderung_zahlungen`, `buchungsvorlagen_occurrences`, and `rechnungsvorlagen_occurrences`. The inventory SHALL record each table's owner, schema version, creation path, and presence rule. SQLite internal objects whose names begin with `sqlite_` are excluded from this application-table inventory. The 40 base tables are required in the application database schema registry and are created by fresh-schema construction or declared versioned migrations; `inventarbewegungen` is owned by inventory, and `feature_table_state` is owned by the database health contract. `forderung_zahlungen` is owned by receivable payments and created by its accepted versioned migration. `buchungsvorlagen_occurrences` is owned by recurring bookings and `rechnungsvorlagen_occurrences` by recurring invoices; each is created only by its owning feature initializer after the marker permits initialization. Each table SHALL match the columns and constraints declared by its accepted owning database or feature specification, and the inventory SHALL record the creating schema version and creation path. A present application table absent from the accepted inventory, a required table absent at its required schema version, or a table whose schema differs from its declared schema SHALL fail schema health; migrations and feature initialization SHALL NOT silently drop, recreate, or replace data-bearing tables.

`feature_table_state` SHALL have `table_name TEXT PRIMARY KEY` constrained to `buchungsvorlagen_occurrences` or `rechnungsvorlagen_occurrences`, and `state TEXT NOT NULL` constrained to `never_initialized`, `initialized`, or `unknown`. It SHALL contain exactly one durable state row for each lazy occurrence table. Fresh database creation SHALL create both rows with `never_initialized`. When migrating an existing profile, a lazy table that exists with its declared schema SHALL be marked `initialized`; an absent lazy table SHALL be marked `unknown` because prior use cannot be disproved without historical state. Lazy feature initialization SHALL create its table and transition its state from `never_initialized` to `initialized` in the same transaction. It SHALL NOT create a table while its marker is `unknown`. State/table mismatches SHALL fail schema health. An `unknown` state may become `never_initialized` only after an explicit integrity reconciliation verifies that the feature was never initialized; it may become `initialized` only after a verified table is restored or its prior data is otherwise verified.

`forderung_zahlungen` SHALL be required at and after the schema version declared by its accepted migration. Before any startup repair or migration that could recreate this table, schema health SHALL compare its presence with `PRAGMA user_version`. If the profile is already at or beyond the required version and the table is absent, initialization SHALL stop before repair, preserve the original database, and mark the profile unavailable for complete export. Recovery SHALL require restoring a verified backup or an explicitly verified manual repair; an empty replacement SHALL NOT be created automatically. At schema versions before that migration, the table is not yet required; exports SHALL be unavailable until normal migration reaches the supported export schema version.

A complete table inventory SHALL be valid only when all 40 base tables exist with declared schemas; `forderung_zahlungen` exists at/after its required schema version; and each lazy table is either present with state `initialized` or absent with state `never_initialized`. An absent lazy table with state `unknown`, any other state/table mismatch, an unknown application table, or a missing required table SHALL prevent a complete inventory. Every feature specification that adds a table SHALL update this inventory before the migration or lazy creation is implemented.

#### Scenario: All Tables Created on Fresh Install

- **GIVEN** the app creates a fresh database at the supported export schema version
- **WHEN** schema creation completes
- **THEN** all 40 base tables SHALL exist with their declared columns and constraints
- **AND** `feature_table_state` SHALL contain `never_initialized` rows for both lazy occurrence tables
- **AND** `forderung_zahlungen` SHALL exist
- **AND** neither lazy occurrence table SHALL exist until its feature is initialized

#### Scenario: Table Count Verification

- **GIVEN** a migration runs against an existing database
- **WHEN** the migration completes
- **THEN** its application-table set SHALL equal the 40 base tables, the migration-required feature tables, and only those lazy tables whose state is `initialized`
- **AND** no existing table SHALL be silently dropped or recreated
- **AND** all table-state pairs SHALL satisfy the declared presence rules

#### Scenario: Known feature-owned tables are inventoried

- **GIVEN** a profile has or has not initialized a declared feature-owned table
- **WHEN** its application schema inventory is inspected
- **THEN** all three feature-owned names SHALL appear in the known inventory
- **AND** the inventory SHALL distinguish required, not-yet-required, initialized, never-initialized, and unknown states

#### Scenario: Existing profile migration records lazy-table uncertainty

- **GIVEN** an existing profile is migrated to the schema version that introduces `feature_table_state`
- **WHEN** the marker rows are initialized
- **THEN** each lazy table already present with its declared schema SHALL be marked `initialized`
- **AND** each absent lazy table SHALL be marked `unknown`
- **AND** migration SHALL NOT infer `never_initialized` from absence alone

#### Scenario: Unknown lazy-table state is not repaired by initialization

- **GIVEN** a lazy occurrence table is absent and its marker state is `unknown`
- **WHEN** its feature is opened or initialized
- **THEN** the feature SHALL remain unavailable pending explicit integrity reconciliation
- **AND** no empty replacement table SHALL be created

#### Scenario: Missing payment table is checked before startup repair

- **GIVEN** `PRAGMA user_version` is at or beyond the accepted `forderung_zahlungen` migration version and that table is absent
- **WHEN** database startup health checks run
- **THEN** the check SHALL fail before any automatic repair can create the table
- **AND** the original database SHALL be preserved and the profile SHALL remain unavailable for complete export

#### Scenario: Missing Table Detection

- **GIVEN** a required table is absent, a table's declared schema is invalid, or an undeclared application table is present
- **WHEN** schema health is checked
- **THEN** the database SHALL be marked unhealthy before an exporter can claim completeness
- **AND** no migration or feature initializer SHALL silently repair the mismatch
