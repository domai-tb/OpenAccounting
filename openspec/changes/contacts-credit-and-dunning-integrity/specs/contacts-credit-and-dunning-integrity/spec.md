## ADDED Requirements

### Requirement: Contacts are data-backed and credit decisions are auditable

The Contacts workspace MUST load and mutate real customer/supplier records, and every credit-limit check/confirmation MUST persist the decision, inputs, actor/time context, and resulting invoice action or rejection.

Implementation evidence: The route is placeholder-only and the current credit method reports an audit flag without storing an audit record.

#### Scenario: Customer change is visible in linked workflows

- Given a customer is created or edited
- When the user returns to the list or opens an invoice selector
- Then the persisted identity, address, tax, and credit fields are shown and usable

#### Scenario: Credit decision leaves an audit trail

- Given an invoice exceeds or approaches a customer's credit limit
- When the user confirms or rejects the action
- Then the decision and relevant balance/limit snapshot are persisted and the invoice action follows that decision

### Requirement: Dunning letters are durable and linked

A dunning run MUST select eligible overdue receivables, create a numbered level-specific letter with reason/amount/due-date context, generate a readable artifact, and link it to the receivable/customer history.

Implementation evidence: Dunning generation currently validates but does not persist or produce the letter, while the existing PDF method is a filename stub.

#### Scenario: Eligible receivable produces a letter

- Given an overdue receivable meets the configured dunning level
- When the user generates a letter
- Then the letter record, PDF artifact, amount/due context, and receivable link are persisted

#### Scenario: Ineligible or failed run is safe

- Given a receivable is not overdue or artifact generation fails
- When the dunning action runs
- Then no misleading sent/created state is recorded and the user receives an actionable explanation
