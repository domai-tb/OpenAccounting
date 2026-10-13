# Backup System

## Purpose
WAL-safe local backup with rotation, profile-scoped paths, and restore validation.

## Requirements

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

### Requirement: External AES-256-GCM encrypted backup

The system SHALL support external backup targets (USB, NAS, local folders) with AES-256-GCM encryption. The backup file SHALL be encrypted with a user-provided passphrase. Encrypted backups SHALL use a standard container format with a random salt and IV stored alongside the ciphertext.

#### Scenario: Encrypted external backup

GIVEN the user has configured an external backup path and passphrase
WHEN the user triggers an external backup
THEN the system SHALL export the database to the configured path
AND encrypt the file with AES-256-GCM using the provided passphrase
AND store salt and IV in the backup header
AND verify integrity after write.

#### Scenario: Encrypted backup with wrong passphrase on restore

GIVEN the user has an encrypted backup file
WHEN the user provides an incorrect passphrase during restore
THEN the system SHALL display a decryption error message
AND SHALL NOT replace the active database.

### Requirement: Restore from encrypted backup

The system SHALL support restoring an encrypted backup through the staged restore workflow. It SHALL decrypt and validate the backup into a staged database without replacing the live database, then apply the staged file only after the application has restarted and before any database handle is opened. The passphrase SHALL NOT be persisted as a preference. Wrong-passphrase or integrity failures SHALL leave the active database and pending-restore state unchanged.

#### Scenario: Restore from encrypted backup

- **GIVEN** the user has an encrypted backup file and knows the correct passphrase
- **WHEN** the user selects it, enters the passphrase, and confirms restore
- **THEN** the system SHALL validate and stage the decrypted database, block writes, and require application restart before replacing the active database

#### Scenario: Restore with corrupted encrypted backup

- **GIVEN** the user has a corrupted encrypted backup file
- **WHEN** the user attempts to stage it for restore
- **THEN** the system SHALL display an integrity verification error and SHALL NOT replace or schedule replacement of the active database

#### Scenario: Encrypted backup with wrong passphrase on restore

- **GIVEN** the user has an encrypted backup file
- **WHEN** the user provides an incorrect passphrase during restore
- **THEN** the system SHALL display a decryption error and SHALL NOT replace or schedule replacement of the active database

### Requirement: SMB network share backup

The system SHALL support backup to SMB network shares (`smb://` paths). The system SHALL authenticate using stored credentials (SMB username and password). No system-level mount is required; the system SHALL use a pure SMB protocol library.

#### Scenario: SMB backup with stored credentials

GIVEN the user has configured an SMB backup target with path, username, and password
WHEN the user triggers an SMB backup
THEN the system SHALL connect to the SMB share using provided credentials
AND write the backup file to the share
AND verify the file exists on the remote share after write.

#### Scenario: SMB backup fails with invalid credentials

GIVEN the user has configured an SMB backup target with incorrect credentials
WHEN the user triggers an SMB backup
THEN the system SHALL display an authentication error message
AND SHALL NOT write any partial backup file to the share.

### Requirement: System drive protection with opt-in override

The system SHALL reject backup targets on system drives (root partition, boot partition) by default. The user SHALL be able to override this protection per-path with an explicit opt-in boolean (`backup_extern_pfad_lokal_ok`).

#### Scenario: System drive backup rejected

