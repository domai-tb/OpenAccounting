## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Table Definitions

The application database SHALL maintain an auditable inventory of 55 known application-table names for supported schema version 19. The 39 legacy base tables SHALL remain: unternehmen, kunden, lieferanten, artikel, journal, rechnungen, rechnungspositionen, kategorien, konten, nummernkreise, ust_saetze, tagesabschluesse, belege, mahnungen, mahnstufen, mahnwesen_einstellungen, forderungen, bank_transaktionen, bank_templates, bank_imports, kunden_belege, kunden_lieferadressen, artikel_gruppen, rechnungsvorlagen, buchungsvorlagen, anlageverzeichnis, dokumentenpakete, dokumentenpaket_belege, ustva_exporte, euer_exporte, eks_exporte, datev_export_log, eu_laender, eks_einstellungen, vorsteuer_ansprueche, schnellbuchungen, auto_filter_regeln, import_mapping_vorlagen, and inventarbewegungen. The additional 16 names are feature-owned: feature_table_state; forderung_zahlungen; buchungsvorlagen_occurrences; rechnungsvorlagen_occurrences; mileage_trips; mileage_trip_corrections; category_mapping_history; master_data_import_templates; anlage_afa_jahreswerte; inventuren; inventur_positionen; settlement_groups; settlement_allocations; statutory_timing_rules; dokument_email_templates; and dokument_email_versuche. SQLite internal objects whose names begin with sqlite_ are excluded. A fresh v19 profile SHALL contain 51 application tables; the two recurring occurrence tables and two optional document-email tables MAY be absent until initialized.

Migration-required tables SHALL use these minimum versions: forderung_zahlungen at v8; category_mapping_history at v9; feature_table_state, mileage_trips, and mileage_trip_corrections at v13; master_data_import_templates at v16; anlage_afa_jahreswerte at v17; inventuren and inventur_positionen at v18; and settlement_groups, settlement_allocations, and statutory_timing_rules at v19. The two recurring occurrence tables SHALL be governed by feature_table_state starting at v13. `dokument_email_templates` and `dokument_email_versuche` are optional lazy tables with no schema-version requirement; when present, they SHALL match their declared schemas. The template columns are `typ`, `betreff`, `text`, and `aktualisiert_am`. The attempt columns are `id`, `dokument_id`, `dokument_typ`, `empfaenger`, `ergebnis`, `mahnung_id`, `idempotenz_schluessel`, `artefakt_ids`, `erstellt_am`, `abgeschlossen_am`, and `fehler_kategorie`.

At a version before a table's required migration version, its absence SHALL NOT make that older schema unhealthy. A profile at version N SHALL require all 39 legacy tables and every migration-required table through N with its declared schema. Each occurrence table SHALL be present with marker state `initialized` or absent with state `never_initialized`; absent with state `unknown`, missing marker rows, and state/table mismatches SHALL fail health. Optional document-email tables MAY be absent; when present, malformed schemas SHALL fail health. Any undeclared application table SHALL fail health. A profile below a later migration version MAY be complete for its recorded schema version; its archive SHALL NOT claim to have checked tables that are still version-pending. Any table with a typed relationship to a selected customer that is not included in the reviewed disclosure projection SHALL make that customer's archive incomplete. Every feature adding a table SHALL update this inventory before migration or lazy creation is implemented.

Before v8, forderung_zahlungen MAY be absent or in its accepted legacy v7 shape; the normal v7-to-v8 migration SHALL create it when absent. At v8 or later, absence is an integrity failure: startup SHALL detect it before any repair or migration that could recreate it, preserve the original database, stop profile initialization, and leave complete export unavailable until verified recovery. It SHALL NOT create an empty replacement. A present repairable payment table MAY use the accepted transactional row-preserving repair path; failed verification SHALL leave its rows and schema unchanged.

The v13 feature_table_state table SHALL contain exactly one durable row for each recurring occurrence table, constrained to those two names and states `never_initialized`, `initialized`, or `unknown`. Fresh v13+ profiles SHALL seed both rows as `never_initialized`. The v12-to-v13 migration SHALL mark a valid existing occurrence table `initialized` and an absent table `unknown`; absence alone SHALL NOT imply `never_initialized`. Feature initialization SHALL create a table and transition its marker in one transaction, and SHALL NOT create an `unknown` table. Unknown may become `never_initialized` only after explicit integrity reconciliation verifies the feature was never initialized; it may become `initialized` only after a verified table is restored or its prior data otherwise verified.

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
