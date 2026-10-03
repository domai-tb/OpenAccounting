## ADDED Requirements

### Requirement: Export a complete, versioned profile archive

The application SHALL provide a user-initiated, profile-owner-controlled export for the active local profile from Settings → Daten & Datenschutz. For the current schema, the archive inventory SHALL include typed records and relationships from all 42 known production tables: the 39 base tables `unternehmen`, `kunden`, `lieferanten`, `artikel`, `journal`, `rechnungen`, `rechnungspositionen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `tagesabschluesse`, `belege`, `mahnungen`, `mahnstufen`, `mahnwesen_einstellungen`, `forderungen`, `bank_transaktionen`, `bank_templates`, `bank_imports`, `kunden_belege`, `kunden_lieferadressen`, `artikel_gruppen`, `rechnungsvorlagen`, `buchungsvorlagen`, `anlageverzeichnis`, `dokumentenpakete`, `dokumentenpaket_belege`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`, `eu_laender`, `eks_einstellungen`, `vorsteuer_ansprueche`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`, and `inventarbewegungen`; plus feature-owned tables `forderung_zahlungen`, `buchungsvorlagen_occurrences`, and `rechnungsvorlagen_occurrences`. It SHALL preserve the declared payment-to-receivable/journal relationships and recurring occurrence-to-template/invoice/journal relationships. The exporter SHALL include every known feature-owned table that is present. An absent `forderung_zahlungen` table at a schema version that requires its migration SHALL make the archive incomplete and SHALL NOT be hidden by automatic creation of an empty replacement before export inspection. If either lazy occurrence table is absent and no accepted durable initialization marker proves it was never initialized, the manifest SHALL classify that table state as unknown and the archive SHALL be incomplete; the exporter SHALL NOT assume that absent means uninitialized or zero records. The manifest SHALL compare the actual profile table set to the complete known inventory and SHALL mark the archive incomplete if any present runtime table is unrecognized or lacks an export projection. The inventory SHALL be updated with each schema change. The current persisted artifact fields are `unternehmen.logo_pfad`, `belege.dateipfad`, and `rechnungen.original_pdf_pfad`; valid profile-local files SHALL be archived by relative path and hash. Machine-specific backup paths and the absolute destination in `datev_export_log.datei_pfad` SHALL be excluded, while non-path data in that log remains included. The versioned manifest SHALL identify the application/export schema version, selected profile label, creation time, table presence and record counts by exported record type, included file paths with integrity hashes, and any excluded or unavailable data. Credentials, secret-store values, operating-system paths outside the profile, and transient runtime state SHALL NOT be included. The export SHALL use a consistent database snapshot and SHALL NOT modify, delete, or mark source records as exported. It SHALL NOT be described as a customer- or supplier-specific disclosure export.

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
