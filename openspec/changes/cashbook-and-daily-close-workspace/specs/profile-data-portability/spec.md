## ADDED Requirements

### Requirement: v26 account-opening sources are preserved in complete profile archives

At schema version v26 and later, the complete profile archive SHALL recognize `account_opening_balance_sources` as the 58th known application-table name after the 57 names through v25, including mileage tables 56 and 57. A pre-v26 profile SHALL treat that table as version-pending; its absence SHALL NOT make that earlier profile incomplete. A v26-or-later profile SHALL require a valid source-table schema and SHALL include every source row and its company, account, and opening-journal references in typed archive records. An empty source table is valid profile data. The exporter SHALL NOT create, repair, infer, omit, or rewrite source rows. The versioned archive SHALL preserve the source reference and integer-cent amount without treating `konten.saldo` or legacy opening rows as a source.

#### Scenario: Pre-v26 profile does not require the opening-source table

- **GIVEN** a healthy profile at schema version 25 has no `account_opening_balance_sources` table
- **WHEN** the complete profile exporter checks its versioned table inventory
- **THEN** the source table SHALL be reported as version-pending
- **AND** its absence SHALL NOT make the v25 archive incomplete.

#### Scenario: v26 profile export preserves opening-source rows

- **GIVEN** a schema-v26 profile has a valid source table with one or more account-scoped opening-source rows
- **WHEN** the owner exports the complete profile
- **THEN** the archive SHALL contain each typed source row and its stable references
- **AND** an empty but valid source table SHALL remain complete without synthesizing any source row.

#### Scenario: Missing v26 source schema blocks complete export

- **GIVEN** a profile records schema v26 or later but its source table is absent or malformed
- **WHEN** the complete profile exporter checks schema health
- **THEN** the export SHALL be unavailable or incomplete with the source table identified
- **AND** the exporter SHALL NOT create or repair the table.