GIVEN the user has not set the local override flag
WHEN the user configures a backup path on a system drive (e.g., `/`, `/boot`, `C:\`)
THEN the system SHALL reject the path with a clear error message.

#### Scenario: System drive override accepted

GIVEN the user has set the local override flag to true for the path
WHEN the user configures a backup path on a system drive
THEN the system SHALL accept the path and proceed with backup.

### Requirement: Restore from backup

The system SHALL support restoring a local backup through the staged restore workflow. It SHALL validate and stage the selected backup without replacing the live database, then apply the staged file only after application restart and before any database handle is opened. Replacement failure SHALL restore the prior database before the application opens it.

#### Scenario: Restore from local backup

- **GIVEN** the user has selected a valid local backup file
- **WHEN** the user confirms restore in Settings
- **THEN** the system SHALL stage and validate the snapshot, block writes, and require restart before replacing the active database

#### Scenario: Restore with missing backup file

- **GIVEN** the selected backup file no longer exists on disk
- **WHEN** the user attempts to stage it for restore
- **THEN** the system SHALL display a file-not-found error and SHALL NOT modify the active database or create pending restore state

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

The system SHALL use platform-appropriate default backup paths: `~/.local/share/OpenInvoices/backups/` on Linux, `~/Library/Application Support/OpenInvoices/backups/` on macOS, and `%LOCALAPPDATA%/OpenInvoices/backups/` on Windows.

#### Scenario: Linux backup path

GIVEN the application runs on Linux
WHEN a local backup is created
THEN backups SHALL be stored under `~/.local/share/OpenInvoices/backups/`.

#### Scenario: macOS backup path

GIVEN the application runs on macOS
WHEN a local backup is created
THEN backups SHALL be stored under `~/Library/Application Support/OpenInvoices/backups/`.

#### Scenario: Windows backup path

GIVEN the application runs on Windows
WHEN a local backup is created
THEN backups SHALL be stored under `%LOCALAPPDATA%/OpenInvoices/backups/`.

### Requirement: Backup target boundaries

Backup destinations SHALL be classified as either local profile backups or external targets. Local backups MUST remain below the active profile's canonical `APP_DATA_DIR`. USB, NAS, SMB, and user-selected local-folder destinations SHALL require an explicit user opt-in and SHALL be validated by their own target-specific path or protocol rules. An approved external destination SHALL NOT be represented as or claimed to be inside `APP_DATA_DIR`.

#### Scenario: External target requires explicit opt-in

GIVEN the user has selected a USB, NAS, SMB, or external local-folder destination
WHEN the destination is configured
THEN the system SHALL require explicit confirmation of that external target
AND SHALL validate it separately from the local `APP_DATA_DIR` backup path.

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

### Requirement: Restore is staged and applied before database open

The active database SHALL never be replaced while any executor or database connection to it remains open. Before opening any writable database handle, each application process SHALL acquire and retain an exclusive OS-level lock on a lock file inside the active profile; inability to acquire that lock SHALL stop startup with a localized profile-in-use state. All database mutations SHALL pass through one profile-scoped `ProfileWriteGate` at the shared database write boundary. A restore requested in Settings SHALL validate its source and stage a restorable database under the active profile, close the gate to new writes, wait for in-flight mutations to finish, record the pending operation, keep the gate closed, and require the application to exit and restart. If staging or pending-state persistence fails, the gate SHALL reopen and the live database SHALL remain unchanged. The next process SHALL acquire the profile lock and apply the staged restore before constructing or opening any database executor. It SHALL remove stale SQLite WAL/SHM sidecars only after no handle can be open, and SHALL use an atomic replacement with rollback to the prior database if replacement fails. Successful replacement SHALL be reported only after the restored database opens and passes validation. Failed validation or replacement SHALL retain the prior database, clean up or mark the staged artifact for safe retry/removal, and report failure.

#### Scenario: Live Settings restore waits for restart

- **GIVEN** the active profile database is open in the current application session
- **WHEN** the user confirms a valid local or encrypted backup for restore
- **THEN** the system SHALL validate and stage the restore, block further writes, leave the open database file untouched, and show that application exit and restart are required

#### Scenario: Startup restore applies before opening the database

- **GIVEN** a valid staged restore is pending for the active profile
- **WHEN** the restarted application owns the profile exclusively and begins startup
- **THEN** it SHALL replace the active database before creating or opening its executor, validate the restored database, clear the pending state, and report success

#### Scenario: Invalid restore does not replace the database

- **GIVEN** a selected local or encrypted backup is missing, corrupt, or has a wrong passphrase
- **WHEN** restore validation runs
- **THEN** the active database and its files SHALL remain unchanged and Settings SHALL show a localized failure without scheduling a replacement

#### Scenario: Startup replacement failure restores the prior database

- **GIVEN** a validated restore is staged and atomic replacement fails during startup
- **WHEN** the restore coordinator handles the failure
- **THEN** the prior active database SHALL be restored before the application opens it, the failure SHALL be retained for Settings to display, and the failed staged artifact SHALL NOT be reported as applied

#### Scenario: A second process cannot open the same profile

- **GIVEN** one application process owns the active profile's exclusive OS-level lock
- **WHEN** another process starts with that same profile selected
- **THEN** it SHALL fail before opening a writable database handle and SHALL show a localized profile-in-use state

#### Scenario: Restore blocks every profile mutation

- **GIVEN** restore has been confirmed and the profile write gate is closed
- **WHEN** any repository or service attempts a database mutation
- **THEN** the shared write boundary SHALL reject it without issuing SQL, and the restore coordinator SHALL wait for already-running mutations before persisting pending restore state

#### Scenario: Restore staging failure reopens writes

- **GIVEN** restore confirmation begins while the active database is open
- **WHEN** staging or pending-state persistence fails
- **THEN** the live database SHALL remain unchanged and the profile write gate SHALL return to its open state
