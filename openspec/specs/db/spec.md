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

SQLite column declarations such as `NUMERIC(12,2)` select numeric affinity but do not enforce decimal scale, precision, truncation, or rounding. Currency columns SHALL retain their `NUMERIC(12,2)` declarations; `vk_netto` and related article pricing columns SHALL retain `NUMERIC(12,4)`; invoice unit-price columns SHALL use `NUMERIC(12,4)` and invoice quantity columns `NUMERIC(12,3)`. These declarations document the storage contract but do not enforce it. Application boundaries MUST validate accepted ranges and decimal scales and MUST reject overflow or excess scale rather than silently changing a value. Invoice header and line currency amounts SHALL be persisted as cents. Invoice unit prices SHALL preserve four decimal places up to `99,999,999.9999` and invoice quantities three decimal places up to `999,999,999.999` through save, reload, and supported conversion. Tests SHALL verify these guarantees against the actual SQLite executor; no claim of database-enforced decimal precision is permitted.

#### Scenario: Invoice price and quantity retain application precision in SQLite
- **GIVEN** an invoice position contains unit price `12.3456` and quantity `1.234`
- **WHEN** it is inserted and reloaded through the app's SQLite executor
- **THEN** both values are unchanged at their accepted scales

#### Scenario: Money Column Precision
- **GIVEN** a currency column stores `123456789.12` through the application money boundary
- **WHEN** the value is stored and reloaded
- **THEN** it is exactly `123456789.12` with no observable floating-point imprecision

#### Scenario: Money Column Overflow
- **GIVEN** a currency value exceeds the supported 12-digit range
- **WHEN** it is submitted through the application money boundary
- **THEN** application validation rejects it before SQLite receives it
- **AND** the application does not silently round or truncate it

#### Scenario: Article Price Precision
- **GIVEN** `vk_netto` stores `2.9412` and 100 units are invoiced
- **WHEN** the line total is calculated
- **THEN** the line total is exactly `294.12`
- **AND** it is neither `294.119999...` nor `294.13`

#### Scenario: Article Price Zero
- **GIVEN** `vk_netto` stores `0.0000`
- **WHEN** it is stored and reloaded through the application boundary
- **THEN** its numeric value remains exactly zero
- **AND** no floating-point artifact changes the calculated line amount

#### Scenario: Excess scale is rejected by the application
- **GIVEN** a caller submits a unit price with five fractional digits or quantity with four
- **WHEN** the invoice boundary validates the values
- **THEN** the write is rejected and SQLite receives no rounded or truncated substitute

#### Scenario: Values beyond the supported range are rejected
- **GIVEN** an invoice unit price exceeds `99,999,999.9999` or quantity exceeds `999,999,999.999`
- **WHEN** the invoice boundary validates it
- **THEN** the write is rejected with `valueOutOfRange` before SQLite receives a substitute value

#### Scenario: SQLite declaration does not promise overflow rounding
- **GIVEN** a `NUMERIC(12,2)` column is used by an application
- **WHEN** an out-of-range value is submitted through the supported money boundary
- **THEN** application validation rejects it without relying on SQLite to round or truncate it

### Requirement: Mileage persistence schema

The database SHALL create `mileage_trips` and `mileage_trip_corrections` on fresh install and through an additive schema migration. `mileage_trips` SHALL contain:

- `id TEXT PRIMARY KEY NOT NULL`, a stable UUID.
- `trip_date TEXT NOT NULL`, canonical valid `YYYY-MM-DD`.
- `purpose TEXT NOT NULL` and `business_context TEXT NOT NULL`, each constrained to non-empty trimmed text.
- `trip_kind TEXT NOT NULL`, constrained to `business_trip`, `commuting`, `eks_allowance`, `other`, or `unknown`.
- `vehicle_source TEXT NOT NULL`, constrained to `private`, `company`, or `unknown`.
- `vehicle_class TEXT NOT NULL`, constrained to `kraftwagen`, `other_motor_vehicle`, `unsupported`, or `unknown`.
- `distance_hundredths_km INTEGER NOT NULL`, constrained to 1 through 999,999,999,999 inclusive. The UI value is this integer divided by 100; no binary floating-point distance is persisted.
- `state TEXT NOT NULL`, constrained to `unresolved`, `calculated`, `posted`, `corrected`, or `voided`.
- Nullable policy snapshot columns `policy_id TEXT`, `policy_source TEXT`, `policy_version TEXT`, `policy_effective_from TEXT`, `policy_effective_to TEXT`, `calculated_amount NUMERIC(12,2)`, and `calculated_at TEXT`. These columns SHALL be either all null or all non-null; non-null text values SHALL be non-empty, dates canonical, and amount non-negative. There is no policy-table foreign key because this change does not define the policy registry.
- `posting_event_id TEXT UNIQUE`, nullable until the accepted accounting boundary returns its stable event ID.
- `created_at TEXT NOT NULL` and `updated_at TEXT NOT NULL`, UTC RFC 3339 timestamps.

