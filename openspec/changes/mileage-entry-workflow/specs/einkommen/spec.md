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
