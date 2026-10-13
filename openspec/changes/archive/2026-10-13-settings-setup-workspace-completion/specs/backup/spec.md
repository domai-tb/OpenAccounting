## MODIFIED Requirements

### Requirement: Platform-specific backup paths

The system SHALL resolve the platform-specific application data base directory and store local backups only under the active profile's canonical `APP_DATA_DIR/backups/`. On Linux this SHALL be below `~/.local/share/OpenInvoices/profiles/<profile>/`; on macOS below `~/Library/Application Support/OpenInvoices/profiles/<profile>/`; and on Windows below `%LOCALAPPDATA%/OpenInvoices/profiles/<profile>/`. The active profile directory SHALL be supplied by `ProfileManager`; a global sibling `backups/` directory SHALL NOT be used for local profile backups.

#### Scenario: Linux backup path

- **GIVEN** the application runs on Linux with profile `Geschäft` active
- **WHEN** a local backup is created
- **THEN** it SHALL be stored below `~/.local/share/OpenInvoices/profiles/Geschäft/backups/`

#### Scenario: macOS backup path

- **GIVEN** the application runs on macOS with profile `Geschäft` active
- **WHEN** a local backup is created
- **THEN** it SHALL be stored below `~/Library/Application Support/OpenInvoices/profiles/Geschäft/backups/`

#### Scenario: Windows backup path

- **GIVEN** the application runs on Windows with profile `Geschäft` active
- **WHEN** a local backup is created
- **THEN** it SHALL be stored below `%LOCALAPPDATA%/OpenInvoices/profiles/Geschäft/backups/`

### Requirement: Backup scheduling

The system SHALL persist backup scheduling per active profile in `backup_state.json` below that profile. The default SHALL be `manual-only`; supported schedules SHALL be `daily` and `weekly`, and local profile backup SHALL be the only scheduled target. On the first startup after the active profile database is open and ready, the application SHALL check the schedule once. A daily backup is due only when there is no successful local backup or the last successful local backup is at least 24 hours old; a weekly backup is due only when it is at least 7 days old. The last-success timestamp SHALL advance only after a complete validated backup. A failed attempt SHALL remain due for a later startup and MUST NOT be reported as a successful backup.

#### Scenario: Manual-only skips startup backup

- **GIVEN** the active profile schedule is `manual-only`
- **WHEN** startup opens the active database
- **THEN** the scheduler SHALL perform no backup and SHALL leave backup history unchanged

#### Scenario: Due scheduled backup runs once after database readiness

- **GIVEN** the active profile is configured for daily or weekly backup and has no successful local backup in its interval
- **WHEN** startup reaches the first ready state for that profile
- **THEN** it SHALL create one local profile backup and record success only after validation completes

#### Scenario: Recent backup suppresses duplicate startup work

- **GIVEN** the active profile has a successful local backup newer than its configured interval
- **WHEN** startup checks the schedule
- **THEN** it SHALL skip backup creation and retain the existing success timestamp

#### Scenario: Failed scheduled backup remains due

- **GIVEN** a scheduled backup is due and the target cannot be written or validated
- **WHEN** the startup attempt fails
- **THEN** the failure SHALL be visible in Settings, the last-success timestamp SHALL remain unchanged, and the next startup SHALL retry when still due

## ADDED Requirements

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

## MODIFIED Requirements

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
