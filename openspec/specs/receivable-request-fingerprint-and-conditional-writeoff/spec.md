# receivable-request-fingerprint-and-conditional-writeoff Specification

## Purpose
TBD - created by archiving change receivable-request-fingerprint-and-conditional-writeoff. Update Purpose after archive.

## Requirements

### Requirement: Keyed payments persist and compare a canonical request fingerprint

For a keyed payment, the system MUST canonicalize the requested amount to integer cents with no silent rounding: more than two fractional digits return typed `amountScale`. It MUST use the selected `forderung_id` as the target, derive direction from the target's persisted `partner_typ` (`kunde` = `incoming`, `lieferant` = `outgoing`), and canonicalize the date as a real calendar date in `YYYY-MM-DD`. An explicit date has policy `explicit`; an omitted date uses an injected clock's UTC request day and policy `request-day`. The `zahlung` relation row MUST persist the requested cents, target, derived direction, date policy, and effective date before the transaction commits. Overpayment/credit-item/Gutschrift policy is outside this requirement, but overpayment state updates remain conditional and atomic.

#### Scenario: A keyed payment stores its canonical fingerprint and applies once

- **GIVEN** an open customer Forderung with 10,000 cents and a new key `bank-1`
- **WHEN** a keyed payment requests 4,000 cents with explicit date `2026-09-29`
- **THEN** one `zahlung` relation stores requested cents `4000`, target equal to the Forderung id, direction `incoming`, policy `explicit`, and effective date `2026-09-29`, and the balance decreases to 6,000 cents

#### Scenario: A structurally invalid keyed request is rejected before any effect

- **GIVEN** a keyed payment has a blank key, malformed amount, non-positive amount, or invalid target id
- **WHEN** the payment command is called
- **THEN** it returns typed `invalidRequest` and creates no journal, relation, or balance change; malformed dates are classified by the date-validation scenarios and unknown partner types by the direction-validation scenario

#### Scenario: A keyed amount with more than two decimals is rejected rather than rounded

- **GIVEN** an open Forderung and a new key
- **WHEN** a keyed payment requests `1.005`
- **THEN** it returns typed `amountScale` and creates no journal, relation, or balance change

#### Scenario: Double inputs use exact decimal text without binary rounding

- **GIVEN** one request supplies `1.1` and another supplies the computed double `0.1 + 0.2`
- **WHEN** both keyed payment requests are parsed
- **THEN** `1.1` is accepted as exactly 110 cents, while `0.1 + 0.2` is rejected as `amountScale` from its canonical `0.30000000000000004` text rather than rounded to 30 cents

#### Scenario: A missing date uses an injected UTC request day

- **GIVEN** an open customer Forderung and a clock fixed at `2026-09-29T23:30:00Z`
- **WHEN** a keyed payment omits `datum`
- **THEN** the persisted fingerprint uses effective date `2026-09-29` and policy `request-day`

#### Scenario: An unknown partner direction is rejected

- **GIVEN** a target row whose raw `partner_typ` is null or outside `kunde`/`lieferant`
- **WHEN** a keyed payment is called
- **THEN** it returns typed `unknownDirection` and changes no accounting state

### Requirement: Public typed errors have stable codes and deterministic precedence

The public `ForderungenException` API MUST expose a closed `ForderungenErrorCode` set, an immutable ordered
`mismatchFields` list, and an optional underlying `cause`. Stable codes MUST include `invalidRequest`, `amountScale`,
`dateFormat`, `unknownDirection`, `idempotencyConflict`, `legacyFingerprintUnknown`, `alreadyClosed`,
`concurrentWriteConflict`, and `schemaMigrationFailed`. For keyed payment validation, invalid key/amount/target
errors precede scale errors, scale errors precede date errors, date errors precede direction errors, and replay
classification runs only after those validations pass. Public wire serialization MUST use an explicit mapping and MUST
never derive values from `enum.name`. The constructor MUST copy any supplied mismatch-field list and expose an
unmodifiable list, so later source-list mutation cannot alter the exception and callers cannot mutate its fields.
`ForderungenException.toString()` MUST return the original human-readable `message` exactly, without adding the error
code, wire value, mismatch fields, or raw SQL text.

