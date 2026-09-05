# Setup Wizard

## ADDED Requirements

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

Each wizard step SHALL validate required fields before allowing progression. Step 1 requires company name. Step 2 requires at least one bank account with IBAN. Step 3 requires at least one category selected. Validation errors SHALL be displayed inline below the relevant field.

#### Scenario: Step 1 validation failure

GIVEN the user is on step 1 (Stammdaten)
WHEN the user leaves the company name field empty and clicks "Weiter"
THEN an inline error message SHALL appear below the name field
AND the wizard SHALL NOT advance to step 2.

#### Scenario: Step 2 validation failure

GIVEN the user is on step 2 (Konten)
WHEN the user enters an invalid IBAN format and clicks "Weiter"
THEN an inline error message SHALL appear below the IBAN field
AND the wizard SHALL NOT advance to step 3.

#### Scenario: Step 3 validation failure

GIVEN the user is on step 3 (Kategorien)
WHEN the user deselects all categories and clicks "Weiter"
THEN an inline error message SHALL appear indicating at least one category is required
AND the wizard SHALL NOT advance to step 4.

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

### Requirement: Profile selection on startup

When multiple profiles exist, the system SHALL display a profile selection screen on startup before loading the main application. The selected profile SHALL determine the active database path. The system SHALL persist the last-used profile for quick selection.

#### Scenario: Multiple profiles exist

GIVEN more than one profile directory exists under `profiles/`
WHEN the application starts
THEN a profile selection screen SHALL be displayed listing all profiles
AND the last-used profile SHALL be highlighted/pre-selected.

#### Scenario: Single profile exists

GIVEN exactly one profile directory exists
WHEN the application starts
THEN the profile selection screen SHALL be skipped
AND that profile SHALL be loaded automatically.

#### Scenario: Profile switching requires restart

GIVEN the user has selected a different profile from the settings or profile manager
WHEN the profile switch is confirmed
THEN the application SHALL restart to load the new profile's database
AND the new profile SHALL be persisted as the last-used profile.

#### Scenario: No profiles exist

GIVEN no profile directories exist under `profiles/`
WHEN the application starts
THEN the system SHALL create a default profile
AND load it automatically without showing the selection screen.

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
