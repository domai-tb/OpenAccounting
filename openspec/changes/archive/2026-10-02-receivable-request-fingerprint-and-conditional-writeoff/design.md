## Context

`zahlungBuchen` currently performs an early key lookup, then inserts a journal and relation inside a transaction. The lookup returns by key alone, so amount, target, direction, and date changes are accepted as replay. `ausbuchen` reads the Forderung before `beginTransaction`, inserts its loss journal, and unconditionally updates the row. The relation table is created only by `ForderungenRepository.ensureSchema`; the current `MigrationRunner.currentVersion` is 7 and v7 does not migrate this lazy table.

## Goals / Non-Goals

**Goals:**

- Make keyed payment replay compare a persisted, canonical fingerprint.
- Keep conflicting replay side-effect free, including when the conflict is discovered after a unique-key race.
- Make write-off state validation and the state transition transaction-local and conditional.
- Prove races with real SQLite/Drift executors and leave no orphan journal/relation.
- Give v7 profiles a transactional schema owner and a conservative legacy-row policy.

**Non-Goals:**

- Overpayment allocation, credit-item creation, refund, Gutschrift, or document-sign policy.
- Bank matching or UI exposure.
- Reconstructing historical requested amounts, directions, or fingerprints from legacy rows.

## Decisions

### Canonical fingerprint

The keyed `zahlung` row stores `requested_betrag_cents INTEGER`, the existing `forderung_id`, `fingerprint_direction TEXT`, `fingerprint_date_policy TEXT`, and the existing `datum` as the canonical effective date. The tuple is `(requested_betrag_cents, forderung_id, fingerprint_direction, fingerprint_date_policy, datum)`. Amount parsing uses the existing `money` helper at scale 2 with `roundExcess: false`: a request such as `1.005` is rejected with `amountScale` rather than silently rounded. Dates are strict calendar dates in `YYYY-MM-DD`; an explicit input uses `explicit`, and a missing input resolves once to the injected clock's UTC request day with `request-day`. Timestamp strings and impossible dates are rejected with `dateFormat`. The direction is derived from the raw row (`kunde` → `incoming`, `lieferant` → `outgoing`) and is never accepted from the caller; null/unknown partner types return `unknownDirection` instead of `_fromRow`'s display fallback.

The command validates the target and derives the tuple inside the payment transaction. Existing `betrag` remains the applied payment amount for statement arithmetic; `requested_betrag_cents` records what the keyed caller requested. The existing overpayment branch stays outside this change and receives no new credit-item semantics, but it still uses the same conditional state update and rollback rules.

`num` remains the public amount parameter for compatibility, but conversion is decimal-text based: an `int` is converted with its exact base-10 string, and a `double` is converted with Dart's shortest round-trip `toString()` decimal representation. The implementation MUST parse that text with `money.parseScaled(scale: 2, roundExcess: false)` before any arithmetic, never use `toStringAsFixed`, binary multiplication, epsilon comparison, or silent rounding. Thus `1.10`/`1.1` is the exact one-decimal request, while `0.1 + 0.2` produces `0.30000000000000004` and is rejected as `amountScale`; no binary residue is hidden by the accounting boundary.

Validation precedence for a keyed request is fixed and testable: (1) blank key, malformed/non-finite amount text, non-positive amount, or invalid target id returns `invalidRequest`; (2) a syntactically valid amount with more than two fractional digits returns `amountScale`; (3) an explicit timestamp or impossible calendar date returns `dateFormat`, while an omitted date uses the injected clock's UTC day; (4) a missing target returns `invalidRequest`, and a present target whose raw partner type is not `kunde`/`lieferant` returns `unknownDirection`; (5) only after all request fields are valid does key lookup produce replay, legacy-unknown, or idempotency-conflict results. This precedence means a bad amount wins over a bad date, and a bad date wins over an unknown direction.

### Replay and race protocol

The payment command begins its transaction before reading a keyed row. Every fingerprint field is compared from the transaction-local row before any journal insert: requested cents, target, direction, date policy, and effective date. A complete matching row returns the previously committed effect. A complete mismatching row throws `idempotencyConflict` with a stable mismatch-field list ordered as `requestedCents`, `forderungTarget`, `direction`, `datePolicy`, `effectiveDate`. A unique-key insert race rolls back the losing transaction, reloads the committed row, and follows the same comparison path; it never returns by key alone. Retry SQLite `busy`/`locked` failures at most three transaction attempts (10 ms then 25 ms backoff); after the bound, return typed `concurrentWriteConflict` with no effect. All conflict paths occur before journal/balance mutation or roll back the entire attempted transaction. A unique non-null key and unique journal foreign key remain database constraints.