The required `ForderungenErrorCode` wire mapping is exactly:
`invalidRequest` = `invalid_request`, `amountScale` = `amount_scale`, `dateFormat` = `date_format`,
`unknownDirection` = `unknown_direction`, `idempotencyConflict` = `idempotency_conflict`,
`legacyFingerprintUnknown` = `legacy_fingerprint_unknown`, `alreadyClosed` = `already_closed`,
`concurrentWriteConflict` = `concurrent_write_conflict`, and `schemaMigrationFailed` = `schema_migration_failed`.
The required mismatch-field wire mapping is exactly:
`requestedCents` = `requested_cents`, `forderungTarget` = `forderung_target`, `direction` = `direction`,
`datePolicy` = `date_policy`, and `effectiveDate` = `effective_date`.

#### Scenario: A typed idempotency conflict exposes stable ordered fields

- **GIVEN** a key differs in requested cents, target, date policy, and effective date but not direction
- **WHEN** the key is replayed
- **THEN** the exception code is `idempotencyConflict` and `mismatchFields` is exactly `[requestedCents, forderungTarget, datePolicy, effectiveDate]` in that order

#### Scenario: Every public error code uses its explicit stable snake-case wire value

- **GIVEN** all public `ForderungenErrorCode` and `ForderungenMismatchField` values
- **WHEN** each value is serialized for the public error payload
- **THEN** serialization equals the complete explicit mappings above, including `schema_migration_failed` and `effective_date`, and never depends on the enum member name

#### Scenario: A typed error defensively copies immutable mismatch fields

- **GIVEN** a mutable source list containing `[requestedCents, effectiveDate]`
- **WHEN** a `ForderungenException` is constructed with that list and the source list is subsequently changed, then the exception list is mutated directly
- **THEN** the exception still contains exactly `[requestedCents, effectiveDate]`, the source-list change has no effect, and direct mutation of `exception.mismatchFields` throws an unsupported-operation error

#### Scenario: A typed error preserves its human-readable toString message

- **GIVEN** a `ForderungenException` with message `Zahlung bereits verbucht` and any typed code/fields
- **WHEN** `exception.toString()` is called
- **THEN** it returns exactly `Zahlung bereits verbucht` and does not append code, wire values, mismatch fields, or SQL details

#### Scenario: Invalid request errors take precedence over date and direction errors

- **GIVEN** a blank key or malformed amount, an invalid explicit date, and an unknown target direction
- **WHEN** the keyed payment is called
- **THEN** the exception code is `invalidRequest` and no date/direction lookup or accounting mutation occurs

#### Scenario: Amount scale errors take precedence over date errors

- **GIVEN** a finite positive double whose canonical decimal text has more than two fractional digits, plus an invalid explicit date
- **WHEN** the keyed payment is called
- **THEN** the exception code is `amountScale` and no date/direction lookup or accounting mutation occurs

#### Scenario: Date errors precede unknown-direction errors

- **GIVEN** a valid two-decimal amount, an explicit timestamp/impossible calendar date, and a target with unknown partner type
- **WHEN** the keyed payment is called
- **THEN** the exception code is `dateFormat` and no direction lookup or accounting mutation occurs

#### Scenario: Valid amount and date expose unknown direction

- **GIVEN** a valid two-decimal amount and valid date targeting a row whose raw partner type is unknown
- **WHEN** the keyed payment is called
- **THEN** the exception code is `unknownDirection` and no journal, relation, or balance changes occur

### Requirement: Idempotent replay is fingerprint-safe

