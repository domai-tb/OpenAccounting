## ADDED Requirements

### Requirement: Exactly-once mileage EÜR source recognition

The EÜR SHALL read a posted mileage trip through one mileage-specific source path in both legacy and settlement-based report modes. The generic journal query excludes non-null `source_kind`, and mileage has no cash settlement allocation, so the mileage reader SHALL identify the canonical group by `(source_kind = 'mileage_trip', source_id = trip UUID)` and require its stored event ID to match `mileage_trips.posting_event_id`. It SHALL include the group by trip date, exactly once per unique source, without requiring or creating a settlement allocation and without also processing its legs through generic journal or settlement totals. The two-leg group SHALL be structurally complete, balanced, and contain the expected expense and private-contribution roles. The expense debit SHALL use its immutable snapshotted EÜR line 71; the private-contribution credit SHALL use its immutable snapshotted EÜR line 107 and SHALL NOT be treated as operating income or profit. A missing, duplicate, unbalanced, malformed, or snapshot-incomplete group SHALL make the EÜR result unavailable or incomplete rather than partially counted. Journal snapshots SHALL preserve each leg's role, category ID and label, category `art`, EÜR line, category SKR mappings, mapping status, mapping source reference/version, and mapping-history ID. Mileage EÜR output SHALL use those stored values and SHALL NOT join current category or mapping-history values; later edits to categories SHALL NOT change historical output. Mileage source legs SHALL NOT create an input-VAT claim. Correction treatment SHALL follow its separately accepted atomic correction contract.

#### Scenario: Include a mileage trip exactly once in either EÜR mode
- **GIVEN** an in-period posted trip has one balanced two-leg group under `(mileage_trip, trip UUID)` with a matching posting-event ID and complete snapshots
- **WHEN** EÜR is generated in legacy or settlement-based mode
- **THEN** the expense debit appears once by trip date under its snapshotted EÜR line 71
- **AND** the private-contribution credit appears once under snapshotted line 107 but is excluded from operating income and profit
- **AND** neither leg is also processed through the generic journal or settlement path

#### Scenario: Mileage category edits do not rewrite historical EÜR output
- **GIVEN** a posted mileage group has category label, EÜR/SKR lines, and mapping provenance in immutable journal snapshots
- **WHEN** the mapped category is later edited or its current mapping history changes
- **THEN** generated EÜR output for that mileage group remains based on the stored snapshots

#### Scenario: Fail closed for an invalid mileage report group
- **GIVEN** an in-period mileage trip has a missing, duplicate, unbalanced, or snapshot-incomplete source group
- **WHEN** EÜR is generated
- **THEN** the report is unavailable or incomplete and does not partially count either leg

### Requirement: Keep correction report periods independent of runtime timezone

For each requested report year, EÜR SHALL inspect an applied correction when either its non-null `mileage_trip_corrections.applied_business_date` or any surviving correction row's stored `journal.datum` names that year. It SHALL NOT derive a correction year from `applied_at` or convert that timestamp using the report process timezone. EÜR SHALL inspect all surviving rows in the correction group even when the persisted business date and row dates name different years. All surviving rows in a correction group SHALL have the same canonical `journal.datum`; when `applied_business_date` is non-null, it SHALL equal every surviving row's date. Any disagreement SHALL make EÜR unavailable or incomplete for every candidate report year: the persisted business-date year and every year named by a surviving row. EÜR SHALL NOT partially count the correction. A complete legacy group with a null business date SHALL use its consistent stored journal date. If an applied legacy correction has no surviving journal rows and a null `applied_business_date`, EÜR SHALL be unavailable or incomplete for every requested year because its report period is unknown.

#### Scenario: Correction report year survives a runtime timezone change
- **GIVEN** a correction is applied in Europe/Berlin at `2024-12-31T23:30Z`, its persisted business date and journal dates are `2025-01-01`, and its audit timestamp is UTC
- **WHEN** the same profile is opened and EÜR is generated under UTC
- **THEN** the complete correction is reported in 2025 and is not treated as missing from 2024

#### Scenario: Partial correction group is detected by a surviving journal date
- **GIVEN** an applied correction has one or more surviving correction rows dated `2025-01-01` and an incomplete group
- **WHEN** EÜR is generated for 2025
- **THEN** the report is unavailable or incomplete even if the correction date metadata is null or names another year

#### Scenario: Date mismatch fails closed in every candidate report year
- **GIVEN** an applied correction has `applied_business_date = 2025-01-01` and its surviving correction rows are dated `2024-12-31` and `2025-01-01`
- **WHEN** EÜR is generated for 2024 and for 2025
- **THEN** both reports are unavailable or incomplete because both years are candidates
- **AND** neither report partially counts the correction

#### Scenario: Entirely missing legacy correction group with unknown date fails closed
- **GIVEN** an applied legacy correction has no surviving journal rows and a null `applied_business_date`
- **WHEN** EÜR is generated for any requested year
- **THEN** the report is unavailable or incomplete without guessing from `applied_at`