Executor opening, PRAGMAs, `AppDatabase.ensureOpen`, `ForderungenRepository.ensureSchema`, schema/index setup,
fixture seeding, dependency wiring, and request validation/canonicalization setup MUST complete in one preflight before
the payment or write-off retry loop starts. The commands MUST NOT call `ensureSchema`, DDL, PRAGMA, seed, service, or
other SQL setup inside an attempt or once per retry; an API guard may only observe an already-completed preflight and
must not issue SQL. They MUST NOT invoke `onPaymentTransactionAttempt` or `onWriteoffTransactionAttempt` for setup.
The retry loop begins at the transaction boundary only; a failed `BEGIN` or transaction body is one attempt. If a
database lock is held, harmless in-memory work such as immutable request parsing, validation, backoff bookkeeping, and
attempt counters may run, but it MUST issue no SQL, open no setup transaction, and mutate no accounting state. Lock
fixtures record one preflight before acquiring the lock and zero setup statements during all attempts.

The production transaction runner uses `BEGIN IMMEDIATE` for payment and write-off attempts. The repository accepts a
test-only `@visibleForTesting` transaction-factory override with this contract:

```dart
enum ForderungenTransactionKind { payment, writeoff }

abstract interface class ForderungenTransactionFactory {
  Future<T> run<T>({
    required ForderungenTransactionKind kind,
    required int attempt,
    required QueryExecutor executor,
    required Future<T> Function(QueryExecutor transaction) action,
  });
}
```

When no override is supplied, the production factory starts `BEGIN IMMEDIATE`, commits on success, and rolls back on
any error. The WAL busy-snapshot, observed-balance, and conflicting-key barrier fixtures inject an override through
the test constructor for their initial payment attempt(s) only; it starts those test attempts with `BEGIN DEFERRED`,
while competing commits and all post-error loser reloads use the production `BEGIN IMMEDIATE` runner. The override is
accepted only by the payment fixture and is never passed to `MigrationRunner`, `AppDatabase.ensureOpen`,
`ensureSchema`, startup, or write-off paths. It is a fixture seam for reproducing SQLite's snapshot behavior, not a
runtime configuration or a change to production lock semantics.

For the executable lock test, `ForderungenRepository` exposes an optional `@visibleForTesting` synchronous
`void Function(int attempt)? onPaymentTransactionAttempt` seam. It is called exactly once immediately before each
payment transaction attempt, with one-based attempt numbers, after all setup has completed. The fixture opens both
repositories, runs `ensureOpen`/`ensureSchema`, seeds the Forderung, and takes the pre-attempt journal/relation/balance
snapshot before acquiring the lock. One separate file-backed SQLite executor then holds a persistent `BEGIN EXCLUSIVE`
lock while the other submits a new keyed payment and keeps the lock until the command finishes. The callback MUST
observe exactly `[1, 2, 3]`; setup work must not add an observation. The command MUST return
`concurrentWriteConflict`, and after releasing the lock the test MUST observe unchanged journal count, keyed relation
count, and Forderung balance compared with the pre-attempt snapshot. No provisional row may survive the failed
attempts.

For the executable conflicting-key race test, the repository exposes an optional `@visibleForTesting`
`Future<void> Function(String idempotencyKey)? afterFingerprintMissBeforeInsert` seam. It is called after the
transaction-local lookup observes no row for the key and before the first journal/relation insert. This barrier test
uses the permitted WAL fixture override for both initial payment attempts, so both requests can observe the miss under
`BEGIN DEFERRED`; it then releases request A to commit before request B proceeds. Production commands remain
`BEGIN IMMEDIATE`, and B's post-error loser reload is a fresh production-immediate transaction. Request A is 4,000
cents to customer Forderung 11 with explicit date `2026-09-29`; request B is 5,000 cents to supplier Forderung 12
with an omitted date resolved by an injected UTC day of `2026-09-30`. B's unique-key or snapshot loser MUST reload A's
committed row and return `idempotencyConflict` with exactly
`[requestedCents, forderungTarget, direction, datePolicy, effectiveDate]`. The loser MUST add no journal or relation
and change neither target balance; the final database MUST contain exactly the winner's one payment journal/relation
and only Forderung 11's balance change. The override MUST never be used by production dependency wiring.

