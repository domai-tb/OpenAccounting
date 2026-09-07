---
description: Adversarially review OpenAccounting OpenSpec changes, fix verified defects, and record verification evidence.
---

# OpenAccounting OpenSpec review loop

Review one OpenAccounting change at a time against its exact `anvil` artifacts, implementation, tests, and current
desktop behavior. A checked task, passing unit test, or existing commit is evidence to inspect—not proof that the
contract is satisfied.

## Project contract

- Verify the development branch and preserve all unrelated worktree changes. This checkout currently uses `dev`; do not
  switch branches over a dirty worktree.
- Flutter 3.47.2 comes from `.fvmrc`; every Flutter or Dart command MUST be prefixed with `fvm`.
- Review the actual architecture: Riverpod providers and `ProviderScope`, Drift/SQLite repositories and migrations,
  GoRouter, desktop platform seams, and the established `lib/features/`/`lib/pages/` boundaries. Treat the GetIt
  injection code as a legacy compatibility shim unless the reviewed change explicitly changes it.
- Check Material 3 desktop behavior against `DESIGN.md`: wide and compact windows, sidebar/shell layout, keyboard
  navigation, themes, tables, accessibility, overflow, and German-first localization.
- Check strict lint and formatting conventions, package imports, generated localization ownership, money precision,
  transaction/GoBD invariants, profile isolation, backup/restore compatibility, and platform-safe test doubles.

## Safety and discovery

- Capture `git status --short --branch` and inspect first-parent history without resetting, rewriting, force-pushing,
  `git add .`, or `git add -A`. Do not amend another worker's commit.
- Use the repository's `openspec` CLI and its reported syntax for `context`, `list`, `status`, `instructions`,
  `validate`, and `archive`. Do not import command names or flags from another project/schema.
- This checkout has no `.codegraph/` index; use `rg`, `sed`, and Git inspection. Do not create an index as a review
  side effect.
- Resolve the exact change and inspect its complete `proposal.md`, specs, `design.md`, `review.md`, `test-plan.md`,
  `tasks.md`, and `verify.md`. A missing gate, `REVISE` verdict, red test-plan row, or failed verification blocks a
  pass. Never guess which change a trailer-less commit belongs to.

## Review procedure

1. Announce the exact change, commit(s), schema, claimed progress, review verdict, test-plan state, verify state, and
   context files.
2. Inspect the isolated implementation diff and the resulting current-tree behavior. Trace every requirement and
   scenario into production code, real provider/database/router wiring, and a named test or mechanical check.
3. Check specifically for:

   - missing failing-first tests, skipped tests, weakened assertions, untested branches, and stale `verify.md` evidence;
   - incorrect Riverpod lifecycle/provider ownership, direct UI GetIt access, dead runtime mocks, or placeholders;
   - Drift schema/migration errors, malformed-data crashes, non-atomic writes, retry duplication, orphan records,
     profile leakage, money rounding, audit-trail violations, or unsafe backup/restore behavior;
   - GoRouter redirects/deep links, desktop lifecycle/tray/window/drag-drop behavior, unsupported platform APIs,
     asynchronous cleanup, concurrency, null safety, and error recovery;
   - missing localization, hand-edited generated files, accessibility failures, responsive overflow, and DESIGN.md
     violations; and
   - accidental scope, secrets, generated junk, lint failures, dead code, or undocumented contract changes.

4. Run focused checks before aggregate checks:

   ```text
   fvm dart format --line-length=120 --set-exit-if-changed <scoped paths>
   fvm flutter analyze <scoped paths>
   fvm flutter test --dart-define=platform=vm <affected tests>
   ```

   Run `fvm flutter pub get` for dependency changes, `fvm flutter gen-l10n` for ARB changes, and relevant desktop
   build/package checks for platform or release changes. When scope warrants it, run the full `fvm flutter analyze` and
   `fvm flutter test --dart-define=platform=vm`. Run OpenSpec validation using the actual CLI instructions and inspect
   `git diff --check`.

5. Report each finding before fixing it in one line:
   `🔴|🟡|🔵 file:line: problem. fix.` Red means security, correctness, data loss, or contract failure; yellow means
   incomplete coverage or operational risk; blue is optional improvement.
6. Fix actionable red and yellow findings in the current scoped change, add regression tests in failing-first order, and
   rerun affected checks. If artifacts are contradictory, amend them and require a fresh adversarial review; do not
   silently reinterpret requirements.

## Review result and handoff

Record the exact reviewed commit/tree, findings, fixes, test results, OpenSpec validation, and any unavailable external
evidence in `review.md`/`verify.md` according to the `anvil` templates. Use `APPROVE` only when no blocking finding
remains; use `APPROVE_WITH_CHANGES` only when required changes are applied and documented; use `REVISE` for unresolved
contract or artifact problems. After two consecutive `REVISE` rounds, stop and escalate to a human as required by the
schema.

Create a focused Conventional Commit for review fixes and documentation, or an intentional empty commit only when the
repository's review workflow requires a marker and the review genuinely passed. Do not archive or publish a blocked or
partial change. Push only when explicitly requested or required by the repository workflow, and never force-push.

## Terminal report

Report every reviewed change and commit, findings and fixes, review/verify verdicts, validations actually run, commits
and publication status, and every blocked or unreviewed item with its exact reason. Never fabricate device, CI,
external-service, or human-review evidence.
