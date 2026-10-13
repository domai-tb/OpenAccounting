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

---

## Review Metadata

- **Review round**: 3
- **Prior round**: APPROVE_WITH_CHANGES; 2 Required Changes (normative disabled-history; requirement-level SHALL insert-only-as-entwurf)
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; this review append only; no shell, no tests
- **Artifacts reviewed**: round 2 Required Changes text, repaired `specs/inventory/spec.md:38-39,55-61,77-100`, `specs/db/spec.md:49-61`, `design.md:30,36`, `proposal.md:7`, maintained `inventory/spec.md:234-246` and `db/spec.md` table inventory
- **Validation evidence**: no validation or tests run per task constraints; semantic inspection only

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

None.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE

CHANGES_APPLIED: yes

## Required Changes

None.

## Rebuttals

- Round 2 Required Change 1, normative disabled-history: **fixed**. `specs/inventory/spec.md:79` now states in SHALL language that the recorded-stocktake history view SHALL remain readable as the sole global-toggle exception while new drafts, edits, and live-stock UI SHALL remain unavailable; `specs/inventory/spec.md:38` and scenario at `55-61` already use SHALL for read-only history with no new rows, and `design.md:30` / `proposal.md:7` prose is aligned. No SHALL-vs-SHALL conflict with the maintained global-toggle requirement, which lists hidden items (navigation, warnings, stock fields, manual controls, shortcuts, invoice warnings) without naming the history view; the delta's explicit sole-exception carve-out resolves the prior MAY ambiguity.
- Round 2 Required Change 2, requirement-level SHALL insert-only-as-entwurf: **fixed**. `specs/inventory/spec.md:79` now states new `inventuren` rows SHALL be inserted only with status `entwurf`, with null counts permitted only in drafts and the draft-to-recorded transition guard remaining enforced; the completeness rule (at least one position, every position counted) and persistence-boundary guards are stated in the same requirement, and scenarios at `specs/inventory/spec.md:88-93` and `specs/db/spec.md:49-54` prove direct-SQL `erfasst` insert rejection.

---

## Review Metadata

- **Review round**: 4
- **Prior round**: APPROVE; no open review findings. This fresh review found a stale exact table-count contract and input-validation gaps in the implemented workspace.
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only artifact/source/test inspection and OpenSpec validation; this review append only; no tests run
- **Artifacts reviewed**: proposal.md, design.md, inventory and db delta specs, prior review rounds, test-plan.md, tasks.md, verify.md, maintained inventory/db specs, migrations and database registry, stocktake repository/use cases/page, and focused tests
- **Validation evidence**: `openspec validate inventory-stocktake-and-valuation --type change --strict --json` passed 1/1; `openspec validate --specs --strict --json` passed 62/62 with INFO-only long-requirement notices. No tests were rerun. `verify.md` reports 25 focused passes and a full-suite result of 1,171 passed / 79 failed, with `DECISION: FAIL`.

<!-- STALENESS: this verdict applies to the exact proposal, design, and spec -->
<!-- contents inspected in round 4. Later edits to those files void it. -->

## Findings

### 🔴 Critical (blocking)

1. **The exact 41-table contract contradicts the current schema.** The delta requires exactly 41 tables after all current migrations (`specs/db/spec.md:5-12,97-103`), but the current database registry and migration test expect 44 named tables (`lib/core/db/database.dart:53-98`; `test/db/inventory_stocktake_migration_test.dart:53-58,103-106`). The stocktake is migration v18 and v19 adds posting-group tables, so a current fresh install cannot satisfy the 41-table requirement. The test called `test_table_count_verification` only checks that listed tables are present; it does not assert the actual SQLite table set equals 41. Reconcile the inventory against the supported migration versions and test exact set equality before this contract proceeds.

### 🟡 Moderate

2. **Invalid count text can erase a saved draft count** (`lib/features/inventory/stocktake_page.dart:253-256,267-273`). If a user changes a saved value to `3x` and presses Save, `_parseCount` returns null and `setCount` persists null without an error; the count silently becomes missing. Distinguish an empty field from non-empty unparseable text, validate every field before writing, and add a regression test.

3. **A precision error is shown as a negative-count error** (`lib/features/inventory/stocktake_page.dart:507-512`). Entering a non-negative value such as `1.2345` correctly fails the three-decimal limit, but the UI says negative quantities are forbidden. Add a dedicated localized precision message and test this input.

