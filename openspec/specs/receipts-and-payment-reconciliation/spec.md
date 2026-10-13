# receipts-and-payment-reconciliation Specification

## Purpose
TBD - created by archiving change receipts-and-payment-reconciliation. Update Purpose after archive.

## Requirements

### Requirement: Receipts follow an actionable inbox lifecycle

Receipt ingestion MUST create a durable inbox record with review state, source artifact, classification/link fields, and explicit transitions from import to review to association; the receipts route MUST expose those states. Import MUST retain the original source bytes unchanged in storage scoped to the active profile and record verifiable source metadata, including a SHA-256 digest. A receipt MAY be linked to an invoice, existing journal/booking record, customer, supplier, or document package. Creating a new financial posting or applying payment is a separate operation requiring explicit user confirmation and the accepted `balanced-journal-postings-and-settlement-events` capability. The relevant receipt and accounting workflows SHALL allow the user to preview the original source without losing the current record context. Import and association SHALL have recoverable outcomes across the inbox record and stored source artifact; the design SHALL define process-crash reconciliation and SHALL NOT claim a filesystem/database atomic transaction. Deletion SHALL be rejected until every active-profile relationship, including invoice, journal, template, package, customer, and supplier associations, is explicitly removed.

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

#### Scenario: Crash after final source write leaves no orphan on recovery
- **GIVEN** the process stops after an imported source is renamed to its final path but before the inbox row commits
- **WHEN** the application next starts
- **THEN** reconciliation finds the unreferenced importer-owned file, removes it, preserves unrelated files, and shows no successful inbox row

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

### Requirement: Bank transactions apply payments to receivables

A confirmed bank match MUST apply its signed amount to the selected receivable, support partial/full/overpayment allocation, create one auditable payment link, and update the receivable balance atomically.

Implementation evidence: Current automatic matching links only journal_id; Forderungen payment methods are not connected to the bank workflow.

#### Scenario: Partial payment is applied once

- Given a 100 euro receivable and a 40 euro confirmed bank transaction exist
- When the transaction is matched
- Then the receivable decreases by 40 euro, one payment link is recorded, and reprocessing does not apply it again

#### Scenario: Ambiguous match requires review

- Given a transaction could match multiple receivables or exceeds the remaining balance
- When automatic matching runs
- Then the transaction is not silently allocated and the user can choose/split/mark it with an explicit audit outcome

### Requirement: Confirmed payment application posts settlement atomically

When the user confirms a bank transaction as a payment against a receivable or payable, the system SHALL atomically create the accounting settlement group and update the open-item balance. The settlement date SHALL be the bank booking/value date (or manual payment date for cash), preserved verbatim in the allocation; the confirmation date SHALL NOT substitute for it. One confirmed bank transaction SHALL produce exactly one settlement group with one or more allocation rows; applied plus unapplied amounts SHALL reconcile to the signed bank amount. A positive bank row SHALL apply only to a customer receivable and a negative bank row only to a supplier payable. Matching suggestions alone SHALL NOT post a payment. A confirmed partial payment SHALL retain the unapplied balance; an overpayment SHALL retain the excess as a separately classified credit according to the existing receivables contract. The open-item status SHALL transition `offen` to `teilbezahlt` on partial payment and to `bezahlt` with zero balance on full payment; a full customer payment SHALL clear the dunning trigger under the maintained dunning contract. Repeating a confirmation SHALL return the committed group without re-applying. The stable identity is `(bank_transaction_id)` on the settlement group root with a uniqueness boundary per bank row.

#### Scenario: Confirm a matched receipt
- **GIVEN** a bank transaction is matched to a customer invoice and its application is confirmed
- **WHEN** the reconciliation is saved
- **THEN** a balanced settlement group SHALL reference the transaction and receivable
- **AND** the receivable balance SHALL decrease by the applied amount
- **AND** both changes SHALL commit together

#### Scenario: Leave an ambiguous suggestion unapplied
- **GIVEN** a bank transaction has multiple candidate invoices and no user confirmation
- **WHEN** the import is confirmed
- **THEN** no payment settlement or receivable balance change SHALL occur
- **AND** the transaction SHALL remain in the reconciliation queue

#### Scenario: Roll back a failed settlement
- **GIVEN** a confirmed payment cannot create a balanced posting group
- **WHEN** reconciliation persistence fails
- **THEN** the open-item balance and transaction application state SHALL remain unchanged
- **AND** no partial journal group SHALL be visible

#### Scenario: Confirm a supplier payment
- **GIVEN** a negative bank transaction is matched to a supplier payable and its application is confirmed
- **WHEN** the reconciliation is saved
- **THEN** a balanced settlement group SHALL reference the transaction and payable
- **AND** the payable balance SHALL decrease by the applied amount with the bank booking date retained

#### Scenario: Split one transaction across invoices
- **GIVEN** one bank transaction is confirmed against two receivables with explicit applied amounts
- **WHEN** the reconciliation is saved
- **THEN** exactly one settlement group SHALL hold both allocations
- **AND** applied plus unapplied amounts SHALL reconcile to the signed bank amount

#### Scenario: Retain a confirmed overpayment as credit
- **GIVEN** a confirmed receipt exceeds the receivable balance
- **WHEN** the reconciliation is saved
- **THEN** the receivable SHALL close and the excess SHALL remain as a separately classified credit per the existing receivables contract

#### Scenario: Repeated confirmation does not duplicate
- **GIVEN** a confirmed bank transaction already has a committed settlement group
- **WHEN** the same confirmation is submitted again
- **THEN** the original settlement group SHALL be returned
- **AND** no additional balance change SHALL occur

#### Scenario: Full payment clears the dunning trigger
- **GIVEN** a receivable with an active dunning level has its full open balance confirmed
- **WHEN** the settlement commits
- **THEN** the open-item status SHALL become `bezahlt` with zero balance
- **AND** the dunning trigger SHALL clear under the maintained dunning contract
