## ADDED Requirements

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

## MODIFIED Requirements

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

#### Scenario: v22-to-v23 migration adds eligibility fields and lifecycle enforcement

- **GIVEN** a valid profile at schema version 22 with both mileage tables present and existing trips that may have posted facts
- **AND** both inventory owners have accepted the common 55-name v19 contract
- **WHEN** the next sequential migration runs
- **THEN** it SHALL add structured eligibility fields and initialize legacy rows to `unknown` without changing existing source facts, snapshots, amounts, posting references, or states
- **AND** it SHALL install and verify triggers rejecting ineligible calculations, non-unresolved trip INSERTs, non-draft correction INSERTs, invalid correction transitions, any DELETE of correction rows, and terminal trip updates without a matching applied correction
- **AND** it SHALL preserve all existing rows and increment `PRAGMA user_version` only after successful verification
