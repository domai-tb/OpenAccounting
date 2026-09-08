---
description: Continuously implement OpenAccounting OpenSpec changes with anvil TDD gates and reviewable commits.
---

# OpenAccounting OpenSpec work loop

Run as a persistent worker. Implement one active OpenAccounting change at a time, publish a reviewable handoff, rebuild
the queue, and immediately continue with the next eligible change. Discover the repository state and the complete
change contract before editing. This repository uses the local `anvil` schema; its artifact gates and test-first
ordering are part of the implementation contract.

## Persistent loop contract

- Repeat the discover → select → implement → verify → archive → commit → publish cycle until the user
  manually interrupts the command. Do not ask for confirmation between changes.
- Work on exactly one OpenSpec change per cycle. After publishing its handoff commit, discard all assumptions about the
  queue, refresh repository/OpenSpec state, and select the next eligible change.
- When no change is currently eligible, do not terminate. Report the queue/blockers once, wait 30 seconds without busy
  polling, refresh Git and OpenSpec state, and try again. Use the environment's native wait facility when available;
  otherwise use a bounded `sleep 30`.
- A transient fetch, tool, or test failure does not end the loop. Diagnose it, preserve a clean/scoped worktree, apply
  safe recovery, then retry with backoff. If recovery needs human authority or would risk unrelated work, quarantine
  that change, keep it incomplete, and continue monitoring the queue.
- Emit a concise cycle update when a change is selected, handed off, blocked, or the queue state changes. A terminal
  summary is produced only when the user interrupts the command.

## Project contract

- Verify the development branch before editing or committing. This checkout currently develops on `dev`; do not switch
  branches over a dirty worktree.
- Flutter 3.47.2 is pinned by `.fvmrc`. Every Flutter or Dart command MUST be prefixed with `fvm`; never run bare
  `flutter` or `dart`.
- This is a desktop application targeting Windows, macOS, and Linux. Keep platform code behind existing desktop seams
  and preserve VM-safe test doubles. Do not add unsupported platform-specific behavior without an approved change.
- Riverpod is the primary dependency and state-management mechanism. Prefer providers and `ProviderScope`; do not add
  BLoC or a competing state-management pattern. The legacy GetIt/injection shim is compatibility infrastructure, not
  a reason to wire new UI directly to GetIt.
- Persist accounting data through the existing Drift/SQLite database and migration/trigger conventions. Preserve
  integer/string money invariants, transaction atomicity, GoBD auditability, profile paths, and backup/restore safety.
  Do not introduce another database or remote persistence layer without an approved change.
- Organize new behavior under the existing `lib/features/<feature>/` or established `lib/pages/<feature>/` boundary.
  Follow the nearest feature's service/repository/page/provider pattern; do not create a second parallel architecture.
- Use the existing GoRouter in `lib/core/router/` for navigation and keep route, shell, redirect, deep-link, and
  desktop-window behavior consistent with the current app.
- Edit localization sources under `assets/l10n/`, then run `fvm flutter gen-l10n`. Never hand-edit generated files in
  `lib/l10n/`. Preserve German-first coverage and add translations for every user-facing string.
- Follow `DESIGN.md` for the Material 3 desktop shell, responsive compact layouts, keyboard support, themes, dense
  data tables, and accessibility. Do not evaluate desktop UI by mobile-only assumptions.
- Use package imports, single quotes, trailing commas, const constructors where applicable, and 120-character lines.

## Repository safety and tools

- Capture `git status --short --branch` before work. Treat existing changes as user-owned; never reset, overwrite, or
  stage unrelated files. Do not use `git reset --hard`, destructive checkout commands, force-push, `git add .`, or
  `git add -A`.
- Use the repository's `openspec` CLI consistently. If it is unavailable, inspect the installed CLI help before choosing
  a fallback; do not assume commands or flags from another OpenSpec schema.
- This checkout has no `.codegraph/` index. Use `rg`, `sed`, and Git inspection; do not create an index as part of a
  routine change.

## Discover the queue and gates

1. At the start of every cycle, verify the branch and capture the worktree status. If the worktree is clean, fetch and
   fast-forward `dev`; never pull over user changes. If another process owns a dirty worktree, wait and retry rather
   than editing concurrently.
