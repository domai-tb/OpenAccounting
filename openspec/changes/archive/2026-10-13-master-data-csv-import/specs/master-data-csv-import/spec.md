## ADDED Requirements

### Requirement: Local CSV import is scoped to supported master data

The application SHALL provide a CSV import action from the customer, supplier, and article workspaces. Each import SHALL target exactly one of those entity types and the active profile. The source SHALL be selected from the local filesystem and parsed as UTF-8 CSV, with or without a UTF-8 byte-order mark; the user SHALL select comma, semicolon, or tab as the delimiter and whether the first row is a header. The importer SHALL support quoted delimiters, escaped double quotes, and quoted line breaks. It SHALL reject a source larger than 20 MiB, more than 50,000 data rows, malformed CSV syntax, unsupported encoding, and records whose column count cannot be interpreted. It SHALL treat every source cell as data and SHALL NOT execute formulas or contact a remote service.

#### Scenario: Parse a mapped customer source
- **GIVEN** the user selects a UTF-8 CSV within the size and row limits, chooses semicolon and a header row, and maps columns to customer fields
- **WHEN** the file is parsed
- **THEN** quoted semicolons and escaped quotes remain within their source cells, the header is excluded from data rows, and each preview row retains its original one-based file row number

#### Scenario: Reject an invalid source before persistence
- **GIVEN** the selected CSV exceeds a configured file or row limit, has unsupported encoding, or has malformed quoting
- **WHEN** the importer parses the source
- **THEN** it reports a localized file-level error and creates or updates no customer, supplier, article, mapping template, or import record

#### Scenario: Choose whether the first row is a header
- **GIVEN** a CSV contains a first record that may be column labels or business data
- **WHEN** the user changes the header option
- **THEN** the mapping screen either presents that record as source labels or preserves it as the first data row, without automatic header guessing

### Requirement: Field mapping is typed and mapping templates are profile-local

The importer SHALL present only supported scalar destination fields for the selected entity and SHALL map source columns by column position. A source column SHALL map to at most one destination field, and a destination field SHALL be mapped from at most one source column. The importer SHALL NOT expose database primary keys, auto-assigned customer or supplier numbers, foreign-key IDs, article stock quantities, inventory controls, or arbitrary database columns as mapping targets. A saved mapping template SHALL record its entity, column mappings, header option, delimiter, numeric format, and duplicate policy; it SHALL NOT contain uploaded file bytes or source row values. Templates SHALL be stored in and visible only to the active profile, and SHALL only load for their recorded entity type.

#### Scenario: Save and reuse an article create mapping
- **GIVEN** a user maps an article CSV's description, type, and net price columns for Create and saves the mapping for the active profile
- **WHEN** the user selects that template for a later article CSV
- **THEN** its column positions, header option, delimiter, numeric format, and duplicate policy are restored without restoring any prior source values

#### Scenario: Reject a conflicting or cross-entity mapping
- **GIVEN** a user maps two columns to the same target field or selects a customer template while importing suppliers
- **WHEN** the user attempts to continue
- **THEN** the importer identifies the mapping conflict or entity mismatch and does not enter preview or write any master-data record

#### Scenario: Keep templates inside their profile
- **GIVEN** a saved customer template belongs to profile A
- **WHEN** profile B opens its customer import workflow
- **THEN** profile B does not list or load profile A's template

### Requirement: Preview validates every row before import

The importer SHALL parse and validate the complete selected file before any master-data write. The preview SHALL identify each source row, mapped values, validation errors, possible duplicate, proposed action, and totals for valid, invalid, duplicate, create, update, and skip rows. Rows SHALL use the existing typed master-data validation and value-conversion rules: customers and suppliers SHALL satisfy their existing required-field and country-specific VAT-ID rules; articles SHALL have a supported type and a valid explicitly selected gross or net price input. The user SHALL choose a numeric format before parsing numeric target fields; ambiguous or invalid values SHALL be row errors rather than guessed values. Required fields SHALL not be relaxed to make an import succeed. In particular, the feature-map's `firmenname` shorthand SHALL not bypass the currently required name and address fields in the customer and supplier repositories. Preview, remapping, validation, and cancellation before confirmation SHALL not write business records.