Trip INSERTs SHALL begin in `unresolved` with null policy snapshot, amount, and posting reference; direct insertion in any later state MUST be rejected. The row-state constraint SHALL require all policy snapshot fields and `calculated_amount` to be null in `unresolved`; complete policy snapshot fields and amount with null posting ID in `calculated`; and complete policy snapshot fields, amount, and posting ID in `posted`, `corrected`, or `voided`. The only lifecycle transitions SHALL be `unresolved → calculated`, `calculated → unresolved`, `calculated → posted`, and `posted → corrected|voided`. An `unresolved → calculated` transition SHALL preserve source facts and atomically set the complete policy snapshot and amount. It SHALL be rejected unless `trip_kind = business_trip`, `vehicle_source = private`, `vehicle_class` is `kraftwagen` or `other_motor_vehicle`, the trip date is within policy `DE-private-business-travel/1` version 1's inclusive effective dates, and the rate matches that class (30 euro cents/km for `kraftwagen`, 20 euro cents/km for `other_motor_vehicle`). The stored amount SHALL match the half-up integer-cents calculation from `distance_hundredths_km` and the applicable rate. Commuting, `eks_allowance`, `other` or `unknown` trip kinds, company-provided vehicles, non-motorized/public transport, unsupported or unknown classes/sources, trips outside the effective range, and missing policy SHALL remain unresolved with a null snapshot. A `calculated → unresolved` transition SHALL clear the full snapshot and MAY update source facts. A `calculated → posted` transition SHALL preserve source facts and the policy snapshot and atomically set the posting reference with the accepted accounting posting. A `posted → corrected` transition SHALL be permitted only when a matching `mileage_trip_corrections` row has the same source trip ID, `kind = replace`, state `applied`, a replacement trip ID, a non-empty accounting correction ID, and a replacement trip already in `posted` with a non-empty posting reference. A `posted → voided` transition SHALL be permitted only when a matching correction row has the same source trip ID, `kind = void`, state `applied`, no replacement trip ID, and a non-empty accounting correction ID. Either terminal transition SHALL preserve all source facts, policy snapshot fields, amount, and original posting reference. No other state transition SHALL be allowed.

Database triggers SHALL enforce the initial state, every allowed transition, and each transition's field invariants. Once a trip is `posted`, `corrected`, or `voided`, triggers SHALL reject UPDATEs to its source facts, policy snapshot, calculated amount, or original posting reference. Triggers SHALL allow only the state-only `posted → corrected|voided` transition above when its matching applied correction exists and, for replacement, its replacement trip is already posted. Rows in `corrected` or `voided` SHALL reject all further UPDATEs and DELETEs. Unresolved and calculated trips may be edited or deleted according to the workspace lifecycle; edits to a calculated trip must return it to `unresolved` and clear its entire policy snapshot.

`mileage_trip_corrections` SHALL contain `id TEXT PRIMARY KEY NOT NULL`, `trip_id TEXT NOT NULL REFERENCES mileage_trips(id) ON DELETE RESTRICT`, `kind TEXT NOT NULL` constrained to `replace` or `void`, `replacement_trip_id TEXT UNIQUE REFERENCES mileage_trips(id) ON DELETE RESTRICT`, non-empty `reason TEXT NOT NULL`, `state TEXT NOT NULL` constrained to `draft`, `applied`, or `cancelled`, nullable `accounting_correction_id TEXT UNIQUE`, `created_at TEXT NOT NULL`, and nullable `applied_at TEXT`. A replace correction SHALL have a replacement trip ID different from its source; a void correction SHALL have no replacement trip. Correction INSERTs SHALL begin as `draft` with null accounting correction ID and applied timestamp; direct insertion as `applied` or `cancelled` MUST be rejected. A correction may be updated only while its old state is `draft`, and may remain `draft` or transition once to `applied` or `cancelled`. The `draft → applied` transition SHALL set a non-empty accounting correction ID and applied timestamp, require its source trip to remain `posted`, and for `replace` require its replacement trip to be `posted` with a non-empty posting reference; for `void`, replacement trip ID SHALL remain null. The `draft → cancelled` transition SHALL keep both application fields null. Applied and cancelled rows SHALL reject all UPDATEs and all correction rows SHALL reject DELETEs. The accepted accounting correction operation SHALL persist the replacement posting, correction state/event, and source terminal state in one SQLite transaction. A partial unique index SHALL enforce `UNIQUE(trip_id) WHERE state IN ('draft', 'applied')`; after a replacement is applied, a later correction targets that replacement, forming a linear chain. Both tables, triggers, and indexes SHALL be verified before the migration version is incremented.

