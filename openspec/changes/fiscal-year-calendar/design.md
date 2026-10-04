## Context

Feature-map item 58 requires a calendar-year default, optional non-calendar fiscal years, and consistent periods in relevant reports (`pasted-text-1.txt:1052-1058`). The production `unternehmen` table has no fiscal-year field, `UnternehmenRepository` has no fiscal-calendar contract, and the maintained accounting specification only mentions fiscal-period controls in its purpose. The active accounting-reporting proposal refers to a company fiscal year but its review identifies that no boundary contract exists (`accounting-reporting-workspaces/review.md:29`). Existing annual EÜR code filters by calendar year. These gaps must be resolved by a shared company setting before reports can safely offer alternate business years.

## Goals / Non-Goals

**Goals:**

- Store one company-level start month, defaulting to January.
- Return typed, deterministic fiscal-month, fiscal-quarter, and fiscal-year labels and date intervals.
- Provide one boundary service for later accepted reports that group data by company business year; this change adds no fiscal-period filters to those reports.
- Make configuration and its effect on historical report boundaries clear to the user.
- Prevent calendar-year EÜR output from being mislabeled as a configured alternate business year.

**Non-Goals:**

- Changing journal entries, invoice dates, tax calculations, or source records when the setting changes.
- Defining filing deadlines, statutory VAT periods, tax eligibility, accounting close rules, or legal treatment of a non-calendar year.
- Replacing explicit custom date ranges or month/quarter filters owned by report capabilities.
- Enabling a report whose accounting source or formula has not been independently accepted.

## Decisions

1. **Store a start month, not arbitrary day boundaries.** Persist `geschaeftsjahr_startmonat` as an integer from 1 to 12 in the company record. January (`1`) is the migration and new-company default. A month-based boundary supports the feature-map requirement without inventing a non-month-aligned fiscal calendar.
2. **Label a fiscal year by its starting calendar year.** For start month `m`, a date in month `m` or later belongs to the fiscal year beginning on the first day of that month in the date's year; an earlier date belongs to the year that began in the previous calendar year. The service returns `[startDate, endDateExclusive)`, where the end is the same month and day one year later. The interval contains calendar dates, has no time zone, and naturally handles leap years.
3. **Define all business-period boundaries centrally.** For a configured year start month, fiscal month 1 is that start month and fiscal months 1–12 are consecutive calendar months within the fiscal year. Fiscal quarters each span three consecutive fiscal months. Fiscal year labels use the starting calendar year. Each service result is a half-open calendar-date range. Explicit calendar-month and calendar-quarter filters remain separate from business-fiscal-month and business-fiscal-quarter filters.
4. **Use a single typed service.** Company configuration and all boundary calculations live behind one injected fiscal-calendar use case. Report widgets and repositories do not reproduce month arithmetic. A consumer that cannot resolve a valid configuration shows an unavailable state rather than assuming a fiscal period.
5. **Keep statutory periods with tax-report owners.** A business-year range is not automatically a VAT declaration period or another filing period. Tax-report capabilities continue using their separately defined statutory period and cadence; this change does not recalculate or shift tax outputs.
6. **Gate report consumers explicitly.** Annual EÜR is the only report consumer in scope. Until its accepted calculation consumes the service's exact half-open range, EÜR for a non-January start month is unavailable and SHALL NOT be relabeled as the configured fiscal year. Dashboard period summaries and all other reports remain unavailable for business-fiscal filters until their own source and calculation contracts are accepted and integrated.
7. **Make configuration changes explicit.** Changing the start month changes the boundaries for every fiscal month, quarter, and year selected afterward, including historical periods. The confirmation names that consequence. No journal or invoice data is rewritten, and report exports keep their own stored period snapshot. No effective-date history is added; the saved start month applies retroactively to historical selections as well as future selections.
8. **Do not imply that other consumers are integrated.** A report may offer a company business-period filter only after its source and calculation contract is accepted and it uses this service. Until then, it must show the fiscal period as unavailable and must not label a calendar-based result as a configured fiscal period.
9. **Follow the existing desktop design system.** Add the selector beside company-period settings in `/settings`, with a short explanation and explicit Save action. Use standard page/card/form tokens, visible focus, semantic labels, active-locale date formatting, German and English catalogs, and narrow-window layouts from `DESIGN.md`.

## Risks / Trade-offs

- [Risk] Changing the setting changes historical report boundaries. → Mitigation: explain this before saving and keep existing exported-period snapshots unchanged.
- [Risk] A report silently uses calendar year despite a configured alternate month or quarter. → Mitigation: route all business-period boundary requests through the shared service; show an unsupported consumer as unavailable until integrated.
- [Risk] The start-month field is missing or invalid in a legacy profile. → Mitigation: migrate to January, validate 1–12 at read and write boundaries, and return a typed failure for corruption.
- [Risk] A fiscal year is confused with a tax filing period. → Mitigation: keep filing period ownership separate and label the controls as the company's business year.

## Migration Plan

1. Add `geschaeftsjahr_startmonat INTEGER NOT NULL DEFAULT 1 CHECK (geschaeftsjahr_startmonat BETWEEN 1 AND 12)` to fresh `unternehmen` table creation. Add a separate ordered migration for existing profiles that adds the same field and backfills existing company rows to `1` without depending on fresh-install migrations.
2. Extend the typed company repository and fiscal-calendar service; do not query raw company rows from report pages.
3. Add the Settings control, confirmation, localization, and unavailable/error states.
4. Integrate only report consumers whose data source and calculations have an accepted OpenSpec contract; each consumer must show its selected boundary and must not reuse this period for unrelated tax filing.
5. Rollback may hide the control/service but must preserve the stored start month and existing accounting data. No automatic journal rewrite is permitted.

## Open Questions

- Should the UI allow the fiscal-year name to be overridden when business terminology differs from the starting calendar year? The initial version uses the starting year to keep labels deterministic.
