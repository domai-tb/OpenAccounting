# Setup Wizard

## Purpose
First-run setup wizard with empty database detection, company creation, and initial configuration.

## Requirements

### Requirement: Empty database detection triggers wizard

The system SHALL detect an empty database on application start (no `unternehmen` record, or `unternehmen` with no `name` set). When an empty database is detected, the system SHALL automatically launch the setup wizard before showing the main application.

#### Scenario: First launch with empty database

GIVEN no existing database file is present
WHEN the application starts for the first time
THEN the setup wizard SHALL be displayed automatically
AND the main application SHALL NOT be accessible until the wizard is completed or dismissed.

#### Scenario: Existing database with data

GIVEN the database contains a valid `unternehmen` record with a name
WHEN the application starts
THEN the setup wizard SHALL NOT be displayed
AND the main application SHALL load normally.

#### Scenario: Corrupted unternehmen record

GIVEN the database exists but the `unternehmen` table is corrupted or unreadable
WHEN the application starts
THEN the system SHALL display a database error message
AND SHALL NOT launch the setup wizard.

### Requirement: Four-step wizard flow

The setup wizard SHALL consist of exactly 4 steps in order: (1) Stammdaten (company name, address, tax ID, legal form), (2) Konten (bank accounts with IBAN, BIC, account holder), (3) Kategorien (income/expense category selection from predefined set), (4) Abschluss (review and finish). Each step SHALL have Next/Back navigation and a progress indicator.

#### Scenario: Complete wizard flow

GIVEN the setup wizard is displayed
WHEN the user starts the setup wizard
THEN step 1 (Stammdaten) SHALL be displayed first
AND after filling required fields and clicking Next, step 2 (Konten) SHALL appear
AND after configuring at least one bank account, step 3 (Kategorien) SHALL appear
AND after selecting categories, step 4 (Abschluss) SHALL show a summary
AND clicking "Fertig" SHALL persist all data and close the wizard.

#### Scenario: Navigation between steps

GIVEN the user is on step 3 of the wizard
WHEN the user clicks "Zurück"
THEN step 2 SHALL be displayed with previously entered data preserved.

#### Scenario: Skip wizard

GIVEN the setup wizard is displayed
WHEN the user clicks "Überspringen" on any wizard step
THEN the system SHALL skip remaining steps
AND create minimal defaults (empty company, no accounts, standard categories)
AND close the wizard.

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

### Requirement: Kassenbestand initialization

The setup wizard SHALL initialize the `kassenbestand` table with a starting balance of 0.00 on completion. The user SHALL be able to optionally set an initial cash balance during step 2 (Konten).

#### Scenario: Default cash balance

GIVEN the user completes the setup wizard without entering a cash balance
WHEN the wizard finishes
THEN `kassenbestand` SHALL be initialized with betrag=0.00 and the current date.

#### Scenario: Custom cash balance

GIVEN the user enters an initial cash balance of 150.00 during the wizard
WHEN the wizard finishes
THEN `kassenbestand` SHALL be initialized with betrag=150.00 and the current date.

#### Scenario: Negative cash balance rejected

GIVEN the user is on step 2 (Konten)
WHEN the user enters a negative cash balance
THEN an inline error message SHALL appear indicating the balance must be non-negative.

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

### Requirement: Profile manager UI

The system SHALL provide a Profile Manager accessible from the application menu. The Profile Manager SHALL allow creating new profiles, deleting existing profiles, and renaming profiles. Deleting a profile SHALL require confirmation and SHALL NOT delete the database file (only remove the directory entry from `profile.json`).

#### Scenario: Create new profile

GIVEN the Profile Manager is open
WHEN the user clicks "Neues Profil" and enters a profile name
THEN a new profile directory SHALL be created under `profiles/`
AND a new empty database SHALL be initialized in that directory
AND the Profile Manager SHALL list the new profile.

#### Scenario: Delete profile

GIVEN the Profile Manager is open and a non-active profile is selected
WHEN the user clicks "Löschen" and confirms the deletion
THEN the profile entry SHALL be removed from `profile.json`
AND the profile directory and database SHALL remain on disk (not deleted).

#### Scenario: Rename to duplicate name rejected

GIVEN the Profile Manager is open
WHEN the user attempts to rename a profile to a name that already exists
THEN the system SHALL display an error message
AND SHALL NOT perform the rename.

### Requirement: Platform-specific data paths

The system SHALL use platform-appropriate data directories: `~/.local/share/OpenInvoices/` on Linux, `~/Library/Application Support/OpenInvoices/` on macOS, and `%LOCALAPPDATA%/OpenInvoices/` on Windows. Profile databases SHALL be stored under `<data_dir>/profiles/<name>/`.

#### Scenario: Linux data path

GIVEN the application runs on Linux
WHEN a profile database is created
THEN it SHALL be stored under `~/.local/share/OpenInvoices/profiles/<name>/`.

#### Scenario: macOS data path

GIVEN the application runs on macOS
WHEN a profile database is created
THEN it SHALL be stored under `~/Library/Application Support/OpenInvoices/profiles/<name>/`.

#### Scenario: Windows data path

GIVEN the application runs on Windows
WHEN a profile database is created
THEN it SHALL be stored under `%LOCALAPPDATA%/OpenInvoices/profiles/<name>/`.

### Requirement: Cash account initialization

The setup wizard SHALL create a cash account in the existing `konten` table with `kontoart = Kasse` and an opening balance of 0.00 on completion. The user SHALL be able to optionally set an initial cash balance during step 2 (Konten). The opening balance SHALL be recorded through the standard opening journal mechanism linked to that cash account; no separate `kassenbestand` table SHALL be created.

#### Scenario: Default cash balance

GIVEN the user completes the setup wizard without entering a cash balance
WHEN the wizard finishes
THEN a `konten` row with `kontoart = Kasse` SHALL exist
AND its opening journal entry SHALL record betrag=0.00 on the current date.

#### Scenario: Custom cash balance

GIVEN the user enters an initial cash balance of 150.00 during the wizard
WHEN the wizard finishes
THEN a `konten` row with `kontoart = Kasse` SHALL exist
AND its opening journal entry SHALL record betrag=150.00 on the current date.

#### Scenario: Negative cash balance rejected

GIVEN the user is on step 2 (Konten)
WHEN the user enters a negative cash balance
THEN an inline error message SHALL appear indicating the balance must be non-negative.

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
