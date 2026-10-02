## ADDED Requirements

### Requirement: Correction and conversion drafts preserve source context

When creating a replacement or converting a document, the system SHALL preserve the source relationship and the source context required by the `documents` contract: counterparty identity and one-time customer address where applicable, delivery address, input mode, introduction and closing text, and every position field already covered by Position Propagation. A replacement SHALL retain its bidirectional source link. A converted document SHALL retain its source and target links. The target remains editable when created as a draft, and later user edits SHALL NOT rewrite the source document.

#### Scenario: Replacement draft retains source fields and links
- **GIVEN** a storniert invoice contains a customer, one-time address, delivery address, input mode, texts, and positions
- **WHEN** a replacement draft is created from it
- **THEN** the draft retains those source fields and positions, the original points to the replacement, and the replacement points to the original

#### Scenario: Ineligible source creates no partial target
- **GIVEN** a finalized invoice is not storniert
- **WHEN** a replacement is requested from that invoice
- **THEN** the operation returns the existing ineligible-source error and creates no target row, target positions, or relationship update

#### Scenario: Supported conversion preserves source context
- **GIVEN** a finalized Angebot contains its company snapshot, customer, input mode, texts, and positions
- **WHEN** the user converts it to an allowed Auftrag draft
- **THEN** the new draft preserves those fields and position values, has a source link to the Angebot, and the Angebot has a reciprocal target link
- **AND** later edits to the draft do not modify the Angebot

## MODIFIED Requirements

### Requirement: Dokumentenpakete

A Dokumentenpaket SHALL retain the existing document membership contract: each accounting document references the package through `dokumentenpaket_id`. Packages SHALL support supporting-evidence membership through the existing `dokumentenpaket_belege` relationship and provide organized display and a ZIP export of the selected snapshot. Package views SHALL show metadata and current document and Beleg members with their source identifiers. Adding or removing membership SHALL NOT change or delete the underlying document or Beleg. Empty package creation SHALL remain rejected. Batch printing and email delivery are deferred until their platform/transport capabilities are specified; this requirement SHALL NOT imply those actions are available or successful.

#### Scenario: Package groups documents and receipt evidence
- **GIVEN** a finalized invoice, a Lieferschein, and an imported receipt are available
- **WHEN** the user adds them to one document package
- **THEN** the invoice and Lieferschein reference the package through `dokumentenpaket_id`, the Beleg is a member through `dokumentenpaket_belege`, and the package lists all three source identifiers
- **AND** each original record and artifact remains unchanged

#### Scenario: Package export preserves member snapshot
- **GIVEN** a package contains readable finalized documents and supporting Belege
- **WHEN** the user exports the package
- **THEN** the ZIP contains a manifest and a copy of each selected member artifact, records source identifiers, and verifies the copied digests before reporting success
- **AND** no member document, relationship, or source file is changed

#### Scenario: Missing member cannot be added
- **GIVEN** an imported receipt identifier does not exist in the active profile
- **WHEN** the user attempts to add it to a package
- **THEN** the operation reports the unavailable member and leaves the package membership unchanged

#### Scenario: Create package from multiple documents
- **GIVEN** a user selects a Rechnung, Lieferschein, and Angebot
- **WHEN** the user creates a Dokumentenpaket
- **THEN** all three documents have `dokumentenpaket_id` pointing to the new package, and the package page shows all three

#### Scenario: Empty package creation blocked
- **GIVEN** no documents are selected
- **WHEN** a user attempts to create a Dokumentenpaket
- **THEN** the system rejects the action with error `Mindestens ein Dokument auswählen`

### Requirement: Belege — Upload and Attach

