# OpenInvoices — Database Layer Specification

## Purpose
SQLite engine configuration, Drift schema management, migration strategy, and connection lifecycle.

## Requirements

### Requirement: SQLite Engine Configuration

The database engine SHALL use SQLite with WAL journal mode and foreign keys enabled. WAL mode SHALL be set on every connection open. Foreign keys SHALL be enforced at the connection level via `PRAGMA foreign_keys = ON`.

#### Scenario: WAL Mode on Connection

GIVEN a new database connection is opened
WHEN the connection is initialized
THEN `PRAGMA journal_mode = WAL` SHALL be executed before any query
AND the journal mode SHALL be confirmed as "wal"

#### Scenario: WAL Mode Already Active

GIVEN the database already has WAL journal mode from a prior connection
WHEN a new connection opens
THEN `PRAGMA journal_mode = WAL` SHALL be executed
AND the operation SHALL be idempotent with no side effects

#### Scenario: Foreign Key Enforcement

GIVEN `PRAGMA foreign_keys = ON` is active on the connection
WHEN a row references a non-existent parent via a FOREIGN KEY
THEN SQLite SHALL reject the INSERT/UPDATE with a constraint violation error

#### Scenario: Foreign Key Enforcement Disabled by Default

GIVEN `PRAGMA foreign_keys` has not been set on a connection
WHEN a row references a non-existent parent via a FOREIGN KEY
THEN SQLite SHALL allow the INSERT/UPDATE without error
AND the orphaned reference SHALL persist in the database

### Requirement: Data Type Precision

All monetary columns SHALL use `NUMERIC(12,2)`. Article net prices (`vk_netto`) and related pricing columns SHALL use `NUMERIC(12,4)` to prevent rounding drift across Netto/Brutto invoice calculations.

#### Scenario: Money Column Precision

GIVEN a NUMERIC(12,2) column exists in a table
WHEN a value of 123456789.12 is stored
THEN the stored value SHALL be exactly 123456789.12
AND no floating-point imprecision SHALL be observable

#### Scenario: Money Column Overflow

GIVEN a NUMERIC(12,2) column exists in a table
WHEN a value exceeding 12 digits is stored
THEN SQLite SHALL truncate or round to fit NUMERIC(12,2) precision
AND the application SHALL handle the rounding silently

#### Scenario: Article Price Precision

GIVEN `vk_netto` is defined as NUMERIC(12,4)
WHEN `vk_netto` stores 2.9412
AND 100 units are invoiced
THEN the line total SHALL be exactly 294.12
AND not 294.119999... or 294.13

#### Scenario: Article Price Zero

GIVEN `vk_netto` is defined as NUMERIC(12,4)
WHEN a value of 0.0000 is stored
THEN the stored value SHALL be exactly 0.0000
AND no floating-point artifacts SHALL appear

### Requirement: Table Definitions

The application database SHALL maintain one auditable inventory of 46 known application-table names, partitioned as 39 pre-existing base tables, one shared database-health table, and six feature-owned tables. The 39 pre-existing base tables SHALL remain the current AppDatabase.allTableNames entries: unternehmen, kunden, lieferanten, artikel, journal, rechnungen, rechnungspositionen, kategorien, konten, nummernkreise, ust_saetze, tagesabschluesse, belege, mahnungen, mahnstufen, mahnwesen_einstellungen, forderungen, bank_transaktionen, bank_templates, bank_imports, kunden_belege, kunden_lieferadressen, artikel_gruppen, rechnungsvorlagen, buchungsvorlagen, anlageverzeichnis, dokumentenpakete, dokumentenpaket_belege, ustva_exporte, euer_exporte, eks_exporte, datev_export_log, eu_laender, eks_einstellungen, vorsteuer_ansprueche, schnellbuchungen, auto_filter_regeln, import_mapping_vorlagen, and inventarbewegungen. The shared database-health table SHALL be feature_table_state. At schema version 13 it is required in addition to the existing 39 base tables; it remains separate from the legacy 39-name AppDatabase.allTableNames count. The six feature-owned table names SHALL be forderung_zahlungen, buchungsvorlagen_occurrences, rechnungsvorlagen_occurrences, mileage_trips, mileage_trip_corrections, and category_mapping_history. SQLite internal objects whose names begin with sqlite_ are excluded from this application-table inventory.

