## MODIFIED Requirements

### Requirement: Table Definitions

The production database baseline SHALL contain these 39 registered tables: `unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`, and `inventarbewegungen`. This baseline SHALL match the production `AppDatabase.allTableNames` registry and created schema. Additional feature-owned tables SHALL be permitted only when an accepted feature specification names their schema, migration, constraints, and version change; each such table SHALL be registered in runtime and maintained inventories. No migration SHALL silently add or drop a table.

#### Scenario: All Tables Created on Fresh Install

- **GIVEN** the app creates a fresh database at the current production schema version
- **WHEN** schema creation completes
- **THEN** each of the 39 baseline tables SHALL exist with its expected columns and constraints
- **AND** each baseline name SHALL appear in `AppDatabase.allTableNames`

#### Scenario: Table Count Verification

- **GIVEN** a migration runs against an existing database
- **WHEN** the migration completes
- **THEN** the total table set SHALL equal the pre-migration set plus only the table names declared by its accepted specification
- **AND** all 39 baseline tables SHALL remain present and registered

#### Scenario: Missing Table Detection

- **GIVEN** an accepted migration should create a named table and table creation or registry verification fails
- **WHEN** migration error handling completes
- **THEN** the migration SHALL roll back
- **AND** the schema version SHALL NOT be incremented
