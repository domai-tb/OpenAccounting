# Multi-Profile Management

## Purpose
Multi-profile management with separate databases, profile switching, and workspace isolation.

## Requirements

### Requirement: Separate databases per profile

Each profile SHALL have its own isolated SQLite database under `<data_dir>/profiles/<profile_name>/`. `profile.json` SHALL store the active profile and the registered profile names. The registered names SHALL be the only source used by startup, recovery, Settings, and explicit profile selection during normal operation. Every target SHALL be validated as a safe direct child with a valid profile database before it is opened. Candidate validation during catalog migration or recovery SHALL use a read-only `ProfileReadOnlyProbe`; it SHALL NOT open a writable database, apply migrations, install triggers, repair schema, seed rows, or alter candidate bytes. Unregistered profile directories SHALL remain untouched and SHALL NOT be listed or loaded automatically. When upgrading a legacy pointer-only `profile.json`, the manager SHALL seed registered names only from candidates accepted by that probe and preserve every directory and database.

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

#### Scenario: Valid but outdated candidate remains unchanged until selected

- **GIVEN** a candidate database is structurally readable but needs a newer schema migration
- **WHEN** catalog migration or ambiguous-catalog recovery probes that candidate
- **THEN** the probe SHALL report its compatibility without running a migration or seed, and the database SHALL remain byte-for-byte unchanged until the user selects it for normal startup

### Requirement: APP_DATA_DIR resolved per profile

The application SHALL resolve `APP_DATA_DIR` to point to the active profile's directory (e.g., `~/.local/share/OpenInvoices/profiles/Geschäft/`). All file operations (uploads, backups, logos) SHALL use `APP_DATA_DIR` as the root. Code SHALL NOT hardcode paths outside `APP_DATA_DIR`.

#### Scenario: Upload path uses active profile

GIVEN the active profile is "Geschäft"
WHEN the user uploads a logo
THEN the logo SHALL be stored under `~/.local/share/OpenInvoices/profiles/Geschäft/uploads/logo.png`
AND NOT under a hardcoded path.

#### Scenario: Backup path uses active profile

GIVEN the active profile is "Privat"
WHEN a local backup is triggered
THEN the backup SHALL be stored under `~/.local/share/OpenInvoices/profiles/Privat/backups/`.

#### Scenario: Code outside APP_DATA_DIR is rejected

GIVEN a file operation attempts to write to a path outside `APP_DATA_DIR`
WHEN the operation is executed
THEN the system SHALL reject the write with a path traversal error.

### Requirement: Profile switching requires restart

When the user selects a different registered profile, the application SHALL persist the selection to `profile.json` and show a localized restart-required state; it SHALL NOT switch the database, providers, or session identity before restart. Selecting the active profile SHALL be a no-op without restart or pointer rewrite. A `profile.json` active pointer that references a missing, unregistered, or invalid profile SHALL NOT fall back to the first available profile by filesystem order; the application SHALL enter the profile recovery flow without opening or altering any database or files, and with multiple valid candidates SHALL require explicit user selection before persisting an active profile.

#### Scenario: Switch profile persists selection and requires restart

- **GIVEN** the active profile is `Geschäft` and `Privat` is registered
- **WHEN** the user selects `Privat` in the Profile Manager
- **THEN** `profile.json` SHALL be updated to `{"active": "Privat"}`, Settings SHALL show a restart-required state, the current session SHALL continue to show only `Geschäft` until restart, and after restart only the `Privat` database SHALL be loaded

#### Scenario: Switch to same profile is a no-op

- **GIVEN** the active profile is `Privat`
- **WHEN** the user selects `Privat` in the Profile Manager
- **THEN** the application SHALL NOT restart, SHALL NOT rewrite the active pointer, and the current database SHALL remain loaded

#### Scenario: Switch to non-existent profile does not fall back to first available

- **GIVEN** `profile.json` references a profile that does not exist on disk or is not in the registered-name list
- **WHEN** the application starts
- **THEN** it SHALL NOT open the first available profile by filesystem order, SHALL enter the profile recovery flow without changing any database or files, SHALL display a warning, and with multiple valid candidates SHALL require explicit user selection before persisting an active profile
#### Scenario: Switch profile