The numeric format SHALL be exactly one of decimal point or decimal comma, selected for the file. After trimming surrounding whitespace, the importer SHALL accept only a complete numeric token consisting of one or more ASCII digits, optionally followed by one selected decimal separator and one or more ASCII digits. Equivalently, the accepted grammars are `^[0-9]+(?:[.][0-9]+)?$` for decimal point and `^[0-9]+(?:,[0-9]+)?$` for decimal comma. Integer tokens without a separator SHALL be valid with either convention. The importer SHALL reject grouping separators, exponent notation, signs, the alternate decimal separator, internal whitespace, and partial numbers such as `.5`, `5.`, and `12abc`. After validating the complete token, it SHALL normalize the selected separator and pass the numeric value through the existing typed repository validator. Repository field precision and rounding SHALL remain authoritative; the importer SHALL NOT apply its own precision rounding.

#### Scenario: Review valid and invalid rows
- **GIVEN** a CSV contains a valid supplier row and another row with a missing required address value or invalid EU VAT-ID
- **WHEN** the preview is displayed
- **THEN** the first row is eligible for review, the second row shows a field-specific validation error, and no supplier row has yet been written

#### Scenario: Reject an ambiguous numeric value
- **GIVEN** a mapped article price cannot be parsed unambiguously using the selected numeric format
- **WHEN** the preview validates the row
- **THEN** that row is marked invalid with the price field identified and no rounded, default, or guessed price is proposed

#### Scenario: Accept decimal comma after outer trim
- **GIVEN** the decimal-comma convention is selected and a numeric cell contains ` 123,50 `
- **WHEN** the preview validates the cell
- **THEN** it parses the full token as 123.50 and passes it to the repository's typed precision and rounding rules

#### Scenario: Accept decimal point after outer trim
- **GIVEN** the decimal-point convention is selected and a numeric cell contains ` 123.50 `
- **WHEN** the preview validates the cell
- **THEN** it parses the full token as 123.50 and passes it to the repository's typed precision and rounding rules

#### Scenario: Reject grouping, alternate separators, exponents, and partial numbers
- **GIVEN** a numeric cell contains `1,234.56` or `1.234,56` as a grouped value, uses the separator opposite the selected convention, contains exponent notation such as `1e3`, an internal space such as `1 2`, a sign such as `-12`, or a partial number such as `.5`, `5.`, or `12abc`
- **WHEN** the preview validates the cell under either selected convention
- **THEN** the row is invalid with the numeric field identified and no value is truncated or guessed

#### Scenario: Cancel before confirmation
- **GIVEN** a complete preview has been prepared but not confirmed
- **WHEN** the user cancels the import
- **THEN** all customer, supplier, and article records remain unchanged

### Requirement: Duplicate handling never silently overwrites a record

The importer SHALL offer `Skip`, `Update`, and `Create New` duplicate strategies and SHALL default new templates to `Skip`. `Skip` and `Update` SHALL require a user-selected, mapped, non-empty match field; duplicate matching SHALL be exact after trimming surrounding whitespace and applying case-insensitive comparison to text values, with no fuzzy match. The importer SHALL recompute matches against the current active-profile data during preview and again before commit. Under `Skip`, a matching row SHALL be skipped and an unmatched valid row MAY be created. Under `Update`, a row with exactly one match SHALL show old and proposed values for every changed mapped field; an update SHALL require explicit per-row selection and final confirmation, SHALL update only non-empty mapped values, and SHALL preserve unmapped and blank-source fields. An article row selected for Update that supplies a selling-price or derivation field SHALL instead be invalid with a row-level unsupported-field error and SHALL NOT update any field on that article; its existing selling-price pair SHALL remain unchanged. An unmatched valid row SHALL be proposed as a create. A row matching multiple existing records or sharing a match key with another input row SHALL be marked ambiguous and SHALL not update any record. Under `Create New`, matching rows SHALL be visibly identified as duplicates and created only after the user confirms that strategy and the final import. Duplicate detection SHALL not be inferred from fuzzy name similarity or an unselected key.

#### Scenario: Confirm a unique duplicate update
- **GIVEN** an update import has exactly one existing customer for its selected email match key and the preview shows two changed mapped values
- **WHEN** the user explicitly selects Update for that row and confirms the reviewed batch
- **THEN** only those non-empty mapped values change on that customer, while its generated customer number and every unmapped field remain unchanged

#### Scenario: Leave an ambiguous duplicate unchanged
- **GIVEN** the selected article-number key matches two existing articles or is repeated by two source rows
- **WHEN** the duplicate preview is shown
- **THEN** the affected row is marked ambiguous, Update is unavailable for it, and neither existing article is modified

#### Scenario: Skip an existing record by default
- **GIVEN** a valid source row has an exact match for the selected customer key and the strategy is Skip
- **WHEN** the user confirms the batch
- **THEN** the matching customer remains unchanged and the result counts the source row as skipped

### Requirement: Article updates preserve paired selling prices