The inventory SHALL record each table owner, its required migration version or lazy-state rule, its declared schema, creation path, and presence rule. The feature-owned presence rules SHALL be: forderung_zahlungen is introduced by the accepted v7-to-v8 migration and required at user_version 8 or later; mileage_trips and mileage_trip_corrections are created together and required at user_version 13 or later; category_mapping_history is owned by accounting-catalog-provenance, created by its v9 migration, and required at user_version 9 or later; the two occurrence tables are owned by recurring features and follow the v13 feature_table_state markers.

At versions before a table's required migration version, that table is not yet required and its absence SHALL NOT make that older schema unhealthy. At a version at or beyond its required migration version, a migration-required table SHALL exist with its declared schema. Before v8, forderung_zahlungen MAY be absent or may exist in its accepted legacy v7 shape; the normal v7-to-v8 migration SHALL create it when absent. At v8 or later, absence of forderung_zahlungen is an integrity failure: startup SHALL detect it before current-version repair or any migration that could recreate it, stop profile initialization, preserve the original database, and leave the profile unavailable for complete export until verified recovery. It SHALL NOT create an empty replacement. The missing table remains the durable completeness signal. A present forderung_zahlungen table with a repairable schema or constraint defect MAY use the accepted transactional, row-preserving repair path; a repair that cannot preserve and verify its rows SHALL fail without changing the database.

The shared feature_table_state table SHALL be introduced at schema version 13 and SHALL contain exactly one durable row for each lazy occurrence table. Its table_name SHALL be constrained to buchungsvorlagen_occurrences or rechnungsvorlagen_occurrences, and state SHALL be constrained to never_initialized, initialized, or unknown. Fresh creation at version 13 or later SHALL seed both rows as never_initialized. The v12-to-v13 migration SHALL classify an existing lazy table with its declared schema as initialized and an absent lazy table as unknown; absence alone SHALL NOT imply never_initialized. Feature initialization SHALL create a lazy table and transition its marker from never_initialized to initialized in the same transaction. It SHALL NOT create a table while its marker is unknown. State/table mismatches SHALL fail schema health. Unknown may become never_initialized only after explicit integrity reconciliation verifies that the feature was never initialized; it may become initialized only after a verified table is restored or its prior data is otherwise verified. Before schema version 13, the marker table is not yet required and legacy lazy-table presence is not judged against marker rows.

A complete version-13 inventory SHALL be valid only when all 39 existing base tables and feature_table_state exist with declared schemas, forderung_zahlungen exists at or after v8, both mileage tables exist at or after v13, category_mapping_history exists at or after v9, and each lazy occurrence table is present with state initialized or absent with state never_initialized. An absent lazy table with state unknown, a missing required marker row, any state/table mismatch, an unknown application table, or a missing or malformed required table SHALL prevent a complete inventory. Before v13, older profiles may remain valid for their own schema version but SHALL NOT be reported as complete version-13 exports. Every feature specification that adds a table SHALL update this inventory before migration or lazy creation is implemented.

#### Scenario: All Tables Created on Fresh Install

- **GIVEN** the application creates a fresh profile at supported schema version 13
- **WHEN** schema creation completes
- **THEN** all 39 existing base tables and feature_table_state SHALL exist with declared schemas
- **AND** feature_table_state SHALL contain never_initialized rows for both lazy occurrence tables
- **AND** forderung_zahlungen, mileage_trips, mileage_trip_corrections, and category_mapping_history SHALL exist
- **AND** neither lazy occurrence table SHALL exist until its owning feature is initialized

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
- **THEN** its application-table set SHALL equal the 39 existing base tables, the shared marker and migration-required feature tables for that version, and only those lazy tables whose marker is initialized
- **AND** no existing table SHALL be silently dropped or recreated
- **AND** all table-state pairs SHALL satisfy their declared presence rules

#### Scenario: Unknown or malformed application tables fail schema health

- **GIVEN** a required table is absent at its required schema version, a declared schema is invalid, or an undeclared application table is present
- **WHEN** schema health is checked
- **THEN** the database SHALL be marked unhealthy before an exporter can claim completeness
- **AND** no migration or feature initializer SHALL silently replace data-bearing tables

#### Scenario: Missing Table Detection

- **GIVEN** a sequential migration is creating a required application table and its `CREATE TABLE` step fails
- **WHEN** the migration transaction rolls back
- **THEN** the migration SHALL leave no partial table or schema change
- **AND** `PRAGMA user_version` SHALL remain at the pre-migration version

### Requirement: Schema Versioning

The database SHALL use `PRAGMA user_version` for schema version tracking. The version number SHALL be a monotonically increasing integer. Each migration SHALL increment the version by exactly 1.

