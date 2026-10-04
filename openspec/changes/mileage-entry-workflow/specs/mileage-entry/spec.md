## ADDED Requirements

### Requirement: Capture traceable business mileage

The system SHALL provide a localized, keyboard-accessible workflow that records trip date, purpose, positive distance in kilometers, and business context. Each saved trip SHALL have a stable UUID and begin in `unresolved` state. Distance SHALL be stored exactly as integer hundredths of a kilometer, with a supported range of 0.01 through 9,999,999,999.99 km. New trips SHALL have null policy, calculated-amount, and posting-event fields until their respective accepted contracts are available. Before posting, source facts may be edited or the trip removed; editing a `calculated` trip SHALL return it to `unresolved` and clear the entire calculation snapshot. The only lifecycle transitions SHALL be `unresolved → calculated`, `calculated → unresolved`, `calculated → posted`, and `posted → corrected|voided`. Calculation and posting transitions SHALL occur atomically with their required snapshot/reference. A posted trip's source facts, policy snapshot, amount, and original posting reference MUST remain unchanged. Its state may change to `corrected` or `voided` only in the same transaction that applies a matching correction record; `corrected` and `voided` are terminal states.

#### Scenario: Record a business trip
- **GIVEN** a trip has a valid ISO date, non-empty purpose, positive distance within the supported range and precision, and non-empty business context
- **WHEN** the user saves the trip
- **THEN** one durable `mileage_trips` row is created with those exact facts, a stable UUID, and `unresolved` state
- **AND** its policy, calculated-amount, and posting-event fields are null

#### Scenario: Reject invalid trip facts
- **GIVEN** a trip has an invalid date, missing purpose, missing business context, non-positive or out-of-range distance, or more than two decimal places
- **WHEN** the user attempts to save it
- **THEN** no mileage row is created and the localized form identifies the invalid field

#### Scenario: Use the form with keyboard and supported locales
- **GIVEN** the user opens mileage entry in any app-supported locale
- **WHEN** the user navigates and submits the form using the keyboard
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

### Requirement: Mileage amounts require an approved effective policy

The system SHALL calculate a general deductible amount only from a separately accepted policy that is approved for the trip purpose and effective on the trip date. The policy SHALL define its source, stable ID and version, eligibility conditions, calculation basis, applicable caps, and rounding rule. A calculated trip SHALL persist the policy source, ID, version, effective-date range, calculation timestamp, and `NUMERIC(12,2)` amount as one complete snapshot. A Jobcenter EKS allowance SHALL remain governed by the existing EKS requirement and MUST NOT be reused as the general deductible mileage rate.

#### Scenario: Calculate from an approved policy
- **GIVEN** an accepted policy matches the trip date and purpose and all required eligibility facts are present
- **WHEN** the user requests a calculation
- **THEN** the system stores the amount produced by that policy's defined calculation and rounding rule
- **AND** it stores the policy source, ID, version, effective-date range, and calculation timestamp with the amount

#### Scenario: Keep an unresolved trip out of accounting
- **GIVEN** no accepted policy applies to the trip date and purpose, or a required eligibility fact is missing
- **WHEN** the user requests a calculation or posting
- **THEN** the trip remains visibly unresolved with all policy and amount fields null
- **AND** no accounting or report total changes

#### Scenario: Do not treat the EKS allowance as the general deduction
- **GIVEN** the only available mileage rate is the existing EKS B6_5 allowance of 0.10 per kilometer
- **WHEN** a general business mileage amount is requested
- **THEN** the general deductible amount remains unresolved unless a separate accepted general policy applies

### Requirement: Post resolved mileage only through the accepted accounting boundary

A mileage record SHALL become a business expense only after the user confirms a policy-resolved amount and a valid category/account and tax mapping exists. Posting SHALL remain unavailable until the accepted accounting contract exposes a canonical posting command, report source, and unique idempotency boundary for source type `mileage_trip` and source ID equal to the trip UUID. Posting the accounting event, trip state, and returned opaque posting-event ID SHALL commit in one SQLite transaction. Posting SHALL use the date, journal structure, and report treatment defined by that accepted contract; this workflow MUST NOT invent those rules. The trip SHALL retain the returned opaque posting-event ID, unique across mileage rows. Reports SHALL include mileage only through the canonical accounting source.

#### Scenario: Post a confirmed resolved mileage expense
- **GIVEN** an accepted policy resolves the trip, the required mapping exists, and the accepted accounting boundary supports the mileage source identity
- **AND** the trip has no prior posting
- **WHEN** the user confirms posting
- **THEN** exactly one expense is created through the accepted accounting boundary with source type `mileage_trip` and source ID equal to the trip UUID
- **AND** the returned posting-event ID is stored on the trip and reports include the expense through the canonical source

#### Scenario: Keep posting unavailable while a prerequisite is missing
- **GIVEN** the policy, required mapping, or accepted accounting posting contract is unavailable
- **WHEN** the user opens or invokes mileage actions
- **THEN** posting is unavailable, the trip remains unresolved or calculated without a posting reference, and no accounting or report total changes

#### Scenario: Reject duplicate or incomplete posting
- **GIVEN** a trip already has a posting, lacks an approved amount, or lacks a valid mapping
- **WHEN** posting is requested or retried
- **THEN** no second posting is created and the system reports the existing posting or unresolved prerequisite

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