#### Scenario: Create mileage tables on fresh install
- **GIVEN** the app creates a new empty profile
- **WHEN** current schema creation completes
- **THEN** both mileage tables and all declared constraints and indexes exist
- **AND** the profile schema version is the current version

#### Scenario: Reject direct inserts into finalized trip states

- **GIVEN** a direct SQL INSERT supplies a trip state of `calculated`, `posted`, `corrected`, or `voided`
- **WHEN** the database trigger evaluates the insert
- **THEN** it rejects the insert and creates no row

#### Scenario: Gate mileage migration until export inventories agree
- **GIVEN** the archived `profile-data-portability` change declares 46 names at v13 and the archived `customer-data-disclosure-export` change declares 55 names at v19, while their maintained inventory requirements still conflict
- **WHEN** the mileage migration release gate is evaluated
- **THEN** the v23 mileage migration remains blocked until both inventory owners accept the same 55-name v19 inventory and version-aware presence rules
- **AND** no migration or export may claim mileage completeness from the conflicting inventories
- **AND** the existing profile and mileage rows remain unchanged while the inventory dependency is open

#### Scenario: Roll back failed mileage migration
- **GIVEN** mileage table or index creation or schema verification fails during migration
- **WHEN** the migration aborts
- **THEN** the transaction rolls back both mileage tables and indexes
- **AND** all prior profile data and the old `PRAGMA user_version` remain unchanged
- **AND** the pre-migration backup is retained

#### Scenario: Preserve mileage data on downgrade attempt
- **GIVEN** a profile has the mileage schema at version 13
- **WHEN** an older application that supports only version 12 opens the profile
- **THEN** it rejects the newer schema without dropping either mileage table or changing profile data

#### Scenario: Protect posted trip facts at the database boundary
- **GIVEN** a mileage trip is `posted`, `corrected`, or `voided`
- **WHEN** a direct SQL UPDATE changes its trip facts, policy snapshot, amount, or posting-event reference, or a DELETE targets the row
- **THEN** a database trigger rejects the operation and preserves the row

#### Scenario: Allow only valid trip lifecycle transitions
- **GIVEN** an `unresolved` trip has a complete accepted policy calculation
- **WHEN** the calculation is persisted
- **THEN** it may transition to `calculated` only with the complete policy snapshot and amount
- **AND** a `calculated` trip may transition to `posted` only in the accepted accounting transaction that stores its posting reference
- **AND** editing a `calculated` trip's facts returns it to `unresolved` and clears its snapshot

#### Scenario: Allow posted correction transition only with a matching applied correction
- **GIVEN** a posted trip has a correction row for the same trip, matching correction kind, state `applied`, and non-empty accounting correction ID
- **WHEN** the correction transaction changes the source state to `corrected` or `voided`
- **THEN** the state transition succeeds while all source facts, policy snapshot fields, amount, and original posting reference remain unchanged

#### Scenario: Require the replacement to be posted before finalizing its source correction

- **GIVEN** a posted source trip has a replacement correction whose replacement trip is not posted
- **WHEN** SQL attempts to mark the correction applied or the source trip corrected
- **THEN** a database trigger rejects the update and preserves both trips and the draft correction

#### Scenario: Keep correction history immutable after application or cancellation

- **GIVEN** a correction is applied or cancelled
- **WHEN** direct SQL attempts to insert it in that state, change it, or delete it
- **THEN** database triggers reject the operation and preserve the correction row