#### Scenario: Fresh Database Gets Current Version

GIVEN a new database is created
WHEN schema creation completes
THEN `PRAGMA user_version` SHALL equal the current schema version
AND all migrations SHALL be skipped

#### Scenario: Outdated Database Triggers Migration

GIVEN a database with `user_version` less than the current schema version is opened
WHEN the app initializes
THEN the migration sequence SHALL execute
AND `user_version` SHALL be updated to the current version after successful completion

#### Scenario: Already Current Database Skips Migration

GIVEN a database with `user_version` equal to the current schema version
WHEN the app initializes
THEN no migration code SHALL execute
AND no backup SHALL be created

#### Scenario: Future Database Version Rejected

GIVEN a database with `user_version` greater than the current schema version
WHEN the app initializes
THEN the app SHALL handle the version mismatch gracefully
AND SHALL NOT attempt to downgrade the schema

### Requirement: Migration System

Every migration SHALL back up the database before execution. Migrations SHALL be idempotent where possible. Post-migration hooks SHALL execute after all version migrations complete (e.g., category seeding, trigger setup).

#### Scenario: Backup Before Migration

GIVEN a migration is about to begin
WHEN the migration starts
THEN a WAL-safe backup SHALL be created in the backups directory
AND the backup filename SHALL include the timestamp

#### Scenario: Idempotent Migration Re-run

GIVEN the app restarts and the database is already at the current version
WHEN the migration system runs
THEN no migration code SHALL execute
AND the backup SHALL NOT be created

#### Scenario: Post-Migration Hooks

GIVEN all version migrations complete successfully
WHEN the post-migration phase begins
THEN the category seed gate SHALL run and create no preconfigured mappings without an approved manifest
AND `_migrate_signaturen()` SHALL run to ensure signature defaults exist
AND `_setup_gobd_triggers()` SHALL install or reinstall GoBD triggers

#### Scenario: Migration Failure Rolls Back

GIVEN a migration is in progress
WHEN a migration step fails with an unhandled error
THEN the schema version SHALL NOT be incremented
AND the backup SHALL be preserved for manual recovery

### Requirement: GoBD Triggers

Journal rows marked as `immutable` SHALL be protected from UPDATE and DELETE by database triggers. The triggers SHALL raise an error with a descriptive message if modification is attempted.

#### Scenario: Immutable Journal Row Protection

GIVEN a row in `journal` has `immutable = 1`
WHEN an UPDATE or DELETE is attempted on that row
THEN the trigger SHALL raise an error: "GoBD: Dieser Journaleintrag ist unveränderlich"
AND the transaction SHALL be rolled back

#### Scenario: Mutable Journal Row Modification

GIVEN a row in `journal` has `immutable = 0`
WHEN an UPDATE or DELETE is attempted on that row
THEN the operation SHALL succeed normally

#### Scenario: Trigger Reinstall After Migration

GIVEN a migration has completed
WHEN `_setup_gobd_triggers()` runs
THEN all GoBD triggers SHALL be dropped and recreated
AND the triggers SHALL apply to the current table schema

#### Scenario: Trigger Protects Against Direct SQL

GIVEN a row in `journal` has `immutable = 1`
WHEN a raw SQL UPDATE or DELETE targets that row
THEN the trigger SHALL still raise the GoBD error
AND the operation SHALL be rolled back

### Requirement: Profile Management

Each user profile SHALL have an isolated database file. The active profile SHALL be tracked via a `profile.json` pointer file. A profile switch SHALL require a process restart.

#### Scenario: Profile Directory Isolation

GIVEN a profile named "Max" is active
WHEN the database path is resolved
THEN the database SHALL be located at `~/.local/share/OpenInvoices/profile/Max/openinvoices.db`
AND a different profile "Erika" SHALL have its own database at `~/.local/share/OpenInvoices/profile/Erika/openinvoices.db`

#### Scenario: Profile Switch Requires Restart

GIVEN the user is on profile "Max"
WHEN the user switches to profile "Erika"
THEN the app SHALL display a restart prompt
AND the new profile SHALL not be active until the app restarts

#### Scenario: Profile Switch Does Not Affect Other Profiles

GIVEN profile "Max" has data in its database
WHEN the user switches to profile "Erika"
THEN "Max" database SHALL remain untouched
AND "Erika" database SHALL load independently

### Requirement: Backup System

