## Context

The dashboard currently stores widget visibility/order and performs several raw SQL reads in `DashboardRepository`. Some reads are unbounded by a selected period, count cancelled invoices, treat positive imported bank rows as receipts, and synthesize a VAT filing date. The base dashboard spec and `docs/07-dashboard.md` also disagree about widget contents. `DESIGN.md` §11 calls for period controls, accounting KPIs, explicit estimates, and links to source records.

Income/expense figures and monthly series must consume the annual typed `AccountingPeriodSummary` from the `accounting-reporting-workspaces` capability (supported calendar years only; month/quarter summaries are not offered by that contract). Tax reserve/deadline data must consume that workspace's UStVA and tax-calendar results. The dashboard must not create a second ledger calculation. Open balances use a point-in-time snapshot derived from accepted event history: receivables from the `receivables-ledger-integrity` statement (signed invoice/correction entries plus dated payments, opening partitioned) combined with approved balanced settlement allocations and keyed `zahlung` effective dates; payables symmetrically from `einkommen` `rechnung_eingang` Forderungen plus approved balanced supplier allocations (negative bank row to payable). Write-off/correction events without an accepted effective date, and periods mixing `legacy_unverified` rows, yield an incomplete-history unavailable state, never a silent total.

## Goals / Non-Goals

**Goals:**

- Provide annual calendar-year headline metrics, prior-year comparisons, and monthly trend views through the shared annual reporting result. Month/quarter summary modes are unavailable until the reporting workspace accepts them.
- Use the approved annual reporting basis, confirmed settlement records, non-cancelled issued invoices, and configured tax calendar.
- Surface actionable work and link metrics to filtered records.
- Localize all dashboard states and keep custom quick links safe and manageable.
- Align `docs/07-dashboard.md`, the base dashboard spec, and feature-map sections 62–63.

**Non-Goals:**

- Define ledger posting, tax liability, fiscal-year policy, or payment reconciliation semantics; consume the corresponding approved accounting capabilities.
- Add dashboard-specific accounting calculations or introduce a charting dependency.
- Add multi-user dashboard configuration or dashboard layout sizes beyond the existing grid/config contract.

## Decisions

1. **Keep presentation separate from accounting calculations.** Dashboard widgets request the annual typed `AccountingPeriodSummary` and attention items through Riverpod providers composed from the dashboard use case/application service (never a page-constructed repository/executor, per `runtime-composition-and-database-lifecycle`). The `accounting-reporting-workspaces` change owns the summary contract and calculations; this dashboard change consumes its accepted annual result (balanced settlement sources and the invoice-money remainder rule are already approved and archived). Alternatives considered: expanding ad hoc SQL in `DashboardRepository` or calculating totals in widgets. Both duplicate accounting rules and are rejected.
2. **Make the period explicit.** Default to the selected supported calendar year (`YYYY-01-01` through next `YYYY-01-01`) from the annual summary; month/quarter requests render the reporting workspace's localized unavailable state. A missing fiscal calendar or invalid range produces an explicit localized unavailable/validation state. Alternative: silently use calendar-year/all-time data; rejected because it makes unlike periods look comparable.
3. **Define metric formulas.** Take profit from the selected EÜR reporting result, including its expense and depreciation treatment; define margin as `profit / income * 100` when income is positive. Compute change as `(current - prior) / abs(prior) * 100`; when the prior amount is zero, show absolute values and "not comparable". Alternatives: independent widget formulas or prior signed denominators; rejected because of drift and misleading loss-period percentages.
4. **Compute historical balances from accepted events.** Include invoices issued on/before the selected year end and subtract settlement allocations effective on/before that date using the authoritative settlement date (bank booking/value date, manual cash date, verbatim; confirmation date never substituted). Receivables combine the `receivables-ledger-integrity` statement with approved settlement allocation rows and keyed `zahlung` effective dates; payables combine `einkommen` `rechnung_eingang` open items with approved supplier settlement allocations. Exclude later-issued invoices and include invoices paid later at the balance they had on the selected date. Events without an accepted effective date (write-off `ausbuchen` relation, undated corrections) and periods mixing `legacy_unverified` rows produce an incomplete-history unavailable state. Current status alone is insufficient.
5. **Use authoritative records for operational metrics.** Exclude drafts/cancelled/paid invoices from open totals; include receipts only after the accounting/payment workflow confirms them; show unmatched transactions as work. Obtain filing deadlines and VAT reserve estimates only from configured tax-period/UStVA results. Alternative: keep simple table counts or a fixed filing day; rejected because current values can misstate obligations.
6. **Keep configuration local and validated.** Reuse the existing dashboard JSON for widget order, visibility, and quick links. Validate quick-link routes against the app router's allowed destinations before saving. No schema migration is needed for the existing fields; new period selection is session state until product asks for persistence.
7. **Follow the dashboard design contract.** Put the period control and headline values first; label estimates; make every KPI operable with keyboard and screen readers; use trend visuals only alongside exact values and accessible text summaries; use existing design-system surfaces and locale formatters.

## Risks / Trade-offs

- [Canonical reporting/payment capabilities may land later] → Sequence after acceptance of `accounting-reporting-workspaces` (annual summary, 2025 EÜR form); balanced-posting/settlement and invoice-money sources are already approved and archived. Do not enable dependent cards until the typed annual source exists; month/quarter cards stay unavailable until that workspace accepts them.
- [Historical open balances need event dates] → Use issue, authoritative settlement (booking/value or manual, verbatim), and signed correction history; write-offs/corrections without an accepted effective date and any `legacy_unverified` mix yield incomplete-history unavailable, never inferred prior state from current status.
- [A large comparison range can make dashboard reads slow] → Request only visible-widget data for one period and its comparison range, reusing indexed report queries.
- [Legacy quick-link JSON may contain unsupported paths] → Filter it through the same route allowlist at load time and show a removable invalid-link state without navigating to it.
- [Users can mistake tax estimates for filed liabilities] → Label the source and estimate status in both visible text and accessibility semantics.

## Migration Plan

No database migration is required. Preserve and parse existing dashboard JSON, merge new widget defaults, and tolerate older configurations. The balanced-posting/settlement and invoice-money sources are approved and archived. Accept `accounting-reporting-workspaces` (annual summary, 2025 EÜR form mapping) plus a write-off/correction effective-date contract for as-of balances covering write-offs before enabling those cards. Then add the new cards against those sources and replace legacy unbounded values. Rollback can hide new cards and retain the existing JSON; no persisted accounting data changes.

## Open Questions

- `accounting-reporting-workspaces` must be accepted for the annual `AccountingPeriodSummary` (supported calendar years only, 2025 EÜR form mapping first; month/quarter remain unavailable). Balanced-posting/settlement sources and the invoice-money remainder rule are already approved and archived. No dashboard-specific SQL/calculation is an acceptable fallback.
- As-of balances consume the `receivables-ledger-integrity` statement plus approved settlement allocations/keyed `zahlung` effective dates (receivables) and `einkommen` `rechnung_eingang` items plus approved supplier allocations (payables). A write-off/correction effective-date contract (effective date on the `ausbuchen` relation and correction records) is still missing; until accepted, as-of balances touching such events show incomplete-history unavailable. Test invoices paid after and issued after the selected year end, plus settlement splits, reversals in the reversal period, and legacy-row mixing.
