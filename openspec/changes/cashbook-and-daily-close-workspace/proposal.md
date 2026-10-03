## Why

The feature map requires a cash book with income, expenses, running balance, supporting documents, categories, VAT, descriptions, reconciliation, and protected history, plus formal daily cash closing. The repository has neither a production cashbook workflow nor a close workflow, and its current journal and balance sources do not yet provide approved complete cash semantics. This change adds the Banking workspace only through approved posting/reporting boundaries and fails closed when those boundaries are missing or incomplete.

## What Changes

- Add Cashbook and Daily Close views to the existing `/banking` workspace while preserving its import, history, rule, and review views.
- Show and record cash movements only through a typed service backed by an approved balanced-posting contract; obtain running and expected balances only from an approved complete cash-reporting result.
- Record a close only from a complete expected-balance result, the user's actual count, a required explanation when the close contract reports a discrepancy, and a signed immutable snapshot. Do not auto-post a cash difference.
- Render the existing Tagesabschluss PDF only from a complete finalized snapshot; do not calculate cash, tax, or discrepancy values in the UI or PDF renderer.
- Add the missing `zaehlung_json` field and signed-close immutability protection to the existing `tagesabschluesse` table without adding a new ledger or table.

## Capabilities

### New Capabilities

- `cashbook-and-daily-close-workspace`: typed Banking views for cash movement history/entry and daily close, gated by approved source contracts.

### Modified Capabilities

- `accounting`: replace the unsupported same-day-journal-sum rule for Tagesabschluss with an approved balance-source boundary and explicit fail-closed behavior.
- `db`: migrate close evidence storage and protect signed close rows.
- `pdf`: require Tagesabschluss PDFs to consume a complete signed close snapshot without recalculation.

## Impact

The existing Banking route and app-service graph, journal posting, a separately approved account/date cash-balance source contract, `tagesabschluesse` migration/immutability, existing PDF generation, and localized desktop views. The active balanced-posting and reporting-workspace proposals are prerequisites but do not by themselves provide an accepted cash-balance source; their current review verdicts are `REVISE`. Cash writes, balances, closes, and PDFs stay unavailable until each required contract is separately approved and registered.
