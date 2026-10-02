## Verification Results

### Task Completion

- [x] Implementation and migration tasks completed in the scoped source and test files.
- [x] The 38 red test-plan scenarios are implemented and green; focused execution reports 77 passing tests.
- [x] The feature table is owned by v7→v8 migration/current-v8 repair and remains outside the base 39-table assertion.
- [x] Legacy rows with incomplete fingerprints retain nulls and use the documented `legacyFingerprintUnknown` policy.

### TDD Integrity

- [x] Focused receivable/migration/schema/profile VM tests pass: **77 passed, 0 failed**.
- [x] Full VM suite passes: **804 passed, 0 failed**.
- [x] Conditional payment/write-off tests cover typed conflicts, immutable mismatch fields, bounded retries, rollback,
  race interleavings, no orphan rows, and unchanged balances.
- [x] No out-of-scope Gutschrift, credit-item, refund, or overpayment policy was added beyond the existing behavior.

### Evidence

- `fvm flutter test --dart-define=platform=vm` — **804 passed, 0 failed**.
- `fvm flutter test --dart-define=platform=vm test/features/einkommen/forderungen_request_fingerprint_test.dart test/features/einkommen/forderungen_test.dart test/db/migration_test.dart test/db/receivable_request_migration_test.dart test/db/schema_test.dart test/db/profile_test.dart` — **77 passed, 0 failed**.
- `fvm flutter analyze` — **No issues found**.
- `openspec validate receivable-request-fingerprint-and-conditional-writeoff --strict` — **valid**.
- `openspec validate --specs --strict` — **54 passed, 0 failed**.
- `fvm flutter build linux --debug` — passed; artifact at `build/linux/x64/debug/bundle/openaccounting`.
- `fvm dart format --line-length=120` on scoped Dart files — completed with no remaining formatting changes.
- `git diff --check` — clean.

### Platform Acceptance

- Linux is verified through the focused/full VM suites, analyzer, and debug build.
- macOS static config check is unavailable on this pinned SDK: `build macos` does not expose `--config-only`.
- Windows static config check is unavailable on this Linux host: Flutter requires a Windows host for `build windows`.
- No macOS or Windows runtime result is claimed.

### Review Integrity

- Historical planning verdict: `REVISE` (retained in `review.md` for audit history).
- Current verifier follow-up status: `REVISE`, pending fresh context approval.
- Fresh implementation review: `PENDING_FRESH_CONTEXT_APPROVAL`.
- Automated validation is evidence only; an independent reviewer must complete the approval placeholder.

### Change Delivery

- Scoped implementation commit is created after staged-path verification.
- No push performed.

## Race Hardening Follow-up

- [x] The observed-balance regression uses separate file-backed WAL executors and a real competing full-payment commit.
- [x] The deferred test transaction factory applies only to the initial payment attempt; payment retries use immediate
  transactions, and write-off/reload paths use the production runner without the deferred seam.
- [x] Partial, full, and overpayment zero-row branches insert provisional rows, force `runUpdate == 0`, and verify
  rollback, unchanged snapshots, bound original id/status/cents, and no orphan journals.
- [x] Write-off/write-off and write-off/payment races use separate file-backed WAL executors and assert one effect with
  no orphan journal or relation.
- `fvm flutter test --dart-define=platform=vm test/features/einkommen/forderungen_request_fingerprint_test.dart` —
  **32 passed, 0 failed**.
- Affected receivable/migration suites — **61 passed, 0 failed**.
- Full VM suite — **804 passed, 0 failed**.
- `fvm flutter analyze` — **No issues found**.
- `openspec validate receivable-request-fingerprint-and-conditional-writeoff --strict` — **valid**.
- `openspec validate --specs --strict` — **54 passed, 0 failed**.
- `fvm dart format --line-length=120` and `git diff --check` — **clean**.

## Round-4 Revision Evidence (2026-10-02)

Round 4 (fresh-context independent review, recorded in `review.md`) returned `VERDICT: REVISE` with two blocking
evidence gates and fabricated-evidence findings. The following revisions were applied and verified:

### Migration evidence gate (round-4 critical #1)

