## ADDED Requirements

### Requirement: Opening-source schema is checked without disclosing company cash data

At schema version v26 and later, the customer-disclosure exporter SHALL require a valid `account_opening_balance_sources` table as part of database schema health. The table SHALL not be projected into a customer-scoped disclosure archive unless a separate accepted contract defines a customer relationship for each source row. A valid source table with no customer projection SHALL not make an otherwise complete disclosure export incomplete.

#### Scenario: v25 customer disclosure remains version-pending

- **GIVEN** a healthy profile at schema version 25 does not contain `account_opening_balance_sources`
- **WHEN** customer-disclosure schema checks run
- **THEN** the table SHALL be treated as version-pending
- **AND** the profile SHALL not fail disclosure schema checks for its absence.

#### Scenario: v26 source table is checked but not projected

- **GIVEN** a schema-v26 profile has a valid account-opening source table but no accepted customer relationship for those rows
- **WHEN** a customer-scoped disclosure export is created
- **THEN** schema health SHALL recognize the table as valid
- **AND** no account-opening source row SHALL be included in the customer disclosure payload.
