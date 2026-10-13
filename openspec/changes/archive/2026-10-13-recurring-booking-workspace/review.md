## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, all four delta specs, maintained recurring/accounting contracts, and the occurrence repositories/schema
- **Validation evidence**: `openspec validate recurring-booking-workspace --type change --strict --json` passed with no issues; `openspec validate --specs --strict` passed 55/55. Structural validation does not establish semantic completeness. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **Occurrence review state and blocking reasons are not persisted.** The design requires durable state, but the existing occurrence table holds only identity, due date, journal, and invoice references. Add a `db` delta for review state and durable handoff/blocking reasons.
2. **Successful work does not advance the schedule.** Define occurrence advancement after successful posting or invoice-draft handoff, overdue catch-up, and month-end behavior. Current design prevents scans from advancing dates but does not define how later periods become eligible.
3. **Invoice-draft handoff is not retry-safe.** Specify how an occurrence identity reaches the draft use case and how recovery avoids duplicate drafts if creation succeeds before the occurrence link is saved.
4. **Category deactivation bypasses unresolved provenance.** Reconcile this delta with category provenance: inactivity can produce a warning, but `legacy_unverified` or `review_required` must continue to block posting.

### 🟡 Moderate

None.

### 📌 Suggestions

- Current generation advances the stored due date and writes journal/tax rows directly; Beleg mode inserts drafts directly. The proposal identifies these effects and requests a shared boundary, but its lifecycle contract remains incomplete.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Add persistence for occurrence review state and durable reasons.
2. Specify success advancement, catch-up, and month-end schedule rules.
3. Define idempotent invoice-draft handoff and failure recovery.
4. Ensure deactivation warnings do not bypass unresolved category provenance.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

---

## Review Metadata — Round 2

- **Review round**: 2
- **Prior round**: round 1 REVISE (4 items); repairs applied to proposal/design/specs
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec inspection; no edits to normative content, no shell, no tests
- **Artifacts reviewed**: proposal, design, all five delta specs (db, recurring, recurring-booking-workspace, accounting, typed-route-workspaces)
- **Validation evidence**: none in this round (run by orchestrator); semantic re-review only

### Round-1 closure check (normative language)

1. **Review-state persistence / db delta — CLOSED.** `specs/db/spec.md` ADDED requirement normatively persists `review_status` (pending/blocked/ready/handed_off/posted/failed), `block_reason`, `handoff_error` on `buchungsvorlagen_occurrences`, preserves `(vorlage_id, faelligkeit)` uniqueness and links, backfills existing rows to `pending`/NULL, and requires displays to read the persisted reason. `recurring-booking-workspace/spec.md` binds review displays to those persisted values. `design.md` Decision 4 and `proposal.md` Impact state the same.
2. **Advancement / catch-up / month-end — CLOSED.** `specs/recurring/spec.md` Auto-Generation states scans/reviews SHALL NOT advance the date; only `posted`/`handed_off` advances by exactly one interval step from the prior stored date with month-end clamping (31 Jan → 28/29 Feb; 29 Feb yearly → 28 Feb non-leap); overdue exposes only the single oldest uncompleted occurrence; failed/blocked leaves the date unchanged. Covered by matching scenarios. `design.md` Decision 2 and workspace confirmed-booking/Beleg requirements restate the one-step rule.
3. **Idempotent draft handoff — CLOSED.** `specs/recurring/spec.md` Modus requires occurrence identity as idempotency source, at most one linked draft per occurrence, and reuse on retry. `specs/recurring-booking-workspace/spec.md` Beleg requirement adds the recovery rule (successful draft with unsaved link SHALL attach the draft found by occurrence identity, no second draft) plus failure-stays-reviewable with persisted `handoff_error` and no date advance. `design.md` Decision 3 states the same with SHALL/MUST language.
4. **Provenance survives deactivation — CLOSED.** `specs/accounting/spec.md` Buchungsvorlagen normatively distinguishes `catalog_verified`/`user_confirmed` (warning, provenance unchanged) from `legacy_unverified`/`review_required` (remains blocked when mapping required; warning does not bypass) plus the `unmapped` independent-data case, with matching scenarios including the explicit stays-blocked scenario.

### Gaps

None blocking. Minor observation (non-blocking): `failed` is listed alongside non-terminal statuses while also described as reviewable/retryable; consistent in behavior (retryable with persisted reason) but the terminal/non-terminal vocabulary could be tightened later.

VERDICT: APPROVE

CHANGES_APPLIED: n/a
