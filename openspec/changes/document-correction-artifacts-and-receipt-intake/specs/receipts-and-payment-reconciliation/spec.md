## MODIFIED Requirements

### Requirement: Receipts follow an actionable inbox lifecycle

Receipt ingestion MUST create a durable inbox record with review state, source artifact, classification/link fields, and explicit transitions from import to review to association; the receipts route MUST expose those states. Import MUST retain the original source bytes unchanged in storage scoped to the active profile and record verifiable source metadata, including a SHA-256 digest. A receipt MAY be linked to an invoice, existing journal/booking record, customer, supplier, or document package. Creating a new financial posting or applying payment is a separate operation requiring explicit user confirmation and the accepted `balanced-journal-postings-and-settlement-events` capability. The relevant receipt and accounting workflows SHALL allow the user to preview the original source without losing the current record context. Import and association SHALL have recoverable outcomes across the inbox record and stored source artifact; the design SHALL define process-crash reconciliation and SHALL NOT claim a filesystem/database atomic transaction.

#### Scenario: Receipt is reviewed and linked
- **GIVEN** a supported receipt file is selected
- **WHEN** the user imports, reviews, previews, and associates it with an invoice or existing booking
- **THEN** the original bytes, metadata and digest, review decision, and link are persisted and visible in the inbox
- **AND** no new posting or payment allocation is created by association alone

#### Scenario: Reviewed receipt is posted only after explicit confirmation
- **GIVEN** a reviewed receipt and a supported target are available after the balanced-posting prerequisite is implemented
- **WHEN** the user separately confirms creating a posting or applying a payment
- **THEN** the settlement use case records the selected accounting effect and links the original receipt without changing its bytes

#### Scenario: Unreadable receipt remains reviewable
- **GIVEN** file parsing or recognition fails after the source bytes are stored
- **WHEN** the receipt is imported
- **THEN** it remains in a visible error/review state with the unchanged original source and a manual assignment action

#### Scenario: Failed intake leaves no partial record or file
- **GIVEN** the source cannot be validated or safely stored
- **WHEN** import fails
- **THEN** no inbox record or package association claims a successful import, and no partial artifact remains

#### Scenario: Source preview failure preserves the record
- **GIVEN** a receipt is linked to an accounting record but its source artifact is unavailable
- **WHEN** the user opens source preview
- **THEN** the UI reports the unavailable source and preserves the receipt state and accounting relationship

### Requirement: Receipt recognition is advisory and reviewable

The system SHALL present recognized receipt fields as suggestions linked to the original source, SHALL require explicit user review before suggested values are used for a posting, and SHALL never modify the original source bytes as a result of recognition. Recognition failure or unavailable recognition SHALL leave the original available and offer manual review. This requirement does not select a recognition provider, confidence threshold, or data-processing policy.

#### Scenario: User accepts reviewed recognition suggestions
- **GIVEN** recognition has produced field suggestions for an imported receipt
- **WHEN** the user reviews and accepts selected suggestions
- **THEN** the accepted values are applied to the review/assignment form and the source artifact remains byte-identical

#### Scenario: Recognition failure falls back to manual review
- **GIVEN** recognition is unavailable or cannot extract fields
- **WHEN** the user reviews the receipt
- **THEN** the original is previewable, no suggested values are applied, and the user can continue with manual entry
