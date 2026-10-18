# customer-data-disclosure-export Specification

## Purpose
TBD - created by archiving change customer-data-disclosure-export. Update Purpose after archive.

## Requirements

### Requirement: Export one customer's explicitly linked data

The application SHALL provide a user-initiated disclosure export for exactly one persisted customer from the customer detail workspace. The export SHALL use one consistent active-profile snapshot and a versioned manifest. Its current relationship inventory SHALL include the selected `kunden` row; that customer's `kunden_lieferadressen`; `rechnungen` linked by `kunde_id` or by `lieferadresse_id` to one of those customer addresses; and connected correction/conversion invoices reached in either direction through `storno_von`, `gutschrift_von`, `ersatz_fuer`, `ersatzrechnung_id`, `konvertiert_von`, or `konvertiert_zu`. The exporter SHALL follow those invoice lineage links until no additional invoice is reached and SHALL verify that inverse `konvertiert_von`/`konvertiert_zu` pointers agree whenever both are populated. It SHALL require populated `kunde_id` and delivery-address references to resolve to the selected customer. A missing or conflicting lineage, customer, supplier, or address identity SHALL cause the affected record to be excluded, identified in the manifest, and make the archive incomplete. The inventory SHALL then include `rechnungspositionen` belonging to those invoices; `mahnungen` linked by customer or those invoices; `forderungen` linked by `kunde_id`, the typed pair `partner_typ = 'kunde'` and `partner_id`, or those invoices; `forderung_zahlungen` for those receivables; journal rows reached through invoice `rechnung_id`, receivable `journal_id`/`ausgleich_journal_id`, or linked receivable-payment rows; `vorsteuer_ansprueche` whose `rechnung_id` references those invoices; `rechnungsvorlagen` whose `kunde_id` is the selected customer or which are verified through `rechnungen.vorlage_id`; invoices reached from those templates through `auftrag_id`; generated invoices and `rechnungsvorlagen_occurrences` for those templates; `kunden_belege` links for the customer; and `belege` rows reached by those links. `buchungsvorlagen_occurrences` MAY be included only as a projected occurrence when its `rechnung_id` or `journal_id` already resolves to an included invoice or journal row; its unrelated booking-template identifier SHALL be omitted. The exporter SHALL preserve verified relationship paths and SHALL NOT infer relationships by name, free-text note, or bank counterparty text. It SHALL NOT include unrelated parties' master records or present the result as a full-profile export.

The published archive SHALL be a ZIP containing `manifest.json`, one UTF-8 JSON Lines file at `records/<table>.jsonl` for each included record type, and copied evidence beneath `evidence/`. The manifest SHALL identify archive schema version `1`, record-projection version `1`, the selected customer reference, included record counts, verified relationship paths, exclusions, outcome, and SHA-256 digests for each record and evidence file. Evidence archive names SHALL use content digests and a safe extension, and SHALL NOT expose source filenames or host paths. The archive SHALL be written to a unique partial file in the destination directory, flushed, closed, and verified before it is renamed to the requested destination only when that destination does not exist. Cancellation or failure SHALL remove only this operation's partial file and leave any existing destination unchanged. A later retry after process interruption MAY remove only the exact matching application-owned partial file. The export SHALL store no persistent export history; only the current run's status and manifest are user-visible.

