## ADDED Requirements

### Requirement: Mileage persistence schema

The database SHALL create `mileage_trips` and `mileage_trip_corrections` on fresh install and through an additive schema migration. `mileage_trips` SHALL contain:

- `id TEXT PRIMARY KEY NOT NULL`, a stable UUID.
- `trip_date TEXT NOT NULL`, canonical valid `YYYY-MM-DD`.
- `purpose TEXT NOT NULL` and `business_context TEXT NOT NULL`, each constrained to non-empty trimmed text.
- `distance_hundredths_km INTEGER NOT NULL`, constrained to 1 through 999,999,999,999 inclusive. The UI value is this integer divided by 100; no binary floating-point distance is persisted.
- `state TEXT NOT NULL`, constrained to `unresolved`, `calculated`, `posted`, `corrected`, or `voided`.
- Nullable policy snapshot columns `policy_id TEXT`, `policy_source TEXT`, `policy_version TEXT`, `policy_effective_from TEXT`, `policy_effective_to TEXT`, `calculated_amount NUMERIC(12,2)`, and `calculated_at TEXT`. These columns SHALL be either all null or all non-null; non-null text values SHALL be non-empty, dates canonical, and amount non-negative. There is no policy-table foreign key because this change does not define the policy registry.
- `posting_event_id TEXT UNIQUE`, nullable until the accepted accounting boundary returns its stable event ID.
- `created_at TEXT NOT NULL` and `updated_at TEXT NOT NULL`, UTC RFC 3339 timestamps.

Trip INSERTs SHALL begin in `unresolved` with null policy snapshot, amount, and posting reference; direct insertion in any later state MUST be rejected. The row-state constraint SHALL require all policy snapshot fields and `calculated_amount` to be null in `unresolved`; complete policy snapshot fields and amount with null posting ID in `calculated`; and complete policy snapshot fields, amount, and posting ID in `posted`, `corrected`, or `voided`. The only lifecycle transitions SHALL be `unresolved → calculated`, `calculated → unresolved`, `calculated → posted`, and `posted → corrected|voided`. An `unresolved → calculated` transition SHALL preserve source facts and atomically set the complete accepted policy snapshot and amount. A `calculated → unresolved` transition SHALL clear the full snapshot and MAY update source facts. A `calculated → posted` transition SHALL preserve source facts and the accepted policy snapshot and atomically set the posting reference with the accepted accounting posting. A `posted → corrected` transition SHALL be permitted only when a matching `mileage_trip_corrections` row has the same source trip ID, `kind = replace`, state `applied`, a replacement trip ID, a non-empty accounting correction ID, and a replacement trip already in `posted` with a non-empty posting reference. A `posted → voided` transition SHALL be permitted only when a matching correction row has the same source trip ID, `kind = void`, state `applied`, no replacement trip ID, and a non-empty accounting correction ID. Either terminal transition SHALL preserve all source facts, policy snapshot fields, amount, and original posting reference. No other state transition SHALL be allowed.

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

#### Scenario: Migrate an existing version-8 profile
- **GIVEN** a profile at schema version 8 on the current repository baseline
- **AND** both `profile-data-portability` and `customer-data-disclosure-export` have accepted the matching 46-name inventory and version-aware presence rules
- **WHEN** the coordinated next sequential migration runs
- **THEN** it creates and verifies both mileage tables and indexes in the shared schema transaction
- **AND** the shared inventory migration creates `feature_table_state` with the two lazy-table markers, classifying existing valid tables as `initialized` and absent tables as `unknown`
- **AND** startup checks `forderung_zahlungen` against its required migration version before any repair could recreate it
- **AND** it increments `PRAGMA user_version` to 9 only after successful verification
- **AND** it preserves all existing rows and creates no mileage trip from `journal.km_anzahl`

#### Scenario: Roll back failed mileage migration
- **GIVEN** mileage table or index creation or schema verification fails during migration
- **WHEN** the migration aborts
- **THEN** the transaction rolls back both mileage tables and indexes
- **AND** all prior profile data and the old `PRAGMA user_version` remain unchanged
- **AND** the pre-migration backup is retained

