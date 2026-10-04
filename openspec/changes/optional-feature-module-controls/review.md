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

## Review Metadata

- **Review round**: 2
- **Prior round**: 1 (`REVISE`)
- **Reviewer context**: fresh independent subagent; did not author proposal changes; read-only
- **Review scope**: repaired proposal, design, all five delta specs, and maintained accounting, inventory, profiles, stammdaten, and database contracts
- **Validation**: `openspec validate optional-feature-module-controls --type change --strict --json` passed; structural validation only. `git diff --check` passed. Tests were not run.

## Findings

### Critical

1. The proposal changes the persistence schema by adding `unternehmen.feature_modules_json` and coordinating a schema-version migration, but it does not modify the maintained `db` capability or provide a `specs/db/spec.md` delta. Consequently, the database capability has no accepted contract for the new company column, its versioned representation, or migration/backfill behavior. Add the database capability to `Modified Capabilities` and specify the additive migration there, keeping its version coordination consistent with the shared schema baseline.
2. The existing inventory requirement `Configurable inventory activation in settings` remains unchanged in `openspec/specs/inventory/spec.md`. It still defines `unternehmen.lagerführung_aktiv` as the runtime switch for hiding the stock fields in article forms and stock warnings in invoice forms. The proposal instead makes `feature_modules_json.inventory` canonical and declares the legacy flag migration-only, but its inventory delta modifies only the dashboard widget requirement. Modify the settings-activation requirement to transfer that contract to the catalog, including article stock fields and invoice stock warnings, so the old flag is not still specified as an independent runtime source.

## Suggestions

- Keep the GuV catalog migration/backfill description aligned across `feature-modules`, `stammdaten`, and the proposed database delta when adding it.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: REVISE

## Required Changes

1. Add the database schema/migration delta and capability mapping for `feature_modules_json`.
2. Replace the maintained inventory settings-toggle contract with the catalog-owned state contract, covering every UI surface named by that requirement.

CHANGES_APPLIED: n/a

## Rebuttals

None; this is an independent second review round.
