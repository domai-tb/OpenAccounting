## ADDED Requirements

### Requirement: v26 stores an account-scoped setup opening source

After the v25 mileage migration and before v27 daily-close evidence, the v26 migration SHALL create `account_opening_balance_sources` with: `id INTEGER PRIMARY KEY`; `unternehmen_id INTEGER NOT NULL` referencing `unternehmen(id)` with `ON DELETE RESTRICT`; `konto_id INTEGER NOT NULL` referencing `konten(id)` with `ON DELETE RESTRICT`; `journal_id INTEGER NOT NULL` referencing `journal(id)` with `ON DELETE RESTRICT`; `effective_date TEXT NOT NULL` in local `YYYY-MM-DD` form; `amount_cents INTEGER NOT NULL` constrained to non-negative values; uppercase two-decimal `currency_code TEXT NOT NULL`; and non-empty `source_reference TEXT NOT NULL`. The table SHALL enforce uniqueness of `(unternehmen_id, konto_id)`, `journal_id`, and `source_reference`, and SHALL reject UPDATE and DELETE after insertion. The v26 runtime inventory SHALL add this table as the 58th known application-table name after the 57 names through v25, including mileage tables 56 and 57. Profile portability SHALL include typed source rows at v26.

Fresh schemas at v26 or later SHALL declare the same columns, foreign keys, uniqueness constraints, and immutability triggers as the migrated schema. A successful v25-to-v26 migration SHALL create the empty source table transactionally and advance the version only after verification. It SHALL preserve every existing account, journal row, and legacy cash table/row unchanged and SHALL NOT infer or backfill source rows from `konten.saldo`, `journal.is_opening_balance`, opening journal rows, or legacy `kassenbestand`. A profile with no v26 source row for an older cash account remains a valid profile but its account/date balance and cashbook writes SHALL be unavailable. Profile portability SHALL require and export this 58th table at v26; customer-disclosure schema health SHALL require it at v26 but SHALL NOT project its rows without an approved customer relationship.

#### Scenario: v26 migration preserves legacy history without backfill

- **GIVEN** a supported v25 profile contains cash accounts, opening journal rows, `konten.saldo` values, and any recognized legacy `kassenbestand` rows
- **WHEN** the v26 opening-source migration completes
- **THEN** `account_opening_balance_sources` SHALL exist and contain no inferred rows
- **AND** all pre-migration account, journal, and legacy cash values SHALL remain unchanged.

#### Scenario: Fresh and upgraded v26 source schemas match

- **GIVEN** one profile is created fresh at schema v26 or later and another is upgraded from v25
- **WHEN** their opening-source schemas are compared
- **THEN** columns, foreign keys, uniqueness constraints, and immutability triggers SHALL match
- **AND** a fresh profile SHALL NOT depend on running the v25-to-v26 migration to obtain the source table.

#### Scenario: Opening-source identity is unique and immutable

- **GIVEN** one account-scoped opening source has been inserted
- **WHEN** a second source is inserted for the same company/account or journal link, or SQL attempts to update or delete the source
- **THEN** the database SHALL reject the conflicting insert or mutation
- **AND** the original source row SHALL remain unchanged.

### Requirement: v27 stores daily-close evidence and protects finalized rows

The ordered v27 migration SHALL run after v25 mileage and v26 account-opening-source migrations, and before the separate v28 e-invoice tax migration. It SHALL add nullable `zaehlung_json TEXT` and `integrity_hash TEXT` columns to the existing `tagesabschluesse` table and install database triggers that reject UPDATE or DELETE when the old row has a non-null `integrity_hash` or legacy `signatur`. Fresh schemas at v27 or later SHALL declare the same columns and triggers. The v27 migration SHALL NOT create another cash ledger or table, backfill or reinterpret legacy close values, rewrite `signatur`, or add/remove any existing table. Existing legacy rows SHALL remain byte-for-byte unchanged and readable as unverified history; no snapshot, digest, signature, or verification state SHALL be synthesized. New finalized rows SHALL store their versioned snapshot and integrity digest together and SHALL leave the legacy `signatur` field unchanged.

#### Scenario: Close evidence migration preserves existing history

- **GIVEN** the v26 source migration is implemented and a supported profile at schema v26 contains `tagesabschluesse` rows, including legacy values
- **WHEN** the ordered v27 migration completes
- **THEN** `zaehlung_json` and `integrity_hash` SHALL exist and the exact pre-migration table set SHALL remain unchanged
- **AND** every existing close-row value SHALL remain byte-for-byte unchanged with no inferred snapshot or digest.

#### Scenario: Fresh and upgraded v27 close schemas match

- **GIVEN** one profile is created fresh at schema v27 or later and another is upgraded from v26
- **WHEN** their `tagesabschluesse` schemas and immutability triggers are compared
- **THEN** the evidence columns and trigger behavior SHALL match
- **AND** a fresh profile SHALL NOT depend on running the v26-to-v27 migration to obtain them.

#### Scenario: Finalized close cannot be rewritten

- **GIVEN** a row has a non-null new `integrity_hash` or a non-null legacy `signatur`
- **WHEN** SQL attempts to update or delete that row
- **THEN** a database trigger SHALL reject the operation
- **AND** the row SHALL remain unchanged.

#### Scenario: Failed evidence migration rolls back

- **GIVEN** adding either evidence column or creating an immutability trigger fails during v27
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