#### Scenario: Reject unlinked or invalid lifecycle transitions
- **GIVEN** a trip has no matching applied correction or its current state does not permit the requested transition
- **WHEN** a direct SQL UPDATE attempts to skip or reverse a lifecycle state
- **THEN** a database trigger rejects the transition and preserves the row

### Requirement: Table Definitions

The application database SHALL maintain an auditable inventory of 55 known application-table names for supported schema version 19. The 39 legacy base tables SHALL remain: unternehmen, kunden, lieferanten, artikel, journal, rechnungen, rechnungspositionen, kategorien, konten, nummernkreise, ust_saetze, tagesabschluesse, belege, mahnungen, mahnstufen, mahnwesen_einstellungen, forderungen, bank_transaktionen, bank_templates, bank_imports, kunden_belege, kunden_lieferadressen, artikel_gruppen, rechnungsvorlagen, buchungsvorlagen, anlageverzeichnis, dokumentenpakete, dokumentenpaket_belege, ustva_exporte, euer_exporte, eks_exporte, datev_export_log, eu_laender, eks_einstellungen, vorsteuer_ansprueche, schnellbuchungen, auto_filter_regeln, import_mapping_vorlagen, and inventarbewegungen. The additional 16 names are feature-owned: feature_table_state; forderung_zahlungen; buchungsvorlagen_occurrences; rechnungsvorlagen_occurrences; mileage_trips; mileage_trip_corrections; category_mapping_history; master_data_import_templates; anlage_afa_jahreswerte; inventuren; inventur_positionen; settlement_groups; settlement_allocations; statutory_timing_rules; dokument_email_templates; and dokument_email_versuche. SQLite internal objects whose names begin with sqlite_ are excluded. A fresh v19 profile SHALL contain 51 application tables; the two recurring occurrence tables and two optional document-email tables MAY be absent until initialized.

Migration-required tables SHALL use these minimum versions: forderung_zahlungen at v8; category_mapping_history at v9; feature_table_state, mileage_trips, and mileage_trip_corrections at v13; master_data_import_templates at v16; anlage_afa_jahreswerte at v17; inventuren and inventur_positionen at v18; and settlement_groups, settlement_allocations, and statutory_timing_rules at v19. The two recurring occurrence tables SHALL be governed by feature_table_state starting at v13. `dokument_email_templates` and `dokument_email_versuche` are optional lazy tables with no schema-version requirement; when present, they SHALL match their declared schemas. The template columns are `typ`, `betreff`, `text`, and `aktualisiert_am`. The attempt columns are `id`, `dokument_id`, `dokument_typ`, `empfaenger`, `ergebnis`, `mahnung_id`, `idempotenz_schluessel`, `artefakt_ids`, `erstellt_am`, `abgeschlossen_am`, and `fehler_kategorie`.

At a version before a table's required migration version, its absence SHALL NOT make that older schema unhealthy. A profile at version N SHALL require all 39 legacy tables and every migration-required table through N with its declared schema. Each occurrence table SHALL be present with marker state `initialized` or absent with state `never_initialized`; absent with state `unknown`, missing marker rows, and state/table mismatches SHALL fail health. Optional document-email tables MAY be absent; when present, malformed schemas SHALL fail health. Any undeclared application table SHALL fail health. A profile below a later migration version MAY be complete for its recorded schema version; its archive SHALL NOT claim to have checked tables that are still version-pending. Any table with a typed relationship to a selected customer that is not included in the reviewed disclosure projection SHALL make that customer's archive incomplete. Every feature adding a table SHALL update this inventory before migration or lazy creation is implemented.

Before v8, forderung_zahlungen MAY be absent or in its accepted legacy v7 shape; the normal v7-to-v8 migration SHALL create it when absent. At v8 or later, absence is an integrity failure: startup SHALL detect it before any repair or migration that could recreate it, preserve the original database, stop profile initialization, and leave complete export unavailable until verified recovery. It SHALL NOT create an empty replacement. A present repairable payment table MAY use the accepted transactional row-preserving repair path; failed verification SHALL leave its rows and schema unchanged.

The v13 feature_table_state table SHALL contain exactly one durable row for each recurring occurrence table, constrained to those two names and states `never_initialized`, `initialized`, or `unknown`. Fresh v13+ profiles SHALL seed both rows as `never_initialized`. The v12-to-v13 migration SHALL mark a valid existing occurrence table `initialized` and an absent table `unknown`; absence alone SHALL NOT imply `never_initialized`. Feature initialization SHALL create a table and transition its marker in one transaction, and SHALL NOT create an `unknown` table. Unknown may become `never_initialized` only after explicit integrity reconciliation verifies the feature was never initialized; it may become `initialized` only after a verified table is restored or its prior data otherwise verified.

