## MODIFIED Requirements

### Requirement: Seed Data

Fresh database creation SHALL seed `ust_saetze` (0%, 7%, 19%), `nummernkreise` (all document types), `eu_laender` (EU member states with USt-IdNr formats), and the separately specified `bank_templates`. Category mappings SHALL be seeded only from an approved, versioned accounting-catalog manifest carrying source reference, source version, and accounting review status. Without such a manifest, a fresh profile SHALL have no preconfigured SKR03, SKR04, EÜR, or EKS category mappings and SHALL expose an explicit unconfigured state. Seed logic MUST NOT generate accounting mappings from identifiers, arithmetic, or placeholder labels.

#### Scenario: Fresh profile without an approved category catalog

- **GIVEN** a fresh database is created and no approved accounting-catalog manifest is bundled
- **WHEN** seed data is inserted
- **THEN** no category is created with a generated SKR03, SKR04, EÜR, or EKS mapping
- **AND** the profile reports category accounting setup as unconfigured

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

## ADDED Requirements

### Requirement: Category mapping provenance is persisted

The versioned database migration SHALL add `mapping_status TEXT NOT NULL`, nullable `catalog_entry_key`, `catalog_source_reference`, `catalog_source_version`, and `mapping_reviewed_at` fields to `kategorien`. `mapping_status` SHALL allow only `catalog_verified`, `user_confirmed`, `legacy_unverified`, `review_required`, or `unmapped`. The migration SHALL create an append-only `category_mapping_history` table with a foreign-key category ID (`ON DELETE RESTRICT`), UTC change timestamp, action (`migration`, `catalog_import`, `mapping_edit`, or `user_review`), previous mapping JSON, new mapping JSON, and catalog source reference/version. Saving any mapping change and its history record SHALL be one transaction. Categories with history SHALL be deactivated rather than physically deleted. The migration SHALL add nullable `mapping_provenance_json` columns to `euer_exporte` and `datev_export_log`; new category-mapped output SHALL persist the versioned provenance snapshot, while preexisting export rows remain NULL. The migration SHALL preserve existing IDs, names, descriptions, mapping values, active state, and journal references while marking preexisting categories `legacy_unverified` and recording their pre-migration values.

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
- **THEN** `euer_exporte.mapping_provenance_json` or `datev_export_log.mapping_provenance_json` stores a JSON snapshot shaped as `{"version":1,"mappings":[{"category_id":1,"status":"catalog_verified","catalog_entry_key":"...","source_reference":"...","source_version":"..."}]}`
- **AND** existing export rows remain unchanged with NULL provenance metadata
- **AND** new history and review timestamps use UTC ISO-8601 format
