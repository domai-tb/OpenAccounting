# Backup System

## ADDED Requirements

### Requirement: Local WAL-safe backup with rotation

The system SHALL perform WAL-safe local backups using SQLite's `.backup()` API, producing a consistent snapshot even during concurrent writes. Local backups SHALL be stored below the active profile's `APP_DATA_DIR` at `${APP_DATA_DIR}/backups/`. The system SHALL retain a maximum of 5 backups, automatically deleting the oldest when the limit is exceeded.

#### Scenario: Local backup creation

GIVEN the application is running with an active database
WHEN a local backup is triggered (manually or automatically)
THEN the system SHALL create a new file named `openinvoices_YYYYMMDD_HHMMSS.db` in `${APP_DATA_DIR}/backups/`
AND the backup SHALL be WAL-safe (consistent snapshot, not corrupted by in-flight writes)
AND if more than 5 backups exist, the oldest SHALL be deleted.

#### Scenario: Backup fails when disk is full

GIVEN the backup directory exists on a filesystem with insufficient space
WHEN a local backup is triggered
THEN the system SHALL NOT corrupt the existing database
AND SHALL display an error message indicating insufficient disk space.

### Requirement: Backup before schema migration

The system SHALL automatically create a local backup before executing any migration statements when a schema version mismatch is detected. The backup SHALL complete before the first `PRAGMA user_version` write.

#### Scenario: Backup before schema migration

GIVEN the application detects a schema version mismatch requiring migration
WHEN the migration process starts
THEN the system SHALL create a local backup before executing any migration statements
AND the backup SHALL complete before the first `PRAGMA user_version` write.

#### Scenario: Backup failure prevents migration

GIVEN the backup directory is not writable
WHEN the application detects a schema version mismatch requiring migration
THEN the system SHALL NOT proceed with the migration
AND SHALL display an error and exit.

### Requirement: Backup target boundaries

Backup destinations SHALL be classified as either local profile backups or external targets. Local backups MUST remain below the active profile's canonical `APP_DATA_DIR`. USB, NAS, SMB, and user-selected local-folder destinations SHALL require an explicit user opt-in and SHALL be validated by their own target-specific path or protocol rules. An approved external destination SHALL NOT be represented as or claimed to be inside `APP_DATA_DIR`.

#### Scenario: External target requires explicit opt-in

GIVEN the user has selected a USB, NAS, SMB, or external local-folder destination
WHEN the destination is configured
THEN the system SHALL require explicit confirmation of that external target
AND SHALL validate it separately from the local `APP_DATA_DIR` backup path.

### Requirement: External AES-256-GCM encrypted backup

The system SHALL support explicitly approved external backup targets (USB, NAS, SMB, and local folders) with AES-256-GCM authenticated encryption. A user-provided passphrase SHALL be processed with a standard password-based key-derivation function using a random salt; the passphrase SHALL NOT be stored in plaintext. The encrypted container SHALL store the salt, nonce/IV, authentication tag, and KDF parameters with the ciphertext. External path validation SHALL be separate from local `APP_DATA_DIR` containment.

#### Scenario: Encrypted external backup

GIVEN the user has explicitly approved an external backup path and supplied a passphrase
WHEN the user triggers an external backup
THEN the system SHALL export the database to the configured path
AND encrypt the file with AES-256-GCM using the provided passphrase
AND store the salt, nonce/IV, authentication tag, and KDF parameters in the backup header
AND verify integrity after write.

#### Scenario: Encrypted backup with wrong passphrase on restore

GIVEN the user has an encrypted backup file
WHEN the user provides an incorrect passphrase during restore
THEN the system SHALL display a decryption error message
AND SHALL NOT replace the active database.

### Requirement: Restore from encrypted backup

The system SHALL support restoring an encrypted backup as the active database. Restore SHALL replace the current database file atomically (write to temp, then rename). The system SHALL prompt for application restart after restore.

#### Scenario: Restore from encrypted backup

GIVEN the user has an encrypted backup file and knows the correct passphrase
WHEN the user selects the encrypted backup and provides the correct passphrase
THEN the system SHALL decrypt the file, verify integrity, and atomically replace the active database
AND prompt for application restart.

#### Scenario: Restore with corrupted encrypted backup

