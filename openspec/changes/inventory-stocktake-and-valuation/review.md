## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, both delta specs, maintained database/inventory specs, and current database table registry
- **Validation evidence**: `openspec validate inventory-stocktake-and-valuation --type change --strict --json` passed with no issues; `openspec validate --specs --strict` passed 55/55. Structural validation does not establish semantic completeness. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **Table-count requirements conflict.** The maintained database spec requires exactly 38 tables, while this delta says 38 base tables remain and adds two tables; runtime already lists 39 including `inventarbewegungen`. Update the main table-definition contract and migration scenarios to describe the actual before/after table sets.
2. **Recorded-count immutability is not enforced at the persistence boundary.** The spec requires snapshots to be immutable but defines no database guard against direct updates or deletes. Specify a trigger or equivalent enforcement and a direct-SQL rejection scenario.

### 🟡 Moderate

None.

### 📌 Suggestions

- Specify whether an empty article snapshot may be recorded and whether a recorded count remains readable after global inventory is disabled.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Reconcile the table inventory and migration scenarios with the maintained database contract and runtime table set.
2. Enforce immutable recorded snapshots at the persistence boundary and add a direct-SQL rejection scenario.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

---

## Review Metadata

- **Review round**: 2
- **Prior round**: REVISE; table-count contract and direct-SQL immutability guards were added and are now consistent across proposal, design, and delta specs.
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; this review append only; no tests
- **Artifacts reviewed**: proposal, design, inventory and db delta specs, maintained inventory and db specs, runtime schema table registry
- **Validation evidence**: `openspec validate inventory-stocktake-and-valuation --type change --strict --json` passed with no issues. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **Disabled-inventory history has no single normative behavior.** The proposal and design say previously recorded stocktakes remain visible read-only when global inventory is disabled, but the inventory spec says they `MAY` remain available. The maintained global-toggle requirement also describes inventory-related UI as hidden without explicitly naming this history exception. Set one required behavior in the delta spec and state that read-only history is the exception while new stocktake actions and live-inventory controls remain unavailable.
2. **A direct SQL insert can create an empty recorded header.** The table permits either `entwurf` or `erfasst` on insert, while the completeness guard is described only for a draft-to-recorded transition. A caller can insert an `erfasst` header directly with no positions; the position guard then prevents adding positions. Require newly inserted headers to start as `entwurf` (or equivalent database enforcement) and add a scenario proving a direct insert as `erfasst` is rejected. The guarded transition must remain the only path to recorded state and validate at least one position plus all non-null counts.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

CHANGES_APPLIED: yes

## Required Changes

1. Make the disabled-inventory history behavior normative and consistent: use `SHALL` for read-only access to prior recorded counts, explicitly allow that history view as the global-toggle exception, and keep new drafts/edits and live stock UI unavailable.
2. Specify database enforcement that headers are inserted only as `entwurf`; allow `erfasst` only through a completeness-checked transition requiring at least one position and a count for each. Add a direct-SQL scenario for rejected insertion of an `erfasst` header.

## Rebuttals

- Round 1 finding 1, table inventory: **fixed**. The delta now lists all 41 tables; its migration scenarios define the 38 non-inventory table baseline plus `inventarbewegungen` as 39, then add both stocktake tables for 41.
- Round 1 finding 2, recorded-count immutability: **fixed**. The inventory and database deltas require guards against recorded-header update/delete and recorded-position insert/update/delete, with direct-SQL rejection scenarios.
- Round 1 suggestion, empty article snapshot: **addressed**. Draft creation requires at least one inventory-enabled article, the zero-article scenario forbids an empty draft, and persistence requires at least one position before recording.
- Round 1 suggestion, disabled-inventory history: **partially addressed**. Proposal/design choose read-only history, but the `MAY` wording leaves the spec optional; see Moderate finding 1.
