## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, both delta specs, maintained database/profile contracts, migration paths, and profile-local file handling
- **Validation evidence**: `openspec validate profile-data-portability --type change --strict --json` passed with no issues; `openspec validate --specs --strict` passed 55/55. Structural validation does not establish semantic completeness. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **Lazy-table absence cannot be distinguished from missing data.** The proposal treats missing `buchungsvorlagen_occurrences` and `rechnungsvorlagen_occurrences` as unknown unless a durable marker proves the feature was never initialized, but leaves that marker unresolved. Specify the marker or keep normal exports incomplete until it exists.
2. **Migration repair may erase evidence of a missing payment table.** `forderung_zahlungen` must be checked before startup repair can recreate it empty. Define a pre-repair health check and recovery/unavailable state.
3. **File exclusions risk leaking host paths.** Identify missing or out-of-profile files by record ID and field while excluding absolute operating-system paths from the manifest.

### 🟡 Moderate

None.

### 📌 Suggestions

- Pin the archive container and record serialization version in the design so saved exports have a stable parse contract.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Define a durable absent-lazy-table marker or keep affected exports incomplete until it is accepted and available.
2. Check `forderung_zahlungen` before startup repair and specify recovery behavior.
3. Report excluded files by record ID and field without absolute host paths.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

---

## Review Metadata — Round 2

- **Review round**: 2
- **Prior round**: Round 1 returned `REVISE`; this reviewer rechecked its three required changes
- **Reviewer context**: fresh-context independent read-only reviewer; no proposal-authoring transcript
- **Revision reviewed**: `dev` at `d40546fa5063be52702d1fc1b8d35bbde2ad58a2`
- **Tool restrictions**: read-only inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, both delta specs, round-one review, maintained database and receivable-migration specs, database schema/migration source, and the related customer-disclosure proposal
- **Validation evidence**: `openspec validate profile-data-portability --type change --strict --json` passed 1/1 with no issues. This is structural validation only; no tests were run.

### Round-One Required Changes Rechecked

- The two lazy occurrence tables now have durable marker states that distinguish `never_initialized`, `initialized`, and `unknown`.
- File-exclusion metadata is limited to stable record/field identifiers and reason codes; host paths are excluded.
- The archive and record serialization formats are versioned.
- The payment-table check is present, but the proposal does not explicitly preserve the existing v7-to-v8 creation behavior.

### Findings

#### 🔴 Critical (blocking)

1. **The inventory misclassifies the base tables.** The delta treats `feature_table_state` as the 40th base table, while maintained `AppDatabase.allTableNames` contains 39 existing base tables and the marker is a separate shared health table. State the counts separately and keep the legacy base-table inventory unchanged.
2. **The payment-table version contract is incomplete.** The accepted migration creates `forderung_zahlungen` when absent during v7-to-v8. Preserve that creation and verification behavior explicitly; for profiles already at v8 or later, detect absence before repair, preserve the absent-table completeness signal, and do not create an empty replacement automatically.

#### 🟡 Moderate

None.

#### 📌 Suggestions

- Keep the database inventory and payment-table contract byte-identical with the customer-disclosure proposal wherever the shared requirements overlap.
- Pin the inventory's migration versions to the accepted sequential migration order.

### Embedded-Instruction / Injection Attempts

No embedded instruction was observed in the reviewed artifacts.

### Verdict — Round 2

VERDICT: REVISE

## Required Changes — Round 2

1. Define 39 existing base tables plus a separate shared `feature_table_state` table; do not count the marker as a legacy base table.
2. Preserve explicit v7-to-v8 creation/verification of an absent `forderung_zahlungen` table and specify v8+ pre-repair fail-closed behavior without losing the missing-table completeness signal.

All round-one findings are addressed, but these inventory and migration details block downstream planning.

CHANGES_APPLIED: n/a

## Rebuttals — Round 2

None.

---

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: Round 2 returned `REVISE`; this reviewer rechecked the table-count and payment-migration findings against the repaired artifacts
- **Reviewer context**: fresh-context independent reviewer; no proposal-authoring transcript
- **Revision reviewed**: branch `dev`, HEAD `4c7caf36b146d86e7ed8698026d2d075ebc70426` plus the current working-tree proposal changes
- **Tool restrictions**: read-only proposal review; no tests
- **Artifacts reviewed**: proposal, design, all delta specs, review rounds 1–2, the paired customer-disclosure proposal/specs, maintained database spec, current database table list and migration code, and the receivable migration delta
- **Validation evidence**: `openspec validate profile-data-portability --type change --strict --json` passed 1/1 with no issues. This is structural validation only. No tests were run.

