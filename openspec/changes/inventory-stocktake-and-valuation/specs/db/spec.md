## MODIFIED Requirements

### Requirement: Table Definitions

Once the inventory movement and physical stocktake migrations are applied, the database SHALL contain exactly 41 tables: `unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`, `inventarbewegungen`, `inventuren`, `inventur_positionen`. This comprises the 38 existing non-inventory tables, the named `inventarbewegungen` table, and the named `inventuren` and `inventur_positionen` stocktake tables. The schema inventory SHALL match the actual table set after each ordered migration; no migration may silently drop an existing table or create an undeclared table.

#### Scenario: All Tables Created on Fresh Install

GIVEN the app runs for the first time with an empty database and all current feature migrations are enabled
WHEN schema creation completes
THEN all 41 declared tables SHALL exist
AND each table SHALL have its expected columns and constraints.

#### Scenario: Table Count Verification

GIVEN all current migrations are applied to a supported database
WHEN a migration completes
THEN the 38 existing non-inventory tables and all three declared inventory tables SHALL remain present
AND the total table count SHALL be exactly 41
AND no table SHALL be silently dropped or created outside the inventory.

#### Scenario: Missing Table Detection

GIVEN a migration should create one of the declared stocktake tables
WHEN the CREATE TABLE statement fails
THEN the migration SHALL roll back
AND the schema version SHALL NOT be incremented.

### Requirement: Explicit feature-table migrations

Feature migrations SHALL declare every table they add, including its columns, constraints, and schema-version change. The existing inventory movement migration SHALL add the named `inventarbewegungen` table defined in the inventory specification. A separate physical stocktake migration SHALL add exactly `inventuren` and `inventur_positionen` with the columns, constraints, and foreign key defined in the inventory specification. These stocktake tables SHALL store count evidence only; this change SHALL NOT add an inventory valuation or journal table. No other unspecified movement or log table SHALL be created.

#### Scenario: Named inventory table migration

GIVEN the existing inventory movement migration is enabled
WHEN that migration completes
THEN `inventarbewegungen` SHALL exist with the columns and constraints specified by the inventory capability
AND the 38 existing non-inventory tables SHALL remain present
AND the total table count SHALL be 39.

#### Scenario: Named stocktake table migration

GIVEN the physical stocktake migration is enabled
WHEN that migration completes
THEN `inventuren` and `inventur_positionen` SHALL exist with the columns and constraints specified by the inventory capability
AND existing article and movement rows SHALL retain their values
AND the table count SHALL increase from 39 to 41.

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