When a key already identifies a complete fingerprint, an identical fingerprint MUST return the original payment effect and MUST create no additional journal, relation, or balance mutation. All five fields (requested cents, target, derived direction, date policy, and effective date) MUST be compared inside the transaction. A mismatch MUST return a typed `idempotencyConflict` containing an immutable mismatch-field list in stable order (`requestedCents`, `forderungTarget`, `direction`, `datePolicy`, `effectiveDate`) and MUST leave all accounting state unchanged. Production payment and write-off transactions MUST use `BEGIN IMMEDIATE`; only a `@visibleForTesting` transaction-factory override may open `BEGIN DEFERRED`, and only for the initial payment attempt in the deferred WAL busy-snapshot or observed-balance fixtures. Migration and schema startup use the shared `MigrationRunner` path with raw `BEGIN`/`COMMIT`/`ROLLBACK` matching `migrations.dart`; no production migration transaction delegate is exposed. Post-error payment reloads use the production immediate runner.

#### Scenario: An identical key and fingerprint returns the original effect

- **GIVEN** key `bank-2` already committed a 4,000-cent payment to Forderung 11 on `2026-09-29` with direction `incoming` and policy `explicit`
- **WHEN** the same key is retried with the identical canonical request
- **THEN** the command returns the original post-payment Forderung effect and the database still has one keyed `zahlung` relation, one payment journal, and the same balance

#### Scenario: A reused key with a different amount is a typed conflict

- **GIVEN** key `bank-3` already committed 4,000 cents to Forderung 11
- **WHEN** it is retried for 5,000 cents
- **THEN** the command returns `idempotencyConflict` with `requestedCents` as a mismatch and journal count, payment-relation count, and balance remain unchanged

#### Scenario: A reused key with a different target is a typed conflict

- **GIVEN** key `bank-4` already committed to Forderung 11
- **WHEN** it is retried against Forderung 12 with the other fingerprint fields unchanged
- **THEN** the command returns `idempotencyConflict` with `forderungTarget` as a mismatch and no journal, relation, or balance changes occur on either Forderung

#### Scenario: A reused key with a different effective date or date policy is a typed conflict

- **GIVEN** key `bank-5` already committed with effective date `2026-09-29` and policy `explicit`
- **WHEN** it is retried with `2026-09-30`, or with an omitted date that resolves to a different policy
- **THEN** the command returns `idempotencyConflict` with date metadata and creates no new accounting effect

#### Scenario: Concurrent identical keyed requests commit one effect

- **GIVEN** two repository instances submit the same new key and identical fingerprint concurrently
- **WHEN** both commands complete
- **THEN** both callers observe the same original effect, exactly one payment journal and keyed `zahlung` relation commit, and the balance is reduced once

#### Scenario: A concurrent conflicting key race reloads the loser and has no side effects

- **GIVEN** separate executors in the permitted WAL deferred fixture submit the same new key behind a barrier after both initial `BEGIN DEFERRED` transaction-local key lookups miss; request A is 4,000 cents to customer Forderung 11 with explicit date `2026-09-29`, and request B is 5,000 cents to supplier Forderung 12 with an omitted date resolved to UTC day `2026-09-30`
- **WHEN** the barrier releases A to commit before B proceeds and both commands complete
- **THEN** A succeeds, B rolls back its deferred loser transaction and reloads A's committed row with production `BEGIN IMMEDIATE` after the unique-key or snapshot race, then returns `idempotencyConflict` with exactly `[requestedCents, forderungTarget, direction, datePolicy, effectiveDate]`; B creates no journal or relation, neither target has a loser balance change, and the database contains only A's one payment effect
- **AND** production payment dependency wiring continues to use `BEGIN IMMEDIATE`; the deferred override is confined to this red fixture

#### Scenario: A deferred WAL SQLITE_BUSY_SNAPSHOT loser reloads and classifies a conflicting key

- **GIVEN** two pre-opened repositories use a WAL-mode file database; a test-only transaction-factory override opens B's initial payment attempt with `BEGIN DEFERRED`, B's key lookup misses, and A uses the production `BEGIN IMMEDIATE` runner to commit a different fingerprint before B's first write
- **WHEN** B's stale write receives extended SQLite error `SQLITE_BUSY_SNAPSHOT` and both commands complete
- **THEN** B rolls back the stale transaction, reloads A's committed row in a fresh production `BEGIN IMMEDIATE` transaction, returns `idempotencyConflict` rather than `concurrentWriteConflict` with exactly `[requestedCents, forderungTarget, direction, datePolicy, effectiveDate]`, and leaves journal count, relation count, and both balances unchanged beyond A's one effect
- **AND** the override is never used for migration, startup/schema setup, write-off, or any production dependency path

