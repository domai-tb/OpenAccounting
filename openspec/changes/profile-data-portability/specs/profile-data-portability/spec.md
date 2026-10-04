## ADDED Requirements

### Requirement: Export a complete, versioned profile archive

The application SHALL provide a user-initiated, profile-owner-controlled export for the active local profile from Settings → Daten & Datenschutz. The supported v10 export schema SHALL use the exact shared 46-name db Table Definitions inventory: 39 pre-existing AppDatabase base tables, the separate feature_table_state database-health table, and six feature-owned tables (forderung_zahlungen, buchungsvorlagen_occurrences, rechnungsvorlagen_occurrences, mileage_trips, mileage_trip_corrections, and category_mapping_history). The archive SHALL include typed records and relationships from every present supported table, including the two durable marker rows, migration-required payment, mileage, and category-history tables, and both occurrence tables when initialized.

The exporter SHALL verify schema version, table schemas, and version-aware table presence before serialization. The 39 existing base tables remain the legacy AppDatabase.allTableNames set. feature_table_state is a separate shared table introduced and required at v9. forderung_zahlungen is required at v8 and later; if absent before v8 it SHALL be created by the normal v7-to-v8 migration. If absent at v8 or later, startup SHALL detect it before any repair or migration that could recreate it, preserve the original database and table absence, stop profile initialization, and keep complete export unavailable until verified restore or explicit verified repair. No empty replacement SHALL be created automatically. A present payment table may be repaired only through the accepted transactional path that preserves its rows. mileage_trips and mileage_trip_corrections are migration-required at v9; category_mapping_history is migration-required at v10. These tables are not required before their declared versions, so a valid pre-v9 profile may lack the marker and mileage tables and a valid pre-v10 profile may lack category_mapping_history; older profiles are not eligible for complete v10 export until normal sequential migrations succeed. Each lazy occurrence table SHALL be present only with marker state initialized, or absent with marker state never_initialized. An absent table marked unknown, a missing marker row, a state/table mismatch, a malformed table, a missing migration-required table, or any undeclared application table SHALL make the archive incomplete. The v9 marker migration SHALL mark present valid lazy tables initialized and absent lazy tables unknown; absence alone SHALL NOT be treated as proof of zero records. A feature initializer SHALL NOT create a lazy table while its marker is unknown.

The versioned archive SHALL use a ZIP container with UTF-8 manifest.json and UTF-8 JSON Lines files at records/<table>.jsonl, plus copied evidence under evidence/. The archive schema and record serialization versions SHALL both be 1. The manifest SHALL identify the application/export schema versions, selected profile label, creation time, table presence/state and exported record counts, included evidence paths and SHA-256 hashes, and excluded or unavailable data. For a missing, unreadable, or out-of-profile artifact, the manifest SHALL report only its stable record_type, record_id, field, and a fixed reason code such as missing, unreadable, or outside_profile; it SHALL NOT contain the source path, basename, canonical path, path fragment, or any absolute operating-system path. For files that are included, the archive SHALL store only a relative archive path and content hash. The exporter SHALL retain supported non-path data in datev_export_log but omit datei_pfad and identify that omission only by record ID, field, and reason. It SHALL also omit unternehmen.backup_extern_pfad and backup_extern_pfad_lokal_ok. Credentials, secret-store values, operating-system paths, and transient runtime state SHALL NOT be included. The export SHALL use a consistent database snapshot and SHALL NOT modify, delete, or mark source records as exported. It SHALL NOT be described as a customer- or supplier-specific disclosure export.
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

The Settings Daten & Datenschutz section SHALL describe the complete profile export as a structured archive of the fixed profile record inventory and referenced files. It SHALL accurately distinguish the archive from any separately scoped DATEV, backup, report, GoBD, or document-package workflow, and SHALL NOT imply that such a workflow is available unless its production runtime path is implemented and registered. Export status SHALL identify the actual destination and whether the result is complete, incomplete, failed, or cancelled. This capability SHALL NOT expose permanent deletion, anonymization, or retention controls; those actions require a separate approved data-class and retention policy. It SHALL identify full-profile export as owner-controlled portability and SHALL NOT present it as customer- or supplier-specific disclosure.

#### Scenario: User distinguishes export types
- **GIVEN** the Settings data/privacy section offers a profile archive and at least one separately implemented and registered export action
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

#### Scenario: Table inventory or durable marker is incomplete

- **GIVEN** a required application table is missing, an undeclared table is present, or a lazy table is absent with marker state `unknown`
- **WHEN** a profile archive is requested
- **THEN** the export SHALL be marked incomplete or unavailable
- **AND** it SHALL identify the table and observed state without exposing a database path
- **AND** it SHALL NOT create or repair a table

#### Scenario: Version-8 profile remains valid before the v9 migration

- **GIVEN** a profile at schema version 8 has all 39 existing base tables and a valid forderung_zahlungen table but no feature_table_state or mileage tables
- **WHEN** schema health is checked before migration
- **THEN** the absent v9 tables SHALL be treated as not yet required
- **AND** the profile SHALL not be eligible for complete v10 export until normal sequential migrations succeed

#### Scenario: Missing payment table is detected before startup repair

- **GIVEN** PRAGMA user_version is 8 or later and forderung_zahlungen is absent
- **WHEN** database startup health checks run before repair
- **THEN** the profile SHALL be preserved and remain unavailable for complete export with the table absence still observable
- **AND** no empty forderung_zahlungen table SHALL be created automatically

#### Scenario: Mileage and category tables follow their migration versions

- **GIVEN** a profile is before v9 or before v10 respectively
- **WHEN** schema health checks migration-required mileage or category_mapping_history tables
- **THEN** absence before the owning migration version SHALL be valid for that older schema
- **AND** absence at or after v9 for either mileage table or at or after v10 for category_mapping_history SHALL prevent complete v10 export

#### Scenario: Excluded file reference contains no host path

- **GIVEN** a profile record references a missing, unreadable, or out-of-profile file
- **WHEN** the archive manifest is written
- **THEN** the exclusion SHALL identify only the record type, stable record ID, field name, and reason code
- **AND** the manifest SHALL contain no source filename or absolute operating-system path
