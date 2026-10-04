## ADDED Requirements

### Requirement: Customer and supplier archive state migration

The `kunden` and `lieferanten` tables SHALL each contain a nullable `archived_at TEXT` column. `NULL` SHALL mean active; a non-`NULL` value SHALL be an ISO-8601 UTC timestamp indicating when the row was archived. Fresh schema creation SHALL include both columns. Existing profile databases SHALL add both columns through one ordered migration, preserving every row, identifier, existing column value, and reference. The migration SHALL be the next sequential schema version after the accepted v10 migration; if migration order changes before implementation, it SHALL be reassigned to the next sequential version. The migration SHALL add no table and SHALL increment `PRAGMA user_version` only after successful verification.

#### Scenario: Fresh profile includes contact archive columns
- **GIVEN** a new profile database is created from the current schema
- **WHEN** the schema is inspected
- **THEN** `kunden.archived_at` and `lieferanten.archived_at` exist as nullable text columns
- **AND** all newly created customer and supplier rows have `archived_at = NULL`

#### Scenario: Existing profile migrates without changing records
- **GIVEN** an existing profile has customer and supplier rows and no archive columns
- **WHEN** the archive migration succeeds
- **THEN** both archive columns exist and all existing rows have `archived_at = NULL`
- **AND** all existing IDs, field values, references, and row counts remain unchanged
- **AND** the schema version advances by exactly one only after verification

#### Scenario: Archive and restore preserve customer identity
- **GIVEN** a customer or supplier row has an existing primary key and historical references
- **WHEN** it is archived and later restored
- **THEN** archive sets a UTC timestamp and restore clears it
- **AND** neither operation changes the primary key or historical references
