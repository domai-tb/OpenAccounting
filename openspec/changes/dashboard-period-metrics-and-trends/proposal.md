## Why

The dashboard shows several values with incorrect or incomplete accounting meaning: cancelled invoices remain in open and overdue totals, payment activity is taken from positive bank transactions rather than posted receipts, and income/expense totals have no selected period. It also lacks period-based profit, margin, and trend views specified in `DESIGN.md` §11 and the feature-map sections 62–63 (attachment lines 1103–1131).

## What Changes

- Add annual calendar-year selection and period-scoped income, expense, profit, margin, open-balance, and year-over-year metrics from the canonical `AccountingPeriodSummary` (supported calendar years only, 2025 form first) and open-item event history sources. Month/quarter summaries remain unavailable until the reporting workspace accepts them.
- Correct invoice, payment, and deadline widgets to use their documented business records and exclude cancelled documents; label estimates and unavailable data clearly.
- Add monthly income/expense and profit trends, expense/VAT distribution, and actionable attention items for overdue invoices, unmatched transactions, and tax deadlines.
- Complete quick-link editing and localize dashboard labels, values, accessibility names, and empty/error states.
- Update dashboard documentation and acceptance scenarios so they match the supported metrics and calculations.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dashboard`: define period-aware business KPIs, trend comparisons, actionable attention items, correct source records, quick-link editing, localization, and explicit estimate/error states.

## Impact

Dashboard query/use-case boundaries and widgets, persisted dashboard configuration, localization catalogs, `docs/07-dashboard.md`, and `openspec/specs/dashboard/spec.md`. The `balanced-journal-postings-and-settlement-events` and `invoice-money-contract` sources are approved and archived; this change consumes their settlement groups/allocation rows (booking/value or manual date, verbatim) and integer-cent remainder rule. Financial summaries remain gated on acceptance of `accounting-reporting-workspaces` (annual `AccountingPeriodSummary`, 2025 EÜR form mapping). As-of balances with write-offs/corrections lacking an effective date remain gated on a write-off/correction effective-date contract (the `ausbuchen` relation currently has no accepted effective-date field).
