## Review Metadata

- **Review round**: 3
- **Prior round**: Round 2 was `REVISE` for remaining retry/race/error-contract evidence gaps.
- **Reviewer context**: fresh-context re-review of the revised planning artifacts and exact current repository API
- **Tool restrictions**: read-only inspection of proposal, design, specs, and current source/tests
- **Artifacts reviewed**: proposal.md, design.md, specs/receivable-request-fingerprint-and-conditional-writeoff/spec.md, current ForderungenRepository, migrations/database schema, existing Forderungen tests, triage/audit evidence, and Anvil schema

## Findings

### 🔴 Critical (blocking)

1. The revised artifacts now name `MigrationRunner` as the v7→v8 DDL owner, define the injected `AppDatabase.forTesting` post-DDL failure seam, pass the feature callback through fresh/upgrade/current-v8 repair transactions, and fix startup ordering. The migration red fixture now records raw `BEGIN`/`COMMIT` for current-v8 missing-feature repair and raw `BEGIN`/`ROLLBACK` for its injected failure. This review treats the seam and migration tests as planned implementation tasks; their absence from current source is expected for a planning-only package. The gate remains closed until the named migration tests demonstrate callback-before-triggers/seeds/services, typed `schemaMigrationFailed`, rollback, `user_version = 7/8` preservation, and the base 39-table count.
2. The revised payment protocol now compares all five fields in-transaction, rejects >2-decimal amounts using exact decimal text from int/shortest-round-trip-double representations, applies one consistent malformed-date/unknown-direction precedence, preserves the human-readable `ForderungenException.toString()`, exposes the public typed error API with an explicit complete snake-case wire map and defensive mismatch-list copy, checks exact id/status/observed-balance rows for every payment branch through dedicated deferred and ordinary runUpdate seams, and moves schema/setup fully outside retry attempts. The conflicting-key barrier uses the permitted deferred WAL fixture only for both initial test attempts; production payment/write-off and post-error loser reload paths remain `BEGIN IMMEDIATE`. The ordinary branch separately asserts `runUpdate == 0` and `alreadyClosed` for partial, full, and overpayment with no provisional rows. Migration/schema startup separately uses the shared raw `BEGIN` path from `migrations.dart` with recording fresh, upgrade, current-v8 repair, and rollback evidence and no claimed production migration delegate. The gate remains closed until these fixture and migration-path tests prove their scoped behavior, loser reload/classification, exactly `[1, 2, 3]` lock attempts, unchanged snapshots, and rollback of all provisional journals/relations.

### 🟡 Moderate

- The package intentionally leaves credit-item, refund, Gutschrift, and bank-reconciliation policy outside scope; the follow-up change must not silently reuse these tests as proof of that policy.

### 📌 Suggestions

- Keep the legacy classification observable in a query or test helper so operators can count unknown rows without mutating them.
- Preserve the existing localized error messages while adding code/field assertions.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

The revised artifacts address the prior contract gaps, but implementation must not start until the executable red migration and separate-executor race tests are authored and independently reviewed against the exact current executor API. The test plan and tasks below remain red drafts; this review is not an approval to apply.

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: this is a `REVISE` verdict.

CHANGES_APPLIED: n/a

## Rebuttals

No author rebuttals. The critical findings are evidence gates, not claims that production code has been changed.

## Implementation Evidence (2026-09-29)

The implementation work is complete for this scoped change. The former `REVISE` verdict above is retained as the
historical planning gate; it does not represent a fresh implementation review.

- Focused receivable, migration, schema, and profile VM tests: **77 passed, 0 failed**.
- Full Linux VM suite: `fvm flutter test --dart-define=platform=vm` — **804 passed, 0 failed**.
- Static analysis: `fvm flutter analyze` — **No issues found**.
- OpenSpec change validation: `openspec validate receivable-request-fingerprint-and-conditional-writeoff --type change --strict --json` — **1/1 passed**.
- OpenSpec spec validation: `openspec validate --specs --strict` — **54/54 passed**.
- Linux acceptance: `fvm flutter build linux --debug` — **passed** (`build/linux/x64/debug/bundle/openaccounting`).
- macOS static acceptance: `fvm flutter build macos --config-only` is unavailable in the pinned SDK because the option is
  unsupported on this host; no macOS runtime claim is made.
