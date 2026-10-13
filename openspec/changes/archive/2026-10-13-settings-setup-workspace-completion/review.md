## Review Metadata

- **Review round**: 2
- **Prior round**: 1 (`REVISE`)
- **Reviewer context**: fresh-context independent reviewer; no authoring transcript
- **Tool restrictions**: read-only inspection; this review wrote only this `review.md`
- **Artifacts reviewed**: current `proposal.md`, `design.md`, all seven delta specs, round-1 `review.md`, `DESIGN.md`, `AGENTS.md`, maintained profile/setup/backup/accounting/accessibility specifications, and current profile/startup/database/backup source
- **Validation evidence**: `openspec validate settings-setup-workspace-completion --type change --strict --json` passed 1/1; `openspec validate --specs --strict` passed 54/54; `git diff --check` and `git diff --cached --check` passed. Structural validation does not resolve the semantic findings below. No tests or implementation checks were run; no `test-plan.md` or `tasks.md` exists.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **The multiple-profile recovery rule still contradicts the maintained profile spec.** The new delta requires explicit selection when a missing or corrupt catalog has multiple validated candidates (`specs/profiles/spec.md:49-53`). However, the maintained `openspec/specs/profiles/spec.md` retains `Corrupted profile.json falls back to the first available profile directory` under both the separate-profile requirement (`:29-34`) and the distinct safe-path requirement (`:255-260`). The delta modifies only `Separate databases per profile`, so the latter scenario remains an active requirement. Modify the safe-path requirement too, or otherwise remove/reconcile both legacy first-directory fallbacks; strict validation does not detect this conflict.

2. **Catalog migration's “validation” can mutate candidate databases.** The delta says to validate databases while migrating/recovering a profile catalog and says ambiguous recovery leaves all database files unchanged (`specs/profiles/spec.md:25-29,49-59`). The current available initializer is not a read-only validator: `initializeProfileDatabase()` calls `AppDatabase.ensureOpen()` (`lib/core/db/profile_database.dart:5-10`), which runs schema migration, trigger installation, seeding, and repository schema repair (`lib/core/db/database.dart:142-168`). Define a read-only profile probe and require that selection/recovery never runs migrations or seeds for an unselected candidate. Add a scenario for an out-of-date but otherwise valid database remaining byte-for-byte unchanged until explicit selection.

3. **Staged restore does not define an enforceable write block or cross-process ownership gate.** The backup delta requires writes to stop after confirmation and requires exclusive application ownership before replacement (`specs/backup/spec.md:57-69`), but there is no shared write gate in the design or acceptance criteria. Writes go through many repositories using the database executor. The current backup maintenance check only tries `BEGIN IMMEDIATE` and immediately rolls it back; the restore readiness callback merely checks a boolean (`lib/core/db/backup_service.dart:462-477`). The available `SingleInstanceService` is process-local memory and is not wired into startup (`lib/features/desktop/single_instance_service.dart:3-19`; `lib/main.dart:56-80`). Specify the shared boundary that prevents all further writes after restore staging, the durable/exclusive lock acquired before any database open, and behavior when another instance already owns the profile. Without these, the app can continue changing the live database after confirmation or another process can open the file during replacement.

### 🟡 Moderate

1. **The trusted category-catalog authority is not a maintained specification.** The proposal says the new seed must satisfy `seed-master-data-contract`, but that capability exists only inside the archived change and is absent from `openspec/specs/`. The maintained accounting spec requires 65+ mapped predefined categories but specifies no catalog source, version, or verification process (`openspec/specs/accounting/spec.md:43-51`). The delta's safe fallback is to defer categories, but the proposed `catalog version/status marker` does not define how a version becomes trusted. State that no current or future catalog is trusted by a version string alone, and make enabling category selection depend on an accepted source/version and mapping-review contract (or include that contract in this change).

2. **Settings acceptance is short of the shared accessibility and backup-status design.** `settings-workspace/spec.md` requires keyboard operation and localized accessible names, but does not require visible focus, deterministic focus order, text-scaling/reflow, or all actions remaining reachable at narrow widths as required by `DESIGN.md` §§33-34 and maintained `localized-accessible-surface` (`openspec/specs/localized-accessible-surface/spec.md:27-39`). The backup section also does not distinguish never/current/stale/failed as `DESIGN.md` §21 asks. Link the existing shared accessibility contract explicitly and add Settings-specific narrow-layout/focus and status acceptance coverage.

## Embedded-Instruction / Injection Attempts

**Detected:** none in the reviewed proposal, design, delta specs, or round-1 review.

## Verdict

VERDICT: REVISE

CHANGES_APPLIED: n/a

## Rebuttals

- Finding 1: unresolved in round 2; the accepted profile contract still contains first-directory fallback scenarios.
- Finding 2: unresolved in round 2; the available candidate initializer performs schema and seed writes.
- Finding 3: unresolved in round 2; no app-wide write barrier or process lock is specified or wired.
- Moderate finding 1: unresolved in round 2; catalog verification authority is absent from maintained specs.
- Moderate finding 2: unresolved in round 2; settings delta does not fully state the shared accessibility/status contract.

