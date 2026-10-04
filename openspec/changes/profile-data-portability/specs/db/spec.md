## MODIFIED Requirements

### Requirement: Table Definitions

The application database SHALL maintain one auditable inventory of 46 known application-table names, partitioned as 39 pre-existing base tables, one shared database-health table, and six feature-owned tables. The 39 pre-existing base tables SHALL remain the current AppDatabase.allTableNames entries: unternehmen, kunden, lieferanten, artikel, journal, rechnungen, rechnungspositionen, kategorien, konten, nummernkreise, ust_saetze, tagesabschluesse, belege, mahnungen, mahnstufen, mahnwesen_einstellungen, forderungen, bank_transaktionen, bank_templates, bank_imports, kunden_belege, kunden_lieferadressen, artikel_gruppen, rechnungsvorlagen, buchungsvorlagen, anlageverzeichnis, dokumentenpakete, dokumentenpaket_belege, ustva_exporte, euer_exporte, eks_exporte, datev_export_log, eu_laender, eks_einstellungen, vorsteuer_ansprueche, schnellbuchungen, auto_filter_regeln, import_mapping_vorlagen, and inventarbewegungen. The shared database-health table SHALL be feature_table_state. At schema version 9 it is required in addition to the existing 39 base tables; it remains separate from the legacy 39-name AppDatabase.allTableNames count. The six feature-owned table names SHALL be forderung_zahlungen, buchungsvorlagen_occurrences, rechnungsvorlagen_occurrences, mileage_trips, mileage_trip_corrections, and category_mapping_history. SQLite internal objects whose names begin with sqlite_ are excluded from this application-table inventory.

The inventory SHALL record each table owner, its required migration version or lazy-state rule, its declared schema, creation path, and presence rule. The feature-owned presence rules SHALL be: forderung_zahlungen is introduced by the accepted v7-to-v8 migration and required at user_version 8 or later; mileage_trips and mileage_trip_corrections are created together and required at user_version 9 or later; category_mapping_history is owned by accounting-catalog-provenance, created by its v10 migration, and required at user_version 10 or later; the two occurrence tables are owned by recurring features and follow the v9 feature_table_state markers. If migration ordering changes, the category migration SHALL be reassigned to the next sequential schema version after the accepted v9 migration before implementation.

At versions before a table's required migration version, that table is not yet required and its absence SHALL NOT make that older schema unhealthy. At a version at or beyond its required migration version, a migration-required table SHALL exist with its declared schema. Before v8, forderung_zahlungen MAY be absent or may exist in its accepted legacy v7 shape; the normal v7-to-v8 migration SHALL create it when absent. At v8 or later, absence of forderung_zahlungen is an integrity failure: startup SHALL detect it before current-version repair or any migration that could recreate it, stop profile initialization, preserve the original database, and leave the profile unavailable for complete export until verified recovery. It SHALL NOT create an empty replacement. The missing table remains the durable completeness signal. A present forderung_zahlungen table with a repairable schema or constraint defect MAY use the accepted transactional, row-preserving repair path; a repair that cannot preserve and verify its rows SHALL fail without changing the database.

The shared feature_table_state table SHALL be introduced at schema version 9 and SHALL contain exactly one durable row for each lazy occurrence table. Its table_name SHALL be constrained to buchungsvorlagen_occurrences or rechnungsvorlagen_occurrences, and state SHALL be constrained to never_initialized, initialized, or unknown. Fresh creation at version 9 or later SHALL seed both rows as never_initialized. The v8-to-v9 migration SHALL classify an existing lazy table with its declared schema as initialized and an absent lazy table as unknown; absence alone SHALL NOT imply never_initialized. Feature initialization SHALL create a lazy table and transition its marker from never_initialized to initialized in the same transaction. It SHALL NOT create a table while its marker is unknown. State/table mismatches SHALL fail schema health. Unknown may become never_initialized only after explicit integrity reconciliation verifies that the feature was never initialized; it may become initialized only after a verified table is restored or its prior data is otherwise verified. Before schema version 9, the marker table is not yet required and legacy lazy-table presence is not judged against marker rows.

A complete version-10 inventory SHALL be valid only when all 39 existing base tables and feature_table_state exist with declared schemas, forderung_zahlungen exists at or after v8, both mileage tables exist at or after v9, category_mapping_history exists at or after v10, and each lazy occurrence table is present with state initialized or absent with state never_initialized. An absent lazy table with state unknown, a missing required marker row, any state/table mismatch, an unknown application table, or a missing or malformed required table SHALL prevent a complete inventory. Before v10, older profiles may remain valid for their own schema version but SHALL NOT be reported as complete version-10 exports. Every feature specification that adds a table SHALL update this inventory before migration or lazy creation is implemented.

#### Scenario: All Tables Created on Fresh Install

- **GIVEN** the application creates a fresh profile at supported schema version 10
- **WHEN** schema creation completes
- **THEN** all 39 existing base tables and feature_table_state SHALL exist with declared schemas
- **AND** feature_table_state SHALL contain never_initialized rows for both lazy occurrence tables
- **AND** forderung_zahlungen, mileage_trips, mileage_trip_corrections, and category_mapping_history SHALL exist
- **AND** neither lazy occurrence table SHALL exist until its owning feature is initialized

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

#### Scenario: V8-to-v9 migration adds shared markers and mileage tables

- **GIVEN** a valid profile is at schema version 8 with forderung_zahlungen present
- **WHEN** the next sequential migration runs
- **THEN** it SHALL create and verify feature_table_state and both mileage tables in the coordinated v9 transaction
- **AND** it SHALL mark existing valid lazy occurrence tables initialized and absent lazy tables unknown
- **AND** it SHALL increment user_version to 9 only after successful verification

#### Scenario: V10 migration adds category history

- **GIVEN** a valid profile is at schema version 9
- **WHEN** the accounting-catalog-provenance migration runs
- **THEN** it SHALL create and verify category_mapping_history at schema version 10
- **AND** schema health SHALL require the table at version 10 or later

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