The mileage version-13 tables SHALL NOT be treated as complete-export eligible until both `profile-data-portability` and `customer-data-disclosure-export` accept the same 55-name v19 inventory and version-aware presence rules, including both mileage tables at v13. If either export encounters a profile containing a table while its accepted inventory omits that table, it SHALL mark the result incomplete and SHALL NOT publish or claim a complete export. These exporters SHALL NOT create, repair, or remove mileage tables. Lifecycle triggers enforcing unresolved-only trip INSERTs, draft-only correction INSERTs, correction transitions, final-row immutability with no DELETEs, and replacement-posted atomicity SHALL be installed by migration v23 (following verified current version 22); if another migration lands first, the triggers SHALL use the next sequential version. The v23 migration SHALL remain blocked until both inventory owners accept the common inventory and version-aware presence rules.

#### Scenario: All Tables Created on Fresh Install

- **GIVEN** the application creates a fresh profile at a supported schema version
- **WHEN** schema creation completes
- **THEN** all 39 legacy tables and every migration-required table through that schema version SHALL exist with declared schemas
- **AND** the recurring occurrence markers SHALL be seeded as `never_initialized`
- **AND** the two occurrence tables and two optional document-email tables SHALL be absent until their owning features initialize them

#### Scenario: Pre-v13 profile is valid before the coordinated feature migration

- **GIVEN** a profile at schema version 12 has the legacy tables, a valid forderung_zahlungen table, and category_mapping_history
- **AND** feature_table_state and both mileage tables are absent
- **WHEN** schema health is checked before migration
- **THEN** those not-yet-required v13 tables SHALL NOT make the version-12 profile unhealthy
- **AND** the profile SHALL remain ineligible for an export complete at the current runtime schema until normal sequential migrations succeed

#### Scenario: Pre-v9 profile is valid before later feature migrations

- **GIVEN** a profile at schema version 8 has the legacy tables and a valid forderung_zahlungen table
- **AND** category_mapping_history, feature_table_state, mileage_trips, and mileage_trip_corrections are absent
- **WHEN** schema health is checked before migration
- **THEN** those not-yet-required tables SHALL NOT make the version-8 profile unhealthy
- **AND** the profile SHALL remain ineligible for an export complete at the current runtime schema until normal sequential migrations succeed

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
- **AND** it SHALL mark existing valid occurrence tables `initialized` and absent occurrence tables `unknown`
- **AND** it SHALL increment user_version to 13 only after successful verification

#### Scenario: v22-to-v23 migration adds eligibility fields and lifecycle enforcement

- **GIVEN** a valid profile at schema version 22 with both mileage tables present and existing trips that may have posted facts
- **AND** both inventory owners have accepted the common 55-name v19 contract
- **WHEN** the next sequential migration runs
- **THEN** it SHALL add structured eligibility fields and initialize legacy rows to `unknown` without changing existing source facts, snapshots, amounts, posting references, or states
- **AND** it SHALL install and verify triggers rejecting ineligible calculations, non-unresolved trip INSERTs, non-draft correction INSERTs, invalid correction transitions, any DELETE of correction rows, and terminal trip updates without a matching applied correction
- **AND** it SHALL preserve all existing rows and increment `PRAGMA user_version` only after successful verification

#### Scenario: V9 migration adds category history

- **GIVEN** a valid profile is at schema version 8
- **WHEN** the accounting-catalog-provenance v9 migration runs
- **THEN** it SHALL create and verify category_mapping_history at schema version 9
- **AND** schema health SHALL require the table at version 9 or later

#### Scenario: Unknown lazy-table state is not repaired by initialization

- **GIVEN** a recurring occurrence table is absent and its marker state is `unknown`
- **WHEN** its feature is opened or initialized
- **THEN** the feature SHALL remain unavailable pending explicit integrity reconciliation
- **AND** no empty replacement table SHALL be created

#### Scenario: Table Count Verification

- **GIVEN** a migration runs against an existing profile
- **WHEN** the migration completes
- **THEN** its application-table set SHALL equal the required inventory for that schema version plus only initialized lazy tables
- **AND** no existing table SHALL be silently dropped or recreated
- **AND** all occurrence-table marker pairs SHALL satisfy their declared presence rules

