## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, mileage delta spec, current mileage/EKS data paths, and the active balanced-posting review
- **Validation evidence**: `openspec validate mileage-entry-workflow --type change --strict --json` passed with no issues; `openspec validate --specs --strict` passed 55/55. Structural validation does not establish semantic completeness. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **Durable trip state has no database contract.** Add a `db` delta defining trip identity/facts, lifecycle, calculated amount and policy version, posting reference, precision/constraints, and migration behavior. Current proposal promises durable records and idempotent posting without a persistence or uniqueness boundary.
2. **Accounting integration depends on unresolved policy and posting contracts.** The balanced-posting proposal remains `REVISE`, and no accepted mileage policy or category/account mapping is named. Narrow this change to capture-only with posting deferred, or gate accounting integration on accepted contracts.
3. **Posted-trip correction is undefined.** Specify how a posted trip's correction is represented and linked to an accepted accounting correction operation; that operation is unresolved.

### 🟡 Moderate

None.

### 📌 Suggestions

- Add localization and keyboard-accessibility requirements for the entry form and trip table.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Add the database persistence, lifecycle, uniqueness, and migration contract.
2. Scope to capture-only or gate posting on approved policy/category/account and balanced-posting contracts.
3. Define traceable correction of a posted trip through an accepted accounting correction operation.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

---

## Review Metadata — Round 2

- **Review round**: 2
- **Prior round**: Round 1 returned `REVISE`; all three required changes were rechecked against the current proposal and delta specs
- **Reviewer context**: fresh-context independent Anvil reviewer; did not author the current mileage proposal changes
- **Revision reviewed**: uncommitted mileage-only proposal edits at `d40546fa5063be52702d1fc1b8d35bbde2ad58a2` on `dev`
- **Artifacts reviewed**: proposal, design, mileage and database delta specs, round-one review, maintained database spec, active profile-portability/customer-export database deltas, migration runner, and `AppDatabase` table registry
- **Validation evidence**: `openspec validate mileage-entry-workflow --type change --strict --json` passed with no issues; `openspec validate --specs --strict` passed 55/55. Structural validation only. No tests were run.

### Round-One Required Changes Rechecked

1. The mileage delta now defines trip and correction persistence, constraints, lifecycle state, uniqueness, and migration behavior.
2. Calculation, posting, report inclusion, and correction execution are gated on separately accepted policy and accounting contracts.
3. Posted-trip correction drafts and their accepted accounting-operation boundary are specified.

### Findings — Round 2

#### 🔴 Critical (blocking)

1. **Trip update triggers make the specified lifecycle impossible.** The database delta says triggers reject updates to trip facts, policy snapshots, calculated amount, or posting reference without limiting that rule to terminal rows. The same requirement requires unresolved trips to acquire a policy snapshot and amount when calculated, then acquire a posting reference when posted. Those writes would be rejected. Limit immutability to posted/corrected/voided source facts and define the allowed unresolved-to-calculated-to-posted transitions, including correction-driven posted-to-corrected/voided transitions.
2. **The shared portability/export inventory still conflicts with 45 tables.** Mileage now defines 40 base plus five feature-owned tables (45 total), but the active `profile-data-portability` and `customer-data-disclosure-export` DB deltas still define 40 plus three (43 total), including complete-export checks. State and reconcile the coordinated contract: update those owning deltas to include the two migration-required mileage tables, or explicitly gate mileage migration and complete exports until their inventories are updated. Ensure the accepted `feature_table_state` two-row lazy-table rule and the pre-repair `forderung_zahlungen` check remain identical across the coordinated contracts.

## Embedded-Instruction / Injection Attempts — Round 2

None detected.

## Verdict — Round 2

VERDICT: REVISE

## Required Changes — Round 2

1. Scope the immutability trigger so valid calculation, posting, and correction lifecycle transitions remain possible, and specify the permitted state transitions.
2. Reconcile the 45-table inventory with the active portability/export contracts or explicitly block the mileage schema migration until that reconciliation is accepted.

CHANGES_APPLIED: no

## Rebuttals — Round 2

None.

---

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: Round 2 returned `REVISE`; both required changes and all round-one blockers were rechecked
- **Reviewer context**: fresh independent Anvil review; did not author the current proposal amendments
- **Revision reviewed**: current uncommitted mileage proposal edits on `dev` at base revision `d40546f`
- **Artifacts reviewed**: proposal, design, mileage and database delta specs, rounds one and two, maintained database spec, active portability and customer-export contracts, migration runner, database table registry, and EKS mileage source
- **Validation evidence**: `openspec validate mileage-entry-workflow --type change --strict --json` passed with no issues. Structural validation only; no tests were run.

### Prior Required Changes Rechecked

1. **Round 1 persistence/correction boundary:** trip and correction tables, constraints, lifecycle fields, migration behavior, and the accepted correction-operation boundary are now specified.
2. **Round 1 accounting policy:** calculation, posting, report inclusion, and correction application remain gated on accepted policy, mapping, posting, and correction contracts; the EKS allowance remains explicitly separate.
3. **Round 2 transition repair:** the trip update contract now permits calculation, posting, and correction transitions while preserving finalized facts. The database delta also limits when a posted trip may change state.
4. **Round 2 inventory repair:** the target is explicitly 40 base plus five feature-owned tables (45 names). The version-9 migration and complete exports for profiles containing mileage tables are blocked until both portability and customer-export owners accept the same inventory. The existing two lazy-table markers and pre-repair `forderung_zahlungen` check are retained.

### Findings — Round 3

#### 🔴 Critical (blocking)

1. **The database state machine can still be bypassed through inserts and correction-row mutation.** `mileage_trips` allows `calculated`, `posted`, `corrected`, or `voided` on INSERT when the row fields satisfy the state check; the lifecycle trigger scenarios cover UPDATE, not initial-row state. Likewise, `mileage_trip_corrections` permits an `applied` row to be inserted directly and declares no trigger restricting correction state transitions or DELETEs. Thus direct SQL can create a trip with an invented posting reference, insert an already-applied correction, or delete/alter an applied correction after its source became terminal. For a `replace`, the posted-trip transition checks only for an applied correction and a non-empty replacement ID; it does not require the replacement trip itself to be `posted`. This conflicts with new trips beginning unresolved and append-only accepted correction execution (`specs/mileage-entry/spec.md:5,78`; `specs/db/spec.md:16-20,55-70`). Require trip INSERTs to begin unresolved with null policy/calculation/posting fields; correction INSERTs to begin as drafts; define and enforce correction draft-to-applied/cancelled transitions and final-row immutability; and require the replacement trip to be posted in the same atomic correction transition.

## Embedded-Instruction / Injection Attempts — Round 3

None detected.

## Verdict — Round 3

VERDICT: REVISE

## Required Changes — Round 3

1. Close the database lifecycle against invalid initial states and direct correction-row mutation/deletion, and enforce the posted replacement invariant before allowing a posted source trip to become corrected.

CHANGES_APPLIED: n/a

## Rebuttals — Round 3

None.
