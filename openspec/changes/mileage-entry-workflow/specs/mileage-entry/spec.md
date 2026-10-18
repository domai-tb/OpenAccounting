## ADDED Requirements

### Requirement: Capture traceable business mileage

The system SHALL provide a localized, keyboard-accessible workflow that records trip date, purpose, positive distance in kilometers, business context, structured trip kind, vehicle source, and vehicle class. Each saved trip SHALL have a stable UUID and begin in `unresolved` state. Distance SHALL be stored exactly as integer hundredths of a kilometer, with a supported range of 0.01 through 9,999,999,999.99 km. Structured trip kind SHALL distinguish `business_trip`, `commuting`, `eks_allowance`, `other`, and `unknown`; vehicle source SHALL distinguish `private`, `company`, and `unknown`; vehicle class SHALL distinguish `kraftwagen`, `other_motor_vehicle`, `unsupported`, and `unknown`. `private` means the user privately owns or has use of the vehicle; a company- or employer-provided vehicle is `company`. `kraftwagen` means a Kraftwagen (for example, a Pkw); `other_motor_vehicle` means another road motor vehicle such as a motorcycle. Unsupported values include non-motorized transport and public transport. The form SHALL require explicit choices and SHALL NOT infer eligibility from free text. New trips SHALL have null policy, calculated-amount, and posting-event fields until their respective accepted contracts are available. Before posting, source facts may be edited or the trip removed; editing a `calculated` trip SHALL return it to `unresolved` and clear the entire calculation snapshot. The only lifecycle transitions SHALL be `unresolved → calculated`, `calculated → unresolved`, `calculated → posted`, and `posted → corrected|voided`. Calculation and posting transitions SHALL occur atomically with their required snapshot/reference. A posted trip's source facts, policy snapshot, amount, and original posting reference MUST remain unchanged. Its state may change to `corrected` or `voided` only in the same transaction that applies a matching correction record; `corrected` and `voided` are terminal states.

#### Scenario: Record a business trip
- **GIVEN** a trip has a valid ISO date, non-empty purpose, positive distance within the supported range and precision, non-empty business context, and explicit structured trip kind, vehicle source, and vehicle class
- **WHEN** the user saves the trip
- **THEN** one durable `mileage_trips` row is created with those exact facts and classifications, a stable UUID, and `unresolved` state
- **AND** its policy, calculated-amount, and posting-event fields are null

#### Scenario: Reject invalid trip facts
- **GIVEN** a trip has an invalid date, missing purpose or business context, missing structured choices, non-positive or out-of-range distance, or more than two decimal places
- **WHEN** the user attempts to save it
- **THEN** no mileage row is created and the localized form identifies the invalid field

#### Scenario: Use the form with keyboard and supported locales
- **GIVEN** the user opens mileage entry in any app-supported locale
- **WHEN** the user navigates and submits the form using the keyboard, including its structured trip and vehicle choices
- **THEN** labels, validation, and unresolved-state text use that locale
- **AND** every control is keyboard operable with a visible focus indicator

#### Scenario: Preserve posted source facts
- **GIVEN** a mileage record has a linked accounting posting
- **WHEN** the user attempts to edit or delete its date, purpose, distance, or business context
- **THEN** the system rejects the in-place mutation and offers a linked correction or undo draft

#### Scenario: Editing a calculated trip invalidates its calculation
- **GIVEN** a trip is `calculated` but has no posting
- **WHEN** the user edits any source fact
- **THEN** the trip returns to `unresolved` and all policy, amount, and calculation-time fields are cleared

### Requirement: Mileage amounts require an effective application policy

