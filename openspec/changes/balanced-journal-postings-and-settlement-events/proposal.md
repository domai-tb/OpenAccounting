## Why

The project advertises double-entry bookkeeping and cash-basis EÜR, but invoice finalization and generic journal creation currently write one gross row without debit/credit accounts, while EÜR includes invoice-date entries before payment. This can produce an unbalanced ledger and report income or expenses in the wrong period.

## What Changes

- Define balanced, account-backed posting groups for invoice and settlement events, with source links, atomic persistence, idempotency, and immutable reversal links.
- Apply full and partial customer receipts and supplier payments to open items through posted settlement events; unmatched imported transactions do not count as payments.
- Make EÜR cash-basis totals recognize the settled portion on the actual receipt/payment date, while preserving the existing separate VAT-claim timing contract.
- Update accounting documentation and scenarios to distinguish issued receivables/payables from cash-basis income/expense.
- Do not define correction-document sign rules, new tax treatment, or monetary precision; use their separately approved contracts.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `accounting`: require balanced account-backed posting groups and atomic, traceable event posting.
- `einkommen`: recognize settled income and expenses using actual cash receipt/payment dates and portions.
- `receipts-and-payment-reconciliation`: connect confirmed payment application to the accounting settlement event; unmatched imports remain unapplied.

## Impact

Journal schema/repository, invoice finalization boundary, receivable/payable settlement use cases, EÜR calculation inputs, bank reconciliation integration, database migrations, and `docs/02-buchhaltung.md`. The existing monetary-invariant and correction-document contracts remain prerequisites for affected money/correction paths.
