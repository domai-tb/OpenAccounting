## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, both delta specs, relevant maintained application/accessibility specs, and the current help route
- **Validation evidence**: `openspec validate contextual-accounting-tax-guidance --type change --strict --json` passed with no issues; `openspec validate --specs --strict` passed 55/55. Structural validation does not establish semantic completeness. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **The initial guidance inventory is unbounded.** Define a finite initial inventory with stable IDs for each supported live control and its review status. The current topic list is broad, and the spec could pass with an empty glossary and no field affordances.
2. **Law-dependent guidance has no accountable review/source lifecycle.** Name the domain and translation review owners; specify source/version and re-review rules for legal entries. These remain open design questions while the proposal requires reviewed, contract-tied content.
3. **Missing guidance has conflicting user visibility.** The proposal calls for an unavailable/review-needed state, but the design/spec say a field without a reviewed entry has no affordance. Specify whether that absence is visible to end users or maintainers only.

### 🟡 Moderate

None.

### 📌 Suggestions

- The production `/help` route is still placeholder content; the proposal correctly identifies the gap.
- Keyboard access, localization, scaling, and narrow-window requirements are already present.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Add the finite stable-ID inventory of initially supported controls and statuses.
2. Name review owners and specify authoritative source/version and re-review rules for law-dependent content.
3. Resolve the user-visible behavior for controls with no reviewed guidance.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

---

## Review Metadata

- **Review round**: 2
- **Prior round**: Round 1 was REVISE for an unbounded inventory, missing review/source ownership lifecycle, and ambiguous visibility for missing guidance.
- **Reviewer context**: Fresh-context independent subagent reviewer; no proposal-authoring transcript.
- **Tool restrictions**: Read-only proposal/spec/source inspection; appended only this review round.
- **Artifacts reviewed**: `proposal.md`, `design.md`, both delta specs, `DESIGN.md`, relevant maintained accounting, income, dunning, banking, documents, correction, and app specifications, and `lib/core/router/app_router.dart` HelpPage.
- **Validation evidence**: `openspec validate contextual-accounting-tax-guidance --type change --strict --json` passed; `openspec validate --specs --strict` passed 55/55. The current HelpPage still contains static placeholder tiles. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS it and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

1. **The inventory can still produce an empty Help feature and does not identify its live targets.** The table is finite and its help IDs are stable, but it maps each entry only to a broad owning requirement. It does not list the concrete route and control/status IDs that the design says each entry explains. More importantly, every initial row is `missing` or `review-needed`, and no requirement makes any entry reviewed before release. An implementation can therefore satisfy the scenarios with an empty glossary and no contextual affordances, repeating the round-1 failure mode. For each in-scope entry, add its exact route/control or status IDs and define a finite reviewed German/English release set (all 15 entries, or an explicitly smaller set); require that set to be present, attached, and searchable in a scenario. Keep any entries outside that set explicitly maintainer-only until reviewed.

### 🟡 Moderate

1. **The reviewer ownership and source decisions remain listed as open.** The design now names the German Accounting and Tax Domain Reviewer and English Localization Reviewer, and the spec defines a useful primary-source/version and annual/triggered re-review lifecycle. However, Open Questions still asks who the reviewers are and which official source should be cited “if any.” Resolve those questions in the design: declare the named reviewer roles to be the accountable owners (or specify the assignment mechanism), and state that every law-dependent entry must cite an authoritative primary source and applicable version before it can be reviewed. Do not leave optional whether legal entries have sources when the spec mandates them.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Complete the bounded inventory with exact UI targets and a non-empty, finite reviewed German/English release set; require those entries to be connected to their controls/statuses and Help glossary.
2. Close the contradictory open questions about reviewer ownership and mandatory primary-source provenance.

CHANGES_APPLIED: n/a

## Rebuttals

Round 1 findings 1 and 2 are only partially addressed: the stable ID list and general review lifecycle now exist, but the control mapping/release coverage floor and decisions left open above remain unresolved. Round 1 finding 3 is addressed: missing and review-needed states are explicitly maintainer-only, suppress end-user affordances/warnings, and do not disable the supported control.