Each record type SHALL use a versioned field allowlist. Unknown columns SHALL NOT be serialized. The `belege` projection SHALL retain the receipt metadata fields `dateiname`, `original_name`, `mime_type`, `dateigroesse`, `sha256`, `hochgeladen_am`, and `loeschdatum`. Its `dateipfad` and `beleg_pdfa_pfad` fields SHALL be resolved and copied only as profile-local evidence; raw source paths SHALL NOT be serialized. Cross-party references, including `rechnungen.lieferant_id`, `belege.lieferant_id`, `journal.vorlage_id`, and `vorsteuer_ansprueche.beleg_id`, SHALL be omitted. `journal.beleg_id` MAY be retained only when it resolves to evidence already linked to the selected customer. A receivable's typed pair SHALL establish inclusion only when `partner_typ = 'kunde'` and `partner_id` resolves to the selected customer. When `kunde_id`, `rechnung_id`, and the typed pair are populated, they SHALL agree with the selected customer and included invoice as applicable. A supplier or other-customer identity, unknown partner type, or missing referenced row SHALL exclude the receivable, identify the conflict, and make the archive incomplete. The validated customer partner pair SHALL be retained in the projection. Any omitted field containing a non-empty value whose scope cannot be proven outside this disclosure SHALL be listed in the manifest and make the result incomplete. A contradictory required relationship, unknown table, or non-empty unclassified field SHALL also make the result incomplete. The manifest SHALL identify the record projection version. This defines the supported export projection and SHALL NOT be described as legally sufficient disclosure.

The exporter SHALL compare the active profile with the versioned Table Definitions inventory and presence rules in this change before reporting completeness: 55 known application-table names through v19 and 57 through v25. It SHALL require each migration-owned table only at or after its declared migration version, including settlement_groups, settlement_allocations, and statutory_timing_rules at v19. A profile SHALL be complete for its recorded schema version when all tables required through that version have their declared schemas and all other completeness checks pass; tables introduced by later migrations SHALL remain version-pending and SHALL NOT make an earlier supported profile incomplete. The inventory SHALL cover the current application schema and known tables through v25. `mileage_posting_account_mapping` and `mileage_posting_period_closures` are required and schema-checked from v25; a valid earlier profile may omit both. Zero, one, or two role rows and an empty period-closure table are valid. Each recurring occurrence table is valid only when present with marker state initialized or absent with marker state never_initialized. The optional document-email tables MAY be absent and SHALL be schema-checked when present. An absent recurring table marked unknown, a missing marker row, any state/table mismatch, a missing required table, a malformed schema, or an undeclared application table SHALL make the archive incomplete. Before v8, a missing payment table is valid input to the normal v7-to-v8 migration. At v8 or later, startup SHALL detect a missing payment table before repair, preserve the original database with the table still absent, and keep the profile unavailable for complete export until verified recovery; it SHALL NOT create an empty replacement. The exporter SHALL NOT create or repair tables. Migration-owned tables without an approved customer relationship, including feature_table_state, mileage, `mileage_posting_account_mapping`, `mileage_posting_period_closures`, category history, import mappings, asset schedules, stocktake, and settlement tables, SHALL be checked for schema health at their declared versions but not projected. Their omission alone SHALL NOT make the customer archive incomplete. A settlement allocation linked through an included receivable, or a document-email attempt linked through an included invoice or reminder, SHALL be reported as unsupported and make the archive incomplete; the exporter SHALL NOT serialize settlement-group data or email recipients. Generic document-email templates have no customer relationship and MAY be omitted. Trip purpose, business context, and category history SHALL NOT be used to infer a customer relationship. feature_table_state SHALL be used for schema health only and SHALL NOT be projected. The manifest SHALL identify each unsupported table/record condition without exposing database paths.

The ZIP SHALL contain a UTF-8 `manifest.json` and UTF-8 JSON Lines record files. Final publication SHALL use an atomic no-replace operation; if the destination exists when finalization occurs, the export SHALL fail without overwriting it.

#### Scenario: Version-24 profile does not require v25 mileage posting tables

- **GIVEN** a healthy profile at schema version 24 without either v25 mileage posting table
- **WHEN** customer-export schema health is checked
- **THEN** both mileage tables are version-pending and their absence alone does not make the archive incomplete

#### Scenario: Version-25 mileage posting tables are checked but not projected

- **GIVEN** a healthy profile at schema version 25 with valid mileage mapping and period-closure tables
- **WHEN** a customer disclosure export is generated
- **THEN** schema health requires both tables and validates their declared schemas
- **AND** neither table is projected because it has no approved customer relationship
- **AND** their non-projection alone does not make the customer archive incomplete