- `test/db/receivable_request_migration_test.dart` was rewritten (9 tests, all green):
  - `test_app_database_post_ddl_failure_rolls_back_before_startup_side_effects` now records the callback's
    observation of the feature DDL (table + `requested_betrag_cents` column inside the transaction) before throwing,
    asserts typed `ForderungenErrorCode.schemaMigrationFailed` with `StateError` cause, asserts no
    `CREATE TRIGGER`/seed `INSERT OR IGNORE` statements ran during the failing open, asserts `isOpen == false`,
    throwing service getters, `PRAGMA user_version = 7`, exactly 39 tables, and no feature residue.
  - Migration failure tests assert typed `schemaMigrationFailed` (not `throwsA(anything)`), preserved
    `user_version = 7`, preserved legacy rows/columns, absent fingerprint columns and unique indexes after rollback,
    and exact all-table counts (no exclusion-based residue masking).
  - The raw-BEGIN path test now covers four fixtures through `AppDatabase.ensureOpen`: fresh creation and v7 upgrade
    and current-v8 repair record raw `BEGIN` → `COMMIT` with the feature DDL and `PRAGMA user_version = 8` between
    them and trigger/seed statements strictly after `COMMIT`; the injected current-v8 failure records raw `BEGIN` →
    `ROLLBACK` (no `COMMIT`), preserves `user_version = 8` and 39 tables, and runs no trigger/seed statements.
  - v7 fixtures are genuine: a real lazy table with legacy rows (preserved values, null fingerprint fields), a real
    missing-table creation with FK and named unique-index assertions plus zero fabricated rows, and a real
    duplicate-legacy-key rollback.
- Production fix (`lib/core/db/migrations.dart`): the absent-table branch of `_migrateReceivableFeature` no longer
  returns early; it falls through to the shared named-unique-index creation and constraint verification, so a freshly
  created feature table is verified before the migration transaction commits and `user_version` is raised.

### Lock evidence gate (round-4 critical #2)

- Both persistent-lock tests were rewritten to use a real file-backed `BEGIN EXCLUSIVE` held by a second
  `AppDatabase` instance for the whole command (the manufactured `_AlwaysLockedFactory` `StateError` was deleted).
- Each test asserts the exact attempt sequence `[1, 2, 3]`, typed `concurrentWriteConflict`, and a real
  `SqliteException` cause with `resultCode` 5/6 and `extendedResultCode != 517`, proving genuine SQLite lock
  contention through the production retry classifier.
- A phase-recording executor records every statement with its attempt-phase tag; no ensureSchema/DDL/PRAGMA/seed SQL
  runs during any attempt window, and all setup SQL precedes attempt 1.
- Status/balance/journal/relation snapshots (and the keyed relation count) are unchanged after lock release.
- New supplementary test `test_production_transaction_takes_the_write_lock_immediately` proves the production
  `executor.beginTransaction()` path holds the write lock immediately (a competing `BEGIN EXCLUSIVE` is denied while
  it is open).

### Fabricated evidence and moderate findings (round-4 critical #3, moderates)

- `test-plan.md` coverage notes were rewritten to describe only fixtures that exist in the repository.
- `test-plan.md` rows 26 and 42 scenario titles now match the delta spec titles.
- Payment ordering was restructured to conditional compare-and-set first (`lib/features/einkommen/
  forderungen_repository.dart`): the `WHERE id = ? AND status = ? AND betrag = ?` update on the observed id/status/
  observed balance runs before any provisional write, so the stale observed-balance attempt fails with extended 517
  on the conditional update itself (spec scenario literal), and a lost race leaves no provisional rows.
  `ausgleich_journal_id` is set by a follow-up update after the closing journal insert; all writes remain inside the
  same `BEGIN IMMEDIATE` transaction.
- The observed-balance test now records and asserts the stale conditional update's bound predicate
  (`[id, 'offen', '100.00']`, observed balance 10000 cents) and the zero-row test asserts the predicate statement and
  the bound observed balance of 7500 cents.
- The ordered-field test now covers the spec's four differing fields (requestedCents, forderungTarget, datePolicy,
  effectiveDate) with direction matching.

### Fresh verification runs (after all revisions)

- `fvm flutter test --dart-define=platform=vm` — **848 passed, 0 failed** (full suite).
- `fvm flutter test --dart-define=platform=vm test/features/einkommen/forderungen_request_fingerprint_test.dart
  test/db/receivable_request_migration_test.dart test/integration/audit/analyzer-and-integration-test-gates_test.dart`
  — **45 passed, 0 failed** (41 in the two revised files after final formatting).
- `fvm flutter analyze` — **No issues found**.
- `fvm dart format --line-length=120 --set-exit-if-changed` on the four scoped files — no changes.
- `openspec validate receivable-request-fingerprint-and-conditional-writeoff --type change --strict` — **1/1 passed**.
- `openspec validate --specs --strict` — **54/54 passed**.
- `git diff --check` — clean.

## Overall Decision

`PASS`

Fresh-context independent review round 5 returned `VERDICT: APPROVE` (all round-4 critical gates closed), and the
fresh-context round-6 delta confirmation returned `VERDICT: APPROVE` for the post-review revisions (in-transaction
write-off reason validation and fixture A/C positional assertions). Final battery after all revisions: full VM suite
**848 passed**, `fvm flutter analyze` clean, `fvm dart format --line-length=120` clean, `git diff --check` clean,
strict validations **1/1** and **54/54**. Both review verdicts are recorded in `review.md`.