The system SHALL retain Beleg metadata (`dateiname`, `original_name`, `mime_type`, `dateigroesse`, `sha256`,
`hochgeladen_am`, optional `beleg_pdfa_pfad`, and optional `loeschdatum`) and support upload, inline view, download,
rename, and deletion.
Uploaded sources SHALL be limited to PDF, PNG, JPEG, and XML files used by supported XRechnung or ZUGFeRD/Factur-X
flows; each source SHALL be at most 50 MiB. The importer SHALL verify the content format rather than trust the filename
or client MIME type, store originals below the active profile root, and preserve the source bytes. A Beleg MAY be
attached to an invoice or journal entry using its existing relationship. Explicit deletion SHALL be available only
when the Beleg has no invoice, journal, template, package, customer, or supplier relationship; the user must explicitly
unlink every relationship first. Deletion SHALL remove its metadata and stored source bytes. Removing a Beleg from a
package or contact SHALL only remove that relationship and SHALL NOT delete the Beleg.
An existing `loeschdatum` SHALL be displayed as informational metadata; automatic purge remains disabled until a
retention policy is accepted. The accompanying documentation SHALL not claim that automatic cleanup currently occurs.

#### Scenario: Attach receipt to invoice
- **GIVEN** a user uploads a PDF receipt
- **WHEN** the user attaches it to Rechnung #100
- **THEN** Rechnung #100 has `beleg_id` pointing to the uploaded Beleg, and the receipt is viewable from the invoice detail page

#### Scenario: Unsupported file type rejected
- **GIVEN** a user attempts to upload a `.exe` file as a Beleg
- **WHEN** the upload is processed
- **THEN** the system rejects the file with error `Dateityp nicht unterstützt`

#### Scenario: Oversized or mislabeled source is rejected
- **GIVEN** a source exceeds 50 MiB or its bytes do not match a supported format
- **WHEN** the user imports the source
- **THEN** import fails before creating a Beleg record or final stored file

#### Scenario: Linked evidence cannot be deleted
- **GIVEN** a Beleg is linked to an invoice, journal entry, template, package, customer, or supplier
- **WHEN** the user requests deletion
- **THEN** deletion is rejected with a localized explanation and all source bytes and relationships remain unchanged

#### Scenario: Customer association must be removed before evidence deletion
- **GIVEN** a Beleg has a customer association through `kunden_belege`
- **WHEN** the user requests deletion
- **THEN** deletion is rejected and the customer association and source bytes remain unchanged
- **AND** after explicit unlinking, the Beleg remains available until the user separately confirms deletion

#### Scenario: Unlinked evidence can be deleted
- **GIVEN** a Beleg has no invoice, journal, template, package, customer, or supplier relationship
- **WHEN** the user confirms deletion
- **THEN** its metadata and stored source bytes are removed

#### Scenario: Scheduled deletion date does not silently purge evidence
- **GIVEN** an unlinked Beleg has an expired `loeschdatum`
- **WHEN** the application starts or displays the Beleg
- **THEN** the source remains available, the date is shown as due, and no automatic deletion occurs

### Requirement: Customer document links preserve shared evidence

The customer-document workspace SHALL retain upload, inline preview, rename, and delete operations for customer
documents. Removing a customer-document association SHALL only remove its `kunden_belege` relationship and SHALL NOT
delete the shared Beleg metadata or source bytes. Deleting the underlying Beleg SHALL follow the Beleg deletion rule
above and SHALL require every customer and other relationship to be explicitly unlinked first. A `loeschdatum` SHALL
remain visible as informational metadata with the maintained due/overdue warning, but SHALL NOT trigger automatic
purging until an explicit retention policy is accepted.

#### Scenario: Remove customer association without deleting shared evidence
- **GIVEN** a Beleg is linked to a customer through `kunden_belege` and also has another active relationship
- **WHEN** a user removes it from the customer documents list
- **THEN** only the customer association is removed and the Beleg metadata, source bytes, and other relationship remain
  unchanged

#### Scenario: Customer document deletion date does not purge shared evidence
- **GIVEN** a customer-linked Beleg has an expired `loeschdatum`
- **WHEN** the customer document list or application starts
- **THEN** the due warning is displayed and the source remains available without automatic deletion
