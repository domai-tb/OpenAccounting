## Context

Feature-map item 54 requests accounting-derived supporting reports for Anlage S and Anlage G. The maintained accounting specs and runtime do not define their official form-year fields, formulas, classification evidence, period, or accepted source. EÜR/EKS totals are not interchangeable with S/G field values. A numeric report cannot be specified safely until those contracts exist.

## Goals / Non-Goals

**Goals:**

- Let a user select Anlage S or Anlage G and see a truthful availability state.
- Preserve that selection in the `/taxes` route and give a localized explanation of the missing contracts.
- Establish a typed seam that a future accepted S/G report capability can replace with numeric results.

**Non-Goals:**

- Produce S/G field values, calculations, a source-coverage count, export, or filing output.
- Decide whether a business belongs to Anlage S, Anlage G, both, or neither.
- Reuse EÜR/EKS/GuV totals without an accepted line mapping.
- Select a tax year or reporting period before a form-year and period contract is accepted.

## Decisions

1. **Expose an availability-only route state.** Add `view=income-tax-schedules` and `schedule=s|g` to the existing `/taxes` route. A missing or invalid schedule returns a localized selection/unavailable state. The route uses `IncomeTaxScheduleAvailabilityUseCase.check(schedule)` and preserves unrelated tax-route query parameters.
2. **Do not expose period or form fields.** No supported S/G form-year or period contract is accepted in this change. The view therefore has no year/period picker, official form-field rows, numeric values, source IDs, completeness count, export, or filing action.
3. **Return explicit blocker reasons without querying accounting data.** The typed availability result identifies `formContractUnavailable`, `periodContractUnavailable`, `classificationContractUnavailable`, and `accountingSourceContractUnavailable`. The use case does not scan journal, EÜR, EKS, invoices, or bank rows to estimate values.
4. **Require explicit schedule choice.** The user selects Anlage S or Anlage G. The application does not infer schedule or legal eligibility from company name, occupation, tax number, transaction description, or account category.
5. **Keep this seam read-only and replaceable.** The availability state writes no accounting records and is not a report artifact. A later proposal may add field values only after it defines official form-year fields, formulas, classification evidence, tax period, accepted accounting sources, and completeness/unresolved-record rules, then receives independent approval.
6. **Follow desktop design.** Use the shared `/taxes` shell, localized explanation, visible keyboard focus, semantic status announcements, active-locale formatting for dates if shown, and narrow-window/text-scaling behavior. Status does not rely on color.

## Risks / Trade-offs

- [Risk] An unavailable state could be mistaken for a completed S/G report. → **Mitigation:** title it as report availability, state that no report values are produced, and expose no form rows or export action.
- [Risk] Users expect EÜR totals to appear as S/G fields. → **Mitigation:** do not query or copy EÜR/EKS totals and explain that field mapping is not accepted.
- [Risk] A future form-year contract is confused with this shell. → **Mitigation:** keep numeric output behind a separate accepted capability delta and source/form fixture.

## Migration Plan

No database migration is required. Add the typed route/query parser, availability use case, and localized status content. On missing prerequisites, render the unavailable state without reading accounting tables. Rollback hides the route view and preserves all existing records.

## Open Questions

These questions block a future numeric S/G report, not this availability-only change:

- Which official tax-year form schema and field inventory will be supported?
- Which accepted evidence and reviewer establish S/G classification?
- Which approved posting/source mapping and completeness rules supply each line?
- Which tax period applies to each supported schedule and fiscal-year configuration?
