# Verification Record — Mileage Policy and Database Contract

## Current implementation checkpoint (2026-10-18)

- **Scope:** Replaced timestamp/random trip IDs with UUIDv4 and strengthened `test_record_a_business_trip` to reload and verify the UUID format, exact persisted integer distance, structured eligibility facts, and unresolved state. No distance conversion or rounding was added.
- **Red evidence:** Before the fix, the focused test failed because the generated ID was `1792347538129862-1436408645`, which was not a UUID.
- **Focused test:** `FLUTTER_SUPPRESS_ANALYTICS=true FVM_CACHE_PATH=/tmp/openaccounting-fvm-cache fvm flutter test --dart-define=platform=vm test/features/mileage/mileage_entry_workflow_test.dart` → 9 passed, exit 0. Flutter required an elevated local VM-test run because the sandbox denied its temporary localhost socket.
- **Scoped analysis:** `FLUTTER_SUPPRESS_ANALYTICS=true FVM_CACHE_PATH=/tmp/openaccounting-fvm-cache fvm flutter analyze lib/features/mileage test/features/mileage` → no issues, exit 0.
- **Formatting:** `fvm dart format --line-length=120` reported 0 changed files; the command then exited nonzero because Dart telemetry could not update `/home/ubuntu/.dart-tool/dart-flutter-telemetry-session.json` on the read-only filesystem.
- **Scope limit:** This checkpoint did not verify policy calculation, migration, posting, corrections, exports, or the rest of the 45-row matrix. The later focused run below adds partial evidence for eligibility and migration only.

## Eligibility and v23 lifecycle checkpoint (2026-10-18)

- **Scope:** Added typed trip/vehicle classification, preserved integer distance, applied the approved policy only to eligible facts and dates, added v23 eligibility columns with legacy `unknown` defaults, and installed lifecycle triggers. Posting remains test-port-only; production accounting, account configuration, corrections, export inventory integration, and UI are not established by this checkpoint.
- **Focused tests:** `FLUTTER_SUPPRESS_ANALYTICS=true FVM_CACHE_PATH=/tmp/openaccounting-fvm-cache fvm flutter test --dart-define=platform=vm test/features/mileage/mileage_entry_workflow_test.dart test/db/mileage_lifecycle_migration_test.dart test/db/inventory_stocktake_migration_test.dart` → 21 passed (10 mileage workflow, 3 mileage lifecycle migration, 8 inventory migration), exit 0. The command required an escalated local VM-test run because the sandbox denied Flutter's temporary localhost socket.
- **Database evidence:** Fresh install reports schema version 23, three classification columns, and 16 mileage lifecycle triggers. The v22 fixture preserves a posted legacy row's classification as `unknown`, exact distance, policy snapshot, amount, and posting event. Trigger tests reject an ineligible calculation and an ungated void transition; the remaining lifecycle matrix is not verified.
- **Eligibility evidence:** Focused workflow tests cover private business travel, both supported vehicle classes, integer half-up examples, and selected exclusions (commuting, other, company vehicle, unsupported class, unknown facts, out-of-period 2027, and EKS). Explicit effective-date boundary assertions and complete posting prerequisites remain untested.
- **Validation limits:** No scoped analyzer was run after the migration changes. The prior formatter invocation formatted the touched Dart sources but exited nonzero when telemetry attempted to write outside the workspace. This checkpoint does not complete the feature or its 45-scenario matrix.

## v24 migration and review-fix checkpoint (2026-10-18)

- **Scope:** Added an additive v24 correction for databases already at v23. Both the v22 migration and v23 correction demote calculated trips whose structured eligibility is unknown or whose calculation snapshot is not trusted, clear that snapshot, and preserve recorded trip facts and legacy posted rows. The calculation table constraint and trigger explicitly reject `NULL` in every required snapshot field. `postTripWithPort` independently validates structured eligibility, the approved policy snapshot, and exact cents before invoking the posting port.
- **Focused tests:** `FLUTTER_SUPPRESS_ANALYTICS=true FVM_CACHE_PATH=/tmp/openaccounting-fvm-cache fvm flutter test --dart-define=platform=vm test/features/mileage/mileage_entry_workflow_test.dart test/db/mileage_lifecycle_migration_test.dart test/db/inventory_stocktake_migration_test.dart` → 24 passed (11 mileage workflow, 5 mileage lifecycle migration, 8 inventory migration), exit 0. This run required escalation because the sandbox denied Flutter's temporary localhost socket.
- **Regression evidence:** The v22 fixture proves unknown calculated facts are demoted and posted facts/snapshots remain preserved. The v23 fixture proves the additive correction runs for an already-v23 profile. Direct SQL attempts setting each of the seven required snapshot fields to `NULL` are rejected. A fake repository/port test confirms ineligible or untrusted calculated snapshots never call the posting port.
- **Scoped analysis:** `FLUTTER_SUPPRESS_ANALYTICS=true FVM_CACHE_PATH=/tmp/openaccounting-fvm-cache fvm flutter analyze lib/core/db/migrations.dart lib/features/mileage test/db/mileage_lifecycle_migration_test.dart test/db/inventory_stocktake_migration_test.dart test/features/mileage/mileage_entry_workflow_test.dart` → no issues, exit 0.
- **Scope limit:** These checks establish the targeted migration, constraint, trigger, and usecase regressions only. Production accounting posting, full correction behavior, export inventory integration, and most of the 45-scenario matrix remain unverified.

