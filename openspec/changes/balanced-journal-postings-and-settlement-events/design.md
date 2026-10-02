## Context

The accounting spec calls the ledger double-entry, but production invoice finalization and `JournalRepository.createEntry` insert a single `betrag` row without populated debit/credit account values. The database already has `soll`, `haben`, and account-id columns, but their defaults allow zero-sided rows. Invoice finalization also creates an open receivable and an invoice-date journal row. EÜR currently sums income/expense journal rows by that row date, so it can treat an unpaid invoice as received cash. Confirmed bank imports are not yet the payment-application boundary.

The implementation must coordinate with the existing receivable, bank-reconciliation, correction-document, and monetary-invariant contracts. In particular, the archived `invoice-money-invariants` review has unresolved precision and sign decisions; this change must not invent replacements for those decisions.

## Goals / Non-Goals

**Goals:**

- Enforce balanced, account-backed posting groups for new supported accounting events.
- Link source events to posting groups and make retries idempotent.
- Record partial payment applications with their cash date and amount.
- Base ordinary EÜR recognition on settled portions and retain auditable statutory timing adjustments.
- Keep old journal history readable without fabricating contra entries.

**Non-Goals:**

- Define invoice line rounding, correction sign conventions, tax rates, account-plan defaults, or statutory exceptions without the separately approved domain contracts.
- Build the bank matching UI, tax-reporting UI, or general ledger account-plan management UI.
- Rewrite or auto-balance historical journal rows.

## Decisions

1. **Keep `journal` as the line-level ledger.** Use one journal row per debit or credit leg, with a shared transaction-group root and explicit account IDs. Enforce at least two legs and equal debit/credit totals in the posting use case inside the same database transaction. A `CHECK` on one row cannot guarantee a cross-row total; transaction-level validation is required. Alternatives: leave one gross row with implicit contra accounts, or infer counterparties from category text. Both conceal missing ledger entries and are rejected.
2. **Give each source event a unique posting identity.** Store source kind/id on the group root and protect it with a unique constraint. Build all lines and link the source, group, and open-item application in one `beginTransaction` scope. A retry returns the committed group; a partial write rolls back. Alternative: application-only duplicate checks without a unique key; rejected because concurrent retries can duplicate postings.
3. **Represent payment allocations separately from invoice issue.** Keep receivable/payable state and add a small allocation relation from a payment group to an open item, amount, and settlement date. This supports multiple partial receipts/payments and one transaction split across invoices without treating a suggested match as cash. Alternatives: overwrite the single `ausgleich_journal_id` or infer allocations from descriptions; rejected because they lose partial-payment history.
4. **Preserve cash and tax timing as distinct facts.** Issue postings establish the receivable/payable; settlement postings represent received/paid portions for EÜR. EÜR reads the settlement relation and dates, while the existing input-tax claim service retains its own Soll-principle date. Statutory year-boundary exceptions must be represented by an explicit reviewed rule result with source trace; never infer them from free text. §11 EStG defines receipt/payment timing and a limited timing rule for regularly recurring items ([official statute](https://www.gesetze-im-internet.de/estg/__11.html)); implementation requires a current domain review of the applicable rule before enabling exception handling.
5. **Do not rewrite old rows.** Migration adds group/source/allocation storage for new events. Existing rows without debit/credit legs remain readable as legacy history and are marked unverified for double-entry reports. Alternatives: synthesize balancing rows or silently relabel all old rows as balanced; rejected because the missing account side cannot be known safely.
6. **Require configured mappings at the posting boundary.** If the event cannot resolve its counterpart accounts and required tax mapping, fail before committing invoice finalization, payment application, or journal lines. Do not use the first active category or fallback account `1`.

## Risks / Trade-offs

- [Double-entry groups expose existing reports that count one row as one transaction] → Update report queries to aggregate groups and use the designated income/expense side; add a regression fixture with multiple legs.
- [Legacy entries remain unbalanced] → Keep them visible and label the historical period as legacy/unverified; do not claim the entire historical ledger is balanced.
- [Concurrent payment applications can over-apply an open item] → Update remaining balance conditionally within the same transaction and reject if it changed since matching.
- [Tax timing exceptions require legal interpretation] → Gate exception rules behind reviewed, versioned policy data; default to actual settlement date when there is no approved result. See §11 EStG linked above.
- [Downstream bank/document changes may be delivered later] → Keep posting methods callable through one accounting boundary and leave unmatched imports unapplied until reconciliation is confirmed.

## Migration Plan

1. Add versioned source/group and payment-allocation storage with indexes and a migration rollback path that removes only new schema when no new postings exist.
2. Add balanced posting validation and begin using it for new invoice and settlement events behind their existing database transaction boundary.
3. Route EÜR income/expense reads through settled allocation dates and add explicit legacy/unverified handling.
4. Update accounting documentation and strict OpenSpec validation. Do not mutate old journal rows; test restore and migration behavior before enabling the new writer.

## Open Questions

- The exact monetary representation and correction sign matrix remain governed by the unresolved `invoice-money-invariants` change. This design cannot be applied to those paths until that contract is accepted.
- Which SKR account defaults should be seeded for the debit/credit legs must be confirmed against the existing company-selected chart and category mappings; missing mappings block posting rather than use a fallback.
- Statutory EÜR timing exceptions require reviewed rule inputs and expected-year fixtures before implementation; the official §11 text is linked above, but this artifact does not encode tax advice.
