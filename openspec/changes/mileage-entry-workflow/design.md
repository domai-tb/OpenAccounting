## Context

The feature map's §35 asks for a dated business-mileage record with purpose, distance, and business context, followed by a deductible amount that reaches accounting and relevant reports. No maintained or active OpenSpec change defines that entry workflow. The closest maintained requirement is EKS-specific: `accounting/spec.md` says EKS B6_5 uses `journal.km_anzahl × 0.10` as a Jobcenter travel allowance (`:211-215`); the database has `journal.km_anzahl NUMERIC(12,2)` (`lib/core/db/database.dart:622`), and `EksService` applies that rate (`lib/features/accounting/eks_service.dart:160-169`). It does not establish a general business tax deduction rate or eligibility policy.

The app currently has no mileage route, form, repository, or use case. The accounting posting boundary is also unresolved: `balanced-journal-postings-and-settlement-events` remains active and its review is `REVISE`. This design therefore separates captured trip facts from calculated and posted amounts. It blocks monetary calculation/posting until a reviewed policy and an accepted posting contract define those outcomes.

No active change currently covers mileage capture. `accounting-reporting-workspaces` covers report workspaces and EKS but not trip entry; the active balanced-posting change covers ledger semantics, not mileage records.

## Goals / Non-Goals

**Goals:**

- Capture and review dated business trips with purpose, distance, and business context.
- Preserve a durable source record that can later link to a policy result and one accounting posting.
- Calculate only from an approved policy effective for the trip; keep unresolved records out of ledger and report totals.
- Keep the existing EKS allowance separate from a general deductible amount.
- Follow the page → use case → repository → data source structure and the accounting workspace conventions in `DESIGN.md`.

**Non-Goals:**

- Choose or encode a statutory rate, deductible share, eligibility rule, cap, or rounding rule without an approved source.
- Treat the EKS B6_5 Jobcenter allowance as a general income-tax deduction.
- Resolve debit/credit, VAT, settlement-date, account-mapping, or reporting-period rules owned by the accounting/posting contracts.
- Infer trip purpose, business share, or vehicle ownership from distance or free text.
- Backfill complete mileage trips from existing `journal.km_anzahl` values; those values lack the trip facts this workflow requires.

## Decisions

### Keep trip facts separate from journal postings

Persist mileage as a first-class source record containing its stable ID, date, purpose, distance, business context, and workflow state. Store a calculated amount and its approved policy reference only after a matching policy is available. A later posting references the trip ID and carries the distance needed by any report contract that explicitly consumes it.

Alternative considered: write directly to `journal.km_anzahl` on save. Rejected because mileage capture is not itself proof of an approved deductible amount, the journal lacks the trip purpose/context, and writing there before policy validation would leak unresolved data into reports. Keep the existing EKS rule as a separate report-specific calculation.

### Fail closed on policy and mapping gaps

The calculation boundary requires a reviewed policy with source/version, effective dates, eligibility conditions, calculation basis, and rounding. No default rate is inferred. When the policy or required business facts are missing, save the trip as unresolved, show the missing decision, and do not create a monetary amount or accounting side effect. The EKS B6_5 value of €0.10/km remains limited to the existing EKS requirement.

Alternative considered: use EKS's €0.10/km for all mileage. Rejected because the maintained requirement labels it a Jobcenter travel allowance and does not establish its use as the general deductible rate.

### Post only through the approved accounting boundary

The UI calls a mileage use case; the use case validates state and policy eligibility; the repository coordinates the mileage record and accounting command; the data source persists source facts. A confirmed posting goes through the accepted accounting posting boundary, stores the unique source-mileage link, and is visible in reports only through that canonical posting. The operation must be idempotent. Until the balanced-posting contract and the policy/mapping decisions are accepted, posting stays unavailable; this change does not invent journal legs or write a journal row directly.

Alternative considered: add a mileage-specific journal writer. Rejected because it would create another financial writer while the shared posting model is under review and would duplicate accounting rules.

### Build a focused mileage workspace

Provide a `Neue Fahrt` primary action and a searchable, filterable trip table with date, purpose, distance, calculated amount/state, and posting status. Keep unresolved policy state visible in text, not color alone. Use right-aligned distance and money columns, keyboard access, and visible focus. Link the workspace from `Auswertungen`; keep the dashboard free of trip-editing controls. This follows `DESIGN.md` page-header and table guidance (`:232-264`, `:572-625`) and accessibility guidance (`:2013-2021`).

Alternative considered: embed mileage fields in the generic report table. Rejected because trip capture and review need a validated form and explicit unresolved/posting actions, not a raw database surface.

## Risks / Trade-offs

- **[Risk]** A trip can be recorded before policy questions are resolved, but no deduction is shown. → **Mitigation:** show an explicit unresolved state and exclude it from every accounting total until approval.
- **[Risk]** Existing EKS and general tax mileage could be confused. → **Mitigation:** keep separate calculation labels, sources, and report paths; never reuse the EKS rate for the general amount.
- **[Risk]** The posting and reporting contracts may change. → **Mitigation:** store trip facts independently and add integrations only through accepted interfaces; retain source IDs for traceability.
- **[Risk]** Historical `km_anzahl` rows may be mistaken for complete trip records. → **Mitigation:** do not backfill missing purpose/context or claim those rows were entered through this workflow.

## Migration Plan

1. Resolve the policy, accounting-mapping, accounting-date, and EKS-link questions below; independently approve the shared posting contract before enabling monetary postings.
2. Add an additive mileage-record table and repository methods. Preserve existing journal rows and IDs. Do not infer trip records from legacy distance fields.
3. Add the localized route and form through the application service boundary. Allow trip capture while policy is unresolved; keep calculation and posting actions disabled until all gates pass.
4. Add policy calculation and source-linked posting through approved contracts, then expose the resulting canonical report data.
5. On downgrade/rollback, preserve captured mileage records or restore the pre-migration profile backup; never delete posted accounting history or silently detach source links.

## Open Questions

- Which reviewed source, effective version, and date range define the general mileage policy? Which trip types, vehicle ownership/use, business share, rate/cap, and rounding rules apply?
- Which business facts must be collected to determine eligibility and the deductible portion? Is free-text context sufficient, or are structured trip/vehicle fields required?
- What category and account mapping should a resolved mileage expense use, and what VAT treatment applies? Until answered, posting must fail closed.
- Which accounting date and period rule governs the expense and any correction? The trip date is captured, but the accounting contract must decide report recognition.
- Should mileage records feed the separate EKS B6_5 calculation? If so, what explicit eligibility/link field connects a trip to the maintained `journal.km_anzahl` requirement without treating €0.10/km as a general tax deduction?
- What approved posting source identity and uniqueness boundary will the balanced-journal change expose for idempotent mileage posting?
