# Proposal: Connect profile management to startup and the workspace UI

## Why

ProfileManager can list/create/rename profiles but deleteProfile performs no deletion. Startup selects one profile directly, ProfileSelectionService returns hard-coded test-path data, and the setup/sidebar selection callbacks are no-ops. Switching therefore cannot reliably change the active database in a running or restarted app.

Evidence: lib/core/db/profile_manager.dart:91-142; lib/features/setup/wizard_service.dart:220-233; lib/features/setup/wizard_page.dart:340-365; lib/design_system/components/app_sidebar.dart:42-60; lib/main.dart:41-46.

## What Changes

- Define one production profile registry/discovery source and remove test-path behavior.
- Implement create, select, switch, rename, delete, and active-pointer lifecycle with isolation safeguards.
- Connect startup, setup, sidebar, and settings UI to the same lifecycle service.

## Capabilities

- Connect profile management to startup and the workspace UI
- Priority: High
- Dependencies: runtime-composition-and-database-lifecycle.

## Impact

lib/core/db/profile_manager.dart, setup/profile services, main startup, sidebar/workspace selector, router reload behavior, and profile integration tests.
