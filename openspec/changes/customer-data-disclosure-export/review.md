## Review Metadata

- **Review round**: 1
- **Prior round**: none
- **Reviewer context**: fresh-context independent subagent reviewer
- **Branch**: `dev`
- **Tool restrictions**: Read-only inspection; no edits or tests
- **Artifacts reviewed**: this change's proposal, design, and delta specs; relevant main profile/database specs; current relationship schema, dynamic occurrence-table creation, and invoice file resolver
- **Validation evidence**: strict validation was not reported by the reviewer. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **The archive and publication boundary are not concrete.** The design calls for a versioned structured archive but leaves its output format and customer-facing history/status unresolved (`design.md:28-30,43-48`). The spec requires a versioned manifest and package but does not select a container/serialization contract or specify atomic publication and cleanup after interrupted writes (`specs/customer-data-disclosure-export/spec.md:3-7,67-72`). Name the container and encoding; require writing to a temporary destination followed by atomic finalization, with deletion on failure or cancellation.
2. **Profile path containment needs a symlink edge case.** The export spec requires paths beneath the active profile's canonical root, but its scenarios do not define symlink resolution. The current invoice PDF resolver checks lexical normalized containment (`lib/pages/rechnungen/invoice_document_page.dart:69-77`), which does not prove the target remains inside the profile root. Require canonical target resolution and add an external symlink-target scenario that excludes the file and marks the export incomplete.
3. **The desktop requirement lacks an edge scenario.** The export design-system requirement (`specs/customer-data-disclosure-export/spec.md:74-83`) has a keyboard success scenario but no failure/edge case. Add a narrow-window/text-scaling or destination-cancel/focus-restoration scenario.

### 📌 Suggestions

- Keep the unsupported-table fail-closed check before the exporter can report a complete archive. The recurring occurrence tables are created lazily (`lib/features/recurring/rechnungsvorlagen_repository.dart:64-72`; `lib/features/recurring/buchungsvorlagen_repository.dart:82-90`).

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. Select the archive/manifest/payload format and specify atomic publish plus cancellation/failure cleanup.
2. Require canonical path resolution and add a scenario for a profile-local symlink targeting outside the canonical root.
3. Add a design-system edge scenario covering narrow-window/text-scaling or cancellation and focus restoration.

CHANGES_APPLIED: no

## Rebuttals

None; round 1.