#### Scenario: A persistent SQLite lock exhausts exactly three bounded retries

- **GIVEN** both repositories have completed executor/schema/fixture setup and the pre-attempt snapshot before one file-backed executor holds a persistent SQLite `BEGIN EXCLUSIVE` lock while the other submits a new keyed payment and records each transaction attempt
- **WHEN** the lock remains held through the retry window and the payment command completes
- **THEN** the attempt record is exactly `[1, 2, 3]`, no `ensureSchema`/DDL/PRAGMA/seed SQL runs during those attempts, the command returns typed `concurrentWriteConflict`, and journal count, keyed relation count, and Forderung balance are unchanged from the pre-attempt snapshot after the lock is released

### Requirement: Legacy payment rows have an explicit unknown-fingerprint policy

The v7-to-v8 migration MUST be owned by MigrationRunner and run inside its existing backup/migration transaction. Fresh schema creation, v7 upgrade, and repair of a present current-version payment table MUST use the shared transaction path: raw executor.runCustom('BEGIN'), followed by COMMIT on success or ROLLBACK on failure. The v7-to-v8 migration MUST create forderung_zahlungen when absent, add nullable fingerprint columns when an accepted legacy v7 table exists, repair missing unique non-null key/journal constraints, and verify them before setting user_version to 8. Before a current-version repair or any later migration could recreate forderung_zahlungen, startup MUST compare its presence with PRAGMA user_version. If user_version is 8 or greater and the table is absent, startup MUST stop before repair, preserve the original database, leave the table absent as a durable schema-health/completeness signal, mark the profile unavailable for complete export, and return the accepted typed schema-migration failure. It MUST NOT create an empty replacement table automatically. A present table with a repairable schema or constraint defect MAY be repaired only transactionally and while preserving all existing rows; failed or unverifiable repair MUST roll back. Fresh database creation MUST create and verify the table. AppDatabase.ensureOpen MUST invoke the feature-schema callback after the existing 39 AppDatabase.allTableNames tables have been created or migrated and before triggers, seeds, repository hooks, _opened = true, or service exposure. The shared feature_table_state database-health table is separate from that legacy 39-name list and is introduced by the coordinated v13 migration. The payment table remains feature-owned and excluded from the 39-name list. Existing relation, journal, amount, type, key, and date values MUST be preserved. Rows with a non-null key and any missing fingerprint field MUST be classified as legacy-unknown; the migration MUST NOT infer requested cents or direction from applied amount or partner data. A key colliding with such a row MUST return typed legacyFingerprintUnknown without mutation. Keyless legacy rows remain readable historical effects and do not participate in keyed replay. Failed DDL or duplicate-constraint repair MUST roll back columns, indexes, rows, and user_version.

#### Scenario: A v7 lazy table migrates without changing legacy rows

- **GIVEN** a profile at PRAGMA user_version = 7 has a lazy forderung_zahlungen table and rows without fingerprint columns
- **WHEN** the profile opens through the migration runner
- **THEN** schema version becomes 8, nullable fingerprint columns exist, every legacy row keeps its original values, and keyed legacy rows are classified legacy-unknown

#### Scenario: A missing v7 relation table is created safely

- **GIVEN** a v7 profile has forderungen and journals but no forderung_zahlungen table
- **WHEN** the normal v7-to-v8 migration opens the profile
- **THEN** the relation table, foreign keys, unique journal constraint, and unique non-null key constraint exist before a payment command runs
- **AND** no fabricated historical payment rows are created

#### Scenario: A present v7 relation table repairs missing constraints

