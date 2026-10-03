## MODIFIED Requirements

### Requirement: Table Definitions

The production base database SHALL contain these 39 registered tables: `unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`, and `inventarbewegungen`. This base SHALL match the production `AppDatabase.allTableNames` registry. The current feature-owned table inventory SHALL additionally name migration-managed `forderung_zahlungen` and lazily created `buchungsvorlagen_occurrences` and `rechnungsvorlagen_occurrences`, with each table's owner, schema, creation path, and presence rule documented. Runtime SHALL expose one auditable inventory of all 42 known table names and distinguish the 39 base tables required on open from the migration-managed and lazily created feature tables. `forderung_zahlungen` SHALL be present once the profile reaches a schema version requiring its migration. If it is absent at that version, schema health SHALL fail before automatic repair can create an empty replacement, and the profile SHALL remain unavailable for complete export until recovered or otherwise verified. An absent lazy occurrence table SHALL be classified unknown and SHALL prevent a complete export unless a durable accepted marker proves that the feature was never initialized. Future feature-owned tables SHALL be declared by an accepted feature specification before migration or lazy creation. No migration or feature initializer SHALL create an undeclared table without reporting any missing-data condition.

#### Scenario: All Tables Created on Fresh Install

- **GIVEN** the app creates a fresh database at the current production schema version
- **WHEN** schema creation completes
- **THEN** each of the 39 baseline tables SHALL exist with its expected columns and constraints
- **AND** each baseline name SHALL appear in `AppDatabase.allTableNames`

#### Scenario: Table Count Verification

- **GIVEN** a migration runs against an existing database
- **WHEN** the migration completes
- **THEN** the total table set SHALL equal the pre-migration set plus only the table names declared by its accepted specification
- **AND** all 39 base tables SHALL remain present and registered

#### Scenario: Known feature-owned tables are inventoried

- **GIVEN** a profile has or has not initialized one of the declared feature-owned tables
- **WHEN** its schema inventory is inspected
- **THEN** `forderung_zahlungen`, `buchungsvorlagen_occurrences`, and `rechnungsvorlagen_occurrences` SHALL all appear in the known-table inventory
- **AND** runtime verification SHALL distinguish present tables from optional tables that are not yet created

#### Scenario: Missing Table Detection

- **GIVEN** an accepted migration should create a named table and table creation or registry verification fails
- **WHEN** migration error handling completes
- **THEN** the migration SHALL roll back
- **AND** the schema version SHALL NOT be incremented
