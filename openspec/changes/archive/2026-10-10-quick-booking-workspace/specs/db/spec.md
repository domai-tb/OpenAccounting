## ADDED Requirements

### Requirement: Quick-booking presets store explicit execution semantics

The `schnellbuchungen` schema SHALL store direction (`art` constrained to `einnahme` or `ausgabe`), optional `ust_satz_id` referencing `ust_saetze`, `eingabemodus` constrained to `netto` or `brutto`, and an optional default `betrag`, in addition to its current stable ID, name, category, account, and description. Migration SHALL preserve existing rows and values, add no inferred direction/tax/basis, and leave incomplete legacy presets reviewable but non-executable. Fresh schema and migration definitions SHALL agree. Any table rebuild required to make `betrag` nullable SHALL preserve stable preset IDs and every existing value.

#### Scenario: Fresh schema stores the complete preset contract

- **GIVEN** a fresh profile is created with Quick Bookings enabled
- **WHEN** the schema is created
- **THEN** `schnellbuchungen` SHALL contain the declared direction, tax, amount-basis, and optional amount fields
- **AND** constraints SHALL reject unsupported direction or amount basis values.

#### Scenario: Legacy preset migration preserves values

- **GIVEN** an existing profile contains quick-booking rows without direction, tax, or amount-basis fields
- **WHEN** the ordered migration completes
- **THEN** every existing preset ID and stored value SHALL remain unchanged
- **AND** the new fields SHALL remain null until reviewed by a user.

#### Scenario: Failed table rebuild rolls back

- **GIVEN** the migration needed to make the default amount optional fails
- **WHEN** migration error handling completes
- **THEN** the prior table, rows, IDs, and schema version SHALL remain unchanged.