- **GIVEN** a v7 profile has forderung_zahlungen and legacy rows but its unique indexes are absent
- **WHEN** the profile opens
- **THEN** the migration creates the unique journal and non-null key constraints and preserves every row value
- **AND** the legacy AppDatabase.allTableNames count remains 39

#### Scenario: A duplicate legacy key rolls the migration back

- **GIVEN** a v7 profile has duplicate non-null legacy keys that cannot satisfy the new unique constraint
- **WHEN** migration attempts constraint repair
- **THEN** it returns typed schemaMigrationFailed, leaves PRAGMA user_version = 7, preserves the original columns and rows, and leaves no partial fingerprint columns or indexes

#### Scenario: A migration failure preserves the base table count

- **GIVEN** a v7 profile whose feature migration is forced to fail after a DDL step
- **WHEN** the profile open is rolled back
- **THEN** its 39 existing base tables, feature table, rows, and user_version remain at their pre-migration state
- **AND** no service is exposed

#### Scenario: AppDatabase post-DDL failure rolls back before startup side effects

- **GIVEN** a v7 profile with its 39 existing base tables and no forderung_zahlungen table, opened with an injected afterFeatureSchemaDdl callback that records feature DDL and throws
- **WHEN** AppDatabase.ensureOpen runs the v7-to-v8 migration
- **THEN** the callback observes the feature table before failure, no triggers or seed rows are installed, isOpen and service getters remain unavailable, PRAGMA user_version remains 7, and the feature table/columns/indexes are absent after rollback
- **AND** the failure is surfaced as typed schemaMigrationFailed without requiring raw SQL text in the public message

#### Scenario: A current v8 profile repairs a missing feature table transactionally

- **GIVEN** a profile at PRAGMA user_version 8 or later has the 39 existing base tables but no forderung_zahlungen table
- **WHEN** AppDatabase.ensureOpen is asked to run current-version feature repair
- **THEN** the pre-repair health check stops initialization before the repair transaction can create a replacement table
- **AND** the original database and user_version remain unchanged, the payment table remains absent, and no triggers, seeds, or services are exposed
- **AND** complete export remains unavailable until verified restore or repair because the missing table remains observable
- **AND** no empty replacement table is created automatically

#### Scenario: A current-version repair preserves a present payment table

- **GIVEN** a profile at PRAGMA user_version 8 or later has forderung_zahlungen present with legacy rows but is missing repairable fingerprint columns or unique constraints
- **WHEN** AppDatabase.ensureOpen runs the current-version feature repair
- **THEN** one repair transaction adds or repairs the declared schema while preserving all existing row values
- **AND** schema health passes only after columns and constraints are verified

#### Scenario: Fresh startup, schema upgrade, current-v8 repair, and rollback share the raw-BEGIN migration path

- **GIVEN** recording fixtures for an empty profile, a v7 profile with and without forderung_zahlungen, a v8-or-later profile with a present table needing repair, a v8-or-later profile with the table missing, and a feature-DDL failure after DDL but before commit
- **WHEN** each fixture opens through AppDatabase.ensureOpen
- **THEN** fresh creation, the v7 upgrade, and present-table repair use the shared raw BEGIN followed by COMMIT, while an injected DDL failure uses raw BEGIN followed by ROLLBACK
- **AND** the v8-or-later missing-table fixture stops before repair DDL, preserves its table absence and user_version, and exposes no triggers, seeds, or services
- **AND** no fixture requires BEGIN IMMEDIATE, a separate transaction factory, or an unsupported production delegate

#### Scenario: A request cannot claim a legacy key

- **GIVEN** a legacy row has idempotency key legacy-1 but no reconstructible fingerprint
- **WHEN** a new keyed payment uses legacy-1
- **THEN** the command returns typed legacyFingerprintUnknown and journal count, relation count, and Forderung balances remain unchanged

### Requirement: Write-off and payment transitions are conditional and atomic