SQLite WAL fixtures MUST also cover the extended `SQLITE_BUSY_SNAPSHOT` path (extended result code 517). The test-only
factory explicitly opens the loser's initial payment attempt with `BEGIN DEFERRED`; production and the subsequent
reload remain `BEGIN IMMEDIATE`. The deferred loser transaction reads the missing key, the winner commits a different
fingerprint, and the loser then attempts its first write from the stale snapshot. On `SQLITE_BUSY_SNAPSHOT`, the
command MUST roll back the stale transaction and open a fresh transaction to reload the committed key before applying
generic lock retry handling. The reloaded row is compared with all five fingerprint fields: a mismatch returns
`idempotencyConflict` with the ordered list
`[requestedCents, forderungTarget, direction, datePolicy, effectiveDate]`, while an identical request returns the
original effect. The extended code MUST NOT be matched by error-message text or mapped directly to
`concurrentWriteConflict`; the loser must leave journal, relation, and both balances unchanged.

Extend `ForderungenException` with this public typed API while preserving human-readable messages for existing callers:

```dart
enum ForderungenErrorCode {
  invalidRequest,
  amountScale,
  dateFormat,
  unknownDirection,
  idempotencyConflict,
  legacyFingerprintUnknown,
  alreadyClosed,
  concurrentWriteConflict,
  schemaMigrationFailed,
}

enum ForderungenMismatchField { requestedCents, forderungTarget, direction, datePolicy, effectiveDate }

class ForderungenException implements Exception {
  ForderungenException(
    this.message, {
    this.code = ForderungenErrorCode.invalidRequest,
    List<ForderungenMismatchField> mismatchFields = const <ForderungenMismatchField>[],
    this.cause,
  }) : mismatchFields = List<ForderungenMismatchField>.unmodifiable(mismatchFields);

  final String message;
  final ForderungenErrorCode code;
  final List<ForderungenMismatchField> mismatchFields;
  final Object? cause;

  @override
  String toString() => message;
}
```

The public wire serializer MUST use these explicit maps, never `Enum.name` or another language-derived spelling:

```dart
const Map<ForderungenErrorCode, String> forderungenErrorCodeWireValues = <ForderungenErrorCode, String>{
  ForderungenErrorCode.invalidRequest: 'invalid_request',
  ForderungenErrorCode.amountScale: 'amount_scale',
  ForderungenErrorCode.dateFormat: 'date_format',
  ForderungenErrorCode.unknownDirection: 'unknown_direction',
  ForderungenErrorCode.idempotencyConflict: 'idempotency_conflict',
  ForderungenErrorCode.legacyFingerprintUnknown: 'legacy_fingerprint_unknown',
  ForderungenErrorCode.alreadyClosed: 'already_closed',
  ForderungenErrorCode.concurrentWriteConflict: 'concurrent_write_conflict',
  ForderungenErrorCode.schemaMigrationFailed: 'schema_migration_failed',
};

const Map<ForderungenMismatchField, String> forderungenMismatchFieldWireValues = <ForderungenMismatchField, String>{
  ForderungenMismatchField.requestedCents: 'requested_cents',
  ForderungenMismatchField.forderungTarget: 'forderung_target',
  ForderungenMismatchField.direction: 'direction',
  ForderungenMismatchField.datePolicy: 'date_policy',
  ForderungenMismatchField.effectiveDate: 'effective_date',
};
```

Both maps MUST contain every public enum value exactly once, and serialization tests MUST assert the complete maps and
their values so an enum rename cannot silently change the wire contract. The exception constructor MUST defensively
copy the supplied mismatch list and expose an unmodifiable list: mutating the caller's source list after construction
cannot change the exception, and attempting to mutate `exception.mismatchFields` throws. `mismatchFields` is ordered
exactly as listed, and is empty for every code except `idempotencyConflict`. Feature DDL, index-repair, or injected
post-DDL failures are caught at the Forderungen schema boundary and mapped to `schemaMigrationFailed` (with the
original error retained only in `cause`); `AppDatabase.ensureOpen` propagates that typed error without exposing raw
SQL text. A payment lock exhaustion maps to `concurrentWriteConflict`, while a payment unique-key collision is handled
by reload/compare and never mapped as a migration error.

### Conditional write-off and cross-command race

Inside one transaction, validate the trimmed reason, load the current row, and allow only `offen`/`teilbezahlt` with positive cents. Insert the loss journal and relation, then update with `WHERE id = ? AND status = ? AND betrag = ?`, binding the observed status and canonical observed cents. Require `runUpdate` to affect exactly one row (zero is `alreadyClosed`; anything other than one is `schemaMigrationFailed`), and rollback removes the just-created journal/relation. Payment applies the same exact predicate for every branch: partial (`teilbezahlt`, observed minus requested), full (`bezahlt`, zero), and overpayment (`bezahlt`, zero plus the existing excess journal/relation). The payment conditional compare-and-set runs before any provisional payment/overpayment write, so a stale snapshot or lost race fails on the conditional update itself and no provisional row is ever left behind; a zero-row payment update therefore leaves no provisional rows and returns `alreadyClosed`. The closing `ausgleich_journal_id` link is applied by a follow-up update inside the same transaction after the closing journal insert, because the foreign key requires the journal row to exist first. Separate repository instances over separate executors race in tests; the implementation must use the same bounded three-attempt lock retry and never retry after a committed effect.