Backups SHALL be WAL-safe using SQLite's online backup API. Up to 5 backups SHALL be retained, with the oldest automatically deleted. External backups SHALL support AES-256-GCM encryption to configurable paths (NAS, USB).

#### Scenario: WAL-Safe Backup Creation

GIVEN the database is in WAL mode with uncommitted WAL entries
WHEN a backup is triggered
THEN the backup SHALL be a consistent snapshot
AND the backup file SHALL be a valid SQLite database

#### Scenario: Backup Rotation

GIVEN 5 backups already exist
WHEN a 6th backup is created
THEN the oldest backup SHALL be automatically deleted
AND exactly 5 backups SHALL remain

#### Scenario: Encrypted External Backup

GIVEN an external backup path is configured with a password
WHEN a backup is triggered
THEN the backup file SHALL be encrypted with AES-256-GCM
AND the file extension SHALL be `.enc`

#### Scenario: Backup Directory Does Not Exist

GIVEN the backups directory has not been created yet
WHEN a backup is triggered
THEN the backup system SHALL create the directory
AND the backup SHALL proceed normally

### Requirement: Seed Data

Fresh database creation SHALL seed `ust_saetze` (0%, 7%, 19%), `nummernkreise` (all document types), `eu_laender` (EU member states with USt-IdNr formats), and the separately specified `bank_templates`. Category mappings SHALL be seeded only from an approved, versioned accounting-catalog manifest carrying source reference, source version, and accounting review status. Without such a manifest, a fresh profile SHALL have no preconfigured SKR03, SKR04, EÜR, or EKS category mappings and SHALL expose an explicit unconfigured state. Seed logic MUST NOT generate accounting mappings from identifiers, arithmetic, or placeholder labels.

#### Scenario: Fresh profile without an approved category catalog

- **GIVEN** a fresh database is created and no approved accounting-catalog manifest is bundled
- **WHEN** seed data is inserted
- **THEN** no category is created with a generated SKR03, SKR04, EÜR, or EKS mapping
- **AND** the profile reports category accounting setup as unconfigured

#### Scenario: Fresh Profile Without Approved Catalog Has No Preconfigured Mappings

- **GIVEN** a fresh database is created and no approved accounting-catalog manifest is bundled
- **WHEN** seed data is inserted
- **THEN** no category SHALL be created with a generated SKR03, SKR04, EÜR, or EKS mapping
- **AND** the profile SHALL report category accounting setup as unconfigured

#### Scenario: USt-Sätze Seeded

- **GIVEN** a fresh database is created
- **WHEN** seed data is inserted
- **THEN** `ust_saetze` contains exactly 3 rows: 0%, 7%, and 19%
- **AND** each row has a descriptive label

#### Scenario: Nummernkreise Seeded

- **GIVEN** a fresh database is created
- **WHEN** seed data is inserted
- **THEN** `nummernkreise` contains entries for `rechnung_ausgang`, `rechnung_eingang`, `angebot`, `auftrag`, `proforma`, `lieferschein`, `stornorechnung`, `gutschrift`, `debitor`, `kreditor`, and `bank_import`
- **AND** each entry has a format string and active flag

#### Scenario: Kategorien Seeded With SKR Accounts

- **GIVEN** a fresh database is created with an approved accounting-catalog manifest
- **WHEN** seed data is inserted
- **THEN** each seeded category and applicable mapping matches a manifest entry exactly
- **AND** each mapped category records its source release and `catalog_verified` status

#### Scenario: Approved category manifest is seeded with provenance

- **GIVEN** a bundled manifest has an approved source reference, version, and accounting review status
- **WHEN** seed data is inserted
- **THEN** each catalog category's mapped values match its manifest entry exactly
- **AND** each category records the manifest entry key, source version, and `catalog_verified` status

#### Scenario: Unapproved manifest is rejected

- **GIVEN** a manifest is missing source/version metadata or approved accounting review status
- **WHEN** seed data is inserted
- **THEN** none of its category mappings are persisted as `catalog_verified`
- **AND** the profile reports category accounting setup as unconfigured

#### Scenario: Existing categories are preserved during migration

- **GIVEN** a profile contains categories with arbitrary user edits and journal references
- **WHEN** the provenance migration runs
- **THEN** each preexisting category is marked `legacy_unverified`
- **AND** its ID, name, description, mapping values, active state, and journal references remain unchanged

#### Scenario: Seed restart preserves reviewed category values

- **GIVEN** a category has been edited and explicitly confirmed by the user
- **WHEN** seed logic runs again
- **THEN** the edited values and `user_confirmed` status remain unchanged

