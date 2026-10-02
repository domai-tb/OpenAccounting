## MODIFIED Requirements

### Requirement: Separate databases per profile

Each profile SHALL have its own isolated SQLite database under `<data_dir>/profiles/<profile_name>/`. `profile.json` SHALL store the active profile and the registered profile names. The registered names SHALL be the only source used by startup, recovery, Settings, and explicit profile selection during normal operation. Every target SHALL be validated as a safe direct child with a valid profile database before it is opened. Unregistered profile directories SHALL remain untouched and SHALL NOT be listed or loaded automatically. When upgrading a legacy pointer-only `profile.json`, the manager SHALL seed registered names only from validated profile directories and preserve every directory and database.

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

#### Scenario: Legacy profile catalog is migrated without data loss

- **GIVEN** `profile.json` has an active pointer but no registered-name list and multiple safe profile directories exist
- **WHEN** the profile manager loads the catalog
- **THEN** it SHALL persist only safe directories whose databases pass profile validation as registered profiles and SHALL NOT delete or move any profile directory or database

#### Scenario: Profile selection uses the registered catalog

- **GIVEN** a registered profile and an unregistered profile directory both exist
- **WHEN** startup, the recovery picker, Settings, or explicit profile selection requests the available profiles
- **THEN** each normal workflow SHALL list only the registered profile and SHALL reject an attempt to open the unregistered directory

#### Scenario: Unregistered active pointer is not loaded after restart

- **GIVEN** `profile.json` points to a profile directory that is not in its registered-name list
- **WHEN** the application starts
- **THEN** it SHALL NOT open that directory and SHALL enter the profile recovery flow without changing its database or files

#### Scenario: Corrupted profile.json falls back to default

- **GIVEN** `profile.json` contains invalid JSON and exactly one safe profile database can be validated
- **WHEN** the application loads profiles
- **THEN** it SHALL recover a catalog containing that profile, select it as active, and display a warning without changing its database or other profile files

#### Scenario: Corrupted profile catalog with multiple validated profiles

- **GIVEN** `profile.json` is missing or contains invalid JSON and multiple safe profile databases can be validated
- **WHEN** the application starts
- **THEN** it SHALL display a dedicated recovery picker containing the validated candidates, SHALL NOT choose or persist an active profile before explicit user selection, and SHALL leave every database and profile directory unchanged

#### Scenario: Invalid profile candidates are preserved but unavailable

- **GIVEN** a profile directory is not a safe direct child or its database fails profile validation
- **WHEN** the application migrates or recovers the catalog
- **THEN** that candidate SHALL remain unchanged on disk and SHALL NOT be registered, listed, or opened

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
