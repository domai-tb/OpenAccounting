## Context

Feature map §35 asks for dated business-mileage records containing purpose, distance, business context, and eventually a deductible amount used by accounting and reports. The closest maintained requirement is EKS-specific: `accounting/spec.md` says EKS B6_5 uses `journal.km_anzahl × 0.10` as a Jobcenter travel allowance (`:211-215`); `journal.km_anzahl` is `NUMERIC(12,2)` (`lib/core/db/database.dart:622`), and `EksService` applies that rate (`lib/features/accounting/eks_service.dart:160-169`). That does not establish a general business mileage policy.

The app currently has no mileage route, form, repository, or use case. The active `balanced-journal-postings-and-settlement-events` change is still `REVISE`, and no accepted mileage policy or mileage account mapping exists. This change therefore defines durable capture and the future integration boundary, but it does not enable calculation, posting, or report totals until those contracts are accepted.

The current database baseline is schema version 8. The shared portability/export inventory comprises 39 pre-existing base tables, the `feature_table_state` health table, and six feature-owned tables: `forderung_zahlungen`, both recurring occurrence tables, both mileage tables, and `category_mapping_history` (46 known application-table names). The two mileage tables are migration-required at version 9; category history is migration-required at version 10; the two occurrence tables use the shared lazy markers. The mileage migration SHALL remain disabled and neither export may claim completeness for a profile containing mileage tables until both inventory owners accept this same 46-name contract. The mileage tables are not lazy and do not use `feature_table_state`. Existing `journal.km_anzahl` values are not complete trip records and are never backfilled.

## Goals / Non-Goals

**Goals:**

- Capture and review dated business trips with purpose, positive distance, and business context.
- Persist exact trip facts, lifecycle state, policy/calculation snapshot fields, and the accounting event reference needed for later accepted integrations.
- Keep captured or unresolved records out of accounting and report totals.
- Preserve posted source facts and define traceable replacement and undo requests.
- Follow page → use case → repository → data source and `DESIGN.md` accounting workspace conventions.

**Non-Goals:**

- Choose or encode a statutory rate, deductible share, eligibility rule, cap, or rounding rule without an accepted policy.
- Treat the EKS B6_5 allowance as a general income-tax deduction.
- Implement a journal writer, account mapping, VAT treatment, settlement-date rule, or report-period rule in this change.
- Infer purpose, business share, or vehicle ownership from distance or free text.
- Backfill trip records from legacy `journal.km_anzahl` values.

## Decisions

### Persist trip facts independently

Create `mileage_trips` with a stable UUID, ISO trip date, non-empty purpose and business context, distance stored as integer hundredths of a kilometer, explicit lifecycle state, and nullable calculation/posting snapshots. The distance range is 1 through 999,999,999,999 hundredths (0.01 through 9,999,999,999.99 km), matching the existing `NUMERIC(12,2)` precision without storing binary floating-point distance. Store calculated amount as `NUMERIC(12,2)` only together with the policy ID, source, version, effective dates, and calculation timestamp. Store the opaque posting event ID returned by the accepted accounting boundary; keep it nullable and unique.

Captured records begin as `unresolved`. The current change does not calculate or post them. Never write a captured distance to `journal.km_anzahl`; that column remains the distinct EKS input. Do not synthesize trip purpose or business context from legacy journal rows.

Alternative considered: write directly to `journal.km_anzahl` on save. Rejected because capture alone does not prove a deductible amount and the journal cannot preserve the required trip facts.

### Add a versioned, additive database migration

After both portability/export owner deltas accept the 46-name inventory, coordinate creation of both mileage tables with the shared inventory/marker migration in the next sequential schema migration (version 9 on the current baseline); do not create competing migrations that increment the version twice. Include both tables in fresh schema creation. If another accepted migration lands first, merge the DDL into the next sequential version before implementation. Before any repair that could recreate `forderung_zahlungen`, check its presence against `PRAGMA user_version` and stop if it is missing at or beyond its required version. In the same migration, seed `feature_table_state` for the two lazy occurrence tables: existing valid tables become `initialized`, and absent tables become `unknown`. Back up the profile before upgrading; create tables and indexes in the migration transaction; verify the complete inventory for the profile's migration version before incrementing `PRAGMA user_version`. Any DDL or verification failure rolls back the transaction and leaves the prior version and data intact. Preserve every existing table and row. Do not add a destructive downgrade; an older binary must reject the newer profile rather than drop mileage records.

