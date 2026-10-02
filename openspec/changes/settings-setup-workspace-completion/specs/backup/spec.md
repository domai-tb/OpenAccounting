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