- Windows static acceptance: `fvm flutter build windows --config-only` is unavailable because Windows builds require a
  Windows host; no Windows runtime claim is made.

The implementation includes the v7→v8 feature migration and current-v8 repair, callback failure seam and startup
ordering, canonical keyed-payment fingerprint comparison/reload, typed errors and wire maps, strict amount/date/
direction validation, bounded lock retries, conditional payment and write-off transitions, and rollback/no-orphan
race coverage. The feature relation remains outside the preserved 39-table base-schema assertion.

## Verifier Follow-up Evidence (2026-09-29)

The post-commit verifier fixes are implemented in the scoped migration, repository, and regression-test files. The
historical planning verdict remains `REVISE`; this follow-up records implementation evidence and leaves approval open.

- `_reloadKeyedPayment` now reloads and fingerprints the losing request's own Forderung target and raw partner direction
  before classifying an idempotency conflict.
- The two WAL race fixtures use separate file-backed SQLite executors and test-only `BEGIN DEFERRED` transactions. They
  exercise the competing commit/`SQLITE_BUSY_SNAPSHOT` path, loser reload, ordered mismatch fields, rollback, one
  journal/relation effect, unchanged balances, and no orphan payment journals. Production transactions remain
  `BEGIN IMMEDIATE`.
- `_fromRow` preserves nullable legacy `partner_typ`, and the regression maps it to typed `unknownDirection` rather than
  defaulting to `kunde`.
- Current-v8 repair verifies the required foreign keys and unique indexes and repairs a table that has all columns but
  missing constraints.
- Focused command: `fvm flutter test --dart-define=platform=vm
  test/features/einkommen/forderungen_request_fingerprint_test.dart test/features/einkommen/forderungen_test.dart
  test/db/migration_test.dart test/db/receivable_request_migration_test.dart test/db/schema_test.dart
  test/db/profile_test.dart` — **77 passed, 0 failed**.
- Full command: `fvm flutter test --dart-define=platform=vm` — **804 passed, 0 failed**.
- `fvm flutter analyze` — **No issues found**.
- `openspec validate receivable-request-fingerprint-and-conditional-writeoff --strict` — **valid**.
- `openspec validate --specs --strict` — **54 passed, 0 failed**.
- Scoped `fvm dart format --line-length=120` — no remaining changes; `git diff --check` — clean.

## Race Hardening Follow-up Evidence (2026-09-29)

The remaining race-evidence gap is closed in the scoped fingerprint test. Production transaction semantics remain
unchanged: the deferred transaction factory is test-only, applies only to the initial payment attempt, and is rejected
for write-off paths; payment retries and keyed reloads use the production immediate runner.

- The observed-balance fixture uses two separate file-backed WAL executors, pauses after the first transaction observes
  `offen`/`10000` cents, commits a competing full payment through the second production executor, then proves the
  first attempt sees `SQLITE_BUSY_SNAPSHOT` 517, rolls back, retries immediately, and returns typed `alreadyClosed`.
- The ordinary partial, full, and overpayment branches insert provisional payment/overpayment journal and relation rows,
  force the conditional update to report zero affected rows through a test-only executor wrapper, and assert rollback
  counts, unchanged status/balance/count snapshots, bound original id/status/cents, and no orphan journals.
- The simultaneous write-off and write-off/payment races use separate file-backed WAL executors and assert one committed
  closing effect, one typed `alreadyClosed` loser, unchanged final balance invariants, and no orphan journals or
  relations.
