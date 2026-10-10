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

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: 2 (`REVISE`)
- **Reviewer context**: fresh-context independent subagent; did not author proposal changes; append-only (prior rounds untouched)
- **Review scope**: proposal, design, all six delta specs (accounting, db, feature-modules, inventory, profiles, stammdaten), rounds 1–2 in `review.md`, and maintained `openspec/specs/inventory/spec.md`, `openspec/specs/db/spec.md`, `openspec/specs/accounting/spec.md`, plus maintained profiles/stammdaten specs
- **Validation**: CLI validation skipped per parent instruction (parent runs it); no shell commands run; artifact-content verification only. Tests were not run.

## Prior Findings Rechecked

1. **Round 2 required change (1) — db delta + capability mapping**: SATISFIED. `specs/db/spec.md` exists with an ADDED `Company feature module state schema and migration` requirement: nullable `unternehmen.feature_modules_json TEXT` in fresh schemas, versioned catalog shape by reference, backfill only when canonical is `NULL`, legacy columns read only when each exists, only integer `0`/`1` valid with absent/invalid → `false`, preservation of legacy columns/values, non-NULL canonical values, unrelated data, and table count, no module-record changes, next-sequential-version coordination (version 9 from the version-8 baseline, merge rather than competing bump), atomic commit, rollback leaving prior `user_version`. Five scenarios cover fresh schema, legacy backfill, canonical preservation, same-version coordination (8→9 once), and failure rollback. Proposal lists `db` under Modified Capabilities (`proposal.md:21`) with matching scope language.
2. **Round 2 required change (2) — inventory settings-toggle transfer**: SATISFIED. `specs/inventory/spec.md` MODIFIES `Configurable inventory activation in settings` (name-matched to maintained `openspec/specs/inventory/spec.md:235`): Settings exposes availability through the `inventory` entry in `unternehmen.feature_modules_json` resolved by the catalog; `lagerführung_aktiv`/`lagerfuehrung_aktiv` is migration-only input and SHALL NOT be read/written as a runtime switch; `artikel.lager_aktiv` stays the independent per-article flag; maintained fields `bestand_aktuell`/`bestand`/`mindestbestand`/`minusbestand_erlaubt` with types/defaults retained. Disabled state hides navigation, dashboard warnings, article stock fields, manual stock controls, shortcuts, and invoice stock-warning indicators; disablement preserves stock values/flags/movement records and SHALL NOT suppress finalization/storno stock effects; enabled state shows per-line invoice warnings without blocking drafts and follows the maintained `minusbestand_erlaubt` confirmation flow. Six scenarios cover disabled, enabled, per-article field meaning, draft-save warning, finalization confirmation, and disabled-but-stock-effects-preserved. Every UI surface named by the maintained requirement (Lagerwarnung, article stock fields, invoice stock warnings) is covered, plus manual controls/shortcuts/navigation. The companion MODIFIED `Dashboard stock warning widget` preserves the low-stock listing semantics and the finalization/storno preservation clause.
3. **No other stale conflicts**: no blocking conflict. GuV threshold auto-activation is preserved through the catalog in accounting (`guv=true` via state writer, no independent `guv_aktiv` runtime flag), feature-modules (threshold row + cannot-disable-while-threshold scenario), stammdaten (missing-legacy-`guv` scenario defers to threshold auto-activation), and design decision 4 — aligned. Profile-manager multi-profile override is stated identically in profiles, stammdaten, feature-modules table, and design decision 4 — aligned. Legacy flags are migration-only everywhere they appear (feature-modules, stammdaten ×2, inventory, accounting) while db/stammdaten preserve legacy columns/values — consistent, not contradictory.

## Suggestions

- Consider relabeling the second stammdaten delta requirement (`Unternehmen — Durable optional module state`, which has no maintained counterpart) from `MODIFIED` to `ADDED`; content is correct and consistent, this is a header-convention nit for the validator, not a contract gap.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: APPROVE

CHANGES_APPLIED: n/a

## Review Metadata — Round 4

- **Review round**: 4
- **Prior round**: 3 (`APPROVE`)
- **Reviewer context**: fresh-context independent subagent; did not author the header move; append-only (prior rounds untouched)
- **Review scope**: delta `specs/stammdaten/spec.md` (36 lines, full file), maintained `openspec/specs/stammdaten/spec.md` requirement headers (full 485-line read), and rounds 1–3 in `review.md`
- **Validation**: no shell commands per parent instruction (no CLI validation, no `git diff`); artifact-content verification only. Tests were not run.

## Verification

1. **(a) Moved requirement has no maintained counterpart — HOLDS.** Delta `## ADDED Requirements` contains exactly one requirement: `Unternehmen — Durable optional module state`. Full read of maintained `openspec/specs/stammdaten/spec.md` shows `Unternehmen` requirements `CRUD`, `SMTP-Konfiguration`, `PDF-Vorlage`, `Unterschrift`, `QR-Zahlung`, `Skonto`, `Zahlungsziel`, `Steuer-Fristen`, `Dashboard-Konfiguration`, `Profilmanager`, plus `Company fiscal-year settings`. No `Durable optional module state` header exists. `ADDED` is the correct header convention.
2. **(b) No content-word change in the move — HOLDS to the extent verifiable by reading.** Current ADDED requirement body (canonical versioned JSON object, catalog v1 `enabled` map with `profile_manager`/`inventory`/`guv` defaulting false, additive migration copying valid booleans from the three legacy columns when each exists, absent/invalid → false, preserve-valid-canonical, legacy columns intact but not runtime-read, catalog-service-only access, no module-record alteration) with its two scenarios (`Existing profile flags are backfilled` incl. same-transaction + legacy/unrelated-data preservation; `Missing legacy flag receives catalog default` deferring to accounting threshold auto-activation) matches the content round 3 reviewed and described as "correct and consistent" (round 3 Suggestion + recheck point 3's threshold-deferral characterization). Word-level byte diff was impossible without shell (`git diff` forbidden); no wording divergence from the round-3-reviewed substance was found.
3. **(c) Remaining MODIFIED requirement name-matches — HOLDS.** Delta `## MODIFIED Requirements` contains exactly one requirement: `Unternehmen — Profilmanager`, matching maintained `openspec/specs/stammdaten/spec.md:330` header verbatim (em dash, spelling, case). Its scenarios (`Single profile hides menu`, `Multiple profiles force menu visible`) correspond to the maintained scenarios.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: APPROVE

CHANGES_APPLIED: n/a