#### Scenario: Export an unambiguous customer's linked records

- **GIVEN** the selected customer exists and its declared linked records are readable from one consistent snapshot
- **WHEN** the user starts a disclosure export from that customer's detail workspace
- **THEN** the archive SHALL include the customer and only the records reached through the declared relationship inventory
- **AND** the manifest SHALL identify its schema version, selected customer reference, included record counts, relationship paths, exclusions, and outcome
- **AND** source records SHALL remain unchanged

#### Scenario: No customer is selected or the ID is invalid

- **GIVEN** the requested customer ID is missing or does not resolve to exactly one record
- **WHEN** the disclosure export is requested
- **THEN** the action SHALL return a localized unavailable/not-found state
- **AND** no archive SHALL be published

#### Scenario: Unlinked data is not guessed

- **GIVEN** a bank transaction or journal row mentions the customer only in free text and has no declared customer relationship
- **WHEN** the export is generated
- **THEN** the row SHALL NOT be included based only on that text
- **AND** the archive SHALL NOT claim that free-text matches were searched or exported

#### Scenario: Unclassified fields prevent a complete outcome

- **GIVEN** a linked row contains a non-empty field outside the reviewed field allowlist and the field's scope cannot be proven to exclude unrelated parties
- **WHEN** the customer archive is projected
- **THEN** the field SHALL be omitted and identified in the manifest
- **AND** the archive SHALL be marked incomplete

### Requirement: Linked evidence has a truthful completeness state

For linked records that reference files, the exporter SHALL resolve only paths beneath the active profile's canonical data root and SHALL package readable files using relative archive paths and integrity hashes. Missing, unreadable, out-of-profile, mixed-party, or unsupported linked content SHALL be listed in the manifest and SHALL prevent a complete outcome until its inclusion or reviewed redaction behavior is approved. The exporter SHALL NOT automatically modify source evidence or claim that an incomplete package is legally sufficient.

#### Scenario: Linked evidence is profile-local and readable

- **GIVEN** a linked receipt or invoice artifact resolves to a readable path inside the active profile
- **WHEN** the package is created
- **THEN** the file SHALL be included with a relative path and integrity hash
- **AND** no absolute machine path SHALL be written to the archive

#### Scenario: Linked evidence is missing or has unresolved third-party content

- **GIVEN** a linked file is missing, unreadable, outside the active profile, or has unresolved mixed-party disclosure scope
- **WHEN** the package is generated
- **THEN** the manifest SHALL identify the excluded or unavailable reference
- **AND** the result SHALL be incomplete or failed, never complete

#### Scenario: Profile-local symlink targets evidence outside the profile

- **GIVEN** a linked evidence path is lexically beneath the profile data root but resolves through a symbolic link to a canonical target outside that root
- **WHEN** the package is created
- **THEN** the target file SHALL NOT be copied into the archive
- **AND** the manifest SHALL identify the excluded reference without exposing an absolute host path
- **AND** the result SHALL be incomplete

### Requirement: Customer disclosure export is separate from erasure and profile portability

The customer detail workspace SHALL describe this operation as a read-only, customer-scoped export and distinguish it from backup and whole-profile export. It SHALL NOT present a whole-profile archive as a response to one customer’s request. The export SHALL NOT delete, anonymize, change retention, or mark a request as legally completed. If no approved policy defines third-party disclosure, retention, or erasure behavior, the UI SHALL state the unresolved boundary and SHALL expose no destructive action.

#### Scenario: User sees the export scope before saving

- **GIVEN** the customer disclosure action is available
- **WHEN** the user opens its confirmation
- **THEN** the UI SHALL describe that the export follows verified links for one customer and may report unsupported or excluded content
- **AND** SHALL distinguish the action from a whole-profile archive or database backup

#### Scenario: Export failure or cancellation