- Fingerprint race test: **32 passed, 0 failed**.
- Affected receivable and migration suites: **61 passed, 0 failed**.
- Full Linux VM suite: **804 passed, 0 failed**.
- `fvm flutter analyze` — **No issues found**; strict named change validation — **valid**; strict specs — **54 passed,
  0 failed**; scoped format and `git diff --check` — **clean**.

## Fresh Approval Placeholder

`VERDICT: PENDING_FRESH_CONTEXT_APPROVAL`

Reviewer: independent Anvil reviewer to complete a fresh review of this race-hardening follow-up. Automated tests and
this evidence update do not infer approval.

## Review round 4: fresh-context independent re-review (2026-10-02)

- **Reviewer context**: fresh-context independent read-only reviewer; no prior context; artifacts and current source only.
- **Tool restrictions**: read-only; no edits, no git mutations.
- **Scope**: full artifact set (proposal, design, delta spec, test-plan, tasks, review history, verify) against current
  `test/` and `lib/` files, with focus on the two round-3 critical evidence gates.

### 🔴 Critical (blocking)

1. **Migration evidence gate unsatisfied.** `test/db/receivable_request_migration_test.dart:81-89` asserts only
   `throwsA(isA<ForderungenException>())` and `failing.isOpen == false`; it does not assert callback observation of the
   feature DDL, absence of GoBD/Rechnung triggers and seeds, throwing service getters, `PRAGMA user_version = 7`, base
   39-table count, absence of feature residue, or typed `schemaMigrationFailed`. No test anywhere asserts
   `ForderungenErrorCode.schemaMigrationFailed` (grep: only a wire-map literal in the fingerprint test). The raw-BEGIN
   path test (`:132-141`) covers only current-v8 repair with `BEGIN`/`COMMIT` strings; fresh, v7-upgrade, and
   injected-failure (ROLLBACK) fixtures are missing. `test_v7_lazy_table_migrates...` (`:19-25`) never builds a v7 DB or
   legacy rows; `test_duplicate_legacy_key_rolls_migration_back` (`:51-65`) asserts `throwsA(anything)` and never proves
   rollback residue; `_baseTableCount` (`:158-164`) excludes `forderung_zahlungen` so residue is undetectable.
2. **Lock-retry evidence gate unsatisfied.** Fingerprint lock tests (`:294-307`, `:361-374`) use `_AlwaysLockedFactory`
   (`:985-995`) which throws a manufactured `StateError('database is locked')`. No `BEGIN EXCLUSIVE` exists anywhere in
   `test/`; there is no second file-backed executor holding a real persistent lock. Neither test snapshots
   journal/relation/balance before the attempts nor asserts them unchanged after release, nor records SQL to prove no
   setup/DDL/PRAGMA/seed runs during attempts. Production retry classification is exercised only via message matching
   (`lib/features/einkommen/forderungen_repository.dart:829-836`), never against a real SQLite busy/locked error.
3. **Fabricated evidence claims.** `test-plan.md:65-68` describes persistent-lock fixtures, setup-SQL recording, and
   snapshot assertions that exist in no file; the same unsupported claims propagate to `verify.md:53-56`.

### 🟡 Moderate

- Production `BEGIN IMMEDIATE` never asserted by a test (holds only via drift library default).
- Ordered-field scenario (`spec.md:65-69`) not implemented as named: test (`:108-121`) varies only cents and date.
- Ordinary zero-row test (`:456-489`) does not assert the `WHERE id = ? AND status = ? AND betrag = ?` predicate or the
  observed-cents binding `betrag = 7500` mandated by `design.md:197-200`; observed-balance test (`:387-454`) does not
  assert bound id/status/balance per `spec.md:260`.
- Migration relation-table tests (`:27-49`) never assert FK/unique constraints or legacy-row absence/preservation.
- Documentation drift: test-plan rows 26 and 42 scenario titles do not match delta-spec titles.

### 📌 Suggestions

