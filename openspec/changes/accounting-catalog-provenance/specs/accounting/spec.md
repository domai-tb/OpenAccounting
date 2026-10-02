## MODIFIED Requirements

### Requirement: Kategorien

The system SHALL provide categories with stable IDs, name, description, activation status, optional SKR03/SKR04/EÜR/EKS mappings, and mapping provenance. It MUST NOT claim a fixed minimum count or present mappings as standard unless they came from an approved, versioned catalog manifest. Each category SHALL distinguish `catalog_verified`, `user_confirmed`, `legacy_unverified`, `review_required`, and `unmapped` status as applicable. A manual edit to any mapping field SHALL set the category to `review_required`; `user_confirmed` requires an explicit review of every populated mapping field. User-confirmed mappings MUST remain distinguishable from catalog-verified mappings.

#### Scenario: Approved catalog category has traceable mappings

- **GIVEN** an approved manifest entry supplies a category and applicable accounting mappings
- **WHEN** the category is persisted
- **THEN** its values match the manifest entry and it records the stable entry key, source version, and `catalog_verified` status

#### Scenario: Category with SKR mapping

- **GIVEN** an approved manifest entry supplies applicable SKR03 and SKR04 mappings
- **WHEN** a category is created from that entry
- **THEN** both account values match the entry and the category records its source version and `catalog_verified` status

#### Scenario: User-defined category is not described as a standard mapping

- **GIVEN** a user creates a category without an approved manifest entry and enters accounting mapping values
- **WHEN** the category is persisted
- **THEN** it is marked `user_confirmed` only after the user explicitly reviews all populated mappings
- **AND** the UI identifies it as user-configured rather than catalog-verified

#### Scenario: Unmapped user category remains explicitly unmapped

- **GIVEN** a user creates a category without accounting mapping values
- **WHEN** the category is persisted
- **THEN** it has `unmapped` status and no generated mapping value

#### Scenario: Editing a catalog mapping requires review

- **GIVEN** a category has `catalog_verified` status and a user edits any accounting mapping field
- **WHEN** the edit is saved
- **THEN** its status becomes `review_required` while the prior catalog source/version remains recorded as baseline provenance
- **AND** it is not represented as catalog-verified until reviewed

#### Scenario: User-modified SKR account

- **GIVEN** a user overrides the SKR03 account for a category
- **WHEN** the override is saved
- **THEN** the entered value is preserved and the category becomes `review_required`
- **AND** it cannot be used as a catalog-verified mapping until all populated mapping fields are explicitly reviewed

#### Scenario: Legacy category values are retained but untrusted

- **GIVEN** a category existed before provenance migration
- **WHEN** the category is loaded after migration
- **THEN** all pre-migration values and references remain unchanged and its status is `legacy_unverified`
- **AND** it remains readable in historical journal views

#### Scenario: Legacy category cannot be posted before review

- **GIVEN** a category has `legacy_unverified` status
- **WHEN** the user attempts to use it for a new journal entry
- **THEN** the entry is rejected with that category's ID and a mapping-review action

#### Scenario: Inactive category

- **GIVEN** a category with `aktiv=0`
- **WHEN** the booking form is displayed
- **THEN** the category does not appear in new-entry dropdowns, but existing journal entries referencing it remain visible

#### Scenario: Category description

- **GIVEN** a category with `beschreibung` set
- **WHEN** a user selects the category in the booking form
- **THEN** the booking form displays the description as a hint

#### Scenario: Unmapped category does not receive an invented account

- **GIVEN** a category has no SKR mapping
- **WHEN** a journal entry or export resolves its category account
- **THEN** the mapping remains absent and no default or formula-generated account number is substituted

#### Scenario: Category with missing SKR mapping

- **GIVEN** a category has `konto_skr03` or `konto_skr04` set to NULL
- **WHEN** a DATEV export requires that account mapping
- **THEN** export resolution reports the category as unresolved and does not substitute a default account

### Requirement: Mapping-dependent reports and exports disclose provenance

EÜR, GuV, and DATEV SHALL use only `catalog_verified` or explicitly `user_confirmed` category mappings. Output using user-confirmed mappings MUST identify them as user-configured and not source-verified in the preview and persisted export metadata. If an output depends on a `legacy_unverified`, `review_required`, or `unmapped` category, generation MUST fail with the affected category IDs and MUST NOT silently omit those entries or substitute a default account.

#### Scenario: User-configured output is identified

- **GIVEN** a requested report or export uses only `catalog_verified` and `user_confirmed` mappings
- **WHEN** the output is generated
- **THEN** output metadata lists the catalog source version for verified mappings and identifies user-confirmed mappings as not source-verified

#### Scenario: Unresolved mapping stops the output

- **GIVEN** a requested report or export includes a contributing `legacy_unverified`, `review_required`, or `unmapped` category
- **WHEN** generation is requested
- **THEN** generation fails with those category IDs
- **AND** no successful report/export is recorded and no fallback account is emitted
