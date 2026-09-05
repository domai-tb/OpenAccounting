## Why

Existing app-shell coverage was incorrectly represented as a separate capability. This change consolidates its regression coverage into the existing app-shell capability and general app test suite.

## What Changes

- Keep shell implementation in `lib/app/app_shell.dart`
- Keep shell regression tests in `test/app/app_shell_test.dart`
- Remove placeholder feature code and feature-specific tests
- Express delta as a modification to the existing `app-shell` requirement
- VM-safe tests, DESIGN.md alignment

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- app-shell: consolidate layout, routing, and responsive shell coverage

## Impact

- Affected: `lib/app/app_shell.dart`, `test/app/app_shell_test.dart`, and `openspec/specs/app-shell/spec.md`
- Removed: placeholder `lib/features/app_shell_polish/` and `test/features/app-shell-polish/`
- Dependencies: existing Flutter/Riverpod test stack, no new dependencies