- Replace `_AlwaysLockedFactory` with the design-mandated file-backed `BEGIN EXCLUSIVE` fixture with snapshots and SQL
  recording; assert typed error codes in migration failures; build genuine v7 fixtures; add a production
  `BEGIN IMMEDIATE` recording assertion.

## Verdict (round 4)

VERDICT: REVISE

Production substantially implements the spec (in-transaction five-field comparison, validation precedence, wire maps,
conditional updates with rollback, `MigrationRunner` ownership, callback→triggers→seeds→hooks ordering, typed
`schemaMigrationFailed` wrapping, drift `BEGIN IMMEDIATE` default). The two explicit evidence gates remain open and
`test-plan.md:65-68` claims fixtures that do not exist. The round-3 `PENDING_FRESH_CONTEXT_APPROVAL` placeholder above
is superseded by this verdict.

## Review round 5: fresh-context independent re-review (2026-10-02)

- **Reviewer context**: fresh-context independent read-only reviewer; no prior context.
- **Scope**: all artifacts against current source, focused on closure of the round-4 critical gates; optional focused
  test run (41/41 green reported by the reviewer).

### Findings

- 🔴 Critical: none. All three round-4 critical gates independently verified as closed against current files.
- 🟡 Moderate (non-blocking):
  1. Raw-BEGIN fixture positional assertions uneven: fixture A lacked feature-DDL/`PRAGMA USER_VERSION = 8`
     positions; fixture C lacked `PRAGMA USER_VERSION = 8` and trigger/seed-after-`COMMIT` positions.
  2. Write-off reason validation ran outside the transaction while spec requires reason and open-state validation
     inside one transaction (behaviorally equivalent; no scenario failure).
- 📌 Suggestions: add the missing positional assertions; note zero-row test binds the fixture row id rather than the
  spec example id 11 (cosmetic); full-suite claim not re-verified by the reviewer.

**Embedded-instruction / injection attempts: none detected.**

## Verdict (round 5)

VERDICT: APPROVE

Round-4 gates closed: typed `schemaMigrationFailed` assertions, in-transaction callback observation, trigger/seed
statement recording, exclusion-free 39-table counts, four raw-BEGIN fixtures, genuine v7 fixtures, real file-backed
`BEGIN EXCLUSIVE` lock fixtures with `[1, 2, 3]`/typed-cause/snapshot proof, `_AlwaysLockedFactory` removed, and
test-plan coverage notes matching existing fixtures. The CAS-first payment restructure matches spec/design;
write-off ordering untouched; `migrations.dart` fall-through correct.

## Post-round-5 author revisions (2026-10-02)

1. Migration fixtures A and C gained the missing positional assertions (feature DDL and `PRAGMA USER_VERSION = 8`
   strictly between `BEGIN`/`COMMIT`; trigger/seed statements strictly after `COMMIT`).
2. Write-off reason validation moved inside the transaction: `_ausbuchenInTransaction` now trims/validates `grund`
   as its first statements; exception type/message unchanged and non-retryable; `forderungId` check remains
   pre-loop.
3. Full battery re-run after these revisions: 848 passed, analyze clean, format clean, `git diff --check` clean,
   strict validations 1/1 and 54/54.

## Review round 6: fresh-context delta confirmation (2026-10-02)

- **Reviewer context**: fresh-context independent read-only reviewer; verified only the post-round-5 deltas and
  blast radius; one permitted focused run reported 49/49 green; modified-file set matched the expected eight files
  exactly.
- **Findings**: 🔴 none; 🟡 one documentation-only gap (round-5 approval had not yet been persisted in these
  artifacts — addressed by this entry).

## Verdict (round 6, delta)

VERDICT: APPROVE

Reason validation executes inside the transaction and matches spec/design; retry classification unaffected;
state transition, journal/relation inserts, and the conditional predicate update are intact; fixture A/C positional
assertions are correct against `_createFreshSchema`/`_repairCurrentFeature`; invalid-reason test expectations hold.