#### Scenario: Version-aware table count verification

GIVEN a supported database is upgraded through schema v18
WHEN its declared table set is checked
THEN the v18 base registry SHALL contain exactly 41 tables
AND no table SHALL be silently dropped or created outside the version-specific inventory.

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

#### Scenario: Present document-email tables match their declared schema

- **GIVEN** either optional document-email table is present
- **WHEN** schema health is checked
- **THEN** all of its declared columns SHALL be present
- **AND** malformed document-email tables SHALL prevent a complete export

#### Scenario: Missing mileage tables are checked at their required version

- **GIVEN** `PRAGMA user_version` is at or beyond version 13 and either mileage table is absent or has an invalid schema
- **WHEN** database startup health checks run
- **THEN** the profile SHALL fail schema health before any repair can create or replace the table
- **AND** the original database and all remaining mileage data SHALL be preserved

#### Scenario: Block mileage completeness until export inventories include its tables

- **GIVEN** either owning portability or customer-export inventory omits `mileage_trips` or `mileage_trip_corrections`
- **WHEN** mileage completeness is considered
- **THEN** mileage tables SHALL remain ineligible for complete export until both inventories accept the 55-name contract

#### Scenario: Keep exports incomplete for undeclared mileage tables

- **GIVEN** an export encounters either mileage table while its accepted owning inventory omits that table
- **WHEN** the export is validated
- **THEN** the export SHALL be marked incomplete and SHALL NOT publish or claim a complete result
- **AND** the exporter SHALL NOT create, repair, or remove either mileage table

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

### Requirement: Customer and supplier archive state migration

The `kunden` and `lieferanten` tables SHALL each contain a nullable `archived_at TEXT` column. `NULL` SHALL mean active; a non-`NULL` value SHALL be an ISO-8601 UTC timestamp indicating when the row was archived. Fresh schema creation SHALL include both columns. Existing profile databases SHALL add both columns through one ordered migration, preserving every row, identifier, existing column value, and reference. The migration SHALL be the next sequential schema version after the accepted v10 migration; if migration order changes before implementation, it SHALL be reassigned to the next sequential version. The migration SHALL add no table and SHALL increment `PRAGMA user_version` only after successful verification.

#### Scenario: Fresh profile includes contact archive columns
- **GIVEN** a new profile database is created from the current schema
- **WHEN** the schema is inspected
- **THEN** `kunden.archived_at` and `lieferanten.archived_at` exist as nullable text columns
- **AND** all newly created customer and supplier rows have `archived_at = NULL`

#### Scenario: Existing profile migrates without changing records
- **GIVEN** an existing profile has customer and supplier rows and no archive columns
- **WHEN** the archive migration succeeds
- **THEN** both archive columns exist and all existing rows have `archived_at = NULL`
- **AND** all existing IDs, field values, references, and row counts remain unchanged
- **AND** the schema version advances by exactly one only after verification

#### Scenario: Archive and restore preserve customer identity
- **GIVEN** a customer or supplier row has an existing primary key and historical references
- **WHEN** it is archived and later restored
- **THEN** archive sets a UTC timestamp and restore clears it
- **AND** neither operation changes the primary key or historical references

### Requirement: Asset schedule schema preserves legacy records and history

The migration SHALL extend `anlageverzeichnis` additively with nullable canonical fields `asset_typ TEXT` constrained to `KFZ`, `EDV`, or `sonstig`; `kaufpreis_netto NUMERIC(12,2)` constrained to non-negative values; `nutzungsdauer_jahre INTEGER` constrained to positive values; `afa_methode TEXT` constrained to `linear`; `privat_anteil_prozent NUMERIC(5,2)` constrained to 0–100; and `verkauft_am TEXT`. A non-KFZ asset SHALL store no private-use percentage or zero until a type-specific rule is accepted. The existing `anschaffungsdatum` SHALL remain the canonical acquisition date. Nullable additions SHALL preserve existing legacy rows without inferred defaults. The migration SHALL preserve the existing primary keys, company/category references, status, and legacy columns `anschaffungskosten`, `nutzungsdauer`, and `privatanteil` without copying or reinterpreting legacy values. Every insert or update that sets `kaufpreis_netto` SHALL also write `anschaffungskosten` with the same amount so the legacy `NOT NULL` constraint is satisfied; reads SHALL treat `kaufpreis_netto` as canonical and SHALL NOT reinterpret `anschaffungskosten`. The migration SHALL verify each added column and roll back without advancing the schema version if verification fails.

