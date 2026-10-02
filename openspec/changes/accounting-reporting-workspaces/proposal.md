## Why

Accounting helpers and reporting specifications exist, but `/reports` and `/taxes` still render generic database records, so users cannot generate the documented EÜR, UStVA, EKS, GuV, ZM, or DATEV workflows. A shared typed reporting boundary is also needed so the dashboard can show period metrics without duplicate calculations.

## What Changes

- Replace generic report/tax routes with localized report workspaces for EÜR, UStVA, EKS, GuV, ZM, DATEV, and export history, using each maintained accounting specification.
- Compose existing report services through the app-service boundary; implement missing GuV/ZM calculations against their existing specs and the accepted balanced-posting/settlement source.
- Provide fiscal-period/customer selection, completeness warnings, preview, status, and safe user-selected export/reopen flows; never imply that a local report was submitted.
- Define a typed `AccountingPeriodSummary` for income, expense, profit, margin, monthly trends, distributions, and tax figures; make the dashboard consume it.
- Correct DATEV documentation and output to the current official DATEV EXTF CSV contract, including its required header and booking fields, partner/account/tax information, and validation.
- Keep GoBD, customer scoping, export metadata, file safety, and input-tax timing aligned with existing OpenSpec requirements.

## Capabilities

### New Capabilities

- `accounting-reporting-workspaces`: User-facing, period-based reporting and tax workspaces backed by typed report results and truthful artifact status.

### Modified Capabilities

None. The new workspace consumes the existing accounting/tax calculation and export contracts; the separate dashboard change consumes the period-summary contract introduced here.

## Impact

Report and tax routes, app-service/provider composition, EÜR/UStVA/EKS/DATEV services, new GuV/ZM report services, export artifact handling/history, `docs/02-buchhaltung.md`, and the dashboard data provider. Implementation depends on `balanced-journal-postings-and-settlement-events` and the maintained tax/reporting contracts. DATEV EXTF is a CSV format with a defined header and field layout, not a fixed-width text file ([DATEV header specification](https://developer.datev.de/de/file-format/details/datev-format/format-description/header), [booking-batch specification](https://developer.datev.de/de/file-format/details/datev-format/format-description/booking-batch)).