## Specification sync snapshot before implementation (2026-10-18)

- **Scope:** Synced the approved mileage database requirement into the maintained DB spec; corrected the false v8-to-v9 mileage-table claim in the active delta, removed its duplicate scenario, updated the related test-plan/task wording, and recorded this evidence. No DDL, application code, or tests were changed.
- **Source-backed table version:** At base `3fbc911d2e0e8ceb7fa76d6ed8bd65c75b253d5b`, `MigrationRunner.currentVersion` is 22 (`lib/core/db/migrations.dart:18`). The upgrade loop calls `_migrateTo(v)` for each next version and sets `user_version` only after verification (`:241-270`). The v9 step calls `_migrateCategoryProvenance` (`:378-385`); the v13 step calls `_migrateProfilePortabilityTables` (`:420-423`), whose DDL creates `feature_table_state`, `mileage_trips`, `mileage_trip_corrections`, and the active-correction index (`:462-469`). Fresh schema creation also calls that helper (`:295-320`, especially `:308`). Thus the mileage-table migration boundary is v12→v13; v8→v9 remains the separate category-history migration.
- **Lifecycle version:** Source is still at schema version 22. The current v22 step runs the v21 path and e-invoice output-format migration (`:456-459`); no v23 migration or lifecycle trigger DDL exists in this source. The accepted v22→v23 lifecycle scenario is a contract target only.
- **Coverage ledger:** The duplicate false v8→v9 marker/mileage scenario was removed from the active and maintained DB specs. Its valid table/marker coverage remains in the single v12→v13 scenario; the distinct v9 category-history scenario remains. The downgrade scenario now uses v13 and an older v12 application. The accepted delta's v22→v23 scenario was added to the maintained spec. Profile portability and customer disclosure inventories were not edited and remain unresolved.
- **Test status:** `test-plan.md` maps 45 scenarios: 9 existing tests are prior-contract evidence only; 36 tests remain `MISSING — planned, not run`. No behavioral tests were run for this spec-only revision.
- **Independent review:** Round 5 approved the earlier reviewed contract at `d6d441c4c4e0779c83282f5fb16b824630d89688`. This version correction changes the reviewed artifacts and invalidates that approval. A fresh independent review is required before dependent implementation.
- **Open dependency:** Mileage migration and complete-export claims remain blocked until both inventory owners accept the same 55-name v19 inventory and version-aware presence rules.
- **Validation:** `openspec validate --specs --strict --json` passed 72/72 maintained specs; `openspec validate mileage-entry-workflow --type change --strict --json` passed 1/1 change; `git diff --check` passed. A scenario-set comparison confirmed all 18 scenarios from the modified DB requirement are present in the maintained DB spec. These are structural checks only.

## Historical evidence from earlier revisions

These results predate this revision and were not rerun:

- Focused mileage suite: `fvm flutter test --dart-define=platform=vm test/features/mileage/mileage_entry_workflow_test.dart` → 9 passed, exit 0.
- Scoped analysis: `fvm flutter analyze lib/features/mileage test/features/mileage` → no issues reported.
- Scoped format: `fvm dart format --line-length=120 --set-exit-if-changed lib/features/mileage test/features/mileage` → 0 changed.
- Earlier OpenSpec validations were structural only and do not establish migration, posting, export, or correction behavior.

## Current decision

**DECISION: PARTIAL — UUID4 identity, exact persisted integer distance, selected eligibility behavior, the posting-usecase snapshot guard, and selected v22/v23/v24 migration behavior have focused test evidence; scoped analysis passes. Production accounting posting, account mapping, correction behavior, export inventory integration, exhaustive migration/lifecycle tests, and the remaining scenario coverage are still in progress.**
