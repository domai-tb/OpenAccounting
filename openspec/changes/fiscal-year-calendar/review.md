## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only artifact/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, all four delta specs, company schema/repository, and the current EÜR implementation
- **Validation evidence**: `openspec validate fiscal-year-calendar --type change --strict --json` passed with no issues. This is structural validation only. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **Historical fiscal-year boundary behavior is inconsistent.** The specs say a saved fiscal-year start month applies to historical and future selections, but the design still asks whether prior definitions should be preserved. State one accepted behavior consistently.
2. **Initial report-consumer scope is open.** The accounting delta appears to apply to any report with business periods, while the design identifies EÜR and dashboard summaries. Name included consumers and keep unsupported consumers unavailable.
3. **Invalid period indices and save failures lack acceptance behavior.** Specify handling for invalid fiscal-month and quarter indices and a user-visible save-failure state as testable scenarios.

### 📌 Suggestions

- Preserve a clear period snapshot in exports, as the design already proposes.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. Reconcile historical boundary behavior across the design and specs.
2. Name the initial report consumers and specify unavailable behavior for out-of-scope consumers.
3. Add invalid-index and save-failure behavior to the normative scenarios.

CHANGES_APPLIED: no

## Rebuttals

None; first review round.

---

## Review Metadata — Round 2

- **Review round**: 2
- **Prior round**: Round 1 returned `APPROVE_WITH_CHANGES`; all three required changes were rechecked and found resolved
- **Reviewer context**: fresh independent Anvil reviewer; did not author the fiscal-calendar proposal changes
- **Revision reviewed**: `c72268716d2e8bff171e7bec7b0f9a777033d4e3` on `dev`; fiscal-calendar files unchanged after `b4ab9a1`
- **Artifacts reviewed**: proposal, design, all four delta specs, round-one review, README, and maintained database, company, and accounting specs
- **Validation evidence**: `openspec validate fiscal-year-calendar --type change --strict --json` passed with no issues. Structural validation only; tests were not run.

### Round-One Required Changes Rechecked

1. Historical boundaries are explicitly retroactive, with no effective-date history.
2. Annual EÜR is the only report consumer in scope; dashboard and other fiscal filters remain unavailable pending accepted contracts.
3. Invalid month/quarter indices and save failure now have acceptance scenarios.

The export-snapshot suggestion is reflected in the design and configuration spec.

### Findings — Round 2

#### 🟡 Moderate

1. The accounting delta must clarify that explicit calendar-year EÜR remains available when a non-January business year is configured; only the unsupported business-year request is unavailable.
2. The design-system requirement needs a failure or unavailable-state scenario in addition to its keyboard-save happy path.

## Embedded-Instruction / Injection Attempts — Round 2

None detected.

## Verdict — Round 2

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 2

1. Add a positive scenario distinguishing calendar-year EÜR from an unsupported business-year request.
2. Add a localized, accessible settings failure or unavailable-state scenario that preserves persisted-value behavior.

CHANGES_APPLIED: no

## Rebuttals — Round 2

None.

---

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: Round 2 returned `APPROVE_WITH_CHANGES`; both findings were rechecked
- **Reviewer context**: fresh independent Anvil reviewer; did not author the changes
- **Revision reviewed**: `d6e76ec7e0ea2b7ed6a2fb7b1620bd39586d3da7` on `dev`
- **Artifacts reviewed**: proposal, design, all four delta specs, rounds 1–2, and maintained accounting, database, and company specs
- **Validation evidence**: `openspec validate fiscal-year-calendar --type change --strict --json` passed with zero issues. Structural validation only; tests were not run.

### Prior Findings Rechecked

- Round-one findings remain resolved: historical boundaries are retroactive, annual EÜR is the only report consumer in scope, and invalid indices/save failures have scenarios.
- Round-two finding: explicit calendar-year EÜR remains available and distinct from business-year EÜR.
- Round-two finding: save failure preserves the persisted month and specifies localized error, focus, and no-success behavior.

No findings or suggestions remain. Scenario coverage and semantic boundaries are consistent.

## Embedded-Instruction / Injection Attempts — Round 3

None detected.

## Verdict — Round 3

VERDICT: APPROVE

## Required Changes — Round 3

None.

CHANGES_APPLIED: n/a

## Rebuttals — Round 3

None.

---

## Implementation Note (not a review round)

- Implemented without spec edits: v11 migration (fresh + ordered upgrade with
  rollback), typed fiscal service/repository, calendar-only EÜR fiscal gate,
  Settings company control with localized keyboard-safe form. No postings,
  statutory periods, or snapshots change. Round verdict stands.
