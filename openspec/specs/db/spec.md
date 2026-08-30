# OpenInvoices — Database Layer Specification

## ADDED Requirements

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

The database SHALL contain exactly 38 tables: `unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`.

#### Scenario: All Tables Created on Fresh Install

GIVEN the app runs for the first time with an empty database
WHEN schema creation completes
THEN all 38 tables SHALL exist
AND each table SHALL have its expected columns and constraints

#### Scenario: Table Count Verification

GIVEN a migration runs against an existing database
WHEN the migration completes
THEN the total table count SHALL remain exactly 38
AND no table SHALL be silently dropped

#### Scenario: Missing Table Detection

GIVEN a migration should create a new table
WHEN the CREATE TABLE statement fails
THEN the migration SHALL roll back
AND the schema version SHALL NOT be incremented

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
THEN `_migrate_kategorien()` SHALL run to ensure seed categories exist
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

The following seed data SHALL be inserted on fresh database creation: `ust_saetze` (0%, 7%, 19%), `nummernkreise` (all document types), `eu_laender` (EU member states with USt-IdNr formats), `bank_templates` (PayPal, N26, Vivid, CAMT XML), and `kategorien` (standard SKR03/SKR04 categories with EÜR line assignments).

#### Scenario: USt-Sätze Seeded

GIVEN a fresh database is created
WHEN seed data is inserted
THEN `ust_saetze` SHALL contain exactly 3 rows: 0%, 7%, 19%
AND each row SHALL have a descriptive label

#### Scenario: Nummernkreise Seeded

GIVEN a fresh database is created
WHEN seed data is inserted
THEN `nummernkreise` SHALL contain entries for: rechnung_ausgang, rechnung_eingang, angebot, auftrag, proforma, lieferschein, stornorechnung, gutschrift, debitor, kreditor, bank_import
AND each SHALL have a format string and active flag

#### Scenario: Kategorien Seeded With SKR Accounts

GIVEN a fresh database is created
WHEN seed data is inserted
THEN `kategorien` SHALL contain at minimum 80 standard categories
AND each SHALL have `konto_skr03`, `konto_skr04`, and `euer_zeile` values where applicable
AND categories SHALL use "Du"-form descriptions

#### Scenario: Seed Data Not Duplicated on Restart

GIVEN seed data has already been inserted
WHEN the app restarts
THEN no duplicate seed rows SHALL be inserted
AND existing seed data SHALL remain unchanged

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
