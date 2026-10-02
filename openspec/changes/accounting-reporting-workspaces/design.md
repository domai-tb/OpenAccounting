## Context

The `/reports` and `/taxes` routes currently render generic database record pages. EÜR, UStVA, EKS, and DATEV calculation classes exist but are not composed into the production route/service graph; GuV and ZM are specified but have no production calculator. `DatevService` builds a semicolon-separated CSV and can write to a selected path, but it currently uses fallback account numbers and omits partner/tax fields in its rows. `docs/02-buchhaltung.md` describes DATEV as fixed-width ASCII, while the current DATEV Developer Portal specifies a structured CSV header and booking records.

Financial period metrics must consume the balanced posting/settlement model from `balanced-journal-postings-and-settlement-events`. This change owns the shared typed reporting result, service wiring, report workspaces, and truthful preview/export statuses; it does not implement another accounting ledger.

## Goals / Non-Goals

**Goals:**

- Replace raw `/reports` and `/taxes` pages with typed, localized reporting workflows.
- Expose EÜR, UStVA, EKS, GuV, ZM, DATEV, and report-export status using maintained OpenSpec accounting rules.
- Provide an `AccountingPeriodSummary` that can be reused by the dashboard.
- Preserve customer scoping, selected period, incomplete-input warnings, and exported artifact integrity.
- Emit DATEV EXTF CSV with current supported header/row layout and validated source fields.
- Distinguish estimates, local calculations, reviewed results, and confirmed external submissions.

**Non-Goals:**

- Revisit the business/legal calculations already owned by the accounting and tax specs without a separate tax-domain review.
- Implement ELSTER submission or claim that a generated local file is filed.
- Create dashboard-specific totals, new account-plan defaults, or alternate posting/settlement data.
- Migrate historical journal records as part of route wiring.

## Decisions

1. **Use report use cases and typed result objects.** Pages call the production app-service/provider boundary and receive report-specific immutable entities. Keep SQL in repositories and calculation rules in accounting services. `AccountingPeriodSummary` is created from the same period result used to render EÜR and tax summaries. Alternatives: pages query Drift directly or widgets calculate totals; rejected because they repeat query/accounting rules and would make dashboard/report values disagree.
2. **Make route state explicit.** Report kind, fiscal year, month/quarter, customer scope, and selected export period are represented in typed page state/query parameters. Missing or invalid filters display a localized validation/configuration state. No page open or preview writes a journal entry.
3. **Keep the reporting result authoritative.** Income, expense, and profit come from the accepted posting/settlement and EÜR rules; margin uses `profit / income * 100` for positive income and is unavailable otherwise. Monthly and category series are projections from the same report result, not independent SQL. VAT estimates use the corresponding UStVA result and retain its completeness/status evidence.
4. **Implement only missing calculator owners.** Add GuV and ZM services in the accounting feature, matching the current accounting spec scenarios; wire existing EÜR/UStVA/EKS/DATEV services instead of creating parallel calculators. EKS callers must provide either a customer ID or explicit all-customer scope.
5. **Treat export as a file artifact.** Use the existing safe-path, write, validation, integrity, and history contracts. The UI reports success only after the file is written and reopened/validated. A saved file remains `Berechnet` (or `Geprüft` only after the specified check), never `Übermittelt` without external confirmation.
6. **Follow the DATEV external contract.** Generate the currently supported official DATEV EXTF Buchungsstapel CSV with format-versioned header, field order, and booking fields from source accounting records ([DATEV header](https://developer.datev.de/de/file-format/details/datev-format/format-description/header), [booking-batch fields](https://developer.datev.de/de/file-format/details/datev-format/format-description/booking-batch)). Do not use fabricated fallback account numbers; fail with source ID/field when required mappings are absent. Keep a version-specific sample fixture and validation notes. The app provides a local file, not a DATEV cloud integration.
7. **Reuse the design-system reporting patterns.** The tax overview leads with estimated amount, period, status, due date, completeness, and next action. Report tables use typed labels and exact amounts; charts supplement numbers, not replace them. All content, errors, accessibility names, and formats use the active locale and preserve keyboard navigation.

## Risks / Trade-offs

- [Balanced posting and settlement work may not be delivered first] → Keep period results explicitly incomplete and block financial summaries until the accepted source exists; do not fall back to invoice dates or imported transactions.
- [Existing tax specifications may require future domain review] → Record the spec version/rule source on each generated result and keep the UI state provisional until reviewed.
- [DATEV versions can evolve] → Pin the emitted version in code, include a matching sample fixture, and update it only with a reviewed spec/version change.
- [Missing company/account configuration can make reports unavailable] → Show required fields with direct Settings links; do not insert default account IDs or imply success.
- [PDF/report output may fail after a preview succeeds] → Treat preview and export as separate states; create history only after file validation.

## Migration Plan

No schema migration is needed for service composition or route replacement. First complete `balanced-journal-postings-and-settlement-events` and ensure tax/report requirements remain accepted; then wire report services into `AppServices` and the production pages. Keep report type/period in route state. Implement GuV/ZM calculation services against the existing base specs. Replace the current DATEV field synthesis with the pinned supported EXTF CSV format and validate its fixture before exposing export. Export history uses the existing artifact metadata contract. Rollback can restore the generic route builders without changing ledger data or existing report files.

## Open Questions

- Confirm against a tax-domain reviewer that the current GuV/ZM/EKS accounting requirements are still the intended calculation contracts before implementation; if not, revise their OpenSpec requirements first.
- Which exact existing export-history/artifact service will own all report types? Reuse one if it already satisfies the current safe-write and integrity requirements; add no new abstraction when the existing service covers them.
