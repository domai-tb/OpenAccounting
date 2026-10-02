## Context

The dashboard currently stores widget visibility/order and performs several raw SQL reads in `DashboardRepository`. Some reads are unbounded by a selected period, count cancelled invoices, treat positive imported bank rows as receipts, and synthesize a VAT filing date. The base dashboard spec and `docs/07-dashboard.md` also disagree about widget contents. `DESIGN.md` §11 calls for period controls, accounting KPIs, explicit estimates, and links to source records.

Income/expense figures and monthly/category series must consume a typed `AccountingPeriodSummary` from the `accounting-reporting-workspaces` capability, established after `balanced-journal-postings-and-settlement-events`. Tax reserve/deadline data must consume that workspace's UStVA and tax-calendar results. The dashboard must not create a second ledger calculation. Open balances use a point-in-time snapshot from receivable/payable event history established by `receivables-ledger-integrity` and settlement allocations.

## Goals / Non-Goals

**Goals:**

- Provide month-, quarter-, and year-scoped headline metrics, prior-year comparisons, and useful trend views through a shared typed reporting result.
- Use the approved reporting basis, confirmed payment records, non-cancelled issued invoices, and configured tax calendar.
- Surface actionable work and link metrics to filtered records.
- Localize all dashboard states and keep custom quick links safe and manageable.
- Align `docs/07-dashboard.md`, the base dashboard spec, and feature-map sections 62–63.

**Non-Goals:**

- Define ledger posting, tax liability, fiscal-year policy, or payment reconciliation semantics; consume the corresponding approved accounting capabilities.
- Add dashboard-specific accounting calculations or introduce a charting dependency.
- Add multi-user dashboard configuration or dashboard layout sizes beyond the existing grid/config contract.

## Decisions

1. **Keep presentation separate from accounting calculations.** Dashboard widgets request a typed `AccountingPeriodSummary` and attention items through Riverpod providers. The future `accounting-reporting-workspaces` change owns the summary contract and calculations; this dashboard change consumes it after balanced postings and settlements are available. Alternatives considered: expanding ad hoc SQL in `DashboardRepository` or calculating totals in widgets. Both duplicate accounting rules and are rejected.
2. **Make the period explicit.** Default to the active company fiscal year and allow the periods supported by the reporting workspace. A missing fiscal calendar or invalid range produces an explicit localized unavailable/validation state. Alternative: silently use calendar-year/all-time data; rejected because it makes unlike periods look comparable.
3. **Define metric formulas.** Take profit from the selected EÜR reporting result, including its expense and depreciation treatment; define margin as `profit / income * 100` when income is positive. Compute change as `(current - prior) / abs(prior) * 100`; when the prior amount is zero, show absolute values and "not comparable". Alternatives: independent widget formulas or prior signed denominators; rejected because of drift and misleading loss-period percentages.
4. **Compute historical balances from events.** Include invoices issued on/before the selected end date and subtract payments, write-offs, and corrections effective on/before that date. Exclude later-issued invoices and include invoices paid later at the balance they had on the selected date. Current status alone is insufficient.
5. **Use authoritative records for operational metrics.** Exclude drafts/cancelled/paid invoices from open totals; include receipts only after the accounting/payment workflow confirms them; show unmatched transactions as work. Obtain filing deadlines and VAT reserve estimates only from configured tax-period/UStVA results. Alternative: keep simple table counts or a fixed filing day; rejected because current values can misstate obligations.
6. **Keep configuration local and validated.** Reuse the existing dashboard JSON for widget order, visibility, and quick links. Validate quick-link routes against the app router's allowed destinations before saving. No schema migration is needed for the existing fields; new period selection is session state until product asks for persistence.
7. **Follow the dashboard design contract.** Put the period control and headline values first; label estimates; make every KPI operable with keyboard and screen readers; use trend visuals only alongside exact values and accessible text summaries; use existing design-system surfaces and locale formatters.

## Risks / Trade-offs

- [Canonical reporting/payment capabilities may land later] → Sequence after `balanced-journal-postings-and-settlement-events`, `accounting-reporting-workspaces`, and payment-allocation implementation; do not enable dependent cards until the typed source exists.
- [Historical open balances need event dates] → Use issue, settlement, write-off, and correction history; never infer prior state from current status.
- [A large comparison range can make dashboard reads slow] → Request only visible-widget data for one period and its comparison range, reusing indexed report queries.
- [Legacy quick-link JSON may contain unsupported paths] → Filter it through the same route allowlist at load time and show a removable invalid-link state without navigating to it.
- [Users can mistake tax estimates for filed liabilities] → Label the source and estimate status in both visible text and accessibility semantics.

## Migration Plan

No database migration is required. Preserve and parse existing dashboard JSON, merge new widget defaults, and tolerate older configurations. Implement `balanced-journal-postings-and-settlement-events` and `accounting-reporting-workspaces` first, plus the open-item history required for as-of balances. Then add the new cards against those sources and replace legacy unbounded values. Rollback can hide new cards and retain the existing JSON; no persisted accounting data changes.

## Open Questions

- `accounting-reporting-workspaces` must define `AccountingPeriodSummary`, recognized-income/expense basis, depreciation treatment, and UStVA results before implementation. `balanced-journal-postings-and-settlement-events` plus settlement applications must provide source dates. No dashboard-specific SQL/calculation is an acceptable fallback.
- `receivables-ledger-integrity` must provide issue, settlement, write-off, and correction event dates for as-of balances; test invoices paid after and issued after the selected end date.
- The deadline provider depends on company filing cadence and period settings from setup/settings. If absent, show the specified configuration state.