- **GIVEN** the active profile is "Geschäft"
- **WHEN** the user selects "Privat" in the Profile Manager
- **THEN** the outcome SHALL follow "Switch profile persists selection and requires restart" above; no pre-restart database switch SHALL occur

#### Scenario: Switch to non-existent profile

- **GIVEN** `profile.json` references a profile that does not exist on disk
- **WHEN** the application starts
- **THEN** the outcome SHALL follow "Switch to non-existent profile does not fall back to first available" above; the legacy first-available fallback SHALL NOT apply

### Requirement: Profile manager UI

The application SHALL provide a `Profile` menu entry accessible from the main navigation or Settings. The Profile Manager SHALL display all profiles with name, database size, and last-modified timestamp, and support create, select, rename, and eligible delete actions. For exactly one profile, the entry SHALL be visible only when the module catalog resolves `profile_manager` as effectively enabled. When more than one profile exists, the entry SHALL be visible regardless of the saved catalog preference. Profile switching requires a process restart.

#### Scenario: Profile manager accessible with multiple profiles

- **GIVEN** more than one profile directory exists and the saved `profile_manager` preference is disabled
- **WHEN** the application loads
- **THEN** the Profile Manager menu entry is visible regardless of that preference

#### Scenario: Profile manager hidden with single profile

- **GIVEN** exactly one profile exists and the module catalog resolves `profile_manager` as disabled
- **WHEN** the application loads
- **THEN** the Profile Manager menu entry is hidden

#### Scenario: Profile manager shown when explicitly activated

- **GIVEN** exactly one profile exists and the module catalog resolves `profile_manager` as enabled
- **WHEN** the application loads
- **THEN** the Profile Manager menu entry is visible

### Requirement: Auto-show profile manager when multiple profiles exist

The Profile Manager SHALL be automatically shown on application start when more than one profile exists and no profile has been pre-selected. When exactly one profile exists, the Profile Manager SHALL be hidden and that profile loaded automatically.

#### Scenario: Multiple profiles on first start

GIVEN `profile.json` does not exist AND more than one profile directory exists
WHEN the application starts
THEN the Profile Manager SHALL be displayed for selection.

#### Scenario: Single profile auto-load

GIVEN exactly one profile directory exists
WHEN the application starts
THEN that profile SHALL be loaded automatically
AND the Profile Manager SHALL NOT be shown.

#### Scenario: No profiles exist

GIVEN no profile directories exist
WHEN the application starts
THEN the system SHALL create a default profile
AND load it automatically.

### Requirement: Create new profile

The Profile Manager SHALL allow creating a new profile with a user-provided name. Profile names SHALL be unique (case-insensitive). Creating a profile SHALL initialize a new database with the full schema and seed data. The newly created profile SHALL NOT automatically become active (the user must explicitly switch).

#### Scenario: Create profile with unique name

GIVEN the Profile Manager is open
WHEN the user enters "Steuerberater" as a new profile name and no existing profile has that name
THEN a new profile directory SHALL be created
AND a fresh database SHALL be initialized with schema and seeds
AND the Profile Manager list SHALL update.

#### Scenario: Create profile with duplicate name

GIVEN the Profile Manager is open and a profile named "Privat" already exists
WHEN the user enters "Privat" as a new profile name
THEN the system SHALL display an error: "Profilname existiert bereits"
AND no new profile SHALL be created.

#### Scenario: Empty profile name rejected

GIVEN the Profile Manager is open
WHEN the user enters an empty string as a profile name
THEN the system SHALL display a validation error
AND no new profile SHALL be created.

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

### Requirement: Rename profile

The Profile Manager SHALL allow renaming a profile. Renaming SHALL move the profile directory on disk and update all references in `profile.json`. The new name SHALL be unique (case-insensitive).

#### Scenario: Rename profile

GIVEN the Profile Manager is open
WHEN the user renames "Privat" to "Privat_2026"
THEN the directory SHALL be moved from `profiles/Privat/` to `profiles/Privat_2026/`
AND `profile.json` SHALL be updated with the new name.

#### Scenario: Rename to duplicate name rejected

