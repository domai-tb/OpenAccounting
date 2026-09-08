---
description: Continuously review OpenAccounting worker commits and archived specifications until manually stopped.
---

# OpenAccounting OpenSpec review loop

Run as a persistent reviewer. Review one queue item at a time against its exact `anvil` artifacts, implementation,
tests, and current desktop behavior. New unreviewed worker commits always have priority; when none exists, audit an
eligible archived specification against the current implementation. A checked task, passing unit test, archived
change, or existing commit is evidence to inspect—not proof that the contract is satisfied.

## Persistent loop contract

- Repeat the refresh → select → review → fix/record → publish cycle until the user manually interrupts the
  command. Never terminate merely because the worker is caught up, the archive queue is exhausted, or an item is
  blocked.
- Do not ask which item to review. Select the oldest unreviewed worker commit first. Only when there is no such commit,
  select an eligible archived-spec audit as described below.
- After every review marker is published, forget the prior queue snapshot and refresh Git/OpenSpec state before
  selecting again. A worker commit that appeared during an archive audit is picked up at the next cycle boundary.
- When neither queue contains eligible work, report the idle state once, wait 30 seconds without busy polling, refresh,
  and try again. Use the environment's native wait facility when available; otherwise use a bounded `sleep 30`.
- Transient fetch/tool failures, a dirty worktree owned by another process, and quarantined blockers put the reviewer
  into wait/retry mode; they do not end it. Never use destructive recovery or overwrite concurrent/user work.
- Emit concise updates on selection, findings, publication, blockers, and queue-state changes. Produce a terminal
  summary only after manual interruption.

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
- Treat Anvil `review.md` as the pre-implementation artifact review. This command performs a post-implementation audit:
  do not replace the existing verdict or rewrite an archived artifact to record this audit. Record the result in the
  review commit and its trailers. If proposal/design/specs themselves must change, invalidate the artifact verdict and
  require the schema's fresh-context review rather than self-approving the edit.

## Build the two review queues

At the start of every cycle:

1. Verify `dev` and capture `git status --short --branch`. If clean, fetch and fast-forward from `origin/dev`. If dirty
   work is not owned by this review cycle, wait and retry instead of pulling or editing over it.
2. Inspect first-parent history. A worker handoff is a commit with all four exact trailers:

   ```text
   OpenSpec-Change: <change-name>
   OpenSpec-Schema: anvil
   OpenSpec-Status: partial|complete
   OpenSpec-Tasks: <complete>/<total>
   ```

3. A worker handoff is reviewed only when a later first-parent review commit names its exact full SHA:

   ```text
   Reviewed-Commit: <full-worker-sha>
   OpenSpec-Change: <same-change>
   Review-Result: pass|fixed|blocked
   ```

   Queue unreviewed workers oldest first. `Review-Result` evaluates the work claimed by that exact handoff; passing a
   partial handoff does not claim that the whole OpenSpec change is complete. Ignore ordinary commits and review-marker
   commits. A trailer-less commit may be reviewed as a worker handoff only when its subject/body and diff identify
   exactly one change; otherwise do not guess—leave it out of this queue and report the ambiguity.
4. Resolve a worker's artifacts first at `openspec/changes/<change-name>/`. If absent, require exactly one matching
   `openspec/changes/archive/*-<change-name>/` directory and inspect that immutable archive. Use the worker diff to
   disambiguate only when necessary.
5. If and only if the worker queue is empty, build the archive-audit queue from
   `openspec/changes/archive/<date>-<change-name>/`. First choose the oldest archive for which first-parent history has
   no marker containing its exact `Reviewed-Archive` path:

   ```text
   Reviewed-Archive: openspec/changes/archive/<date>-<change-name>
   Reviewed-Tree: <full-git-tree-object-sha-that-passed-review>
   OpenSpec-Change: <change-name>
   Review-Result: pass|fixed|blocked
   ```

   Compute `Reviewed-Tree` with `git rev-parse HEAD^{tree}` after all fixes and verification. After every archive has a
   marker, requeue an archive only when production code, maintained specs, dependencies, or tests relevant to its
   contract changed after its latest marker commit. Do not generate empty repeat audits for an unchanged relevant
   tree. If no archive is new or stale, enter the wait path rather than exiting.
6. A `blocked` marker quarantines that exact worker SHA or archive/tree pair until a later commit changes the relevant
   state. Surface its reason, continue monitoring other items, and honor Anvil's rule that two consecutive `REVISE`
   artifact rounds require human escalation; escalation pauses that item, not the persistent reviewer.

## Review procedure

1. Announce whether the item is a worker handoff or archived-spec audit, plus its exact change, worker/base/tree SHA,
   schema, claimed progress, artifact verdict, test-plan state, verify state, and context files.
2. For a worker handoff, inspect `git diff <parent>..<worker-sha>` plus any earlier partial commits needed to understand
   the change. For an archive audit, keep the archive immutable and compare every archived requirement/scenario with
   current production behavior and tests. In both cases, trace the contract into real provider/database/router wiring
   and a named test or mechanical check.
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
   `🔴|🟡|🔵 file:line: problem. fix.` Red means security, correctness, data loss, or contract failure;
   yellow means incomplete coverage or operational risk; blue is optional improvement.
6. Fix actionable red and yellow implementation findings in the current scoped contract, add regression tests in
   failing-first order, and rerun affected checks. Do not modify archived artifacts. If artifacts are contradictory or
   a fix requires a new/changed requirement, record `blocked`, require a new active OpenSpec change and fresh artifact
   review, and continue the outer loop without silently reinterpreting the contract.

## Review result and handoff

Record the exact reviewed commit/tree, findings, fixes, test results, OpenSpec validation, and unavailable external
evidence in the review commit body and cycle report. Preserve the Anvil artifact verdict; this post-implementation
result is `pass`, `fixed`, or `blocked`. Use `pass` only when no blocking finding remains, `fixed` only when all
actionable red/yellow findings were applied and reverified, and `blocked` when contract, evidence, safety, or authority
still prevents acceptance.

For a worker handoff, create a focused Conventional Commit for review fixes, or an intentional empty marker when no file
change is needed, and append `Reviewed-Commit`, `OpenSpec-Change`, and `Review-Result` exactly as shown above.

For an archive audit, keep the audit marker separate from any fix commit. If fixes were needed, commit and verify them
first. Then capture the full Git tree object SHA with `git rev-parse HEAD^{tree}` and create an intentional empty marker
with `Reviewed-Archive`, `Reviewed-Tree`, `OpenSpec-Change`, and `Review-Result`. The empty marker preserves that tree
SHA, so it does not make its own audit stale. A `blocked` result may also use an empty marker so the same unchanged item
is quarantined instead of being retried forever; describe the blocker precisely in the commit body and never label it
pass/fixed.

This persistent command explicitly calls for publication: fetch `origin/dev`, integrate only the scoped review commit
without rewriting worker history, rerun affected checks when the base moved, and push with `git push origin HEAD:dev`.
If integrating a concurrent commit changes an archive audit's resulting tree, repeat the relevant audit and refresh its
`Reviewed-Tree` trailer before pushing. Never force-push. Confirm the review marker is reachable from the exact reviewed
worker/tree and that local `dev` matches `origin/dev`, then immediately return to queue discovery.

## Loop reporting and manual stop

After each cycle, report the reviewed worker/archive, findings and fixes, validations actually run, review marker and
publication status, plus quarantined/remaining items. Keep running after the update. Only when manually interrupted,
produce the aggregate terminal report. Never fabricate device, CI, external-service, or human-review evidence.
