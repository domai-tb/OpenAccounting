## ADDED Requirements

### Requirement: Receipts follow an actionable inbox lifecycle

Receipt ingestion MUST create a durable inbox record with review state, source artifact, classification/link fields, and explicit transitions from import to review to assignment/posting; the receipts route MUST expose those states.

Implementation evidence: No production receipt repository/use case/ingestion path was found despite the Belege table and route.

#### Scenario: Receipt is reviewed and linked

- Given a valid receipt file is selected
- When the user imports, reviews, and assigns it to an invoice or booking
- Then the artifact, review decision, link, and resulting posting are persisted and visible in the inbox

#### Scenario: Unreadable receipt remains reviewable

- Given file parsing or OCR fails
- When the receipt is imported
- Then it remains in a visible error/review state with the original artifact and a manual assignment action

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