GIVEN the user has a corrupted encrypted backup file
WHEN the user attempts to restore from the corrupted backup
THEN the system SHALL display an integrity verification error
AND SHALL NOT replace the active database.

### Requirement: SMB network share backup

The system SHALL support explicitly approved backup targets on SMB network shares (`smb://` paths). The system SHALL authenticate using credentials stored in OS-provided secret storage; credentials SHALL NOT be stored in `profile.json` or backup metadata. No system-level mount is required; the implementation MAY use a platform-compatible SMB data source.

#### Scenario: SMB backup with stored credentials

GIVEN the user has explicitly approved an SMB backup target and credentials are available from OS secret storage
WHEN the user triggers an SMB backup
THEN the system SHALL connect to the SMB share using provided credentials
AND write the backup file to the share
AND verify the file exists on the remote share after write.

#### Scenario: SMB backup fails with invalid credentials

GIVEN the user has configured an SMB backup target with incorrect credentials
WHEN the user triggers an SMB backup
THEN the system SHALL display an authentication error message
AND SHALL NOT write any partial backup file to the share.

### Requirement: External local-path protection with opt-in override

The system SHALL reject explicitly configured external local-folder backup targets on system drives (root partition, boot partition) by default. The user SHALL be able to override this protection per-path with an explicit opt-in boolean (`backup_extern_pfad_lokal_ok`). This rule SHALL NOT change the fixed local backup location below `APP_DATA_DIR`.

#### Scenario: System drive backup rejected

GIVEN the user has not set the external local-path override flag
WHEN the user configures a backup path on a system drive (e.g., `/`, `/boot`, `C:\`)
THEN the system SHALL reject the path with a clear error message.

#### Scenario: System drive override accepted

GIVEN the user has set `backup_extern_pfad_lokal_ok` to true for the external local path
WHEN the user configures a backup path on a system drive
THEN the system SHALL accept the path and proceed with backup.

### Requirement: Restore from backup

The system SHALL support restoring a local backup as the active database. Restore SHALL replace the current database file atomically (write to temp, then rename). The system SHALL prompt for application restart after restore.

#### Scenario: Restore from local backup

GIVEN the user has a valid local backup file
WHEN the user selects a local backup file to restore
THEN the system SHALL copy the backup to a temporary file
AND atomically replace the active database
AND prompt for application restart.

#### Scenario: Restore with missing backup file

GIVEN the user has selected a backup file that no longer exists on disk
WHEN the user attempts to restore
THEN the system SHALL display a file-not-found error
AND SHALL NOT modify the active database.

### Requirement: Backup scheduling

The system SHALL support automatic backup scheduling with configurable intervals (daily, weekly, manual-only). The last backup timestamp SHALL be persisted to avoid duplicate backups within the same interval window.

#### Scenario: Scheduled daily backup

GIVEN backup scheduling is set to "daily" and the last backup is older than 24 hours (or no backup exists)
WHEN the application starts
THEN the system SHALL automatically trigger a local backup.

#### Scenario: No duplicate backup within interval

GIVEN a scheduled backup is due and a backup was already created within the current interval window
WHEN the scheduled backup check runs
THEN the system SHALL skip the backup and log the skip.

### Requirement: Platform-specific backup paths

The system SHALL use the active profile's platform-appropriate local backup path: `~/.local/share/OpenInvoices/profiles/<active>/backups/` on Linux, `~/Library/Application Support/OpenInvoices/profiles/<active>/backups/` on macOS, and `%LOCALAPPDATA%/OpenInvoices/profiles/<active>/backups/` on Windows.

#### Scenario: Linux backup path

GIVEN the application runs on Linux
WHEN a local backup is created
THEN backups SHALL be stored under `~/.local/share/OpenInvoices/profiles/<active>/backups/`.

#### Scenario: macOS backup path

GIVEN the application runs on macOS
WHEN a local backup is created
THEN backups SHALL be stored under `~/Library/Application Support/OpenInvoices/profiles/<active>/backups/`.

#### Scenario: Windows backup path

GIVEN the application runs on Windows
WHEN a local backup is created
THEN backups SHALL be stored under `%LOCALAPPDATA%/OpenInvoices/profiles/<active>/backups/`.