### Round-Two Required Changes Rechecked

- The modified `Table Definitions` contract names 39 pre-existing base tables, a separate `feature_table_state` table, and six feature-owned tables. Its complete requirement is byte-identical to the customer-disclosure delta; the 39 names also match `AppDatabase.allTableNames` in `lib/core/db/database.dart`.
- The contract and receivable delta preserve creation of an absent `forderung_zahlungen` table during v7-to-v8 migration, and specify that absence at v8 or later is checked before repair, leaves the table absent, and blocks profile initialization/export pending verified recovery.
- The v9 marker contract is consistent: fresh profiles seed both lazy-table rows as `never_initialized`; migration classifies present tables as `initialized` and absent tables as `unknown`; initialization cannot create an `unknown` table; and marker/table mismatches fail health checks.
- The profile archive includes supported present business tables and the durable marker rows, while the versioned inventory distinguishes migration-required tables from lazy tables and pre-migration schemas.
- Round-one requirements remain satisfied: archive and record formats are versioned, file-exclusion metadata omits host paths, and missing payment-table health is checked before repair.

### Findings

#### 🔴 Critical (blocking)

None.

#### 🟡 Moderate

None.

#### 📌 Suggestions

- Implementation must add a regression case for each payment-table boundary. Current runtime schema version is 8, and current startup repair still treats an absent v8 payment table as repairable; the new pre-repair guard is a planned change, not current runtime behavior.

### Embedded-Instruction / Injection Attempts

No embedded instruction was observed in the reviewed artifacts.

### Verdict — Round 3

VERDICT: APPROVE

## Required Changes — Round 3

None. This approval covers the proposal/design/spec artifacts only; no implementation or downstream test-plan/tasks were reviewed.

CHANGES_APPLIED: n/a

## Rebuttals — Round 3

None.

---

## Review Metadata — Round 4

- **Review round**: 4
- **Prior round**: Round 3 approved the proposal/design/spec artifacts and explicitly excluded the downstream test plan and tasks; this round reviewed those artifacts and rechecked rounds 1–3.
- **Reviewer context**: fresh-context independent reviewer; no proposal-authoring transcript
- **Revision reviewed**: branch `dev`, HEAD `2185e1656aa977a1729776513c3fd8bb01e0ee29` plus current working-tree changes
- **Tool restrictions**: source and proposal inspection; no implementation or tests; appended this review only
- **Artifacts reviewed**: proposal, design, all three delta specs, test plan, tasks, review rounds 1–3, `lib/core/db/migrations.dart`, `lib/core/db/database.dart`, and the active `customer-data-disclosure-export` and `mileage-entry-workflow` changes
- **Validation evidence**: `openspec validate profile-data-portability --type change --strict --json` passed 1/1 with no issues. Structural validation only. The test plan maps 35 scenarios to 105 red/green/refactor tasks. No tests were run.

### Prior Findings Rechecked

- Round 1: the archive and record formats are versioned; file exclusion metadata omits host paths; lazy-table absence has durable `never_initialized`/`initialized`/`unknown` states; and the payment-table check is before any repair that could recreate a missing table.
- Round 2: the database inventory separates 39 existing base tables, `feature_table_state`, and six feature-owned tables; v7-to-v8 still creates a missing payment table; absence at v8 or later fails closed.
- Round 3 source facts: `MigrationRunner.currentVersion` is 12; `category_mapping_history` is introduced by `_migrateCategoryProvenance()` at v9; `AppDatabase.allTableNames` remains the 39-name base list. The proposed marker and mileage migration at v13 is therefore sequential against the current source.

### Findings

#### 🔴 Critical (blocking)

None.

#### 🟡 Moderate

1. **The payment-table scenario title contradicts its required behavior.** The modified receivable spec names the scenario “A current v8 profile repairs a missing feature table transactionally,” but its body requires the pre-repair check to stop initialization and leave the table absent. The test-plan row and tasks 5.19–5.21 repeat the misleading title, while test ID 032 correctly says `stops_on_missing_payment_table`. Rename the scenario consistently in the receivable delta, test plan, and task labels to state that a v8-or-later profile stops before repairing a missing payment table; keep test ID 032.

