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