The migration SHALL add `anlage_afa_jahreswerte` with a stable ID, `anlage_id INTEGER NOT NULL` foreign key to `anlageverzeichnis(id)` using `ON DELETE RESTRICT`, `jahr INTEGER NOT NULL`, `quell_snapshot TEXT NOT NULL`, `quell_hash TEXT NOT NULL`, `regel_version TEXT NOT NULL`, `status TEXT NOT NULL` constrained to `verfuegbar` or `nicht_verfuegbar`, `formel TEXT`, nullable `betrag NUMERIC(12,2)`, `blockierungsgrund TEXT`, and `berechnet_am TEXT NOT NULL`. A unique constraint SHALL cover `(anlage_id, jahr, quell_hash, regel_version)` so a stable source/rule result is not overwritten. An available row SHALL contain an amount and no blocking reason; an unavailable row SHALL contain no amount and a non-empty blocking reason. Schedule rows SHALL be append-only and immutable after insertion; database triggers SHALL abort every `UPDATE` or `DELETE` against this table. The table SHALL preserve prior schedule snapshots when source values or rules change. The table SHALL be owned by `fixed-asset-register-workspace`, introduced by this change's additive migration at the next accepted sequential schema version, and required at that version or later; before that version its absence SHALL NOT make the profile unhealthy. The runtime Table Definitions inventory and the profile portability export inventory SHALL declare it with this owner and version before any released profile creates it; an undeclared `anlage_afa_jahreswerte` SHALL make the profile export incomplete.

#### Scenario: Existing asset data survives migration

- **GIVEN** a profile contains legacy asset rows with arbitrary existing IDs, company/category links, and values in legacy columns
- **WHEN** the asset-schema migration completes
- **THEN** all existing rows and legacy values SHALL remain unchanged
- **AND** the canonical fields SHALL be present without inferred values
- **AND** the schema version SHALL advance only after schema verification succeeds

#### Scenario: Canonical writes satisfy the legacy required column

- **GIVEN** a new asset sets `kaufpreis_netto`
- **WHEN** the record is inserted
- **THEN** `anschaffungskosten` SHALL hold the same amount
- **AND** the insert SHALL NOT fail the legacy `NOT NULL` constraint

#### Scenario: Schedule history remains immutable

- **GIVEN** an asset has a stored annual schedule snapshot
- **WHEN** new source values or a new calculation rule produce another schedule
- **THEN** the earlier snapshot SHALL remain unchanged
- **AND** the new snapshot SHALL use its own source hash or rule version
- **AND** the asset SHALL NOT be hard-deleted while a schedule references it

### Requirement: Customer disclosure uses declared relationship paths

The scoped exporter SHALL read one consistent profile-local snapshot and traverse only its maintained relationship inventory: `kunden_lieferadressen.kunde_id`; `rechnungen.kunde_id`/`lieferadresse_id`/`vorlage_id` and self-links `storno_von`, `gutschrift_von`, `ersatz_fuer`, `ersatzrechnung_id`, `konvertiert_von`, and `konvertiert_zu`; `rechnungspositionen.rechnung_id`; `mahnungen.kunde_id`/`rechnung_id`; `forderungen.kunde_id`/`rechnung_id`/`journal_id`/`ausgleich_journal_id`; `forderung_zahlungen.forderung_id`/`journal_id`; `rechnungsvorlagen.kunde_id`/`auftrag_id` (where `auftrag_id` references `rechnungen.id`); `rechnungsvorlagen_occurrences.vorlage_id`/`rechnung_id`; `journal.rechnung_id`; `vorsteuer_ansprueche.rechnung_id`; and `kunden_belege.kunde_id` to `belege.id`. `buchungsvorlagen_occurrences` rows MAY be projected only when their `rechnung_id` or `journal_id` reaches an already included invoice or journal row; their unrelated booking-template relationship SHALL NOT be traversed. Invoice-lineage, recurring-template source-invoice, and delivery-address traversal SHALL verify inverse conversion pointers when both are present and verify that any populated customer/address key resolves to the selected customer; conflict, missing relationship targets, or unresolved identity SHALL exclude the affected record and make the export incomplete. Any schema migration that adds a customer-linked table or relationship SHALL declare whether and how the disclosure inventory includes it before the exporter can report a complete result. This capability SHALL NOT infer links from text or amounts.