Write-off MUST validate the reason and current open state inside one transaction. The state transition MUST use `WHERE id = ? AND status = ? AND betrag = ?` with the observed status and cents and MUST affect exactly one row from `offen` or `teilbezahlt` with a positive balance to `ausgebucht` and zero balance. A zero-row conditional transition MUST return typed `alreadyClosed`; the loss journal and `ausbuchen` relation MUST roll back. A successful write-off MUST commit exactly one loss journal, one linked relation, and the state transition together. Payment state transitions MUST use the same conditional id/status/observed-balance predicate for partial, full, and existing overpayment branches so a full payment racing a write-off leaves one closing effect and no orphan journal or relation. SQLite lock retries MUST be bounded to three transaction attempts. The payment observed-balance interleaving MUST be exercised through a dedicated post-read/pre-update test seam, and write-off lock counting MUST use a separate transaction-attempt seam after setup.

#### Scenario: A valid write-off commits one loss effect

- **GIVEN** an open Forderung has 7,500 cents remaining and reason `uneinbringlich`
- **WHEN** one write-off command commits
- **THEN** the Forderung is `ausgebucht` with zero balance and exactly one `Ausbuchung` journal and one linked `ausbuchen` relation store 7,500 cents

#### Scenario: A second simultaneous write-off returns already-closed

- **GIVEN** two repository instances write off the same open Forderung concurrently with valid reasons
- **WHEN** both commands complete
- **THEN** one succeeds, the other returns typed `alreadyClosed`, and exactly one loss journal and relation are committed

#### Scenario: Write-off and full payment race without an orphan

- **GIVEN** an open 7,500-cent Forderung and concurrent full payment and write-off commands
- **WHEN** both commands complete
- **THEN** exactly one command commits the closing state/effect, the loser returns a typed already-closed conflict, and every committed journal has exactly one corresponding relation with no balance mismatch

#### Scenario: Invalid reason or already-closed state has no write-off effect

- **GIVEN** a Forderung is already `bezahlt` or `ausgebucht`, or the reason is blank
- **WHEN** a write-off command is called
- **THEN** it returns a typed validation/already-closed error and inserts no loss journal or `ausbuchen` relation

#### Scenario: A conditional payment update detects an observed-balance race

- **GIVEN** the production payment runner remains `BEGIN IMMEDIATE`, while a test-only deferred WAL fixture opens only the initial payment attempt with `BEGIN DEFERRED`; its dedicated interleaving seam suspends after observing an open status/balance and another pre-opened executor commits a competing Forderung transition
- **WHEN** the first payment resumes and its stale conditional update reports extended `SQLITE_BUSY_SNAPSHOT` code 517
- **THEN** the attempted update is bound to the original id/status/observed-balance values, the command rolls back that attempt, reloads with production `BEGIN IMMEDIATE`, returns typed `alreadyClosed`, and every provisional payment/overpayment journal and relation is absent while the competing state is the only persisted effect

#### Scenario: An ordinary zero-row conditional payment update is already-closed for every branch

- **GIVEN** a production `BEGIN IMMEDIATE` payment uses a recording executor seam that returns `runUpdate == 0` after binding Forderung id `11`, observed status `offen`, and observed balance `7500` cents
- **WHEN** each partial, full, and existing overpayment branch reaches its conditional update
- **THEN** every branch records the original `id/status/betrag` predicate with bound values, returns typed `alreadyClosed`, rolls back all provisional payment/overpayment journals and relations, and leaves the balance and pre-test journal/relation counts unchanged

#### Scenario: A persistent SQLite lock exhausts exactly three write-off retries

- **GIVEN** both write-off repositories have completed executor/schema/fixture setup and the pre-attempt Forderung/journal/relation snapshot before one file-backed executor holds `BEGIN EXCLUSIVE`
- **WHEN** the other repository submits a valid write-off while the lock remains held through all retries
- **THEN** the write-off attempt record is exactly `[1, 2, 3]`, no `ensureSchema`/DDL/PRAGMA/seed SQL runs during those attempts, it returns typed `concurrentWriteConflict`, and after lock release the Forderung status/balance and loss-journal/relation counts are unchanged
