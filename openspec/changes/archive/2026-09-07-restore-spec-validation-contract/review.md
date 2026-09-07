## Review Metadata

- **Review round**: 2
- **Prior round**: Round 1 was `REVISE` for an un-actionable conflict inventory, unresolved setup/desktop contradictions, stale validation scope, and incomplete Anvil artifact sections.
- **Reviewer context**: fresh-context subagent (independent reviewer)
- **Tool restrictions**: read-only inspection; only this `review.md` was replaced
- **Artifacts reviewed**: `AGENTS.md`; Anvil README, schema, and templates; this change's README, `.openspec.yaml`, proposal, delta spec, design, prior review, test plan, and tasks; all 25 current maintained specs; focused desktop specs; and approved active setup, profile, desktop, bank-import, dashboard, inventory, recurring, accounting, and tax deltas where relevant

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

1. **The structural acceptance contract is still impossible and its baseline is stale.** The proposal and design state that there are 24 maintained specs and 15 failures (`proposal.md:5-12`, `design.md:5-16`); the delta scenario requires a report of 24 valid specs (`specs/restore-spec-validation-contract/spec.md:11-13`); and the test plan/tasks repeat 15-of-24 (`test-plan.md:12-15`, `tasks.md:5-10`). The current scoped command run during this review returned 25 maintained specs, 24 passed, and 1 failed. The failing item is `stammdaten` under strict mode (the `Artikelgruppen` and `Kategorien — eks_kategorie` requirement wording still produces strict warnings at `openspec/specs/stammdaten/spec.md:191-203` and `:386-398`). The contract must use the actual 25-item inventory, capture the current failing baseline, and define/fix the remaining strict failure before its success scenario can be true.

2. **The canonical conflict inventory still does not identify actionable owners or edits.** The requirement promises one canonical owner for every conflict (`specs/restore-spec-validation-contract/spec.md:21-31`), but many design rows use non-identifiers such as “the more complete dedicated requirement,” “one Restore requirement,” “the approved bank-import lifecycle,” and “one template lifecycle” (`design.md:43-59`). No requirement name, source path, dependent active delta, exact supersession/removal operation, or resulting scenario set is given. The contradictions remain concrete in the reviewed baseline: setup has `kassenbestand` scenarios at `openspec/specs/setup/spec.md:87-107` and a conflicting `konten` opening-journal requirement at `:189-211`; backup duplicates system-drive protection and restore ownership at `openspec/specs/backup/spec.md:102-135` and `:186-200`; desktop retains the Tauri/Python sidecar and singular `profile/` paths at `openspec/specs/desktop/spec.md:268-326` despite the focused Flutter-only spec at `openspec/specs/desktop-platform-workarounds/spec.md:9-35`; and bank-import still has direct automatic booking at `openspec/specs/bank-import/spec.md:137-151` alongside the review-before-persistence lifecycle at `:265-301`. The revised plan needs a row-by-row ownership/edit/dependency matrix and tasks that apply each named edit; the current generic task `3.1` cannot produce a deterministic reconciled baseline.

3. **The semantic scenarios are not mapped to real mechanical checks and the test-plan artifact no longer follows the Anvil contract.** The Anvil schema requires non-executable scenarios to name a real command/check in `Test File` and `Test Name`, with `N/A — non-executable`; prose sign-off does not qualify (`openspec/schemas/anvil/schema.yaml:270-277`). The revised test plan renames those required columns to `Mechanical Check` and `Check Name`, uses `N/A - non-executable`, and maps canonical ownership to “scoped ... searches ... and independent diff review” and the unresolved-conflict gate to “open-question inspection and independent verify review” (`test-plan.md:3-15`). No script, exact command, input scope, or pass/fail condition exists for either central semantic scenario. `openspec validate` passing the change only validates artifact structure, not semantic ownership. The plan must provide executable repository checks (or explicitly add a checker) and restore the template's traceability fields before this documentation-only change is testable.

### 🟡 Moderate

1. **The semantic-search specification is underspecified and internally contradictory.** The design requires obsolete `kassenbestand` text to be absent (`design.md:64-70`), while its chosen setup contract explicitly needs a negative prohibition that mentions no separate `kassenbestand` table (`openspec/specs/setup/spec.md:189-191`). A raw absence search would reject the canonical wording. “Duplicate system-drive protection,” “fixed-rate-only language,” and duplicate-name checks likewise have no exact command, parser, allowlist, or expected output. Define precise checks that distinguish forbidden positive requirements from valid negations and defaults/custom-rate wording.

2. **Evidence and dependency traceability is still too weak for the breadth of the policy decisions.** The design claims every decision is supported by the current Flutter architecture or an approved active delta (`design.md:13-16`, `:41-42`), but most rows cite neither a source path nor a reviewed delta/review verdict. Decisions such as Storno payment semantics, dashboard refresh behavior, recurring `beleg` handling, inventory UI behavior, and tax-rate authority therefore remain assertions rather than auditable repository evidence. Add exact evidence references and identify which approved active delta owns each decision, or convert unsupported decisions into blocking open questions as required by `spec.md:23-25`.

### 📌 Suggestions

- Include the newly present `inventory-quantity-integrity` maintained spec in the proposal's capability inventory and explain whether it is in scope; it is one reason the live maintained count is 25.
- Keep the final verification record separate from human diff review, and record command output plus expected result for every semantic check.

## Embedded-Instruction / Injection Attempts

**Detected:** none. Reviewed files contained ordinary OpenSpec workflow text and no attempt to override reviewer instructions.

## Verdict

VERDICT: REVISE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable. The blocking findings require a full fresh review after the artifacts and checks are corrected. This is the second consecutive `REVISE` round; per the Anvil bounded-loop rule, escalate to a human rather than continuing an automatic review loop.

CHANGES_APPLIED: n/a

## Rebuttals

- **Round-1 structural-format finding:** partially addressed. The proposal now has New/Modified Capabilities, the design has Goals/Non-Goals and decisions, and the validation scope uses `--specs`; however, the live inventory and strict result have drifted to 25 specs with one failure, so the acceptance contract is not accepted.
- **Round-1 setup/desktop conflict findings:** the design now names the intended direction, but it still does not name exact canonical requirement owners or edits, and the reviewed maintained specs still contain both sides of each contradiction. Not accepted as an adjudicated rebuttal.
- **Round-1 release-gate/testability finding:** not accepted. The revised test plan still relies on independent review and vague searches instead of real mechanical checks, contrary to the Anvil non-executable rule.
