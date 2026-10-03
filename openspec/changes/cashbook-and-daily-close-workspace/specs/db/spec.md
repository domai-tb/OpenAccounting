## ADDED Requirements

### Requirement: Tagesabschluss evidence storage and immutability

A versioned database migration SHALL add nullable `zaehlung_json TEXT` to the existing `tagesabschluesse` table so the close use case can persist explicit count details and discrepancy explanation required by the accounting/PDF contracts. The migration SHALL NOT create another cash ledger/table, backfill or reinterpret legacy close values, or add/remove any existing table. It SHALL preserve the exact pre-migration table set. Rows with a non-null `signatur` SHALL be protected from UPDATE and DELETE by database triggers. Legacy rows SHALL remain readable; missing evidence or signatures SHALL NOT be synthesized.

#### Scenario: Close evidence migration preserves existing history

- **GIVEN** an existing supported profile database contains `tagesabschluesse` rows
- **WHEN** the ordered migration completes
- **THEN** `tagesabschluesse.zaehlung_json` SHALL exist and the exact pre-migration table set SHALL remain unchanged
- **AND** all existing close-row values SHALL remain byte-for-byte unchanged with no inferred JSON or signature.

#### Scenario: Signed close cannot be rewritten

- **GIVEN** a `tagesabschluesse` row has a non-null `signatur`
- **WHEN** SQL attempts to update or delete the row
- **THEN** a database trigger SHALL reject the operation
- **AND** the signed close SHALL remain unchanged.

#### Scenario: Failed evidence migration rolls back

- **GIVEN** the migration adding close evidence storage or its triggers fails
- **WHEN** migration error handling completes
- **THEN** the schema version and all existing `tagesabschluesse` rows SHALL retain their pre-migration values
- **AND** the failure SHALL be surfaced as a schema migration error.

### Requirement: Tagesabschluss finalization prevents duplicate identities

The close persistence use case SHALL serialize existing-record lookup and signed-row insertion inside one SQLite write transaction using `BEGIN IMMEDIATE`. A finalized close identity SHALL be the composite `(unternehmen_id, konto_id, datum)`. If exactly one signed record is the only matching row for the identity, the service SHALL return it without mutation. Any matching unsigned legacy row, multiple rows, or ambiguous legacy identity SHALL cause the service to fail closed for that identity. Concurrent requests SHALL NOT persist more than one signed close. The database SHALL preserve every legacy row without automatically choosing, deleting, or rewriting one.

#### Scenario: Duplicate guard runs in a serialized transaction

- **GIVEN** two requests attempt to finalize the same company, account, and date
- **WHEN** each performs lookup and insertion through the close transaction boundary
- **THEN** only one signed row SHALL be persisted
- **AND** the subsequent request SHALL return the existing row read-only.

#### Scenario: Legacy rows without one verified signed identity block a new close

- **GIVEN** an unsigned legacy row, multiple rows, or identity-ambiguous legacy close rows match a requested close
- **WHEN** the persistence use case checks the identity
- **THEN** all legacy rows SHALL remain unchanged
- **AND** no new signed row SHALL be inserted for that identity.