The system SHALL calculate a mileage amount only under application policy `DE-private-business-travel/1`, version `1`, effective for trip dates from 2025-01-01 through 2026-12-31 inclusive. `business_trip` means a user-confirmed trip directly related to the user's business or work, excluding home-to-first-workplace/business-premises travel, other commuting, family-home travel, and EKS allowance travel. Eligibility requires a privately owned or privately available motor vehicle in a supported class; company- or employer-provided vehicles are ineligible. `other` and `unknown` trip kinds are ineligible. This policy is an accounting estimate and does not determine whether an amount is deductible for a particular taxpayer. Its official source references are [EStG §9(1), sentence 3, no. 4a](https://www.gesetze-im-internet.de/estg/__9.html) (`beruflich veranlasste Fahrten`, excluding `Fahrten zwischen Wohnung und erster Tätigkeitsstätte`), [BRKG §5(1)–(2)](https://www.gesetze-im-internet.de/brkg_2005/__5.html) (20 cents/km for motor vehicles; 30 cents/km for a `Kraftwagen` when the official-interest condition applies), [BMF LStH 2026, Appendix 25 III, paragraph 37](https://lsth.bundesfinanzministerium.de/lsth/2026/B-Anhaenge/Anhang-25/III/inhalt.html) (employee rate examples: `Kraftwagen ... 0,30 €`, `jedes andere motorbetriebene Fahrzeug 0,20 €` per driven kilometer), and [BMF Anlage EÜR 2025, line 71](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Einkommensteuer/2025-08-29-anlage-EUER-2025.pdf?__blob=publicationFile&v=3) (private car business use at `0,30 € für jeden vollen km`; home-to-first-business-premises travel is recorded separately). The source documents have different legal scopes; the application policy adopts the listed rates as product rules and does not claim universal tax treatment. It does not model the separate BRKG federal travel-reimbursement cap or approval condition.

For an eligible trip with `trip_kind = business_trip`, `vehicle_source = private`, and a supported vehicle class, `kraftwagen` uses 30 euro cents per driven kilometer and `other_motor_vehicle` uses 20 euro cents per driven kilometer. The amount SHALL be calculated exactly from integer hundredths of a kilometer and rounded half-up to cents: `amount_cents = floor((distance_hundredths_km × rate_cents_per_km + 50) / 100)`. This half-up fractional-kilometer rounding is the application contract; the sources do not prescribe this rounding rule, and Anlage EÜR 2025 instead specifies full kilometers for private-car use. A calculated trip SHALL persist the policy source, ID, version, inclusive effective-date range, calculation timestamp, and `NUMERIC(12,2)` amount as one complete snapshot. A Jobcenter EKS allowance SHALL remain governed by the existing EKS requirement and MUST NOT be reused as the general mileage rate.

#### Scenario: Calculate from an approved policy
- **GIVEN** the trip date is within policy version 1's inclusive effective range, `trip_kind = business_trip`, `vehicle_source = private`, and `vehicle_class` is `kraftwagen` or `other_motor_vehicle`
- **WHEN** the user requests a calculation
- **THEN** the system applies €0.30/km for `kraftwagen` or €0.20/km for `other_motor_vehicle`, multiplies the exact hundredths-kilometer distance, and rounds half-up to cents using integer arithmetic
- **AND** it stores the policy source, ID, version, effective-date range, and calculation timestamp with the amount

#### Scenario: Keep an unresolved trip out of accounting
- **GIVEN** the trip is commuting, EKS, `other`, or `unknown`, uses a company-provided vehicle, has an unsupported or unknown vehicle class/source, is non-motorized or public-transport travel, is outside the policy's effective dates, or the effective policy is unavailable
- **WHEN** the user requests a calculation or posting
- **THEN** the trip remains visibly `unresolved` with every policy snapshot field and amount null
- **AND** no accounting or report total changes

#### Scenario: Do not treat the EKS allowance as the general deduction
- **GIVEN** a trip is classified as `eks_allowance` and the existing EKS B6_5 allowance is 0.10 per kilometer
- **WHEN** a general business mileage amount is requested
- **THEN** the general mileage amount remains unresolved unless a separate accepted general policy applies

### Requirement: Explicit mileage posting role mapping

Before a mileage trip may post, the profile SHALL have one durable, explicitly user-configured mapping for each role: travel expense and private contribution. Each role SHALL pair one ledger account ID from `konten` whose `kontoart = 'Sachkonto'` with one reporting category ID from `kategorien`. The travel-expense category SHALL be active, have `art = 'Ausgabe'`, map to EÜR line 71, have an active SKR account mapping, and have mapping status `catalog_verified` or `user_confirmed`. The private-contribution category SHALL be active, map to EÜR line 107, have an active SKR account mapping, and have mapping status `catalog_verified` or `user_confirmed`. The user SHALL explicitly review the two account/category pairs together. The bank-account domain SHALL support `Sachkonto` as a non-bank ledger-account type with nullable banking fields; existing bank and cash account types and rows SHALL be preserved. Bank and cash account types MUST NOT be selected for either mileage role.

