## ADDED Requirements

### Requirement: Company fiscal-year start month migration

Fresh `unternehmen` table creation SHALL include `geschaeftsjahr_startmonat INTEGER NOT NULL DEFAULT 1 CHECK (geschaeftsjahr_startmonat BETWEEN 1 AND 12)`. Existing profile databases SHALL receive the equivalent column through an ordered migration that backfills existing company rows to January and preserves all other company fields and rows. Fresh creation SHALL NOT depend on incremental migrations, since the fresh-schema path sets the current schema version directly. Both paths SHALL verify the 1–12 constraint and preserve schema-version atomicity.

#### Scenario: Fresh company schema defaults to January

- **GIVEN** a fresh profile creates its `unternehmen` table from the current schema
- **WHEN** a company is created without a fiscal-year override
- **THEN** `geschaeftsjahr_startmonat` SHALL be `1`
- **AND** the fresh database SHALL not depend on an incremental migration to supply the value

#### Scenario: Existing company rows are migrated

- **GIVEN** a database contains one or more company rows without a fiscal-year start month
- **WHEN** the ordered fiscal-year migration completes
- **THEN** every existing company row SHALL have `geschaeftsjahr_startmonat = 1`
- **AND** all prior values SHALL remain unchanged

#### Scenario: Migration failure preserves the prior database

- **GIVEN** the fiscal-year migration cannot add or verify the required column
- **WHEN** migration handling completes
- **THEN** the migration SHALL roll back
- **AND** the schema version and pre-existing company data SHALL remain at their pre-migration values
