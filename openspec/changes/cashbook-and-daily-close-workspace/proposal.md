## Why

The feature map requires a cash book with income, expenses, running balance, supporting documents, categories, VAT, descriptions, reconciliation, and protected history, plus formal daily cash closing. The repository has neither a production cashbook workflow nor a close workflow, and its current journal and balance sources do not yet provide approved complete cash semantics. This change adds the Banking workspace only through approved posting/reporting boundaries and fails closed when those boundaries are missing or incomplete.

## What Changes

- Add Cashbook and Daily Close views to the existing `/banking` workspace while preserving its import, history, rule, and review views.
- Show and record cash movements only through the accepted balanced-posting service; obtain running and expected balances from a complete typed account/date result containing integer cents, currency, source reference, and completeness. Count verified setup opening cash once; never add its duplicate `konten.saldo` value.
- Record a close only for an explicit company/account/date, with `betrag` expected, `kassenbestand` counted, `differenz` counted minus expected, and the selected `konto_id`. Store a versioned canonical `zaehlung_json` plus SHA-256 integrity digest; this digest does not authenticate a person or signing key. Do not auto-post a cash difference.
- Render the existing Tagesabschluss PDF only from a complete finalized snapshot; do not calculate cash, tax, or discrepancy values in the UI or PDF renderer.
- Reserve migration v25, after v23 mileage and the v24 setup anchor, to add versioned `zaehlung_json` and `integrity_hash` fields and finalized-close immutability protection to the existing `tagesabschluesse` table without adding a new ledger or table. Verify the canonical UTF-8 digest before finalized display or PDF generation and preserve legacy rows unchanged.

## Capabilities

### New Capabilities

- `cashbook-and-daily-close-workspace`: typed Banking views for cash movement history/entry and daily close, gated by approved source contracts.

### Modified Capabilities

- `accounting`: replace the unsupported same-day-journal-sum rule for Tagesabschluss with an approved balance-source boundary and explicit fail-closed behavior.
- `receipts-and-payment-reconciliation`: require a selected receipt reference and balanced cash posting to commit or roll back together.
- `db`: migrate close evidence storage and protect finalized close rows.
- `pdf`: require Tagesabschluss PDFs to consume a complete integrity-verified stored snapshot without recalculation.

## Impact

The existing Banking route and app-service graph, the accepted `balanced-journal-postings-and-settlement-events` posting boundary, an account/date cash-balance result defined by this change, `tagesabschluesse` migration/immutability, receipt references, existing PDF generation, and localized desktop views. The accepted posting boundary supplies balanced `cash_payment` groups; this change defines how those groups and the verified setup opening event produce a complete account/date result. Cash writes, balances, closes, and PDFs remain unavailable until this change passes fresh independent review and the specified production paths are implemented and verified.
