## Verification Results

- Verification date: 2026-10-13.
- `fvm dart format --line-length=120 --output=none --set-exit-if-changed` passed for all 15 changed Dart files in the staged candidate with zero changes.
- `fvm flutter analyze` passed with no issues.
- `fvm flutter test --dart-define=platform=vm --concurrency=2` passed: 1,434 tests.
- The focused wrong-sign Storno regression passed and confirmed that invalid `gesamt` is rejected before document or number-counter changes.
- `openspec validate --specs --strict --json` passed: 63/63 maintained specs.
- After all 141 task checkboxes were marked complete, `openspec validate 2026-10-12-invoice-money-contract-completion --archived --strict --json` reported the invoice archive valid. Its repository-wide scan passed 47/51 archives; the four failures are older archives with 12 unchecked tasks each: `2026-09-08-correction-document-accounting-integrity`, `2026-09-09-finalized-document-artifact-lifecycle`, `2026-09-09-localization-settings-and-data-protection`, and `2026-09-09-profile-workspace-lifecycle`.
- `git diff --check` and `git diff --cached --check` passed.
- All 50 mapped test-plan rows are green across 48 scenarios and 49 unique test functions.
- Fresh full-scope review approved on 2026-10-13; see Round 13 in `review.md`.

## Commit Scope

The invoice candidate includes invoice arithmetic, persistence, lifecycle, signed PDF line calculations, tests, and synchronized invoice/database requirements. Document-artifact creation and original-date PDF display remain outside the invoice commit. Other active specification work remains unstaged.

The original implementation is present in branch history at `7bcaf2c`, whose commit also included document-email changes. This follow-up records the final invalid-source regression and Round 13 completion evidence in `ae13dab`; it does not rewrite the earlier commit.

## Overall Decision

DECISION: COMPLETE