GIVEN the Profile Manager is open and a profile named "Geschäft" exists
WHEN the user attempts to rename "Privat" to "Geschäft"
THEN the system SHALL display an error
AND SHALL NOT perform the rename.

#### Scenario: Rename active profile triggers restart

GIVEN the active profile is "Privat"
WHEN the user renames "Privat" to "Privat_2026"
THEN the application SHALL restart to load the renamed profile.

### Requirement: Platform-specific data paths

The system SHALL use platform-appropriate base data directories: `~/.local/share/OpenInvoices/` on Linux, `~/Library/Application Support/OpenInvoices/` on macOS, and `%LOCALAPPDATA%/OpenInvoices/` on Windows. Profile subdirectories SHALL be created under this base path.

#### Scenario: Linux profile path

GIVEN the application runs on Linux AND the active profile is "Geschäft"
WHEN `APP_DATA_DIR` is resolved
THEN it SHALL resolve to `~/.local/share/OpenInvoices/profiles/Geschäft/`.

#### Scenario: macOS profile path

GIVEN the application runs on macOS AND the active profile is "Geschäft"
WHEN `APP_DATA_DIR` is resolved
THEN it SHALL resolve to `~/Library/Application Support/OpenInvoices/profiles/Geschäft/`.

#### Scenario: Windows profile path

GIVEN the application runs on Windows AND the active profile is "Geschäft"
WHEN `APP_DATA_DIR` is resolved
THEN it SHALL resolve to `%LOCALAPPDATA%/OpenInvoices/profiles/Geschäft/`.

### Requirement: Safe profile names and canonical local paths

Profile names MUST be non-empty single path components. The system SHALL reject `.` and `..` path segments, `/`, `\`, NUL/control characters, and any name that would normalize to a different path component. Names SHALL remain unique case-insensitively. Before creating, renaming, or writing a profile, the system SHALL resolve the base data directory and candidate profile directory to canonical paths and SHALL reject any candidate that is not beneath the canonical base directory, including paths that escape through symlinks. Local profile content writes SHALL be resolved canonically and remain beneath the active profile's canonical `APP_DATA_DIR`; the `profile.json` management pointer is written only at the canonical data-directory root. A missing or corrupt profile catalog SHALL be recovered using `ProfileReadOnlyProbe`: one valid candidate may be selected with a warning; multiple valid candidates SHALL require explicit user selection and MUST NOT be resolved by filesystem order.

#### Scenario: Profile name traversal rejected

- **GIVEN** the Profile Manager is open
- **WHEN** the user enters `../Geschäft`, `Privat/Geschäft`, or `Privat\Geschäft` as a profile name
- **THEN** the system SHALL reject the name before any directory or `profile.json` write and SHALL display a profile-name validation error

#### Scenario: Symlink escape rejected

- **GIVEN** a profile directory or parent path resolves through a symlink outside the canonical profile base
- **WHEN** the application resolves the profile's `APP_DATA_DIR`
- **THEN** the system SHALL reject the profile and SHALL NOT read or write files through the escaped path

#### Scenario: Local write stays within active profile

- **GIVEN** the active profile's canonical `APP_DATA_DIR` is resolved
- **WHEN** a local upload, logo, database, or backup path is constructed
- **THEN** the canonical target SHALL remain beneath `APP_DATA_DIR` and a target outside it SHALL be rejected before writing

#### Scenario: Corrupted profile.json falls back to default

- **GIVEN** `profile.json` contains invalid JSON and exactly one profile database passes the read-only profile probe
- **WHEN** the application starts
- **THEN** it SHALL recover a catalog containing that profile, select it as active, and display a warning without changing its database or other profile files

#### Scenario: Corrupt catalog with one candidate recovers without mutation

- **GIVEN** `profile.json` is missing or invalid and exactly one valid profile candidate exists
- **WHEN** recovery probes available profile directories
- **THEN** it SHALL recover that candidate with a warning without changing its database or files

#### Scenario: Corrupt catalog with multiple candidates requires explicit choice

- **GIVEN** `profile.json` is missing or invalid and multiple valid profile candidates exist
- **WHEN** recovery probes available profile directories
- **THEN** it SHALL show a picker with no preselected candidate and SHALL NOT persist an active profile until the user chooses one
