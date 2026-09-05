## ADDED Requirements

### Requirement: Finalization creates the complete accounting posting set

Finalizing an eligible invoice MUST create exactly the required immutable journal postings, outgoing receivable or incoming input-tax claim, and inventory effects using the persisted document totals and tax context.

Implementation evidence: The current finalization path updates the invoice and inventory only; the existing receivable creation method is not on that call path.

#### Scenario: Outgoing invoice creates a receivable

- Given a valid outgoing invoice has a customer and is in draft state
- When finalization succeeds
- Then one finalized document, its journal posting, and one receivable with matching totals and due date exist

#### Scenario: Incoming invoice creates input-tax state

- Given a valid incoming invoice has taxable positions
- When finalization succeeds
- Then the journal and input-tax claim reflect the positions and no outgoing turnover is created

#### Scenario: Failure leaves no partial posting

- Given journal or receivable persistence fails during finalization
- When the transaction completes
- Then document status, inventory, journal, and receivable state are rolled back and the user receives a typed failure

### Requirement: Finalization is idempotent and audit-linked

A finalized document MUST NOT create duplicate postings when finalization is retried, and every generated posting MUST retain a stable document reference sufficient for later Storno, payment, and audit operations.

Implementation evidence: Current finalization has no accounting side-effect guard or idempotence assertion.

#### Scenario: Retry does not duplicate accounting

- Given the same document is already finalized
- When the finalization command is repeated
- Then the command returns the existing result or a clear conflict and journal/receivable counts remain unchanged

#### Scenario: Correction can find its source

- Given a finalized document has generated accounting entries
- When a reversal or credit-note workflow starts
- Then the source postings are discoverable by stable document linkage and the correction cannot silently orphan them