- **GIVEN** snapshot, destination, serialization, linked-file, or validation work fails or is cancelled
- **WHEN** the export stops
- **THEN** no incomplete final archive SHALL be reported as successful
- **AND** the operation's partial file SHALL be removed
- **AND** any existing destination file SHALL remain unchanged
- **AND** customer and related source records SHALL remain unchanged

#### Scenario: Retry after interrupted archive creation

- **GIVEN** a prior process interruption left an application-owned partial file for the same export destination
- **WHEN** the user retries the export
- **THEN** the exporter MAY remove only that exact matching partial file before creating a new one
- **AND** it SHALL preserve unrelated files and any existing destination

### Requirement: Customer export follows the desktop design system

The export flow SHALL be keyboard accessible, provide visible focus and semantic labels, use localized scope, progress, empty, unavailable, error, and outcome states, and adapt to narrow windows and text scaling as specified in `DESIGN.md`. German and English translations SHALL be available, and dates SHALL use the active locale.

#### Scenario: Keyboard operation

- **GIVEN** the customer export action is focused
- **WHEN** the user activates it with the keyboard and confirms a destination
- **THEN** the same scoped export flow SHALL run as for pointer input
- **AND** completion, incompleteness, failure, or cancellation SHALL be announced as a localized semantic status

#### Scenario: Cancel destination selection in a narrow window with enlarged text

- **GIVEN** the customer detail workspace is at a narrow window width with enlarged text and the destination dialog is open
- **WHEN** the user cancels the dialog with the keyboard
- **THEN** the dialog SHALL remain readable without horizontal overflow
- **AND** focus SHALL return to the disclosure-export action
- **AND** no archive SHALL be published and a localized cancelled status SHALL be shown

#### Scenario: Unknown table state prevents complete disclosure

- **GIVEN** a lazy occurrence table is absent with marker state `unknown`, a required table is missing, or an undeclared application table is present
- **WHEN** the customer exporter validates the profile before projection
- **THEN** the export SHALL be incomplete or unavailable
- **AND** the manifest SHALL identify the table and state without exposing a database path
- **AND** the exporter SHALL NOT create, repair, or replace a table

#### Scenario: Pre-v9 profile remains valid but is not a complete export source

- **GIVEN** a version-8 profile has the 39 existing base tables and valid forderung_zahlungen but lacks feature_table_state and mileage tables
- **WHEN** database schema health is checked before migration
- **THEN** the v9 tables SHALL be treated as not yet required
- **AND** the customer archive SHALL remain unavailable for complete supported-schema export until normal sequential migrations succeed

#### Scenario: Missing payment table is detected before startup repair

- **GIVEN** PRAGMA user_version is 8 or later and forderung_zahlungen is absent
- **WHEN** startup health checks run before any repair or later migration
- **THEN** the profile SHALL remain unavailable for complete export and the original database and table absence SHALL be preserved
- **AND** no empty replacement table SHALL be created automatically

#### Scenario: Mileage and category tables remain outside customer payload

- **GIVEN** the v10 mileage tables and category_mapping_history are present without an accepted typed relationship to the selected customer
- **WHEN** a customer-scoped archive is generated
- **THEN** the tables SHALL be checked for schema health but none of their rows SHALL be projected into the customer archive
- **AND** free-text purpose, business context, or category history SHALL NOT be used to infer a customer relationship
- **AND** their omission SHALL not by itself make the customer-scoped archive incomplete

#### Scenario: Linked settlements are reported as unsupported

- **GIVEN** an included customer receivable has a settlement allocation
- **WHEN** a customer disclosure archive is created
- **THEN** the allocation and group SHALL not be serialized
- **AND** the manifest SHALL identify the unsupported relationship without exposing another party's allocation
- **AND** the archive SHALL be incomplete

#### Scenario: Linked document-email attempts are reported as unsupported

- **GIVEN** an included invoice or reminder has a document-email attempt
- **WHEN** a customer disclosure archive is created
- **THEN** the attempt and recipient SHALL not be serialized
- **AND** the manifest SHALL identify the unsupported record without exposing the recipient
- **AND** the archive SHALL be incomplete
