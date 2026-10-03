## ADDED Requirements

### Requirement: Export a complete, versioned profile archive

The application SHALL provide a user-initiated export for the active local profile from Settings → Daten & Datenschutz. A complete archive SHALL contain a versioned manifest, typed structured representations of all supported persisted business records and their relationships, and copies of profile-local files referenced by those records. The manifest SHALL identify the application/export schema version, the selected profile label, creation time, record counts by exported record type, included file paths with integrity hashes, and any excluded or unavailable data. Credentials, secret-store values, operating-system paths outside the profile, and transient runtime state SHALL NOT be included. The export SHALL use a consistent database snapshot and SHALL NOT modify, delete, or mark source records as exported.

#### Scenario: Export a populated profile
- **GIVEN** the active profile database and all referenced profile-local files are readable
- **WHEN** the user selects complete profile export and a safe destination
- **THEN** the saved versioned archive SHALL contain the profile's supported records, relationships, and referenced files
- **AND** its manifest SHALL identify the format version, export time, record counts, and file integrity hashes
- **AND** the source profile SHALL remain unchanged

#### Scenario: Export excludes secrets
- **GIVEN** the profile has SMTP or other integration credentials in a secret store
- **WHEN** a complete profile archive is generated
- **THEN** the archive SHALL contain no credential values or secret-store payloads
- **AND** the manifest SHALL identify the integration configuration as excluded without exposing its secret

#### Scenario: Referenced source file is unavailable
- **GIVEN** a persisted business record references a file that is missing or unreadable
- **WHEN** the user requests a complete profile export
- **THEN** the manifest SHALL identify the missing reference and the export result SHALL be marked incomplete or failed
- **AND** the application SHALL NOT label the archive complete

### Requirement: Export is consistent, bounded, and safe to save

The exporter SHALL take a consistent profile-local database snapshot before serializing records. It SHALL validate the selected destination, write through a temporary file, and publish the final archive only after structural verification succeeds. Cancellation or any snapshot, serialization, file-copy, integrity, or write failure SHALL leave source data unchanged, remove only temporary output created by that export attempt, and return a localized failure without reporting success. Existing destination files SHALL NOT be overwritten unless the user explicitly confirms replacement.

#### Scenario: Successful export is verified before publication
- **GIVEN** a writable destination and a readable profile snapshot
- **WHEN** archive generation and validation complete
- **THEN** the validated archive SHALL appear at the selected path and Settings SHALL show the actual saved location and completion state

#### Scenario: Destination or validation failure
- **GIVEN** the destination is unsafe/unwritable or archive validation fails
- **WHEN** the export is attempted
- **THEN** Settings SHALL show a localized retryable failure
- **AND** no incomplete final archive SHALL be reported as successful
- **AND** the active database and pre-existing files SHALL remain unchanged

#### Scenario: User cancels export
- **GIVEN** the user cancels destination selection or confirms cancellation during generation
- **WHEN** the export stops
- **THEN** no final archive SHALL be published and source profile records SHALL remain unchanged

### Requirement: Settings reports the exact export scope

The Settings Daten & Datenschutz section SHALL describe the complete profile export as a structured archive of supported profile records and referenced files. It SHALL distinguish this operation from DATEV/report exports, GoBD exports, document packages, and raw database backups. Export status SHALL identify the actual destination and whether the result is complete, incomplete, failed, or cancelled. This capability SHALL NOT expose permanent deletion, anonymization, or retention controls; those actions require a separate approved data-class and retention policy.

#### Scenario: User distinguishes export types
- **GIVEN** the Settings data/privacy section offers a profile archive and a DATEV or report export
- **WHEN** the user reviews the available actions
- **THEN** each action SHALL show its actual data scope and the profile archive SHALL be identified as the complete structured export

#### Scenario: Export action is unavailable
- **GIVEN** the export service is not registered or the active profile cannot be read
- **WHEN** the user opens or invokes profile export
- **THEN** Settings SHALL show a localized unavailable state and SHALL NOT claim that any data was exported

#### Scenario: Erasure policy is unresolved
- **GIVEN** no approved data-class retention and erasure policy exists
- **WHEN** the user opens the data/privacy section
- **THEN** no permanent profile-data deletion, anonymization, or retention control SHALL be available
