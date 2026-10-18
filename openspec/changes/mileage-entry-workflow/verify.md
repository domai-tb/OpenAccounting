# Verification Record — Revised Mileage Policy Contract

## Current revision status (2026-10-18)

- **Contract validation:** `openspec validate mileage-entry-workflow --type change --strict --json` passed with no issues after the current edits. This is structural validation only.
- **Behavioral tests:** not run against this revised contract. No code or tests were changed in this spec-only revision.
- **Scenario inventory:** `test-plan.md` maps all 46 scenarios: 9 existing test names and 37 missing tests. The nine tests were reported passing before this policy revision; that historical result does not prove the revised eligibility inputs, policy boundaries, rounding, database migration, posting, or correction contract.
- **Test-plan status:** all 37 missing tests remain `MISSING — planned, not run`. The existing policy calculation test requires assertions for v1 dates, classes/rates, half-up cents, and fail-closed exclusions before it can establish the revised requirement.
- **Migration/runtime:** v23 fields and trigger behavior are specified but not implemented or verified here. No migration DDL was changed.
- **Posting and corrections:** the contract retains debit travel expense / credit private contribution, no cash or VAT leg, trip-date accounting, and unresolved-trip fail-closed behavior. Runtime atomicity/idempotency is not verified by this revision.
- **Inventory dependencies:** still open. `profile-data-portability` declares 46 names at v13; `customer-data-disclosure-export` declares 55 names at v19. Mileage v23 migration and complete-export claims remain blocked pending both owners' acceptance of one inventory and version-aware presence rules. The inherited maintained `db` spec also contains a v8-to-v9 scenario that creates mileage tables, conflicting with its v13 minimum-version rule; the shared owner must reconcile this before migration behavior is implemented or tested.
- **Independent review:** Round 4 `APPROVE` reviewed the prior contract only. It does not approve this policy-source, eligibility, scenario-map, task, or verification revision. A fresh independent review is required before dependent code work.
- **Full suite, production runtime, migration execution, and export integration:** not run or established by this revision.

## Historical evidence from the earlier contract

The earlier work reported the following; these results predate the current contract and have not been rerun here:

- Focused mileage suite: `fvm flutter test --dart-define=platform=vm test/features/mileage/mileage_entry_workflow_test.dart` → 9 passed, exit 0.
- Scoped analysis: `fvm flutter analyze lib/features/mileage test/features/mileage` → no issues reported.
- Scoped format: `fvm dart format --line-length=120 --set-exit-if-changed lib/features/mileage test/features/mileage` → 0 changed.
- Earlier OpenSpec validation and strict validation passed structurally; those passes predate this revision and are not evidence for the final edited artifacts.
- The earlier review's `APPROVE` verdict and its findings remain in `review.md` as historical context only.

## Current decision

**DECISION: FAIL — revised contract is not independently reviewed, 37 mapped tests are missing, one existing policy test needs contract-specific assertions, and the inventory dependency remains open.**

Archive and implementation readiness are not established. Do not treat planned tests, historical test results, or mechanical artifact checks as runtime evidence.
