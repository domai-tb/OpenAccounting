## MODIFIED Requirements

### Requirement: Separate databases per profile

Each profile SHALL have its own isolated SQLite database under `<data_dir>/profiles/<profile_name>/`. `profile.json` SHALL store the active profile and the registered profile names. The registered names SHALL define the profiles visible to normal application workflows; unregistered profile directories SHALL remain untouched and SHALL NOT be loaded automatically. When upgrading a legacy pointer-only `profile.json`, the manager SHALL seed the registered names from validated profile directories and preserve every directory and database.

#### Scenario: New profile creates isolated database

- **GIVEN** no profile exists
- **WHEN** the application creates the initial profile `Geschäft`
- **THEN** its isolated database SHALL be initialized and `profile.json` SHALL contain `active: Geschäft` and `Geschäft` in the registered names

#### Scenario: Additional profile is registered without changing the active profile

- **GIVEN** the active profile is `Privat`
- **WHEN** a new profile `Geschäft` is created
- **THEN** its isolated database SHALL be initialized and `Geschäft` SHALL be added to the registered names while `Privat` remains active

#### Scenario: Profile isolation

- **GIVEN** `Privat` and `Geschäft` each contain an invoice with the same document number
- **WHEN** a query runs against one active profile
- **THEN** it SHALL read only that profile's database and the other profile's invoice SHALL remain isolated

#### Scenario: Legacy profile catalog is recovered without data loss

- **GIVEN** `profile.json` has an active pointer but no registered-name list and multiple safe profile directories exist
- **WHEN** the profile manager loads the catalog
- **THEN** it SHALL persist those directory names as registered profiles and SHALL NOT delete or move any profile directory or database

#### Scenario: Corrupted profile.json falls back to default

- **GIVEN** `profile.json` contains invalid JSON and safe profile directories exist
- **WHEN** the application loads profiles
- **THEN** it SHALL recover a usable catalog from the safe directories, select the first available profile only under the existing recovery rule, and display a warning without changing any profile files

### Requirement: Delete profile

The Profile Manager SHALL allow a confirmed non-destructive removal of an eligible inactive profile from the registered-name list in `profile.json`. Removal SHALL NOT delete, move, truncate, or overwrite the profile directory, database, uploads, or backups. The active profile and last registered profile SHALL NOT be removable. The application SHALL NOT automatically purge unregistered profile data. A permanent-erasure or retention duration policy remains unresolved and SHALL NOT be inferred from unregistering a profile.

#### Scenario: Delete inactive profile

- **GIVEN** the Profile Manager is open, `Privat` is active, and `Geschäft` is registered
- **WHEN** the user confirms removal of `Geschäft`
- **THEN** `Geschäft` SHALL no longer appear in the registered profile list and its directory, database, uploads, and backups SHALL remain unchanged on disk

#### Scenario: Cannot delete active profile

- **GIVEN** the selected profile is active or is the last registered profile
- **WHEN** the user requests removal
- **THEN** the registry and all profile files SHALL remain unchanged and the manager SHALL return a localized explanation

#### Scenario: Delete last remaining profile

- **GIVEN** only one profile is registered
- **WHEN** the user requests its removal
- **THEN** the registry and all profile files SHALL remain unchanged and the manager SHALL explain that at least one profile must remain

#### Scenario: Unregistered data is not automatically purged

- **GIVEN** a profile directory exists but its name is no longer registered
- **WHEN** the application starts or the profile catalog is loaded
- **THEN** no cleanup task SHALL erase or alter that directory or its files