#### Scenario: Preserve mileage data on downgrade attempt
- **GIVEN** a profile has the mileage schema at version 9
- **WHEN** an older application that supports only version 8 opens the profile
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

## MODIFIED Requirements

### Requirement: Table Definitions

The application database SHALL maintain one auditable inventory of 46 known application-table names, partitioned as 39 pre-existing base tables, one shared database-health table, and six feature-owned tables. The 39 pre-existing base tables SHALL be `unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`, and `inventarbewegungen`. The shared database-health table SHALL be `feature_table_state`, required in addition to those base tables at schema version 9 or later. The six feature-owned tables SHALL be `forderung_zahlungen`, `buchungsvorlagen_occurrences`, `rechnungsvorlagen_occurrences`, `mileage_trips`, `mileage_trip_corrections`, and `category_mapping_history`. SQLite internal objects whose names begin with `sqlite_` are excluded. Each inventory entry SHALL record its owner, schema-version rule or lazy-state rule, creation path, and presence rule. Every table SHALL match its accepted owning schema; an undeclared application table, required table absent at its required version, or invalid table schema SHALL fail schema health. Migrations and feature initialization SHALL NOT silently drop, recreate, or replace data-bearing tables.

The 39 base tables SHALL be created by fresh-schema construction or declared versioned migrations. `inventarbewegungen` is owned by inventory; `feature_table_state` is owned by the database health contract. The feature-owned tables SHALL have these owners and presence rules: `forderung_zahlungen` is owned by receivable payments and required at and after its accepted migration version; `buchungsvorlagen_occurrences` is owned by recurring bookings and `rechnungsvorlagen_occurrences` by recurring invoices, each created only by its feature initializer after the marker permits initialization; `mileage_trips` and `mileage_trip_corrections` are owned by mileage entry and required at and after schema version 9; and `category_mapping_history` is owned by accounting catalog provenance and required at and after schema version 10. If migration ordering changes, the category migration SHALL use the next sequential version after the accepted v9 migration. The two mileage tables are created together in the coordinated migration; they are migration-required and SHALL NOT use lazy-table markers.

`feature_table_state` SHALL have `table_name TEXT PRIMARY KEY` constrained to `buchungsvorlagen_occurrences` or `rechnungsvorlagen_occurrences`, and `state TEXT NOT NULL` constrained to `never_initialized`, `initialized`, or `unknown`. It SHALL contain exactly one durable state row for each lazy occurrence table. Fresh database creation SHALL create both rows with `never_initialized`. When migrating an existing profile, a lazy table that exists with its declared schema SHALL be marked `initialized`; an absent lazy table SHALL be marked `unknown` because prior use cannot be disproved without historical state. Lazy feature initialization SHALL create its table and transition its state from `never_initialized` to `initialized` in the same transaction. It SHALL NOT create a table while its marker is `unknown`. State/table mismatches SHALL fail schema health. An `unknown` state may become `never_initialized` only after an explicit integrity reconciliation verifies that the feature was never initialized; it may become `initialized` only after a verified table is restored or its prior data is otherwise verified.

`forderung_zahlungen` SHALL be required at and after the schema version declared by its accepted migration. Before any startup repair or migration that could recreate this table, schema health SHALL compare its presence with `PRAGMA user_version`. If the profile is already at or beyond the required version and the table is absent, initialization SHALL stop before repair, preserve the original database, and mark the profile unavailable for complete export. Recovery SHALL require restoring a verified backup or an explicitly verified manual repair; an empty replacement SHALL NOT be created automatically. Before that migration version, the table is not yet required.

A complete version-10 inventory SHALL be valid only when all 39 pre-existing base tables and `feature_table_state` exist with declared schemas, `forderung_zahlungen` exists at or after version 8, both mileage tables exist at or after version 9, `category_mapping_history` exists at or after version 10, and each lazy occurrence table is present with state `initialized` or absent with state `never_initialized`. An absent lazy table with state `unknown`, a missing required marker row, any other state/table mismatch, an unknown application table, or a missing required table SHALL prevent a complete inventory. Before version 10, older profiles may be valid for their own version but SHALL NOT be reported as complete version-10 exports. Every feature specification that adds a table SHALL update this inventory before migration or lazy creation is implemented.

