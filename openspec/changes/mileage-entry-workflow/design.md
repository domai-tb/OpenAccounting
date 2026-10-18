## Context

Feature map §35 asks for dated business-mileage records containing purpose, distance, business context, and eventually an amount used by accounting and reports. The existing EKS B6_5 rule uses `journal.km_anzahl × 0.10` for a Jobcenter travel allowance; that EKS-specific amount does not define the general mileage policy in this change. Legacy `journal.km_anzahl` values are not trip records and SHALL NOT be backfilled.

The mileage tables are required from schema v13. The current proposal for v23 adds structured eligibility facts and lifecycle enforcement to those existing tables. No part of this design asserts that the current runtime has v23 enforcement or the accepted posting integration.

The change's proposed table contract is 55 known application-table names at v19: 39 legacy tables plus 16 feature-managed tables, including `feature_table_state`. The active inventory dependencies disagree: `profile-data-portability` is at 46 names/v13, while `customer-data-disclosure-export` is at 55 names/v19. This mismatch remains open. Mileage migration work and complete-export claims stay blocked until both owners accept the same inventory and version-aware presence rules.

## Goals / Non-Goals

**Goals:**

- Capture dated trips with exact distance, purpose, business context, trip kind, vehicle source, and vehicle class.
- Apply one explicit, source-backed policy version to eligible private-vehicle business trips, with an auditable calculation snapshot.
- Leave unsupported or ineligible trips unresolved and outside accounting and report totals.
- Preserve posted source facts and define traceable replacement and undo requests.
- Post confirmed mileage as a mapped travel expense against private contribution, with no cash or VAT leg.

**Non-Goals:**

- Reuse the EKS allowance as a general mileage deduction or infer eligibility from distance or free text.
- Determine taxpayer-specific deductibility, VAT treatment, or tax advice from this application policy.
- Post without an accepted account mapping and an atomic, idempotent accounting command.
- Edit or delete a posted trip or its original accounting event.

## Decisions

### Capture structured policy inputs

Each trip records a structured `trip_kind`, `vehicle_source`, and `vehicle_class` alongside the human-readable purpose and context. `trip_kind` distinguishes `business_trip`, `commuting`, `eks_allowance`, `other`, and `unknown`. A `business_trip` is explicitly user-confirmed as related to work or business and excludes home-to-first-workplace/business-premises travel, other commuting, family-home travel, and EKS allowance travel. `vehicle_source` distinguishes `private`, `company`, and `unknown`; `private` means user-owned or privately available, while an employer/company-provided vehicle is `company`. `vehicle_class` distinguishes `kraftwagen` (Kraftwagen, for example a Pkw), `other_motor_vehicle` (another road motor vehicle such as a motorcycle), `unsupported`, and `unknown`. Non-motorized and public-transport trips are unsupported. Unknown and unsupported values remain valid capture facts but never qualify for calculation. The v23 additive migration initializes these fields on existing rows to `unknown`; it SHALL preserve every existing source fact, calculation snapshot, posting reference, and lifecycle state.

The form requires explicit structured selections and never infers them from prose. A trip classified as commuting, EKS, company-supplied, or otherwise unsupported may be retained for review, but it remains unresolved with a null calculation snapshot.

### Use the explicit application policy `DE-private-business-travel/1`

Policy ID: `DE-private-business-travel/1`. Policy version: `1`. It applies by trip date from 2025-01-01 through 2026-12-31 inclusive. This is a versioned application expense policy for user-confirmed private-vehicle business trips; it is not a ruling that a particular user's amount is tax-deductible. Its source/version record names the official references below:

- [Einkommensteuergesetz §9(1), sentence 3, no. 4a](https://www.gesetze-im-internet.de/estg/__9.html): for employees, qualifying work trips exclude travel between home and the first place of work and refer to the BRKG rates. The source says `beruflich veranlasste Fahrten` and excludes `Fahrten zwischen Wohnung und erster Tätigkeitsstätte`.
- [Bundesreisekostengesetz §5(1)–(2)](https://www.gesetze-im-internet.de/brkg_2005/__5.html): §5(1) sets 20 cents/km for a motor vehicle or other motor-driven vehicle; §5(2) sets 30 cents/km for a `Kraftwagen` where significant official interest was recorded before the trip.
- [BMF Lohnsteuer-Handbuch 2026, Appendix 25 III, paragraph 37](https://lsth.bundesfinanzministerium.de/lsth/2026/B-Anhaenge/Anhang-25/III/inhalt.html): for employees, paragraph 37 lists `Kraftwagen ... 0,30 €` and `jedes andere motorbetriebene Fahrzeug 0,20 €` per driven kilometer.
- [BMF Anlage EÜR 2025, line 71](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Einkommensteuer/2025-08-29-anlage-EUER-2025.pdf?__blob=publicationFile&v=3): business use of a private car can be recorded at `0,30 € für jeden vollen km` or at proportionate actual costs; home-to-first-business-premises travel is reported separately under the distance allowance.

Version 1 supports these rate classes only:

| Structured vehicle facts | Rate |
|---|---:|
| `vehicle_source = private`, `vehicle_class = kraftwagen` | €0.30 per driven kilometer |
| `vehicle_source = private`, `vehicle_class = other_motor_vehicle` | €0.20 per driven kilometer |

Eligibility also requires `trip_kind = business_trip`, a supported trip date, valid distance, and the user's confirmation. Commuting between home and the first workplace, company vehicles, EKS allowance trips, non-motorized or public-transport travel, unsupported or unknown vehicle classes, unknown vehicle source, and a missing or out-of-date policy are excluded. Such trips remain `unresolved` with every policy snapshot field and amount null. The EKS €0.10/km allowance stays inside the EKS calculator only.

The source rules inform the reference rates but have different legal scopes: EStG §9 and the Lohnsteuer-Handbuch address employees, BRKG §5 concerns federal travel reimbursement, and Anlage EÜR 2025 gives 30 cents for each full kilometer for private-car business use. The application's supported rates, effective dates, user confirmation, and fractional-kilometer half-up calculation are an explicit product policy, not a direct transcription of one universal tax rule. The app policy intentionally differs from the EÜR's full-kilometer convention by rounding the computed amount to cents. It does not model BRKG's federal-reimbursement cap or official-interest approval condition. For non-negative distance stored as integer hundredths of a kilometer, compute `amount_cents = floor((distance_hundredths_km × rate_cents_per_km + 50) / 100)`. This is exact integer arithmetic and rounds half-up to the nearest cent. A calculated trip stores the policy ID, source, version, inclusive effective dates, calculation timestamp, and resulting amount together.

### Keep the database migration additive and gated by the inventory owners

The current v22 baseline already has the v13 mileage tables. The v23 proposal adds the structured fields above and installs lifecycle triggers; it must not recreate or replace existing tables. It also preserves the v13 migration history, the `forderung_zahlungen` pre-repair check, existing shared lazy-table markers, and the trigger requirements for unresolved-only trip inserts, draft-only correction inserts, correction transitions, immutable terminal rows, and posted replacements.

Do not claim the v23 migration or complete mileage exports are ready while the inventory dependency remains mismatched. Both owning changes must explicitly accept the same 55-name v19 inventory and version-aware presence rules before that gate closes. This change does not edit their artifacts.

### Post only through the canonical accounting boundary

A confirmed calculated trip may post only when the travel-expense and private-contribution accounts are mapped, the accounting period containing the trip date is open, and the canonical posting command can atomically store the event and trip state. The event debits the mapped travel-expense account and credits the mapped private-contribution account. It creates no cash or VAT leg. Its source identity is `(mileage_trip, trip UUID)`. A same-payload retry returns the existing event; a conflicting payload fails. Store the returned opaque event ID on the trip, and include mileage in reports only through the canonical accounting source.

### Preserve posted facts; correct through linked accounting operations

Facts on a posted trip are immutable. A `replace` correction records a new trip with corrected facts and links it to the posted source; a `void` correction has no replacement. Creating a correction draft has no accounting or report effect. Applying a correction is unavailable until an accepted operation can reverse the original and, for replacement, post the replacement under one idempotent correction identity. The accepted operation controls correction date and report-period treatment. On success, the source becomes `corrected` or `voided`, the correction becomes `applied`, and the replacement becomes `posted`; the original facts and posting remain intact. On failure, all accounting and trip state stays unchanged and the draft remains retryable.

### Build a focused, accessible workspace

Provide a `Neue Fahrt` primary action and a searchable, filterable trip table with date, purpose, distance, amount/state, and posting state. Localize labels and validation. Make controls keyboard-operable with visible focus. Show structured trip kind and vehicle choices and make unresolved state clear. Keep trip editing out of the dashboard.

## Risks / Trade-offs

- **[Risk]** A user may record a trip without enough facts to qualify. → **Mitigation:** require the user's explicit business-trip, private-vehicle, and supported-class selection; keep unknown facts explicit, leave the trip unresolved, and exclude it from monetary totals.
- **[Risk]** EKS and general mileage can be confused. → **Mitigation:** preserve distinct trip kinds and never reuse the EKS rate.
- **[Risk]** The two inventory owners disagree about table presence and versioning. → **Mitigation:** keep the dependency open and block migration/export-completeness claims until they accept one contract.
- **[Risk]** Posting or correction can duplicate accounting events. → **Mitigation:** require a single atomic operation with stable source identities and idempotent retries.

## Migration Plan

1. Keep the current v13 tables intact. After the inventory owners resolve their contract mismatch, add the structured eligibility columns and lifecycle triggers in the next sequential migration (v23 on the verified v22 baseline, or the next version if another migration lands first). Initialize legacy eligibility facts as `unknown`, preserve all rows, and increment the schema version only after verifying columns, indexes, and triggers.
2. Require new captures to retain explicit structured trip and vehicle facts; no legacy `journal.km_anzahl` backfill is allowed.
3. Calculate only from policy v1 and only for the eligible combinations above. Keep unsupported trips unresolved.
4. Keep posting unavailable until the mapped, trip-date, open-period, atomic posting boundary is wired. The posted journal event has the travel-expense/private-contribution legs only.
5. Keep correction execution unavailable until its accepted atomic reversal/replacement operation is wired.

## Dependency Ledger

| Dependency | Baseline evidence | Status | Gate |
|---|---|---|---|
| `profile-data-portability` inventory | Active change declares 46 application-table names through v13. | **Open; conflicts with customer export.** | Owner must accept the common 55-name v19 inventory and mileage presence rules. |
| `customer-data-disclosure-export` inventory | Active change declares 55 application-table names through v19. | **Open; conflicts with portability.** | Owner must accept the same common 55-name v19 inventory and mileage presence rules. |
| Inherited maintained `db` migration scenario | `V8-to-v9 migration adds shared markers and mileage tables` conflicts with the same requirement's minimum-version rule that makes mileage tables required at v13. | **Open; not edited in this scoped revision.** | The shared-spec owner must reconcile the version before migration behavior is implemented or tested. |
| Mileage schema v23 | Current baseline is v22; current mileage tables are required from v13. | **Not implemented in this revision.** | Fresh independent review must approve the revised contract; inventory owner agreement must also be recorded before migration work. |
| Mileage posting integration | Account mapping and atomic canonical posting wiring are still required. | **Open.** | Debit travel expense, credit private contribution, no cash/VAT leg; trip date in an open period; source idempotency key `(mileage_trip, trip UUID)`. |

## Open Questions

- Which existing accepted posting service and account-selection contract will supply the travel-expense and private-contribution mapping?
- Which accepted correction operation will provide atomic reversal/replacement and report-period treatment?
- When will both inventory owners reconcile the 46-name/v13 versus 55-name/v19 mismatch?
- When will the shared `db` owner reconcile the inherited v8-to-v9 mileage migration scenario with the v13 minimum-version rule?
