# Verify: journal-integrity-and-snapshots

## TDD Integrity

All 4 test-plan rows transitioned from 🔴 red to 🟢 green through red-green-refactor cycles. Tests were written first, confirmed failing for the correct reason, then production code was implemented to pass them.

## Review Compliance

The approved review.md required no changes. All findings addressed:
- Storno enforces immutable finalized source rules
- Journal rows carry audit-stable snapshots resolved from category
- Booking groups preserved via gruppe_id column

## Test-Plan Coverage

| Scenario | Status |
|----------|--------|
| Finalized source can be reversed once | 🟢 green |
| Mutable or already reversed source is rejected | 🟢 green |
| Missing snapshots are resolved | 🟢 green |
| Historical read is stable after master-data edit | 🟢 green |

## Final Suite Result

```
fvm flutter analyze — No issues found
fvm flutter test --dart-define=platform=vm — 541 passed, 0 failed
git diff --check — clean
openspec validate — valid
```

## Changes Made

- `lib/features/accounting/journal_repository.dart`: Added immutable check in storno, immutable flag on storno entries, gruppe_id in INSERT/SELECT, snapshot resolution from kategorien
- `lib/core/db/database.dart`: Added gruppe_id column to journal CREATE TABLE
- `lib/core/db/migrations.dart`: Added migration v7 for gruppe_id column, bumped currentVersion to 7
- `test/integration/audit/journal-integrity-and-snapshots_test.dart`: New test file with 4 integration tests
- `test/features/accounting/journal_test.dart`: Updated storno immutability expectation to match new spec
- `openspec/changes/journal-integrity-and-snapshots/tasks.md`: All tasks marked complete
- `openspec/changes/journal-integrity-and-snapshots/test-plan.md`: All rows marked green
