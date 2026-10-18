# Verification Record — Mileage Policy and Database Contract

## Current revision status (2026-10-18)

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

**DECISION: NOT READY — the DB contract sync is complete, but a fresh independent review and both inventory owners' agreement are required before implementation.** Planned tests and structural checks do not prove runtime behavior.