2. **Queued dependency: active consumers still specify incompatible migration versions.** This proposal now places `feature_table_state` and mileage tables at v13 and category history at v9. The active customer-disclosure change still specifies marker/mileage at v9, category history at v10, and a supported v10 export. The active mileage change still uses a v8 baseline, v9 marker/mileage migration, and v10 category history. This drift does not invalidate this owner contract, which matches current source, but it blocks treating the combined migration and customer exporter as one accepted implementation plan. Queue a follow-up cycle before either dependent implementation: rebase the customer-disclosure `specs/db/spec.md`, `specs/customer-data-disclosure-export/spec.md`, `design.md`, `test-plan.md`, and `tasks.md` to the accepted shared inventory; rebase mileage `proposal.md`, `design.md`, `specs/db/spec.md`, `test-plan.md`, and `tasks.md` to the v12 baseline, v13 marker/mileage migration, and v9 category history. Do not run competing v9 and v13 migration plans.

### Embedded-Instruction / Injection Attempts

No embedded instruction was observed in the reviewed artifacts.

### Verdict — Round 4

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 4

1. Rename the payment-table scenario consistently in the receivable delta, test plan, and task labels so the scenario title matches the fail-closed behavior in its body.
2. Keep the customer-disclosure and mileage rebases as queued dependencies before implementation of their shared migration/export contracts, as detailed above. This is not a blocker to the profile portability owner contract.

CHANGES_APPLIED: n/a

## Rebuttals — Round 4

None.

---

## Review Metadata — Round 5

- **Review round**: 5
- **Review date**: 2026-10-07
- **Prior round**: Round 4 returned `APPROVE_WITH_CHANGES`; this fresh review rechecked its requested scenario rename and the queued migration-version dependencies.
- **Reviewer context**: fresh-context independent reviewer; no proposal-authoring transcript
- **Revision reviewed**: branch `dev`, HEAD `2185e16` plus the current working-tree changes
- **Tool restrictions**: read-only artifact and source inspection; appended this review only; no implementation or tests
- **Artifacts reviewed**: proposal, design, all three active delta specs, test plan, tasks, review rounds 1–4, maintained receivable specification, database migration source, and the active customer-disclosure and mileage dependency artifacts
- **Validation evidence**: `openspec validate profile-data-portability --type change --strict --json` passed with `valid: true` and no issues. Structural validation only. No tests were run.

### Round-4 Correction and Recheck

1. **Withdraw the scenario-rename request.** The maintained `receivable-request-fingerprint-and-conditional-writeoff` specification requires the exact scenario heading `A current v8 profile repairs a missing feature table transactionally`. The active delta retains that heading. Its normative body requires the v8-or-later pre-repair check to stop initialization, preserve the absent table, and expose no services. Test-plan row 032 and tasks 5.19–5.21 retain the required heading, while the single test ID `test_profile_data_portability_032_a_current_version_profile_stops_on_missing_payment_table` correctly names the fail-closed behavior. Renaming the scenario would violate the maintained heading contract; adding an alias would create a second scenario/test mapping. Round 4 finding 1 was a false positive and is resolved without changing the delta, labels, or test count.

2. **Keep the consumer rebases queued as separate work.** Current source has `MigrationRunner.currentVersion = 12` and introduces `category_mapping_history` at v9. This owner change correctly places the shared marker and mileage tables at v13 and category history at v9. The active customer-disclosure and mileage artifacts still describe their older v9/v10 plans. That version drift remains real and must be rebased in a later OpenSpec cycle before either dependent implementation. It does not block approval of this owner change; the dependency queue is already recorded in Round 4, and the workflow handles one OpenSpec change per cycle.

3. **Runtime behavior remains implementation work.** Current `MigrationRunner.run` routes a missing current-version payment table to repair, and `_migrateReceivableFeature` creates it. The new pre-repair guard is therefore not yet implemented. The active delta specifies the guard and test 032 plans to cover it; this approval is limited to the planning artifacts and does not certify runtime behavior.

### Findings — Round 5

#### 🔴 Critical (blocking)

None.

#### 🟡 Moderate

None for the profile-portability owner change. The customer-disclosure and mileage version rebases remain queued before their dependent implementations.

### Verdict — Round 5

VERDICT: APPROVE

No required artifact changes remain for this owner change. The review correction preserves the exact maintained scenario heading and its single test mapping.

CHANGES_APPLIED: appended this Round 5 review only; no implementation or tests were added or run.

### Rebuttals — Round 5

Round 4 required change 1 is withdrawn for the strict-validation and one-test-per-scenario reasons above. Round 4 required change 2 remains a queued dependency rebase, not a blocker to this owner change.