The mapping SHALL be editable in a mileage-posting settings form and scoped to the current profile. The settings and account CRUD forms SHALL expose the `Sachkonto` type explicitly, while bank-specific account pickers SHALL exclude Sachkonten. Saving a mapping and posting a trip SHALL each revalidate that both selected account rows still have `kontoart = 'Sachkonto'`; an account-type change after configuration SHALL therefore fail closed at posting. The system SHALL NOT infer either role from IDs, account numbers, labels, free text, category order, or EKS mappings, and SHALL NOT fall back to a first active account/category. A missing mapping, inactive category, non-Sachkonto account, or untrusted category mapping SHALL make posting unavailable while retaining the trip's calculated state and amount. A mapping change SHALL affect future posts only; every committed posting SHALL preserve the exact account/category IDs and resolved mapping values used in immutable per-leg journal snapshots: role, category ID/label/art/EÜR line/SKR mappings, mapping status, source reference/version, and mapping-history ID. EÜR and journal-derived reports SHALL use these snapshots and SHALL NOT re-read mutable category mappings for a posted mileage leg.

#### Scenario: Require explicit reviewed mileage roles
- **GIVEN** no complete, reviewed travel-expense and private-contribution account/category mapping exists
- **WHEN** a calculated mileage trip is posted
- **THEN** posting is unavailable, the trip remains calculated without a posting reference, and no journal or report total changes

#### Scenario: Reject an unsafe mileage role mapping
- **GIVEN** either configured category is inactive, unmapped, or not `catalog_verified` or `user_confirmed`, or either selected account is not a `Sachkonto`
- **WHEN** a calculated mileage trip is posted
- **THEN** posting fails closed before any journal group is created

### Requirement: Atomic mileage expense posting

A mileage record SHALL become a business expense only after the user confirms a policy-resolved amount, both configured account/category role pairs are valid, and the fiscal period containing the trip date is open. Posting SHALL use one canonical accounting command and source identity `(mileage_trip, trip UUID)`. It SHALL create exactly two balanced journal legs: debit the configured travel-expense account/category and credit the configured private-contribution account/category. It SHALL create no bank, cash, or VAT leg and SHALL NOT create an input-VAT claim. Posting the accounting event, trip state, and returned opaque posting-event ID SHALL commit in one SQLite transaction. A retry with the same payload SHALL return the existing event; a retry with changed trip facts, amount, policy snapshot, or mapped roles SHALL fail without creating another event. The trip SHALL retain the returned opaque posting-event ID, unique across mileage rows. The unique `(mileage_trip, trip UUID)` source and stored posting-event ID identify exactly one reportable two-leg group. EÜR SHALL include an in-period posted trip once by trip date in both legacy and settlement-based modes, despite the generic `source_kind IS NULL` filter and without adding a settlement allocation: its debit SHALL appear once under snapshotted EÜR line 71, and its private-contribution credit SHALL appear once under snapshotted line 107 without being treated as operating income or profit. Neither leg SHALL also enter generic journal or settlement totals. A missing, duplicate, unbalanced, malformed, or snapshot-incomplete group SHALL make the EÜR result unavailable/incomplete rather than partially counted. Correction treatment remains with the accepted atomic correction contract.

#### Scenario: Post a confirmed resolved mileage expense
- **GIVEN** policy version 1 resolves the eligible trip, both reviewed account/category role pairs are configured, the trip date is in an open period, and the canonical posting boundary supports the mileage source identity
- **AND** the trip has no prior posting
- **WHEN** the user confirms posting
- **THEN** exactly one expense is created with a debit to travel expense and a credit to private contribution, without cash or VAT legs, using source type `mileage_trip` and source ID equal to the trip UUID
- **AND** its accounting date is the trip date
- **AND** the two legs use their configured account/category pairs, with no bank, cash, or VAT leg
- **AND** the returned posting-event ID is stored on the trip and reports include the expense through the canonical source