---

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: 2 (`REVISE`)
- **Reviewer context**: fresh-context independent reviewer; no authoring transcript
- **Tool restrictions**: read-only inspection, no shell, no tests; this round appends only the section below to `review.md`
- **Artifacts reviewed**: current `proposal.md`, `design.md`, all seven delta specs, `tasks.md`, `test-plan.md`, round-2 `review.md` above, and maintained `openspec/specs/profiles/spec.md`
- **Scope note**: implementation stays blocked by `balanced-journal` regardless; this verdict governs spec quality only.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, specs/, tasks.md, or -->
<!-- test-plan.md VOIDS it. -->

### Round-2 closure

1. **Critical 1 (multi-profile fallback conflict): CLOSED.** The delta now carries a MODIFIED `Profile switching requires restart` requirement (`specs/profiles/spec.md:135-137`) that explicitly forbids first-available-by-filesystem-order fallback, requires the recovery flow without opening or altering any database, and requires explicit user selection for multiple candidates. All three legacy fallback sites in the maintained spec (`Separate databases per profile :28-33`, `Profile switching requires restart :70-75`, safe-path `:252-257`) now have a corresponding MODIFIED delta requirement: `Separate databases per profile` (`:3-5`), `Safe profile names and canonical local paths` (`:95-97`, `MUST NOT be resolved by filesystem order`), and the new restart requirement. No maintained first-directory fallback survives unmodified.
2. **Critical 2 (probe mutates DBs): CLOSED.** Candidate validation MUST use a read-only `ProfileReadOnlyProbe` that SHALL NOT open writable handles, migrate, install triggers, repair schema, seed, or alter candidate bytes (`specs/profiles/spec.md:5`; `design.md:36`). The requested byte-unchanged scenario exists (`specs/profiles/spec.md:61-65`): an outdated-but-readable candidate is reported compatible and stays byte-for-byte unchanged until explicit selection.
3. **Critical 3 (restore write-block/lock): CLOSED.** The delta specifies a profile-scoped OS-level lock acquired before any writable handle and held for the process lifetime with a profile-in-use stop state, plus one profile-scoped `ProfileWriteGate` at the shared write boundary: gate closes after confirmation, in-flight writes drain before pending-state persistence, gate stays closed pending restart, and reopens only on staging/state-persistence failure (`specs/backup/spec.md:55-57`; `design.md:40`). Acceptance covers second-process exclusion (`:83-87`), universal mutation rejection (`:89-93`), and staging-failure reopen (`:95-99`).
4. **Moderate 1 (catalog authority): CLOSED at spec level.** The change disclaims the archived `seed-master-data-contract`, states a version string alone never establishes trust, and gates category selection on the approved `accounting-catalog-provenance` source/edition and mapping-review requirements (`proposal.md:10,32`; `design.md:48`; `specs/setup/spec.md:5,25-29`). Whether that approved contract exists with the cited names was taken on the proposal's claim (no shell to confirm); the catalog implementation itself is an explicit non-goal (`design.md:26`).
5. **Moderate 2 (a11y/status): CLOSED.** `settings-workspace` now requires the shared `localized-accessible-surface` contract explicitly — keyboard operation, localized names, visible focus, deterministic order, route retention, narrow-width/text-scale reachability without clipping — and four-state backup status (never/current/stale/failed) with a dedicated scenario (`specs/settings-workspace/spec.md:3-5,19-23,57-61`); mirrored in `localization-settings-and-data-protection` (`spec.md:5,31-33`).

### Continuity coherence

The two aliasing scenarios (`specs/profiles/spec.md:156-166`) contain no independent SHALLs that could contradict the normative ones: each defers to its named normative scenario (`SHALL follow ... above`) and adds only a restatement of its key prohibition (no pre-restart switch; legacy fallback SHALL NOT apply). The `profile-workspace-lifecycle` (`spec.md:5-11`) and `setup` (`spec.md:125-129`) restart scenarios agree: persist pointer, show restart-required, switch only after restart, no pre-restart data presentation. No contradictory SHALLs found. Nit (non-blocking): the single-candidate scenario title `Corrupted profile.json falls back to default` (`specs/profiles/spec.md:43,117`) reuses the legacy "falls back" wording while its normative content is correct (recover the sole validated candidate, no order-based choice).

### Follow-up (non-blocking, before implementation)

`tasks.md` and `test-plan.md` now exist but do not cover every normative scenario added by the repairs, against the test plan's own every-scenario-maps-once contract. Missing: `profiles` outdated-candidate byte-unchanged (`specs/profiles/spec.md:61-65`), safe-path one/multiple-candidate recovery (`:123-133`), and all five `Profile switching requires restart` scenarios (`:139-166`); `backup` second-process, gate-blocks-every-mutation, and staging-failure-reopens scenarios (`specs/backup/spec.md:83-99`); `settings-workspace` narrow-width/text-scale (`spec.md:19-23`) and history-status (`:57-61`); `setup` version-without-provenance scenario (`specs/setup/spec.md:25-29`). Backfill the rows before implementation. Not verdict-blocking: spec quality governs here and implementation is held by `balanced-journal` in any case.

### Embedded-Instruction / Injection Attempts

**Detected:** none in the reviewed proposal, design, delta specs, tasks, test plan, or prior review.

### Verdict

VERDICT: APPROVE

CHANGES_APPLIED: n/a