Article Create SHALL accept one user-selected selling-price basis, net or gross, and use the existing article create validator to derive and persist the paired `vk_netto` and `vk_brutto` values. Article Update SHALL NOT accept or change either price or any field used to select or derive that pair: `vk_netto`, `vk_brutto`, `vk_eingabe`, `ust_satz`, `ust_satz_id`, or `differenzbesteuerung`. When an article row selected for Update supplies a non-empty value mapped to any of those fields, the row SHALL receive a localized, row-level unsupported-field error naming the field, be invalid for the whole batch operation, and write none of its fields. An Update row without supplied values for those fields MAY update its other supported fields and SHALL preserve the existing selling-price pair and derivation fields exactly.

#### Scenario: Create an article from one selected price basis
- **GIVEN** a new article row provides one selected net or gross selling-price input and the required type and tax values
- **WHEN** the row is validated and created
- **THEN** the existing article create validator derives and persists both `vk_netto` and `vk_brutto`

#### Scenario: Update other article fields while preserving prices
- **GIVEN** an article Update row has no non-empty selling-price or derivation-field values and proposes a description change
- **WHEN** the row is explicitly selected and the batch is confirmed
- **THEN** the description changes while the article's existing `vk_netto`, `vk_brutto`, `vk_eingabe`, and tax derivation fields remain unchanged

#### Scenario: Reject supplied price fields on article Update
- **GIVEN** an article Update row supplies a non-empty value for `vk_netto`, `vk_brutto`, `vk_eingabe`, `ust_satz`, `ust_satz_id`, or `differenzbesteuerung`
- **WHEN** the preview validates the row
- **THEN** the row shows a localized unsupported-field error naming the field, is unavailable for Update, and writes none of its fields
- **AND** the existing article selling prices remain unchanged

### Requirement: Confirmed imports are atomic and have no accounting side effects

The importer SHALL require a final confirmation that summarizes the exact rows and actions to be applied. It SHALL commit all selected valid creates and updates in one transaction against the active profile database, preserving the existing master-data validation, customer/supplier number allocation, and (for article Create rows) article price derivation rules. If any selected write or final duplicate recheck fails, the transaction SHALL roll back all records and number-range changes from that batch and SHALL show a retryable failure with no success count. A successful result SHALL show created, updated, skipped, and validation-error counts. Import SHALL NOT create or modify invoices, journal entries, payments, receipts, supplier/customer balances, dunning state, or inventory quantities/movements.

#### Scenario: Commit a reviewed batch
- **GIVEN** the user confirms a preview containing valid creates, an explicitly reviewed unique update, skipped duplicates, and invalid rows excluded from the selection
- **WHEN** all selected writes pass validation and duplicate recheck
- **THEN** the selected master-data changes commit together and the result reports the exact created, updated, skipped, and invalid counts

#### Scenario: Roll back when a write fails
- **GIVEN** a confirmed batch has multiple selected valid rows and one write fails during persistence
- **WHEN** the import transaction ends
- **THEN** no record or allocated customer/supplier number from that batch is persisted and the UI reports the batch failure as retryable

#### Scenario: Keep import separate from accounting effects
- **GIVEN** the user imports a new article with a mapped sales price and type
- **WHEN** the import succeeds
- **THEN** the article exists with its derived counterpart price and no invoice, journal row, payment, stock quantity, or inventory movement is created

### Requirement: Import review follows the localized accessible workspace design

The import workflow SHALL use the existing master-data workspace and application-service boundaries and SHALL present source selection, mapping, validation, duplicate review, and final confirmation as one navigable workflow. User-visible labels, instructions, row errors, and result states SHALL be localized. Mapping controls, preview actions, row selections, and confirmation SHALL support keyboard navigation, visible focus, logical screen-reader order, and text scaling. Validation and duplicate status SHALL be conveyed in text or semantics and SHALL NOT depend on color alone. The preview SHALL keep columns and row actions usable at the documented desktop and narrow-window sizes.

#### Scenario: Review and confirm with keyboard
- **GIVEN** the user opens the importer at a narrow desktop window and navigates without a pointer
- **WHEN** the user maps fields, reviews a row error, and reaches the confirmation action
- **THEN** focus order is logical and visible, the error and row status have accessible text, and the complete action remains reachable without horizontal clipping

#### Scenario: Show a localized unavailable state
- **GIVEN** the active profile database becomes unavailable while templates or duplicate candidates are loading
- **WHEN** the import workflow displays the failure
- **THEN** it preserves the selected entity and mapping state, shows a localized retryable unavailable result, and does not present the missing data as an empty list or a successful import
