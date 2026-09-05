## Context

The shell already has a dedicated implementation and general widget tests. The prior delta incorrectly described a new feature instead of a focused change to that existing capability.

## Goals / Non-Goals

**Goals:** consolidate regression coverage under the existing app-shell capability and preserve DESIGN.md shell behavior.
**Non-Goals:** no new shell feature, no new production service, no breaking changes.

## Decisions

- Keep `AppShell` as the only shell implementation.
- Keep layout, routing, and responsive tests in `test/app/app_shell_test.dart`.
- Delete placeholder feature code and tests; they tested unrelated amount formatting.
- Rejected: adding a separate shell feature for one task.

## Risks / Trade-offs

- [Coverage drift] → map change scenarios to existing general shell tests.
- [Layout regressions] → retain VM-safe widget tests at DESIGN breakpoints.

## Migration Plan

Remove placeholder implementation and tests, retain existing `AppShell` and general shell tests, then update the delta to the existing `app-shell` capability. No runtime data or user configuration migration.

## Open Questions

none
