## ADDED Requirements

### Requirement: Confirmed payment application posts settlement atomically

When the user confirms a bank transaction as a payment against a receivable or payable, the system SHALL atomically create the accounting settlement group and update the open-item balance. Matching suggestions alone SHALL NOT post a payment. A confirmed partial payment SHALL retain the unapplied balance; an overpayment SHALL retain the excess as a separately classified credit according to the existing receivables contract.

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