For the observed-balance payment interleaving, `ForderungenRepository` exposes an optional
`@visibleForTesting` callback
`Future<void> Function(int forderungId, String observedStatus, int observedBalanceCents)? afterPaymentStateReadBeforeConditionalUpdate`.
The production payment runner remains `BEGIN IMMEDIATE` and does not use this interleaving to admit a competing
commit. The red fixture injects the deferred payment transaction factory only for the initial payment attempt, calls
this callback once after the transaction-local state read and before any provisional payment/overpayment journal or
relation insert, and commits a competing transition through a second pre-opened executor while the first deferred
snapshot is paused. When the first command resumes, its attempted conditional update MUST bind the original id,
status, and cents; the fixture records the stale `SQLITE_BUSY_SNAPSHOT` result (517), the command rolls back that
attempt, reloads with production `BEGIN IMMEDIATE`, and returns typed `alreadyClosed` after observing the competing
state. The red assertions MUST cover the observed status/cents passed to the seam, the competitor's committed state,
the `alreadyClosed` result, and unchanged payment journal/relation counts (no provisional rows). The ordinary
zero-affected-row conditional branch remains required for non-snapshot races; this fixture exists only to make the
otherwise impossible competing commit deterministic without weakening production locking.

The ordinary conditional-update red test uses the production `BEGIN IMMEDIATE` runner and a narrowly scoped recording
executor seam that lets the conditional `runUpdate` execute with its bound arguments but returns affected-row count
`0`. It runs the partial, full, and existing overpayment branches against Forderung id `11`, observed status
`offen`, and observed balance `7500` cents. For every branch, the recorded predicate MUST be exactly
`WHERE id = 11 AND status = 'offen' AND betrag = 7500` (with bound parameters, not interpolated SQL); the
`betrag = 7500` value denotes the observed balance of 7500 cents and is bound as its canonical decimal text
`'75.00'` (the column stores decimal amounts, so integer cents would not match), never interpolated; the command MUST
return typed `alreadyClosed`, roll back every provisional payment/overpayment journal and relation, and leave the
balance and pre-test counts unchanged. This seam does not alter production locking or the deferred snapshot fixture.

Write-off retries have a separate optional `@visibleForTesting` synchronous
`void Function(int attempt)? onWriteoffTransactionAttempt` seam. It is invoked only at the transaction boundary after
executor/schema/fixture setup, with one-based attempts. A file-backed fixture holding `BEGIN EXCLUSIVE` through the
entire command MUST observe exactly `[1, 2, 3]`, receive typed `concurrentWriteConflict`, and find unchanged
Forderung status/balance and loss-journal/relation counts after lock release.

### Version 7 to version 8 migration ownership and startup ordering

The current v7 lazy table is not treated as evidence that fingerprints can be backfilled. Raise `MigrationRunner.currentVersion` to 8. `MigrationRunner` owns the v7→v8 DDL: its `_migrateTo(8)` creates `forderung_zahlungen` if absent, adds the three nullable fingerprint columns if missing, repairs the unique non-null key and journal constraints, and verifies the result inside the existing backup/migration transaction. `MigrationRunner` MUST use one shared migration transaction path matching the current raw source form `await executor.runCustom('BEGIN')`, followed by `COMMIT` on success or `ROLLBACK` on any error; the path is immediate startup work but deliberately retains SQLite's raw `BEGIN` text. Fresh schema creation, v7 upgrade, and current-v8 feature repair all use this same helper. `MigrationRunner.run` accepts a feature-schema callback and invokes the same callback inside the fresh-schema transaction before setting `user_version = 8`; this gives fresh profiles and upgraded v7 profiles one schema owner. No production migration transaction factory/delegate is claimed or injected.

