## Review Metadata

- **Review round**: 1
- **Prior round**: none
- **Reviewer context**: fresh-context independent subagent; no authoring transcript
- **Tool restrictions**: read-only inspection; this review wrote only this `review.md`
- **Artifacts reviewed**: `proposal.md`, `design.md`, all seven delta specs, `DESIGN.md`, `AGENTS.md`, current profile/setup/backup/settings/runtime source; `openspec/project.md` is absent
- **Validation evidence**: `openspec validate settings-setup-workspace-completion --type change --strict --json` passed 1/1; `openspec validate --specs --strict` passed 54/54. These are structural checks only. No Flutter tests or implementation checks were run. No `test-plan.md` or `tasks.md` exists yet.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

1. `design.md:36,62` and `specs/profiles/spec.md:5,39-63` make the registered-name list authoritative, but they do not route every runtime discovery path through it. `ProfileSelectionService.listProfiles()` still enumerates every profile directory (`lib/features/setup/wizard_service.dart:250-259`); startup uses that list for its recovery picker (`lib/main.dart:60-75`); and `ProfileManager.getActiveProfile()` accepts any existing directory named by `profile.json` (`lib/core/db/profile_manager.dart:51-68`). An unregistered directory can therefore reappear in the picker and be loaded, contrary to the new isolation contract. Make the registry the only source for startup, recovery, Settings, and explicit selection; reject unregistered targets; add a restart scenario proving an unregistered profile remains on disk but cannot be listed or opened.

2. The corrupt-catalog recovery policy can select the wrong accounting database. `specs/profiles/spec.md:31-35` says to select the “first available” profile “under the existing recovery rule,” while `design.md:52` calls for explicit recovery of malformed or ambiguous catalogs. The maintained `openspec/specs/profiles/spec.md` also says invalid JSON falls back to the first directory, but runtime `ProfileManager._recoverableProfile()` requires explicit selection when multiple directories exist. Specify one safe rule across the active and maintained specs: auto-recover only when one validated registered profile exists; require user selection when multiple candidates exist, preserve their files, and do not persist a guessed active profile. Add a corrupt `profile.json` scenario with two profiles.

3. The setup contract assumes seeded category rows are authoritative, but the current seed is fabricated. `lib/core/db/seed.dart:109-121` creates 85 labels of the form `Kategorie N` and synthetic SKR/EÜR mappings (`8000+N`, `4000+N`, `(N % 60)+10`). These values flow into EÜR grouping (`lib/features/accounting/euer_service.dart:38-42`) and DATEV account mapping (`lib/features/accounting/datev_service.dart:70-80`). Replacing the wizard's numeric chips with these rows would present synthetic mappings as real bookkeeping categories and could misstate reports. Reconcile the seed source with the maintained category contract before treating it as setup data, or define a truthful unavailable/deferred state until authoritative categories exist; do not merely assert that a stored row is a real category.

4. Settings restore has no specified live-database lifecycle. The design composes restore with the active executor and readiness gate (`design.md:40`), but `BackupService.restoreFromBackup()` requires the gate to report ready and then replaces the database file (`lib/core/db/backup_service.dart:138-153,329-343`); its replacement removes WAL/SHM files, and the source comment says restore runs during restart (`backup_service.dart:339-343`). The app keeps its `AppDatabase` open until provider disposal (`lib/main.dart:103-107`; `lib/core/db/database.dart:258-263`). Define how Settings drains and closes every database handle before replacement, prevents current-session queries/writes afterward, and recovers on failed restore. Add scenarios for a live restore, failed validation/write, and restart-required success so the active database cannot be replaced underneath an open SQLite connection.

### 🟡 Moderate

1. The required bank-account holder cannot currently be entered or persisted. The new setup spec requires IBAN, BIC, and account holder (`specs/setup/spec.md:5-11`), but the wizard only builds `BankAccount` from IBAN/BIC (`lib/features/setup/wizard_page.dart:119-130`), and `SetupRepository.createKonto()` accepts `inhaber` but never writes it (`lib/features/setup/setup_repository.dart:62-93`; `wizard_service.dart:202-205`). Specify the repository/database change and an assertion that the reviewed holder value survives completion.

2. Scheduled backup behavior is not wired by the current runtime, and its Settings scenario only verifies a manual backup. `BackupService.isScheduledDue()` exists but has no caller (`lib/core/db/backup_service.dart:186-203`; only migration code calls `createLocalBackup()`, `lib/core/db/migrations.dart:78-80`). State the startup hook and preference values/defaults, then add scenarios proving manual-only skips startup, a due schedule creates one backup, and a recent backup does not duplicate it. Otherwise a saved preference can look enabled without scheduling any work.

### 📌 Suggestions

- `settings-workspace/spec.md:5,21` requires profile controls but the listed Settings destinations have no “Profile” section. Name their placement (for example under Allgemein) so the required actions are discoverable and testable.

## Embedded-Instruction / Injection Attempts

**Detected:** none. The reviewed proposal, design, and delta specs contain no reviewer-directed instructions or prompt-injection text.

## Verdict

VERDICT: REVISE

## Required Changes (if APPROVE WITH CHANGES)

n/a for `VERDICT: REVISE`; resolve the blocking findings and obtain a full fresh-context review round.

CHANGES_APPLIED: n/a

## Rebuttals

- Finding 1: pending author response; round 1.
- Finding 2: pending author response; round 1.
- Finding 3: pending author response; round 1.
- Finding 4: pending author response; round 1.
- Moderate findings 1-2: pending author response; round 1.
- Suggestion: pending author response; may be declined by the author.
