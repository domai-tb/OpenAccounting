## ADDED Requirements

### Requirement: Manual supplier invoice capture reuses a reviewed Beleg

The system SHALL let a user open an imported PDF Beleg in an incoming-invoice capture workspace that keeps the original source preview visible beside the editable fields. The user SHALL be able to select an existing supplier and enter source invoice details and supported line fields, then save an editable `rechnung_eingang` draft linked to that Beleg. A supplier's source invoice number, when present, SHALL be stored separately from the application's assigned `rechnungsnummer`. Saving capture SHALL not finalize the invoice. The source and field-review layout SHALL follow DESIGN.md §§15–16 and the form rules in §25.

#### Scenario: Save a manually reviewed PDF as an incoming draft
- **GIVEN** an imported PDF Beleg and an existing supplier are available
- **WHEN** the user previews the PDF, enters its source invoice number and supported details, selects the supplier, and saves
- **THEN** one editable `rechnung_eingang` draft is linked to that supplier and Beleg
- **AND** the supplier's source invoice number is stored independently from the application's invoice number
- **AND** the selected Beleg remains the unchanged source shown by the preview

#### Scenario: Missing supplier prevents draft creation
- **GIVEN** a PDF Beleg is open in incoming-invoice capture with no supplier selected
- **WHEN** the user attempts to save
- **THEN** the capture reports the missing supplier and creates no invoice draft or invoice-to-Beleg link

### Requirement: Structured supplier invoice data is reviewed before draft creation

For an imported Beleg containing standalone XRechnung XML or supported structured XML embedded in a ZUGFeRD/Factur-X PDF, the system SHALL offer the invoice fields that the existing incoming-draft model can represent as reviewable suggestions. The user SHALL explicitly confirm the selected supplier and field values before the system creates a linked, editable `rechnung_eingang` draft. Imported values and user edits SHALL remain distinguishable during review, while the original source preview remains available. Field conversion SHALL follow the separately accepted invoice-money contract and SHALL NOT add calculation, rounding, or tax policy. The review layout SHALL follow DESIGN.md §§15–16 and §25.

#### Scenario: Confirm structured fields into an incoming draft
- **GIVEN** a Beleg contains readable supported XRechnung or ZUGFeRD/Factur-X invoice XML
- **WHEN** the user reviews the proposed supplier, source invoice number, dates, and supported line fields, selects the supplier, and confirms draft creation
- **THEN** one editable incoming draft is created with the confirmed values and a link to the Beleg
- **AND** the imported source remains unchanged and previewable
- **AND** no finalization or accounting effect is created by capture

#### Scenario: Unconfirmed suggestions do not create a draft
- **GIVEN** structured invoice suggestions are displayed for a Beleg
- **WHEN** the user leaves the review without confirming draft creation
- **THEN** no incoming invoice draft or invoice-to-Beleg link is created
- **AND** the original Beleg remains available in its receipt-review state

### Requirement: Unsupported source data remains reviewable without inferred invoice values

If structured invoice data is unreadable or contains a field that the existing incoming-draft model cannot represent, the system SHALL identify that condition in the review state, preserve the Beleg review path, and allow manual entry where possible. It SHALL NOT use OCR, invent a field value, silently discard an unsupported value, or create a draft from unconfirmed data. Error and recovery states SHALL follow DESIGN.md §§16 and 26.

#### Scenario: Unreadable structured data falls back to manual entry
- **GIVEN** an imported Beleg has no readable supported structured invoice data
- **WHEN** the user opens incoming-invoice capture
- **THEN** no extracted invoice values are populated, the source remains previewable, and manual entry is available

#### Scenario: Unrepresentable value is not silently mapped
- **GIVEN** a supported invoice source contains a value with no representation in the current incoming-draft model
- **WHEN** the importer prepares the review state
- **THEN** it identifies the unsupported value for the user and does not substitute a different value or create a draft