2. Resolve the local OpenSpec context and active queue:

   ```text
   openspec context --json
   openspec list --json
   ```

   Confirm that the change uses the `anvil` schema and inspect its status/instructions with the actual CLI syntax.
3. For the selected change, read the complete `proposal.md`, every delta spec, `design.md`, `review.md`,
   `test-plan.md`, and `tasks.md` that exists. A `REVISE` review blocks implementation until the artifacts are fixed
   and re-reviewed. A missing or placeholder gate is not approval.
4. Select only a change whose dependencies and review gate are satisfied. Prefer a safe finalization of partially
   completed work, then the oldest dependency-ready change by `lastModified` and name. Do not pause for a human choice
   when this deterministic rule identifies the next change.
5. Announce the exact change, schema, task progress, gate status, context files, and selected scope before editing.

## Implement with anvil TDD ordering

1. Re-run the change instructions immediately before editing and map each task/scenario to its affected feature,
   database, router, desktop, localization, and test paths.
2. Keep the required order for each scenario: write a focused failing test for the right reason, implement the smallest
   production change, then refactor without weakening assertions. Every spec scenario must have a named test in
   `test-plan.md`; non-executable changes need an equivalent mechanical check.
3. Preserve production wiring: providers must use the real database/services, migrations must be additive and tested,
   and UI must not hide errors, bypass data boundaries, or rely on test-only implementations.
4. Add regression coverage for malformed persisted data, retries/idempotency, deletion and cleanup, transaction/error
   paths, concurrency, null safety, and platform boundaries whenever the change affects them.
5. Mark a test-plan row green only after its test passes. Mark a task complete only after implementation and fresh
   verification pass; never fabricate manual, device, CI, or external-service evidence.

## Verification

Run the narrowest relevant checks first, then the aggregate checks required by the change:

```text
fvm dart format --line-length=120 --set-exit-if-changed <scoped paths>
fvm flutter analyze <scoped paths>
fvm flutter test --dart-define=platform=vm <scoped test paths>
```

Also run `fvm flutter pub get` after dependency changes, `fvm flutter gen-l10n` after ARB changes, and the relevant
desktop build or packaging check after platform/release changes. Before completion, run:

```text
fvm flutter analyze
fvm flutter test --dart-define=platform=vm
git diff --check
```

Run the repository's OpenSpec validation using the syntax reported by `openspec --help`/the change instructions. Finish
the required `verify.md` evidence, including TDD integrity, review compliance, test-plan coverage, and the final suite
result. Do not archive a change with a red test-plan row, incomplete tasks, a failing gate, or a failed verification.

## Complete and publish a change

If a change becomes genuinely blocked after safe local options are exhausted, do not archive it. Preserve only coherent,
verified partial work in a scoped checkpoint commit with `OpenSpec-Status: partial`, publish that handoff, leave the
worktree clean, and quarantine the change until its prerequisite or reviewer state changes. Never carry failing or
uncommitted partial work into another specification.

Completion requires all tasks done, an approving `review.md`, passing `verify.md`, successful OpenSpec validation, clean
scoped diff review, and no unresolved red/yellow correctness findings. Inspect the archive command's effect before
using it; archive only after verification and only with the repository's actual CLI syntax. This schema may update main
specs during archive, so inspect those changes too.

Create one focused Conventional Commit containing only the change's implementation, tests, documentation, generated
localization, and OpenSpec lifecycle files. Every worker handoff commit, complete or partial, MUST end with:

```text
OpenSpec-Change: <change-name>
OpenSpec-Schema: anvil
OpenSpec-Status: partial|complete
OpenSpec-Tasks: <complete>/<total>
```

This persistent command explicitly calls for publication: fetch `origin/dev`, integrate only by a safe fast-forward or
rebase of the scoped worker commit, rerun affected checks if the base changed, and push with
`git push origin HEAD:dev`. Never force-push. Confirm the full worker SHA is reachable from `origin/dev`; that SHA and
the trailers are the reviewer handoff. Then return to the top of the loop immediately.

## Loop reporting and manual stop

After every cycle, report the selected/completed or partial change, task progress, review/verify gates, validations
actually run, commit SHA, publication status, remaining queue, and exact blockers. Keep running after that update. Only
when manually interrupted, produce the aggregate terminal report and confirm that no external or human evidence was
fabricated and no incomplete change was archived.
