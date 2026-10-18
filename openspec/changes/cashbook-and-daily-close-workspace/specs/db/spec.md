## ADDED Requirements

### Requirement: Tagesabschluss evidence storage and immutability

The ordered v25 migration SHALL run after v23 mileage and the separately reviewed and implemented v24 `account-opening-balance-source` prerequisite. Cashbook implementation SHALL remain blocked while that prerequisite lacks fresh independent approval. The v25 migration SHALL add nullable `zaehlung_json TEXT` and `integrity_hash TEXT` columns to the existing `tagesabschluesse` table and install database triggers that reject UPDATE or DELETE when the old row has a non-null `integrity_hash` or legacy `signatur`. It SHALL NOT create another cash ledger/table, backfill or reinterpret legacy close values, rewrite `signatur`, or add/remove any existing table. Existing legacy rows SHALL remain byte-for-byte unchanged and readable as unverified history; no snapshot, digest, signature, or verification state SHALL be synthesized. New finalized rows SHALL store their versioned snapshot and integrity digest together and SHALL leave the legacy `signatur` field unchanged.

#### Scenario: Close evidence migration preserves existing history

- **GIVEN** the independently approved `account-opening-balance-source` v24 migration is implemented and a supported profile at schema v24 contains `tagesabschluesse` rows, including legacy values
- **WHEN** the ordered v25 migration completes
- **THEN** `zaehlung_json` and `integrity_hash` SHALL exist and the exact pre-migration table set SHALL remain unchanged
- **AND** every existing close-row value SHALL remain byte-for-byte unchanged with no inferred snapshot or digest.

#### Scenario: Finalized close cannot be rewritten

- **GIVEN** a row has a non-null new `integrity_hash` or a non-null legacy `signatur`
- **WHEN** SQL attempts to update or delete that row
- **THEN** a database trigger SHALL reject the operation
- **AND** the row SHALL remain unchanged.

#### Scenario: Failed evidence migration rolls back

- **GIVEN** adding either evidence column or creating an immutability trigger fails during v25
- **WHEN** migration error handling completes
- **THEN** the schema version and all existing `tagesabschluesse` rows SHALL retain their pre-migration values
- **AND** the failure SHALL be surfaced as a schema migration error.

### Requirement: Tagesabschluss finalization prevents duplicate identities

The close persistence use case SHALL perform existing-record lookup, integrity verification, and new-row insertion inside one SQLite write transaction using `BEGIN IMMEDIATE`. A finalized close identity SHALL be the composite `(unternehmen_id, konto_id, datum)`. If exactly one row is the only match and its version-1 snapshot and SHA-256 digest verify, the service SHALL return it without mutation. Any matching unsigned legacy row, signature-only legacy row, multiple rows, or ambiguous company/account/date identity SHALL cause the service to fail closed for that identity. Concurrent requests SHALL NOT persist more than one finalized close. The database SHALL preserve every legacy row without automatically choosing, deleting, backfilling, or rewriting one.

#### Scenario: Duplicate guard runs in a serialized transaction

- **GIVEN** two requests attempt to finalize the same company, account, and date
- **WHEN** each performs lookup and insert through the close transaction boundary
- **THEN** only one integrity-verified row SHALL be persisted
- **AND** the subsequent request SHALL return the verified row read-only.

#### Scenario: Legacy rows without one verified identity block a new close

- **GIVEN** an unsigned or signature-only legacy row, multiple rows, or identity-ambiguous rows match a requested close
- **WHEN** the persistence use case checks the identity
- **THEN** every legacy row SHALL remain unchanged and unverified
- **AND** no new finalized row SHALL be inserted for that identity.
