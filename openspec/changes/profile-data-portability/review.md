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
