# Multi-Profile Management

## ADDED Requirements

### Requirement: Separate databases per profile

Each profile SHALL have its own isolated SQLite database file stored under `<data_dir>/profiles/<profile_name>/`. Profile directories SHALL be managed via a `profile.json` pointer file at the data directory root. The active profile SHALL be determined by `profile.json`, which contains `{"active": "<profile_name>"}`.

#### Scenario: New profile creates isolated database

GIVEN the Profile Manager is open
WHEN a new profile "Geschäft" is created
THEN a directory `profiles/Geschäft/` SHALL be created
AND a new empty database `openinvoices.db` SHALL be initialized in that directory
AND `profile.json` SHALL be updated with `{"active": "Geschäft"}`.

#### Scenario: Profile isolation

GIVEN profile "Privat" has an invoice with number RE-260001
AND profile "Geschäft" also has an invoice with number RE-260001
WHEN querying one profile
THEN both invoices SHALL exist independently in their respective databases
AND querying one profile SHALL NOT return data from the other.

#### Scenario: Corrupted profile.json falls back to default

GIVEN `profile.json` contains invalid JSON
WHEN the application starts
THEN the system SHALL display a warning
AND SHALL fall back to the first available profile directory.

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

When the user selects a different profile from the Profile Manager or settings, the application SHALL perform a full restart to load the new profile's database. The new profile SHALL be written to `profile.json` before restart. On restart, the application SHALL read `profile.json` and load the indicated profile.

#### Scenario: Switch profile

GIVEN the active profile is "Geschäft"
WHEN the user selects "Privat" in the Profile Manager
THEN `profile.json` SHALL be updated to `{"active": "Privat"}`
AND the application SHALL restart
AND the new session SHALL load the "Privat" database.

#### Scenario: Switch to non-existent profile

GIVEN `profile.json` references a profile that does not exist on disk
WHEN the application starts
THEN the application SHALL fall back to the first available profile
AND display a warning message.

#### Scenario: Switch to same profile is a no-op

GIVEN the active profile is "Privat"
WHEN the user selects "Privat" in the Profile Manager
THEN the application SHALL NOT restart
AND the current database SHALL remain loaded.

### Requirement: Profile manager UI

The application SHALL provide a "Profile" menu entry accessible from the main navigation or settings. The Profile Manager SHALL display all profiles as a list with: profile name, database size, last modified timestamp. Actions: create new profile, select (switch), rename, delete. The Profile Manager SHALL be accessible only when `unternehmen.profilmanager_aktiv = true` OR when more than one profile exists.

#### Scenario: Profile manager accessible with multiple profiles

GIVEN more than one profile directory exists
WHEN the application loads
THEN the Profile Manager menu entry SHALL be visible regardless of `profilmanager_aktiv` setting.

#### Scenario: Profile manager hidden with single profile

GIVEN exactly one profile exists
AND `unternehmen.profilmanager_aktiv = false`
WHEN the application loads
THEN the Profile Manager menu entry SHALL be hidden.

#### Scenario: Profile manager shown when explicitly activated

GIVEN exactly one profile exists
AND `unternehmen.profilmanager_aktiv = true`
WHEN the application loads
THEN the Profile Manager menu entry SHALL be visible.

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

The Profile Manager SHALL allow deleting a profile. Deletion SHALL require user confirmation. Deletion SHALL remove the profile entry from `profile.json` but SHALL NOT delete the database file or directory (data safety). The active profile SHALL NOT be deletable without first switching to another profile.

#### Scenario: Delete inactive profile

GIVEN the Profile Manager is open and "Privat" is the active profile
WHEN the user selects "Geschäft" for deletion and confirms
THEN the "Geschäft" entry SHALL be removed from `profile.json`
AND the directory and database SHALL remain on disk.

#### Scenario: Cannot delete active profile

GIVEN the user attempts to delete the currently active profile
WHEN the deletion is requested
THEN the system SHALL display a warning: "Aktives Profil kann nicht gelöscht werden"
AND require switching to another profile first.

#### Scenario: Delete last remaining profile

GIVEN only one profile exists
WHEN the user attempts to delete that profile
THEN the system SHALL prevent the deletion
AND display an error indicating at least one profile must exist.

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

Profile names MUST be non-empty single path components. The system SHALL reject `.` and `..` path segments, `/`, `\\`, NUL/control characters, and any name that would normalize to a different path component. Names SHALL remain unique case-insensitively. Before creating, renaming, or writing a profile, the system SHALL resolve the base data directory and candidate profile directory to canonical paths and SHALL reject any candidate that is not beneath the canonical base directory, including paths that escape through symlinks. Local profile content writes SHALL be resolved canonically and remain beneath the active profile's canonical `APP_DATA_DIR`; the `profile.json` management pointer is written only at the canonical data-directory root.

#### Scenario: Profile name traversal rejected

GIVEN the Profile Manager is open
WHEN the user enters `../Geschäft`, `Privat/Geschäft`, or `Privat\\Geschäft` as a profile name
THEN the system SHALL reject the name before any directory or `profile.json` write
AND SHALL display a profile-name validation error.

#### Scenario: Symlink escape rejected

GIVEN a profile directory or parent path resolves through a symlink outside the canonical profile base
WHEN the application resolves the profile's `APP_DATA_DIR`
THEN the system SHALL reject the profile
AND SHALL NOT read or write files through the escaped path.

#### Scenario: Local write stays within active profile

GIVEN the active profile's canonical `APP_DATA_DIR` is resolved
WHEN a local upload, logo, database, or backup path is constructed
THEN the canonical target SHALL remain beneath `APP_DATA_DIR`
AND a target outside it SHALL be rejected before writing.

#### Scenario: Corrupted profile.json falls back to default

GIVEN `profile.json` contains invalid JSON
WHEN the application starts
THEN the system SHALL display a warning
AND SHALL fall back to the first available profile directory.
