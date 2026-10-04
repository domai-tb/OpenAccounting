## ADDED Requirements

### Requirement: Export a complete, versioned profile archive

The application SHALL provide a user-initiated, profile-owner-controlled export for the active local profile from Settings → Daten & Datenschutz. The supported export schema SHALL use the shared `db` `Table Definitions` contract: 40 required base tables (`unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`, `inventarbewegungen`, and `feature_table_state`) and three feature-owned tables (`forderung_zahlungen`, `buchungsvorlagen_occurrences`, and `rechnungsvorlagen_occurrences`), for 43 known application-table names. The archive SHALL include typed records and relationships from every present supported table, including the two durable marker rows in `feature_table_state`, and preserve the declared payment-to-receivable/journal and recurring-occurrence-to-template/invoice/journal relationships.

The exporter SHALL verify schema version, table schemas, and table presence before serialization. At the supported export schema version, `forderung_zahlungen` SHALL be present. Startup SHALL check this table against `PRAGMA user_version` before any repair that could recreate it; if it is absent at or beyond its required migration version, the profile SHALL remain unavailable for complete export until a verified backup restore or explicit verified repair, and an empty replacement SHALL NOT be created automatically. Each lazy occurrence table SHALL be present only with marker state `initialized`, or absent with marker state `never_initialized`. An absent table marked `unknown`, a missing marker row, a state/table mismatch, a malformed table, a missing required table, or any undeclared application table SHALL make the archive incomplete. For existing profiles, absent lazy tables SHALL be marked `unknown` by the marker migration; absence alone SHALL NOT be treated as proof of zero records. A feature initializer SHALL NOT create a lazy table while its marker is `unknown`.

The versioned archive SHALL use a ZIP container with UTF-8 `manifest.json` and UTF-8 JSON Lines files at `records/<table>.jsonl`, plus copied evidence under `evidence/`. The archive schema and record serialization versions SHALL both be `1`. The manifest SHALL identify the application/export schema versions, selected profile label, creation time, table presence/state and exported record counts, included evidence paths and SHA-256 hashes, and excluded or unavailable data. For a missing, unreadable, or out-of-profile artifact, the manifest SHALL report only its stable `record_type`, `record_id`, `field`, and a fixed reason code such as `missing`, `unreadable`, or `outside_profile`; it SHALL NOT contain the source path, basename, canonical path, path fragment, or any absolute operating-system path. For files that are included, the archive SHALL store only a relative archive path and content hash. The exporter SHALL retain supported non-path data in `datev_export_log` but omit `datei_pfad` and identify that omission only by record ID, field, and reason. It SHALL also omit `unternehmen.backup_extern_pfad` and `backup_extern_pfad_lokal_ok`. Credentials, secret-store values, operating-system paths, and transient runtime state SHALL NOT be included. The export SHALL use a consistent database snapshot and SHALL NOT modify, delete, or mark source records as exported. It SHALL NOT be described as a customer- or supplier-specific disclosure export.

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

#### Scenario: Missing payment table is detected before startup repair

- **GIVEN** `PRAGMA user_version` is at or beyond the required `forderung_zahlungen` migration version and the table is absent
- **WHEN** database startup health checks run before repair
- **THEN** the profile SHALL be preserved and remain unavailable for complete export
- **AND** no empty `forderung_zahlungen` table SHALL be created automatically

#### Scenario: Excluded file reference contains no host path

- **GIVEN** a profile record references a missing, unreadable, or out-of-profile file
- **WHEN** the archive manifest is written
- **THEN** the exclusion SHALL identify only the record type, stable record ID, field name, and reason code
- **AND** the manifest SHALL contain no source filename or absolute operating-system path
