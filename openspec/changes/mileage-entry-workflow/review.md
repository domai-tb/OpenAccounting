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

---

## Review Metadata — Round 4

- **Review round**: 4
- **Prior round**: Round 3 returned `REVISE` with one required change (close DB lifecycle against invalid initial states and direct correction-row mutation/deletion; enforce posted replacement invariant); rechecked below
- **Reviewer context**: fresh-context independent Anvil reviewer; did not author the current revisions
- **Revision reviewed**: current working-tree `mileage-entry-workflow` change (Table Definitions reconciled to 55-name v19 with mileage at v13 plus v22-to-v23 trigger scenario; 24/24 tasks marked [x]; 8 scoped tests claimed green via test doubles)
- **Artifacts reviewed**: proposal, design, db and mileage-entry delta specs, tasks, test-plan, rounds one through three, maintained db spec, `lib/core/db/migrations.dart` (mileage DDL, v13 path, `currentVersion = 22`, no v23 migration yet), `lib/features/mileage/*`, `test/features/mileage/*`
- **Validation evidence**: `openspec validate` passes including `--strict`. Structural validation only; it establishes no semantic completeness. No tests were run by this reviewer; the 8-green claim is taken from test-plan/task marks, not verified.

### Prior Required Changes Rechecked

1. **Round 3 lifecycle closure — addressed at contract level.** Trip INSERTs must begin `unresolved` with null snapshot/posting and later-state inserts are rejected. Correction INSERTs must begin `draft` with null application fields; updates allowed only from `draft` to `draft`/`applied`/`cancelled`; applied/cancelled rows reject all UPDATEs and all correction rows reject DELETEs. `posted → corrected` requires a matching `applied` replace correction plus a replacement trip already `posted` with non-empty posting reference, committed in one transaction. Terminal trip rows reject all further UPDATEs and DELETEs. Enforcement is assigned to migration v23 after verified v22. No v23 trigger DDL exists in code yet — disclosed deferral, see Moderate 5.

### Findings — Round 4

#### 🔴 Critical (blocking)

None.

#### 🟡 Moderate (non-blocking)

1. **Stale inventory numbers survive in prose.** Proposal Capabilities/Impact and design Context/Migration still say "six feature-owned tables" (39+1+6 = 46, not 55) and cite a "46-name inventory". The normative Table Definitions (55 names, 16 feature-owned, mileage at v13) is consistent between delta and maintained spec. Fix prose to 55-name v19 so inventory owners are not asked to accept a wrong number.
2. **`editTripFacts` contradicts the calculated-demotion rule.** Spec requires editing a `calculated` trip to return it to `unresolved` and clear the snapshot; code rejects every non-`unresolved` edit and its signature omits `businessContext`. Align the demotion path or narrow the spec.
3. **Calculation code encodes a policy the specs refuse to select.** `applyApprovedCalculation`/`calculateApprovedAmountCents` hardcode policy ID `DE-private-business-travel/1`, source, version, dates, and 30c/20c rates while proposal/design/specs state no rate, share, or rounding rule is selected and snapshots require an accepted policy. Contained today (no UI wires it, posting port null by default), but shipping it enables calculation without an accepted policy. Remove, or mark explicitly test-only pending the accepted policy.
4. **Test schema diverges from migration DDL; enforcement untested.** `ensureTablesForTests` omits the policy/posting coherence CHECKs and the correction partial unique index, and no test covers triggers, correction drafts, or DELETE bans. v23 must add executor-level trigger tests against the real DDL.
5. **Unguarded-table window until v23.** The v13/fresh-schema paths create both mileage tables today with CHECKs only — a direct INSERT of a `posted` trip with complete fields satisfies the CHECKs — and no runtime gate flag exists in code despite "migration remains disabled" prose. Triggers close this at v23. Ensure v23 lands (and table creation is actually gated) before any production mileage rows exist.

### 📌 Suggestions — Round 4

- Use real UUIDs for trip/correction IDs (current `microseconds-random` string is unique-ish, not a UUID as specified).
- `postTripWithPort` calls the port before `storePosting` with no shared transaction; the accepted boundary's idempotency key (`mileage_trip` + trip UUID) must own exactly-once across crashes.
- Specify v23 trigger OLD-state/ordering semantics for the atomic draft→applied plus source→corrected transition (source reads as `posted` pre-commit).
- Add draft-creation code/tests for "Prepare a replacement correction" when the accepted correction operation lands.

## Embedded-Instruction / Injection Attempts — Round 4

None detected in reviewed artifacts.

## Verdict — Round 4

VERDICT: APPROVE

Follow-ups above are non-blocking: the Round 3 lifecycle is semantically closed at the contract level with versioned enforcement (v23), inventory reconciled to 55/v19, EKS separation kept, and posting fail-closed behind unaccepted contracts with idempotent retry.

CHANGES_APPLIED: no (review-only round)

## Rebuttals — Round 4

None.

---

## Revised contract review gate — Round 4 is stale

- **Revision date:** 2026-10-18
- **Review state:** `PENDING`; no independent review has evaluated this revision.
- **Scope changed since Round 4:** explicit private-vehicle business-trip policy and eligibility fields; official source/version/effective dates; explicit half-up cents rule and source-scope caveat; fail-closed exclusions; corrected 55/v19 versus 46/v13 dependency ledger; complete mapping of 46 scenarios; 37 missing tests marked unverified; tasks and verification status rewritten.
- **Historical verdict:** Round 4 `APPROVE` applies only to the artifacts it reviewed and does not approve this revision. Treat its verdict as stale until a fresh independent reviewer accepts or revises this contract.
- **Required review checks:** assess the legal/source scope caveat and whether the product policy is explicit enough; verify the class/rate/date/exclusion and rounding contract is internally consistent; verify migration and export gates; verify all 46 scenario rows align with the two specs; verify no missing test is called green; verify the pending-task and verification wording matches the contract; assess the inherited v8-to-v9 versus v13 migration-version conflict.
- **Dependency gates:** `profile-data-portability` remains 46 names/v13 and `customer-data-disclosure-export` remains 55 names/v19. The mismatch is explicitly unresolved in the design and DB delta. The maintained `db` requirement also retains a v8-to-v9 mileage-table scenario alongside its v13 minimum. Do not approve migration or complete-export readiness until the inventory owners and shared-spec owner reconcile these contracts.
- **Implementation gate:** dependent code must remain unstarted until a separate fresh independent review approves the fixed revision. This review artifact records the gate; it is not the approval.