`AppDatabase.forTesting` receives an optional `afterFeatureSchemaDdl` callback with the signature `Future<void> Function(QueryExecutor executor)`. `ensureOpen` passes it to `MigrationRunner` immediately after feature DDL/index verification and before any `PRAGMA user_version` write, trigger installation, seed insertion, repository hooks, `_opened = true`, or service exposure. The callback is an injected failure seam, not a production behavior: a test callback records that the feature table/columns exist, then throws. The test asserts callback observation, no GoBD/rechnung triggers, no seed rows, `isOpen == false` and throwing service getters, exactly 39 base tables, no feature-table/column/index residue, and `PRAGMA user_version = 7`. This makes callback-before-triggers/seeds/services and rollback executable rather than inferred from source order.

`AppDatabase.ensureOpen` ordering is fixed: open executor and PRAGMAs → `MigrationRunner.run` with the base 39-table creator and Forderungen feature-schema callback → verify feature schema and `user_version` → install triggers and seeds → run repository additive schema hooks → set `_opened = true` and expose services. The callback is idempotent for table-present, table-absent, and partially indexed v7 fixtures. A current v8 database missing the feature table enters the same shared raw-`BEGIN`/`COMMIT`/`ROLLBACK` migration helper through the feature callback; the table, columns, and indexes are committed before triggers/seeds/services run, while a repair failure rolls back and leaves `user_version = 8` and `isOpen = false`. A duplicate historical key/journal prevents index repair, rolls back all DDL, and surfaces `schemaMigrationFailed` without setting a newer version. The feature table remains outside `AppDatabase.allTableNames`; the base schema assertion stays exactly 39 tables, while focused migration tests assert the feature table separately.

The migration red test uses a recording executor/fixture, not a production transaction delegate. It runs fresh empty-schema
startup, a v7 upgrade, a current-v8 profile missing `forderung_zahlungen`, and injected post-DDL failures through
`AppDatabase.ensureOpen`. Fresh, v7-upgrade, and current-v8-repair success paths MUST each record the shared raw
`BEGIN` followed by `COMMIT`; an injected current-v8 repair failure MUST record raw `BEGIN` followed by `ROLLBACK`.
The assertions also require feature DDL, `user_version`, and rollback to be inside that same path, with triggers, seeds,
repository hooks, and services occurring only after commit. The current-v8 failure must leave `user_version = 8`, the
base 39-table count, and no feature residue unchanged. The fixture MUST fail if migration code requests `BEGIN IMMEDIATE`,
bypasses the shared helper, or exposes a configurable production migration factory.

Rows with any null fingerprint column are `legacy-unknown`. The migration copies no inferred values and changes no historical row. A non-null legacy key is reserved: a request using it returns `legacyFingerprintUnknown`. Keyless legacy rows remain statement-readable and do not match keyed requests. Migration fixtures cover a v7 table present with legacy rows, a v7 table absent, a partially indexed table, duplicate-constraint rollback, and a failed migration that must leave `user_version = 7`, the original row values, and the base 39-table set unchanged. This policy is safe but intentionally loses automatic replay recognition for old keyed rows.

### Platform acceptance

Linux is the executable gate: run all Flutter/Dart commands through FVM, targeted red tests, `fvm flutter analyze`, the VM suite, and `fvm flutter build linux --debug`. macOS and Windows acceptance is static on Linux: run analyzer against the changed Dart files, inspect that no `dart:io`/platform-specific API or dependency was introduced, and record `fvm flutter build macos --config-only` / `fvm flutter build windows --config-only` as unavailable or passing according to the installed SDK. No Linux host run may be reported as a macOS/Windows runtime test.

## Risks / Trade-offs

- **Legacy keyed rows cannot be reconstructed** → keep them immutable and return `legacyFingerprintUnknown`; never guess from applied amount or partner type.
- **SQLite lock timing can vary** → use unique/conditional SQL, transaction rollback, and a bounded three-attempt retry; race tests must assert persisted rows, not only returned exceptions.
- **v8 adds a feature-owned table outside the base table count** → verify table/index presence directly and preserve existing 39-table base-schema assertions.
- **Existing callers compare German messages** → retain messages during the typed-error extension, but new tests assert codes and fields.

## Migration Plan

1. Add red repository/integration tests listed in `test-plan.md`, including v7 database fixtures and `Future.wait` races.
2. Add typed error/fingerprint data contract and make the v7→v8 migration create/upgrade the relation table.
3. Implement keyed replay inside the transaction with compare-on-conflict and conditional payment transition.
4. Implement conditional write-off and cross-command rollback behavior.
5. Refactor SQL/constants, run focused and full Linux FVM gates, then perform static macOS/Windows acceptance.

Rollback is a code revert after a backup. A schema downgrade is unsupported; a failed migration must leave `user_version` and all v7 rows unchanged through the existing migration rollback.

## Open Questions

None for this bounded slice. Product policy for overpayment/credit items and Gutschrift remains a separate decision gate.