#### Scenario: New relationship is not in the reviewed inventory

- **GIVEN** a migrated profile contains a customer-linked table or foreign-key path absent from the disclosure inventory
- **WHEN** a scoped export is requested
- **THEN** the exporter SHALL report the unsupported relationship
- **AND** SHALL NOT mark the archive complete

#### Scenario: Snapshot cannot be acquired consistently

- **GIVEN** the profile database cannot provide one verified consistent snapshot
- **WHEN** a scoped export is requested
- **THEN** the export SHALL fail without publishing a final archive
- **AND** source records SHALL remain unchanged

### Requirement: Customer export completeness uses an accepted table inventory

The customer exporter SHALL validate the active profile against the exact 55-name application-table inventory and version-aware presence rules in this change's modified `Table Definitions` requirement before reporting completeness. A complete export SHALL require every migration-required table at or after its declared version through the profile's recorded schema version; a table introduced by a later migration SHALL remain version-pending and SHALL NOT make an earlier supported profile incomplete. Each lazy occurrence table is valid only when present with state `initialized` or absent with state `never_initialized`; a lazy table absent with state `unknown`, a missing required table, a state/table mismatch, a malformed declared schema, or an undeclared application table SHALL make the archive incomplete. The exporter SHALL NOT create or repair tables. At v7 and earlier, a missing `forderung_zahlungen` table is created by the normal v7-to-v8 migration; at v8 or later, startup SHALL detect its absence before any repair that could recreate it, preserve the missing-table signal, and keep the profile unavailable for complete export until verified recovery. `mileage_trips`, `mileage_trip_corrections`, `category_mapping_history`, `master_data_import_templates`, `anlage_afa_jahreswerte`, and the inventory/settlement tables SHALL be included in schema-health checks at their required versions but SHALL NOT be projected unless a customer relationship is explicitly reviewed. Their omission SHALL not by itself make a customer-scoped archive incomplete. `feature_table_state` rows SHALL be used for schema health only and SHALL NOT be included in the customer payload. The manifest SHALL identify the failing table by table name and condition, without exposing database paths.

#### Scenario: Unlisted customer-linked table prevents a complete export

- **GIVEN** a profile at a supported schema version contains a customer-linked application table absent from the accepted inventory
- **WHEN** a customer disclosure export checks the profile schema
- **THEN** the manifest SHALL identify the table as unknown
- **AND** the archive SHALL not be reported as complete
- **AND** the exporter SHALL NOT create or repair tables

#### Scenario: Required or unknown customer table is missing or present

- **GIVEN** an accepted required table is absent, an unmarked lazy table is absent, or an unknown customer-relevant table is present
- **WHEN** the customer disclosure export checks the profile schema
- **THEN** it SHALL identify the table condition in the manifest
- **AND** it SHALL not report the archive as complete

### Requirement: Buchungsvorlagen occurrence review-state persistence

The system SHALL persist occurrence review state on `buchungsvorlagen_occurrences` with `review_status TEXT NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','blocked','ready','handed_off','posted','failed'))`, durable `block_reason TEXT NULL`, and durable `handoff_error TEXT NULL`, preserving the existing unique `(vorlage_id, faelligkeit)` key and linked journal/invoice references. Existing rows SHALL backfill to `pending` with NULL reasons. Blocking and handoff-failure displays SHALL read the persisted reason; a missing contract, mapping, or draft failure MUST leave a non-terminal status with that reason stored.

#### Scenario: Existing occurrences backfill without losing links
- **GIVEN** existing occurrence rows with journal/invoice links and no review columns
- **WHEN** the migration runs
- **THEN** each row keeps its identity and links with `pending` status and NULL reasons

#### Scenario: Blocked occurrence persists its reason
- **GIVEN** a due occurrence cannot execute because the shared contract or required mapping is unavailable
- **WHEN** the workspace records the block
- **THEN** the row persists a non-terminal status with the missing contract or mapping named in `block_reason` and creates no financial record

#### Scenario: Failed handoff persists its error
- **GIVEN** Beleg draft creation fails or its use case is unavailable
- **WHEN** the handoff is attempted
- **THEN** the row persists `failed` with the failure in `handoff_error`, remains reviewable, and the stored template date does not advance
