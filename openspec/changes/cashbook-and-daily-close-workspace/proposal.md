## Why

The feature map requires a cash book with income, expenses, running balance, supporting documents, categories, VAT, descriptions, reconciliation, and protected history, plus formal daily cash closing. The repository has neither a production cashbook workflow nor a close workflow, and its current journal and balance sources do not yet provide approved complete cash semantics. This change adds the Banking workspace only through approved posting/reporting boundaries and fails closed when those boundaries are missing or incomplete.

## What Changes

- Add Cashbook and Daily Close views to the existing `/banking` workspace while preserving its import, history, rule, and review views.
- Persist one account-scoped setup opening source in this change's v26 migration and setup transaction. Show and record cash movements only through the accepted balanced-posting service; obtain running and expected balances from a complete typed account/date result containing integer cents, currency, source reference, and completeness. Count the verified opening cash once; never add its duplicate `konten.saldo` value. Existing accounts without an unambiguous v26 source remain unavailable for balances and cash writes; legacy rows and `konten.saldo` are never backfilled as sources.
- Record a close only for an explicit company/account/date, with `betrag` expected, `kassenbestand` counted, `differenz` counted minus expected, and the selected `konto_id`. Store a versioned canonical `zaehlung_json` plus SHA-256 integrity digest; this digest does not authenticate a person or signing key. Do not auto-post a cash difference.
- Render the existing Tagesabschluss PDF only from a complete finalized snapshot; do not calculate cash, tax, or discrepancy values in the UI or PDF renderer.
- Reserve v26 for the account-opening source after v25 mileage; reserve v27 for versioned `zaehlung_json` and `integrity_hash` fields plus finalized-close immutability protection on the existing `tagesabschluesse` table. The v27 close migration adds no table. Verify the canonical UTF-8 digest before finalized display or PDF generation and preserve legacy rows unchanged. The agreed sequence reserves v28 for the separate e-invoice tax migration.

## Capabilities

### New Capabilities

- `cashbook-and-daily-close-workspace`: typed Banking views for cash movement history/entry and daily close, gated by approved source contracts.

### Modified Capabilities

- `accounting`: replace the unsupported same-day-journal-sum rule for Tagesabschluss with an approved balance-source boundary and explicit fail-closed behavior.
- `receipts-and-payment-reconciliation`: require a selected receipt reference and balanced cash posting to commit or roll back together.
- `db`: migrate close evidence storage and protect finalized close rows.
- `profile-data-portability`: include the v26 opening-source table and typed rows in complete versioned profile archives.
- `customer-data-disclosure-export`: schema-check the v26 source table without projecting company cash data absent an approved customer relationship.
- `pdf`: require Tagesabschluss PDFs to consume a complete integrity-verified stored snapshot without recalculation.

## Impact

The existing Banking route and app-service graph, the accepted `balanced-journal-postings-and-settlement-events` posting boundary, this change's v26 account-opening source, v27 `tagesabschluesse` evidence migration/immutability, profile portability and customer-disclosure schema health, receipt references, existing PDF generation, and localized desktop views. The accepted posting boundary supplies balanced `cash_payment` groups; the v26 setup transaction supplies a verified account-scoped opening event. This change composes those inputs into a complete account/date result. Cash writes and balances remain unavailable until the v26 source is complete and implemented; close finalization and PDFs additionally require v27 evidence support. All production paths remain gated on fresh independent review and verification. The separate v28 e-invoice tax migration remains outside this change.
