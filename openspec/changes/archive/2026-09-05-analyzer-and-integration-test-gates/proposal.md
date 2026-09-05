# Proposal: Restore trustworthy static analysis and application-level test gates

## Why

fvm flutter analyze exits non-zero with 255 diagnostics, including deprecated lint configuration and unused production code. The suite can report all tests passing while dashboard providers log LateInitializationError, route tests assert placeholder text, and shortcut/update tests replace the production services with local fakes.

Evidence: fvm flutter analyze reported 255 issues including analysis_options.yaml:37, :40, :92, :144 and unused production imports/fields; test/core/router_test.dart:61-94 asserts placeholders; test/features/desktop/shortcuts_test.dart:1 and update_test.dart:4 redeclare production types; dashboard widget tests emit LazyDatabase errors.

## What Changes

- Reduce analyzer output to zero diagnostics under the pinned Flutter version and maintain the strict lint contract.
- Make application tests use the production composition and feature services rather than local helper implementations.
- Add release-gating route/runtime tests that fail on hidden provider errors, placeholders, and inert command paths.

## Capabilities

- Restore trustworthy static analysis and application-level test gates
- Priority: Medium
- Dependencies: runtime-composition-and-database-lifecycle; primary-workspace-exposure; desktop-lifecycle-and-command-wiring.

## Impact

analysis_options.yaml, production dead code, test/core/router_test.dart, app shell/dashboard/shortcut/update tests, and future CI/release commands.