#### Scenario: Seed Data Not Duplicated on Restart

- **GIVEN** seed data has already been inserted
- **WHEN** the app restarts
- **THEN** no duplicate seed rows are inserted
- **AND** existing seed data remains unchanged

### Requirement: Indexes and Constraints

Partial unique indexes SHALL enforce: kunden kundennummer (unique where not null), lieferanten lieferantennummer (unique where not null), bank_transaktionen dedupe_hash (unique where not null on konto_id + hash).

#### Scenario: Duplicate Konto-Nummer Rejected

GIVEN a customer with kundennummer "K-001" already exists
WHEN a second customer with kundennummer "K-001" is inserted
THEN the insert SHALL fail with a unique constraint violation

#### Scenario: Null Kundennummer Allowed

GIVEN one customer exists with kundennummer = null
WHEN another customer is inserted with kundennummer = null
THEN both inserts SHALL succeed
AND the partial index SHALL not conflict

#### Scenario: Duplicate Dedupe Hash Rejected

GIVEN a bank transaction with a specific dedupe_hash exists for konto_id 1
WHEN another transaction with the same dedupe_hash and konto_id 1 is inserted
THEN the insert SHALL fail with a unique constraint violation

#### Scenario: Dedupe Hash Null Allowed

GIVEN a bank transaction exists with dedupe_hash = null
WHEN another transaction with dedupe_hash = null and the same konto_id is inserted
THEN the insert SHALL succeed
AND the partial index SHALL not apply to null hashes

### Requirement: Explicit feature-table migrations

Feature migrations SHALL declare every table they add, including its columns, constraints, and schema-version change. The inventory feature SHALL add the named `inventarbewegungen` table defined in the inventory specification; no unspecified movement or log table SHALL be created.

#### Scenario: Named inventory table migration

GIVEN the inventory feature migration is enabled
WHEN the migration completes
THEN the `inventarbewegungen` table SHALL exist with the columns and constraints specified by the inventory feature
AND the 38 base tables SHALL remain present.

### Requirement: Company fiscal-year start month migration

Fresh `unternehmen` table creation SHALL include `geschaeftsjahr_startmonat INTEGER NOT NULL DEFAULT 1 CHECK (geschaeftsjahr_startmonat BETWEEN 1 AND 12)`. Existing profile databases SHALL receive the equivalent column through an ordered migration that backfills existing company rows to January and preserves all other company fields and rows. Fresh creation SHALL NOT depend on incremental migrations, since the fresh-schema path sets the current schema version directly. Both paths SHALL verify the 1–12 constraint and preserve schema-version atomicity.

#### Scenario: Fresh company schema defaults to January

- **GIVEN** a fresh profile creates its `unternehmen` table from the current schema
- **WHEN** a company is created without a fiscal-year override
- **THEN** `geschaeftsjahr_startmonat` SHALL be `1`
- **AND** the fresh database SHALL not depend on an incremental migration to supply the value

#### Scenario: Existing company rows are migrated

- **GIVEN** a database contains one or more company rows without a fiscal-year start month
- **WHEN** the ordered fiscal-year migration completes
- **THEN** every existing company row SHALL have `geschaeftsjahr_startmonat = 1`
- **AND** all prior values SHALL remain unchanged

#### Scenario: Migration failure preserves the prior database

- **GIVEN** the fiscal-year migration cannot add or verify the required column
- **WHEN** migration handling completes
- **THEN** the migration SHALL roll back
- **AND** the schema version and pre-existing company data SHALL remain at their pre-migration values

### Requirement: Quick-booking presets store explicit execution semantics

The `schnellbuchungen` schema SHALL store direction (`art` constrained to `einnahme` or `ausgabe`), optional `ust_satz_id` referencing `ust_saetze`, `eingabemodus` constrained to `netto` or `brutto`, and an optional default `betrag`, in addition to its current stable ID, name, category, account, and description. Migration SHALL preserve existing rows and values, add no inferred direction/tax/basis, and leave incomplete legacy presets reviewable but non-executable. Fresh schema and migration definitions SHALL agree. Any table rebuild required to make `betrag` nullable SHALL preserve stable preset IDs and every existing value.

#### Scenario: Fresh schema stores the complete preset contract

- **GIVEN** a fresh profile is created with Quick Bookings enabled
- **WHEN** the schema is created
- **THEN** `schnellbuchungen` SHALL contain the declared direction, tax, amount-basis, and optional amount fields
- **AND** constraints SHALL reject unsupported direction or amount basis values.

