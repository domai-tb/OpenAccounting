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
