## Context

Feature map §35 asks for dated business-mileage records containing purpose, distance, business context, and eventually an amount used by accounting and reports. The existing EKS B6_5 rule uses `journal.km_anzahl × 0.10` for a Jobcenter travel allowance; that EKS-specific amount does not define the general mileage policy in this change. Legacy `journal.km_anzahl` values are not trip records and SHALL NOT be backfilled.

The mileage tables are required from schema v13. Structured eligibility and lifecycle enforcement are already present through schema v24. The v25 migration adds explicit role mappings, a date-range period-closure table, and nullable mileage-only journal snapshots; it preserves existing rows and introduces no default mapping or closed period.

The reconciled inventory has 55 known application-table names through v19: 39 legacy tables plus 16 feature-managed tables, including `feature_table_state`. Schema v25 adds `mileage_posting_account_mapping` and `mileage_posting_period_closures` as names 56 and 57. All maintained inventory contracts SHALL use these counts and version-aware rules: a v24 profile may omit both tables; v25 and later profiles require both schemas, while role rows may be absent and the empty closure table means all trip dates are open. A fresh v25 profile has 53 application tables when the two lazy occurrence tables and two optional document-email tables are absent. Profile export includes both tables; customer export schema-checks them without projecting them.

## Goals / Non-Goals

**Goals:**

- Capture dated trips with exact distance, purpose, business context, trip kind, vehicle source, and vehicle class.
- Apply one explicit, source-backed policy version to eligible private-vehicle business trips, with an auditable calculation snapshot.
- Leave unsupported or ineligible trips unresolved and outside accounting and report totals.
- Preserve posted source facts and define traceable replacement and undo requests.
- Post confirmed mileage as an explicitly mapped travel expense against private contribution, with no bank, cash, or VAT leg.

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

The live schema is v24 and already has the v13 mileage tables and v23/v24 eligibility and lifecycle enforcement. The v25 migration adds `mileage_posting_account_mapping`, `mileage_posting_period_closures`, and 11 nullable mileage-only journal mapping snapshot columns. It must preserve existing rows and journal data, must not recreate existing tables, must not seed an account/category mapping, and must leave the closure table empty so all periods start open. Schema health and both export inventories recognize these additions only at v25 and later.

Round 6 independently approved the contract for the aligned 55-name v19 / 57-name v25 inventory and its version-aware presence rules. The mapping table may exist without either role row; posting remains unavailable until a user configures and reviews both role pairs and the trip date is outside every explicitly closed inclusive range.

### Configure the two posting roles explicitly

The role mapping SHALL pair a user-selected ledger account ID and a reporting category ID for each role:

| Role | Journal side | Category requirement |
|---|---|---|
| Travel expense | Debit | Active expense category (`art = Ausgabe`) mapped to EÜR line 71, whose mapping status is `catalog_verified` or `user_confirmed` and whose active SKR mapping is present |
| Private contribution | Credit | Active category mapped to EÜR line 107 whose mapping status is `catalog_verified` or `user_confirmed` and whose active SKR mapping is present |

The mapping is profile-local, durable, explicitly reviewed, and editable through a dedicated mileage-posting settings form. The v25 `mileage_posting_account_mapping` table stores at most one row for each role (`travel_expense`, `private_contribution`), each with non-null foreign keys to existing `konten` and `kategorien` rows and a required review timestamp. Posting requires both rows. It stores no seeded IDs and SHALL NOT choose a first active account/category or infer a role from an account number, category name, free text, or EKS section.

The live repository and the pre-revision `stammdaten` contract treat `konten` as bank accounts, while the table itself has an unconstrained `kontoart TEXT`, nullable banking fields, and journal foreign keys. This proposal extends the maintained account contract with `kontoart = 'Sachkonto'` and requires its CRUD UI to let a user create/select Sachkonten without bank details. Existing bank and cash types and rows remain unchanged. The mileage role picker SHALL include only `Sachkonto` rows; bank-import, bank-balance, and other bank-specific account pickers SHALL exclude Sachkonten while preserving existing behavior for all other rows. The user explicitly assigns a Sachkonto to each role; no new chart numbers or fixed account numbers are introduced. The mapping table's migration remains gated on independent review and reconciliation of the shared inventory contract.

Changing the mapping affects future posts only. The v25 journal columns SHALL snapshot, on each mileage leg, its role, category label and ID, category `art`, EÜR line, SKR mappings, mapping status, source reference/version, and mapping-history ID. Account IDs and account SKR values use the existing journal account fields/snapshots. EÜR SHALL read these stored values and SHALL NOT join current `kategorien` rows for mileage legs. If either role is absent, its category is inactive, it is not a `Sachkonto`, or its category mapping is untrusted, posting fails closed and leaves the trip calculated without an event or report effect.