#### Scenario: Legacy preset migration preserves values

- **GIVEN** an existing profile contains quick-booking rows without direction, tax, or amount-basis fields
- **WHEN** the ordered migration completes
- **THEN** every existing preset ID and stored value SHALL remain unchanged
- **AND** the new fields SHALL remain null until reviewed by a user.

#### Scenario: Failed table rebuild rolls back

- **GIVEN** the migration needed to make the default amount optional fails
- **WHEN** migration error handling completes
- **THEN** the prior table, rows, IDs, and schema version SHALL remain unchanged.

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

### Requirement: Category mapping provenance is persisted

On the next sequential migration (version 9 from the current version-8 baseline; reassigned from version 10 because no accepted v9 migration had landed when implemented and no approved DDL exists for the mileage/marker tables), the database SHALL add `mapping_status TEXT NOT NULL DEFAULT 'legacy_unverified' CHECK (mapping_status IN ('catalog_verified','user_confirmed','legacy_unverified','review_required','unmapped'))`, nullable `catalog_entry_key`, `catalog_source_reference`, `catalog_source_version`, and `mapping_reviewed_at` fields to `kategorien`. Adding the status column with the safe literal default SHALL classify all existing rows without rewriting category values, and the migration SHALL verify the backfill before commit. The default SHALL remain `legacy_unverified` for legacy insert paths; only an approved manifest import or explicit user-review transaction may set a trusted status. SQLite DDL, mapping snapshots, and history inserts SHALL run in the same migration transaction so any failure restores the original schema and rows. `mapping_status` SHALL allow only `catalog_verified`, `user_confirmed`, `legacy_unverified`, `review_required`, or `unmapped`. The migration SHALL create `category_mapping_history` with `id INTEGER PRIMARY KEY`, a foreign-key category ID (`ON DELETE RESTRICT`), UTC RFC 3339 change timestamp, action (`migration`, `catalog_import`, `mapping_edit`, or `user_review`), previous mapping JSON, new mapping JSON, and catalog source reference/version. Each `new_mapping_json` SHALL include every persisted mapping value and resulting status. History rows SHALL be append-only; UPDATE and DELETE SHALL be rejected. Saving any mapping change and its history record SHALL be one transaction. Categories with history SHALL be deactivated rather than physically deleted. The migration SHALL add nullable `mapping_provenance_json` columns to `euer_exporte` and `datev_export_log`; new category-mapped output SHALL persist a version-1 JSON snapshot that records the exact resolved mapping values and immutable `category_mapping_history.id` used for each category, while preexisting export rows remain NULL. The snapshot SHALL contain `mappings`, whose entries contain `category_id`, `status`, `history_id`, catalog source fields, and `resolved_values` with every applicable mapping key (including null values); DATEV snapshots SHALL also contain one `datev_accounts` entry per emitted slot with `journal_id`, `slot` (`Konto` or `Gegenkonto`), emitted `account_number`, `source`, and category/history reference when applicable. The migration SHALL preserve existing IDs, names, descriptions, mapping values, active state, and journal references while marking preexisting categories `legacy_unverified` and recording their pre-migration values.

#### Scenario: Provenance migration preserves and marks existing categories

- **GIVEN** a profile contains categories with arbitrary mapping edits and journal references
- **WHEN** the provenance migration runs
- **THEN** the category rows retain their IDs and values and receive `legacy_unverified` status
- **AND** a migration history record preserves each row's prior mapping values

#### Scenario: Mapping status and values update atomically

- **GIVEN** a user edits or reviews one or more category mapping fields
- **WHEN** the category mapping action saves
- **THEN** the category values, resulting provenance status, review timestamp when applicable, and history record commit together
- **AND** a failed transaction leaves all of them unchanged

#### Scenario: Export records persist the mapping provenance snapshot

- **GIVEN** an EÜR or DATEV export is generated using category mappings
- **WHEN** the export record is persisted
- **THEN** `euer_exporte.mapping_provenance_json` or `datev_export_log.mapping_provenance_json` stores a version-1 snapshot whose DATEV `datev_accounts` array contains one object per emitted `Konto` or `Gegenkonto` slot, including journal ID, slot, exact number, source, and category/history reference when applicable
- **AND** every emitted account is bound to the exact persisted mapping value and resolver source
- **AND** existing export rows remain unchanged with NULL provenance metadata
- **AND** new history and review timestamps use UTC ISO-8601 format
