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