#### Scenario: Include a mileage posting exactly once in EÜR
- **GIVEN** a posted trip has exactly one balanced two-leg group under `(mileage_trip, trip UUID)` with a matching `posting_event_id` and complete snapshots
- **WHEN** EÜR is generated for the trip date in either legacy or settlement-based mode
- **THEN** the debit is included exactly once under its snapshotted EÜR line 71
- **AND** the private-contribution credit is represented once under snapshotted line 107 but is excluded from operating income and profit
- **AND** neither leg is also included through generic journal or settlement processing

#### Scenario: Fail closed for an incomplete mileage report group
- **GIVEN** an in-period mileage trip has a missing, duplicate, unbalanced, or snapshot-incomplete posting group
- **WHEN** EÜR is generated
- **THEN** the result is unavailable or incomplete and does not partially count either leg

#### Scenario: Keep posting unavailable while a prerequisite is missing
- **GIVEN** the policy, either explicit role mapping, or accepted accounting posting contract is unavailable
- **WHEN** the user opens or invokes mileage actions
- **THEN** posting is unavailable, the trip remains unresolved or calculated without a posting reference, and no accounting or report total changes

#### Scenario: Reject duplicate or incomplete posting
- **GIVEN** a trip already has a posting, lacks an approved amount, or lacks a valid mapping
- **WHEN** posting is requested or retried
- **THEN** a same-payload retry returns the existing event, a conflicting payload creates no event, and the system reports the existing posting or unresolved prerequisite

### Requirement: Correct or undo a posted trip through linked accounting corrections

The system SHALL preserve every posted trip and its original posting. A replacement correction SHALL create a new trip record containing the corrected facts and link it to the posted source; an undo SHALL create a correction record with no replacement trip. Each correction SHALL record a non-empty reason and stable ID. Creating a draft correction SHALL NOT change the original trip, posting, or report totals. A correction SHALL be applied only through an accepted accounting correction operation, keyed by source type `mileage_correction` and source ID equal to the correction UUID, that reverses the original posting and, for replacement, posts the replacement under that same unique correction identity. The reversal, optional replacement posting, correction event ID, and mileage state transitions SHALL commit in one SQLite transaction. The correction operation SHALL define correction date and report-period treatment. On success, the original trip SHALL become `corrected` or `voided`, the correction SHALL become `applied`, and a replacement SHALL become `posted`; original facts and posting references remain unchanged. Failure SHALL leave all accounting and trip states unchanged and the draft retryable. A later correction SHALL target the latest replacement trip, preserving a linear traceable chain.

#### Scenario: Prepare a replacement correction without changing accounting
- **GIVEN** a posted trip needs corrected facts
- **WHEN** the user creates a replacement correction draft with a reason and replacement trip
- **THEN** the correction row links the original and replacement trip
- **AND** the original remains posted, the replacement is not posted, and no accounting or report total changes

#### Scenario: Apply an accepted replacement correction
- **GIVEN** a posted trip has a valid replacement draft, approved policy and mapping, and an accepted correction operation
- **WHEN** the user confirms the correction
- **THEN** the operation reverses the original posting and posts the replacement as one idempotent correction
- **AND** the original becomes `corrected`, the correction becomes `applied` with the accepted correction event ID, and the replacement becomes `posted`
- **AND** the original trip facts and posting remain unchanged

#### Scenario: Undo a posted trip
- **GIVEN** a posted trip should be withdrawn and has an accepted accounting correction operation available
- **WHEN** the user confirms an undo correction with a reason and no replacement trip
- **THEN** the operation reverses the original posting once, marks the source trip `voided`, and marks the correction `applied`
- **AND** the original facts and posting remain unchanged

#### Scenario: Keep correction execution unavailable without an accepted operation
- **GIVEN** no accepted accounting correction operation defines reversal, idempotency, and report-period behavior
- **WHEN** the user drafts or attempts to apply a correction
- **THEN** a draft may be saved, but applying it is unavailable and the original posting and report totals remain unchanged

#### Scenario: Failed or repeated correction is safe
- **GIVEN** a correction operation fails or the same correction is submitted more than once
- **WHEN** the operation is retried
- **THEN** a failed attempt leaves the draft retryable and all trip/accounting state unchanged
- **AND** a repeated successful request returns the existing correction event and creates no duplicate reversal or replacement posting