`mileage_trip_corrections` records `replace` or `void`, the original trip, optional replacement trip, non-empty reason, lifecycle, and the accepted accounting correction event ID. A partial unique index permits at most one draft or applied correction per trip. A later correction targets the replacement trip, producing an auditable chain. Foreign keys use `ON DELETE RESTRICT`.

### Keep monetary and accounting effects fail-closed

Until a separately accepted policy defines source/version, effective dates, eligibility, calculation basis, and rounding, captured trips remain unresolved with all calculation fields null. A policy snapshot may be stored only after such a policy is approved and implemented.

Posting is unavailable until an accepted accounting contract supplies a posting command, a valid mileage category/account and tax mapping, canonical report inclusion, and a stable idempotency boundary keyed by source type `mileage_trip` and the trip UUID. A retry for the same trip must return the existing accounting event and cannot create another. This proposal does not choose journal legs, VAT, booking date, or report timing.

Alternative considered: add a mileage-specific journal writer. Rejected because it would bypass the shared posting contract, which is under review.

### Preserve posted facts; correct through linked accounting operations

Facts on a posted trip are immutable. A `replace` correction records a new trip with corrected facts and links it to the posted source; a `void` correction has no replacement. Creating or editing a correction draft does not change the source trip, posting, or totals. Applying a correction is unavailable until the accepted accounting correction operation can reverse the original posting and, for `replace`, post the replacement under one idempotent correction identity. The accepted operation controls correction date and report-period treatment. On success, the original trip becomes `corrected` or `voided`, the correction row becomes `applied`, and the replacement becomes `posted`; the source facts and original posting remain intact. On failure, no trip or accounting state changes and the draft remains retryable. Never directly update or delete a finalized journal row.

### Build a focused, accessible workspace

Provide a `Neue Fahrt` primary action and a searchable, filterable trip table with date, purpose, distance, amount/state, and posting state. Use localized labels and validation, keyboard-operable controls, visible focus, and text labels for unresolved states. Align distance and money values to the right. Link the workspace from `Auswertungen` and keep trip editing out of the dashboard. This follows `DESIGN.md` page-header and table guidance (`:232-264`, `:572-625`) and accessibility guidance (`:2013-2021`).

Alternative considered: embed trip fields in the generic report table. Rejected because capture needs a validated form and explicit unresolved state.

## Risks / Trade-offs

- **[Risk]** Trips can be captured before policy questions are resolved. → **Mitigation:** show `Unresolved`, keep calculation values null, and exclude trips from every monetary total.
- **[Risk]** EKS and general tax mileage can be confused. → **Mitigation:** retain separate labels and sources; never reuse the EKS rate.
- **[Risk]** Posting and correction contracts may change. → **Mitigation:** keep their UI actions unavailable until accepted interfaces exist; preserve opaque source references and immutable trip facts.
- **[Risk]** Historical `km_anzahl` values may be mistaken for complete trip records. → **Mitigation:** do not backfill them.

## Migration Plan

1. Keep the mileage migration disabled until both portability/export owner deltas accept all 46 known names and their version-aware presence rules. Then coordinate `mileage_trips` and `mileage_trip_corrections` with the shared version-9 inventory/marker migration on the current version-8 baseline. Preserve existing data, apply the `forderung_zahlungen` pre-repair health check, seed lazy-table markers as `initialized` or `unknown`, and create no synthetic trips.
2. Add capture and review through the application service boundary. New rows remain unresolved with null policy, amount, and posting fields.
3. Keep calculation and posting controls unavailable until a separate accepted policy and the required mapping/posting/report contracts are implemented.
4. Keep correction execution unavailable until an accepted accounting correction operation provides idempotent reversal/replacement and report-date behavior. Correction drafts have no financial effect.
5. On migration failure, roll back DDL and retain the pre-migration backup. Do not drop either mileage table on downgrade; older binaries reject the newer schema version.

## Open Questions

- Which reviewed source, effective version, trip types, eligibility rules, rate/cap, and rounding rule define the general mileage policy?
- Which structured business facts are required to determine eligibility and deductible share?
- Which mileage category/account mapping and VAT treatment apply? Posting stays unavailable until accepted.
- Which accounting date and report-period rule governs posting and correction? The accepted accounting contract must decide this.
- Should eligible mileage records feed EKS B6_5? If so, what explicit eligibility link applies without treating €0.10/km as a general deduction?
