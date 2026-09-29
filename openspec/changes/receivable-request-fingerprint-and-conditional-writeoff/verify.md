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

## Overall Decision

`REVISE_PENDING_FRESH_CONTEXT_APPROVAL`
