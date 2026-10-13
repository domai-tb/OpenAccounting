## ADDED Requirements

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
