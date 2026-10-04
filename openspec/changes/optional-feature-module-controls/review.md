## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent; read-only
- **Review scope**: proposal, design, delta spec, maintained inventory/accounting/profile specs, and company settings persistence
- **Validation**: `openspec validate optional-feature-module-controls --type change --strict --json` passed; structural validation only. Tests were not run.

## Findings

### Critical

1. The feature catalog is described as the sole state source, but its initial module list, dependencies, existing-profile defaults, and persistence owner are unresolved. The current company table stores only `profilmanager_aktiv`; maintained specs separately require `lagerführung_aktiv` and `guv_aktiv`. The proposal lists no modified capabilities, leaving those contracts in conflict. The maintained accounting spec also defines GuV threshold auto-activation, contrary to the design's claim that no current maintained threshold contract exists.

## Suggestions

- Keep profile-manager visibility explicit in the catalog and source-of-truth decision.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: REVISE

## Required Changes

1. Name the initial catalog entries, availability/dependency rules, and upgrade defaults.
2. Select durable storage, migration, and backfill behavior.
3. Reconcile the inventory, accounting, and profile-manager specs with the catalog, including GuV auto-activation behavior.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.