4. **The green workspace tests do not exercise the workspace UI** (`test/features/inventory/stocktake_workspace_test.dart:446-455`). `test_recorded_quantities_appear_as_physical_counts` checks the repository result only; no test builds `StocktakeWorkspacePage`, so the test plan does not verify the visible physical-count label or unavailable book, variance, and valuation rows. Add one widget test that asserts those displayed values and labels.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

CHANGES_APPLIED: n/a

## Required Changes

1. Reconcile the database-table inventory and migration scenarios with the actual current schema; make the test assert exact table-set equality.
2. Reject non-empty unparseable count text before persistence and provide an accurate localized message for precision failures.
3. Add widget-level coverage for the recorded stocktake display contract.

## Rebuttals

- Round 3's read-only history and insert-only-as-entwurf changes remain consistent in the reviewed specs and database triggers. This fresh verdict does not reopen those findings.

---

## Review Metadata

- **Review round**: 5
- **Prior round**: REVISE with one Critical table-inventory finding and three Moderate implementation/test findings.
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only artifact, implementation, and test inspection; no tests rerun by reviewer
- **Artifacts reviewed**: proposal.md, design.md, both delta specs, test-plan.md, tasks.md, verify.md, review rounds 1–4, migration/database registry, stocktake page/repository/use cases, and focused tests
- **Validation evidence**: worker reported 28/28 focused tests, clean scoped analysis, successful format check, and passing strict OpenSpec validation. Full-suite result remains pending for this round.

<!-- STALENESS: this verdict applies to the proposal, design, and specs inspected -->
<!-- in round 5. Later edits to those files void it. -->

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

None.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE

CHANGES_APPLIED: no

## Required Changes

None.

## Rebuttals

- Round 4 finding 1, exact schema inventory: **fixed**. The fresh v19 database assertion checks exact equality with 51 tables. The v18 snapshot test checks exact equality with 48 tables after removing the three v19-only tables and setting `user_version` to 18. This constructs the v18 snapshot from a fresh v19 database rather than pausing `MigrationRunner` immediately after v18; the stocktake migration path is independently covered by migration tests.
- Round 4 finding 2, malformed count data loss: **fixed**. `_saveAndRecord` validates all entered values, including precision, before calling `setCount`; the regression test proves malformed and later over-precision input leave existing draft counts unchanged.
- Round 4 finding 3, precision feedback: **fixed**. Precision failures map to dedicated English and German messages and the widget test distinguishes this feedback from the negative-count message.
- Round 4 finding 4, recorded result UI: **fixed**. The widget test asserts the physical count and physical-count label while book quantity, variance, and valuation remain unavailable.

---

<!-- STALENESS: this review covers the staged v18 implementation and artifacts
     on top of 2ca1966 inspected on 2026-10-11. Later implementation/spec edits void it. -->

## Review Metadata — Round 6

- **Review round**: 6
- **Prior round**: 5 (APPROVE; later verification found multi-row draft writes were not atomic)
- **Reviewer context**: fresh independent review of the staged diff; no authoring transcript
- **Tool restrictions**: read-only index, artifact, and implementation inspection; no tests run by reviewer
- **Artifacts reviewed**: 25 staged files on top of `2ca1966`, including v18 migration/database registry, transaction-safe stocktake repository/page, rollback regression, OpenSpec tasks/test-plan/verify, and localization
- **Validation evidence**: worker supplied 29/29 focused tests, clean scoped analysis, format and strict OpenSpec validation; staged Dart files parse and `git diff --cached --check` passes. Latest full-suite evidence remains 1,316 passed / 63 failed.

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

None for this scoped v18 checkpoint.

### 📌 Suggestions

Keep archival blocked until a fresh full-suite run passes with zero failures.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE

CHANGES_APPLIED: no

## Required Changes

None for the scoped local checkpoint. The repository-wide full-suite gate remains open.

## Rebuttals

- The draft save-loss finding is fixed: `saveCounts` validates all values, persists count updates, and optionally records the stocktake in one transaction. The forced second-write failure regression confirms earlier counts and draft status roll back; focused inventory tests pass 29/29.
- The v18 boundary is isolated: `MigrationRunner.currentVersion` is 18 in the staged patch, the two stocktake tables and seven guards are included, `_asInt` appears once, and settlement/email/balanced-posting migration code is excluded. Settlement table names occur only in the compatibility fixture that verifies the exact v18 snapshot from a later integrated schema.