The mileage version-9 migration SHALL NOT be enabled until both `profile-data-portability` and `customer-data-disclosure-export` accept the same 46-name inventory and version-aware presence rules, including both mileage tables at v9 and category history at v10. If either export encounters a profile containing a table while its accepted inventory omits that table, it SHALL mark the result incomplete and SHALL NOT publish or claim a complete export. These exporters SHALL NOT create, repair, or remove mileage tables.

#### Scenario: All Tables Created on Fresh Install

GIVEN the app creates a fresh database at the supported schema version
WHEN schema creation completes
THEN all 39 pre-existing base tables and the required shared health table SHALL exist with their declared columns and constraints
AND `feature_table_state` SHALL contain `never_initialized` rows for both lazy occurrence tables
AND `forderung_zahlungen`, `mileage_trips`, `mileage_trip_corrections`, and `category_mapping_history` SHALL exist at their required schema versions
AND neither lazy occurrence table SHALL exist until its feature is initialized

#### Scenario: Table Count Verification

GIVEN a migration runs against an existing database
WHEN the migration completes
THEN its application-table set SHALL equal the 39 pre-existing base tables, the shared health table when required, all migration-required feature tables at their required versions, and only those lazy tables whose state is `initialized`
AND no existing table SHALL be silently dropped or recreated
AND all table-state pairs SHALL satisfy their declared presence rules

#### Scenario: Missing Table Detection

GIVEN a migration should create a new table
WHEN the CREATE TABLE statement or schema verification fails
THEN the migration SHALL roll back
AND the schema version SHALL NOT be incremented

#### Scenario: Existing profile migration records lazy-table uncertainty

- **GIVEN** an existing profile is migrated to the schema version that introduces `feature_table_state`
- **WHEN** the marker rows are initialized
- **THEN** each lazy table already present with its declared schema SHALL be marked `initialized`
- **AND** each absent lazy table SHALL be marked `unknown`

#### Scenario: Lazy feature initialization updates the marker transactionally

- **GIVEN** a lazy occurrence table has marker state `never_initialized`
- **WHEN** its owning feature initializes the table
- **THEN** table creation and marker transition to `initialized` SHALL commit in one transaction
- **AND** a failed creation SHALL leave the marker and schema unchanged

#### Scenario: Unknown lazy state is not recreated automatically

- **GIVEN** a lazy occurrence table has marker state `unknown` and the table is absent
- **WHEN** the owning feature initializes
- **THEN** it SHALL fail closed without creating an empty table or changing the marker

#### Scenario: Missing payment table is checked before startup repair

- **GIVEN** `PRAGMA user_version` is at or beyond the accepted `forderung_zahlungen` migration version and that table is absent
- **WHEN** database startup health checks run
- **THEN** the check SHALL fail before any automatic repair can create the table
- **AND** the original database SHALL be preserved and the profile SHALL remain unavailable for a complete export

#### Scenario: Missing mileage tables are checked at their required version

- **GIVEN** `PRAGMA user_version` is at or beyond version 9 and either mileage table is absent or has an invalid schema
- **WHEN** database startup health checks run
- **THEN** the profile SHALL fail schema health before any repair can create or replace the table
- **AND** the original database and all remaining mileage data SHALL be preserved

#### Scenario: Block mileage migration until export inventories include its tables

- **GIVEN** either owning portability or customer-export inventory omits `mileage_trips` or `mileage_trip_corrections`
- **WHEN** the version-9 mileage migration is considered
- **THEN** the mileage migration SHALL remain disabled until both inventories accept the 46-name contract

#### Scenario: Keep exports incomplete for undeclared mileage tables

- **GIVEN** an export encounters either mileage table while its accepted owning inventory omits that table
- **WHEN** the export is validated
- **THEN** the export SHALL be marked incomplete and SHALL NOT publish or claim a complete result
- **AND** the exporter SHALL NOT create, repair, or remove either mileage table
