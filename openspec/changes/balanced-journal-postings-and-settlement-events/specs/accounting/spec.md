## ADDED Requirements

### Requirement: Balanced, source-linked posting groups

Every posted financial event SHALL be stored as a source-linked posting group with at least two account-backed journal lines. The sum of debit values SHALL equal the sum of credit values for the group, and all lines SHALL be created atomically. Repeating the same source event SHALL NOT create duplicate groups. A posted group SHALL be reversed by a new linked immutable group; posted lines SHALL NOT be edited or deleted.

#### Scenario: Post a finalized invoice
- **GIVEN** an issued invoice has valid configured accounts and tax mapping
- **WHEN** its accounting event is posted
- **THEN** a source-linked journal group with at least two account-backed lines SHALL be committed
- **AND** total debit SHALL equal total credit
- **AND** the invoice SHALL reference that group

#### Scenario: Required posting mapping is missing
- **GIVEN** an invoice cannot resolve a required account or tax mapping
- **WHEN** finalization attempts to post its accounting event
- **THEN** the transaction SHALL roll back the invoice finalization and all journal lines
- **AND** the user SHALL receive a field/actionable mapping error

#### Scenario: Retry a source event
- **GIVEN** a source event already has a committed posting group
- **WHEN** the same event is submitted again
- **THEN** the original group SHALL be returned or recognized
- **AND** no additional journal lines SHALL be created

#### Scenario: Reverse a posted group
- **GIVEN** an immutable balanced posting group exists
- **WHEN** an authorized reversal is posted
- **THEN** a new immutable group SHALL link to the original and contain the exact opposite account balances
- **AND** the original group SHALL remain unchanged

### Requirement: Payment and invoice posting linkage

Invoice issue events and payment events SHALL have distinct source identifiers and posting groups. A payment posting SHALL identify its bank/cash account, counterparty, applied receivable or payable, settlement date, and applied amount. Partial payment SHALL reduce only the applied open balance; any unapplied remainder SHALL remain separately identifiable.

#### Scenario: Post a partial receipt
- **GIVEN** a customer receivable has an open balance of 100.00
- **WHEN** a confirmed receipt of 40.00 is applied to it
- **THEN** one balanced payment group SHALL reference the receipt and receivable
- **AND** the receivable balance SHALL become 60.00
- **AND** the payment date SHALL be retained

#### Scenario: Do not post an unconfirmed bank row
- **GIVEN** an imported bank transaction has no confirmed invoice/payment application
- **WHEN** accounting postings are requested
- **THEN** no receipt settlement group SHALL be created
- **AND** the transaction SHALL remain available as unreconciled work
