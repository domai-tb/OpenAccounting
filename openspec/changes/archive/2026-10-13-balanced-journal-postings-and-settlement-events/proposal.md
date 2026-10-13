## Why

The project advertises double-entry bookkeeping and cash-basis EÜR, but invoice finalization and generic journal creation currently write one gross row without debit/credit accounts, while EÜR includes invoice-date entries before payment. This can produce an unbalanced ledger and report income or expenses in the wrong period.

## What Changes

- Define balanced, account-backed posting groups for invoice and settlement events, with source links, atomic persistence, idempotency, and immutable reversal links. Posting amounts use integer cents governed by the accepted invoice-money contract. Proportional splits use floor shares, then distribute remaining cents by descending remainder and stable ascending key; mixed-category settlement allocations use source journal IDs as keys.
- Apply full and partial customer receipts and supplier payments to open items through posted settlement events; one confirmed bank transaction maps to one settlement group with one or more allocations whose applied plus unapplied amounts reconcile to the signed bank amount. Unmatched imported transactions do not count as payments.
- Make EÜR cash-basis totals recognize the settled portion on the authoritative cash date (bank booking/value date for imports, manual payment date for cash; confirmation date is not the settlement date), while preserving the existing separate VAT-claim timing contract. Partial and mixed-category settlements inherit the invoice's persisted category/tax proportions; direct cash events, write-offs, overpayments, refunds, corrections, reversals, and legacy rows have explicit recognition rules in the delta specs.
- Update accounting documentation and scenarios to distinguish issued receivables/payables from cash-basis income/expense. New invoice and settlement events route through the posting boundary; recurring templates, setup opening balances, and other direct single-row writers remain explicitly out of scope and keep their maintained behavior until a separate contract routes them.
- Do not redefine correction-document workflows, tax treatment, or the accepted monetary precision and sign contract; consume their approved contracts. Reversals restore allocations and open-item balances atomically, link VAT-claim and document corrections, and reject duplicates; migration rollback means restoring the pre-migration backup.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `accounting`: require balanced account-backed posting groups and atomic, traceable event posting.
- `einkommen`: recognize settled income and expenses using actual cash receipt/payment dates and portions.
- `receipts-and-payment-reconciliation`: connect confirmed payment application to the accounting settlement event; unmatched imports remain unapplied.

## Impact

Journal schema/repository, invoice finalization boundary, receivable/payable settlement use cases, EÜR calculation inputs, bank reconciliation integration, database migrations, and `docs/02-buchhaltung.md`. The accepted invoice-money contract governs totals, signs, and cent allocation; the correction-document contract governs linked correction records. Both are consumed as approved contracts. Migration is forward-only; rollback is restoration from the pre-migration backup.
