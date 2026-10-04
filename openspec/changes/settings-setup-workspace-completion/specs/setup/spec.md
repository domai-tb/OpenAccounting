## MODIFIED Requirements

### Requirement: Four-step wizard flow

The setup wizard SHALL consist of exactly four steps in order: Stammdaten, Konten, Kategorien, and Abschluss. Each step SHALL have Next/Back navigation and a progress indicator. It SHALL collect the company name, address, tax ID, legal form, and bank-account IBAN, BIC, and account holder, then show the values that will be persisted. The account holder SHALL be stored in the account record. Step 3 SHALL use only category records whose catalog source and edition are covered by an accepted accounting-catalog provenance contract and whose mapping manifest has passed its required review. A version string or populated category table alone SHALL NOT establish trust. The application SHALL verify the stored source, edition, manifest identity, and accepted review status before marking categories selectable. If no verified catalog is available, Step 3 SHALL clearly mark category selection as deferred, allow the user to continue without category IDs, and show that setup remains incomplete for categories; it MUST NOT present the current synthetic seed rows as a real chart of accounts. Skip SHALL close setup with minimal company/account values, no category selection, and an explicit deferred state. A later verified catalog MAY populate the same step without changing the four-step order.

#### Scenario: Setup displays and saves real values

- **GIVEN** the setup database exposes a verified category catalog
- **WHEN** the user completes all four steps and reviews Abschluss
- **THEN** the summary SHALL show the entered company and account values and selected stored category names, and completion SHALL persist the account holder and category IDs through the setup transaction

#### Scenario: Categories remain deferred when no verified catalog exists

- **GIVEN** setup is opened with missing, unknown-version, or explicitly unverified category seed data
- **WHEN** the user reaches the Kategorien step
- **THEN** the step SHALL explain that categories are unavailable pending an approved catalog, allow continuation without category IDs, and SHALL show the category choice as incomplete in the Abschluss summary

#### Scenario: Synthetic category rows are not offered as configured records

- **GIVEN** the database contains the current generated `Kategorie N` rows or rows with an unverified catalog version
- **WHEN** the user opens setup or a category selector
- **THEN** those rows SHALL NOT be presented as an approved chart, and no selection or report mapping SHALL be marked configured from those rows

#### Scenario: Catalog version without accepted provenance is not trusted

- **GIVEN** category rows contain a version marker but lack an accepted source/edition provenance record or reviewed mapping manifest
- **WHEN** setup loads the Kategorien step
- **THEN** it SHALL treat the catalog as unverified, defer category selection, and SHALL NOT mark any category mapping as configured

#### Scenario: Invalid required setup value blocks progression

- **GIVEN** a required company or account value is invalid
- **WHEN** the user attempts to advance or finish the wizard
- **THEN** the wizard SHALL remain on the relevant step, show a localized actionable validation error, and SHALL NOT persist the invalid value

#### Scenario: Back navigation preserves entered values

- **GIVEN** the user has entered valid company and account fields and is on step 3
- **WHEN** the user selects Zurück
- **THEN** step 2 SHALL return with the previously entered account values intact

#### Scenario: Skip keeps unconfigured choices explicit

- **GIVEN** the user chooses Überspringen before completing setup
- **WHEN** the wizard closes
- **THEN** minimal defaults SHALL be created without marking company identity, bank accounts, or category mappings as user-configured, and Settings SHALL identify the deferred destinations

## ADDED Requirements

### Requirement: Bank-account holder survives setup persistence

The setup persistence boundary SHALL store the account holder entered in the wizard. Existing profile databases SHALL receive a nullable `konten.inhaber` column through the ordered schema migration path. Create and duplicate-IBAN update paths SHALL persist the normalized holder value, and setup summaries SHALL read that value back from the same account record.

#### Scenario: Holder value is persisted and reviewed

- **GIVEN** the user enters `Max Mustermann` as the holder for a bank account
- **WHEN** setup saves and reloads the account summary
- **THEN** the existing account row SHALL contain `inhaber = Max Mustermann` and the summary SHALL display that stored value

#### Scenario: Existing database receives the holder field safely

- **GIVEN** an existing profile database has a `konten` table without `inhaber`
- **WHEN** the ordered schema migration runs
- **THEN** it SHALL add the nullable column without rewriting existing account values or changing their IDs

## MODIFIED Requirements

### Requirement: Required field validation per step

Each wizard step SHALL validate required fields before allowing progression. Step 1 requires company name. Step 2 requires at least one bank account with a valid IBAN. Step 3 requires at least one selected category only when a verified category catalog is available; with a missing or unverified catalog it SHALL permit continuation with an explicit deferred state and no category IDs. Validation and load errors SHALL be localized and displayed inline below the relevant field or step.

#### Scenario: Step 1 validation failure

- **GIVEN** the user is on step 1 (Stammdaten)
- **WHEN** the user leaves the company name field empty and selects Weiter
- **THEN** an inline error SHALL appear below the name field and the wizard SHALL NOT advance

#### Scenario: Step 2 validation failure

- **GIVEN** the user is on step 2 (Konten)
- **WHEN** the user enters an invalid IBAN and selects Weiter
- **THEN** an inline error SHALL appear below the IBAN field and the wizard SHALL NOT advance

#### Scenario: Step 3 validation failure

- **GIVEN** a verified category catalog is available and the user selected no category
- **WHEN** the user selects Weiter
- **THEN** an inline error SHALL indicate that at least one category is required and the wizard SHALL NOT advance

#### Scenario: Step 3 permits deferred categories when no verified catalog exists

- **GIVEN** no verified category catalog is available
- **WHEN** the user selects Weiter without a category ID
- **THEN** the wizard SHALL advance with a localized deferred notice and SHALL NOT invent or persist a category selection

### Requirement: Profile selection on startup

When multiple registered profiles exist, the system SHALL display a profile selection screen on startup before loading the main application. The selected profile SHALL determine the active database path. Startup selection and recovery lists SHALL use the validated registered profile catalog, never every directory by default. An absent or corrupt catalog with one validated profile SHALL recover that profile with a warning; when multiple valid recovery candidates exist the user SHALL choose explicitly before an active profile is persisted.

#### Scenario: Multiple profiles exist

- **GIVEN** more than one validated profile is registered
- **WHEN** the application starts
- **THEN** a profile selection screen SHALL list only those registered profiles and SHALL highlight the last-used registered profile when it is available

#### Scenario: Unregistered directory exists

- **GIVEN** an unregistered profile directory exists beside registered profiles
- **WHEN** the application starts normally
- **THEN** the directory SHALL not appear in profile selection and SHALL not be loaded

#### Scenario: Multiple profiles need catalog recovery

- **GIVEN** the profile catalog is missing or corrupt and multiple valid profile directories exist
- **WHEN** the application starts
- **THEN** a recovery selection screen SHALL appear without preselecting or persisting an active profile until the user chooses one

#### Scenario: Single profile exists

- **GIVEN** exactly one validated registered profile exists
- **WHEN** the application starts with a valid catalog
- **THEN** that profile SHALL be loaded automatically without showing the selection screen

#### Scenario: Profile switching requires restart

- **GIVEN** the user has selected a different registered profile from Settings or profile manager
- **WHEN** the profile switch is confirmed
- **THEN** the application SHALL persist the selection and clearly require restart before loading the new profile database

#### Scenario: No profiles exist

- **GIVEN** no valid or recoverable profile exists
- **WHEN** the application starts
- **THEN** the system SHALL create and register a default profile and load it automatically
