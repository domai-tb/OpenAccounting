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

## Fresh Approval Placeholder

`VERDICT: PENDING_FRESH_CONTEXT_APPROVAL`

Reviewer: independent Anvil reviewer to complete a fresh review of this follow-up. Automated tests and this evidence
update do not infer approval.