### Post only through the canonical accounting boundary

A confirmed calculated trip may post only when both configured role pairs pass validation, the trip date is outside every row in `mileage_posting_period_closures`, and the canonical posting command can atomically store exactly two balanced journal legs and the trip state/reference. A closure row has canonical inclusive `closed_from`/`closed_through` dates and a non-empty closure timestamp; an empty table leaves every date open. The event debits the mapped travel-expense account/category and credits the mapped private-contribution account/category. It creates no bank, cash, or VAT leg. Its source identity is `(mileage_trip, trip UUID)`. A same-payload retry returns the existing event; a retry with changed trip facts, amount, policy snapshot, or mapped roles fails without another event. Posting the journal group and changing the trip from `calculated` to `posted` with its opaque event ID is one SQLite transaction. The unique `(source_kind, source_id)` identity and `mileage_trips.posting_event_id` identify one reportable group.

EÜR SHALL add a mileage-specific source path in both its legacy and settlement-based generation modes, because the current generic query excludes non-null `source_kind` and settlement allocations do not represent this private-vehicle use entry. For an in-period `posted` trip, it SHALL read exactly one two-leg group by `(mileage_trip, trip UUID)`, require the stored event ID to match the trip, and use the trip date as the report date. It SHALL include the travel-expense debit exactly once under its snapshotted EÜR line 71 and represent the private-contribution credit exactly once under snapshotted line 107 without treating it as operating income or profit. It SHALL not also process these legs through generic journal or settlement paths. A missing, duplicate, unbalanced, malformed, or snapshot-incomplete mileage group makes that EÜR result unavailable/incomplete rather than partially counted. Category edits after posting cannot change a previously posted leg's EÜR line, label, SKR mapping, or provenance.

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

1. Treat the v13 mileage tables and v23/v24 eligibility/lifecycle migrations as live. The v25 migration SHALL add both mapping/closure tables and 11 nullable journal snapshot columns without converting account rows, seeding role pairs, closing any date range, or changing prior postings; profile health/export inventories SHALL recognize these additions only from v25 onward.
2. Require new captures to retain explicit structured trip and vehicle facts; no legacy `journal.km_anzahl` backfill is allowed.
3. Calculate only from policy v1 and only for the eligible combinations above. Keep unsupported trips unresolved.
4. Keep posting unavailable until both explicit account/category role pairs, the v25 inclusive date-range closure guard, and the atomic posting boundary are wired. The posted journal event has exactly the travel-expense/private-contribution legs.
5. Keep correction execution unavailable until its accepted atomic reversal/replacement operation is wired.

## Dependency Ledger

| Dependency | Baseline evidence | Status | Gate |
|---|---|---|---|
| `profile-data-portability` inventory | Round 6 approved the 55-name v19 baseline and two v25 additions. | **Contract approved; implementation evidence pending final review.** | Preserve 55 known names through v19 and 57 through v25; export all present supported rows, and report undeclared tables as incomplete. |
| `customer-data-disclosure-export` inventory | Round 6 approved the shared versioned inventory and customer-scoped omission rules. | **Contract approved; implementation evidence pending final review.** | Schema-check mapping and closure tables from v25 without projecting them into customer exports; their absence alone is version-pending before v25. |
| Inherited maintained `db` migration scenario | The earlier duplicate v8-to-v9 mileage-table wording is absent; v9 category history and v12-to-v13 mileage tables use separate boundaries. | **Resolved by the maintained DB correction.** | V25 adds role mapping, inclusive date-range closures, and immutable journal snapshots; v24 profiles remain valid without them. |
| Mileage schema v25 | Live baseline was v24; lifecycle enforcement was already present. | **Implemented; independent implementation review pending.** | Preserve existing rows, add the two v25 tables and 11 canonical nullable snapshot columns, and leave both role rows and closure ranges empty by default. |
| Mileage posting integration | Existing journal FKs support `konten`/`kategorien`; `kontoart` is unconstrained text and bank-detail fields are nullable. | **Core backend implemented; UI/configuration remains the next slice.** | Configure both role rows explicitly; reject dates inside a closed inclusive range; atomically post two non-bank/non-cash, non-VAT legs under `(mileage_trip, trip UUID)`, and preserve existing account rows/types and bank-specific filtering. |

## Open Questions

- Which accepted correction operation will provide atomic reversal/replacement and report-period treatment?
