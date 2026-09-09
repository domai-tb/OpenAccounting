# Proposal: Complete desktop lifecycle persistence and command integrations

## Why

Window state has two incompatible storage implementations and no lifecycle save caller. Shortcut callbacks are no-ops and target /invoices/new even though routing treats new as an ID. Tray actions are empty, while updater download/install are stubs and signature verification accepts only the literal valid.

Evidence: lib/main.dart:77-153 and lib/features/desktop/window_state.dart:49-50/:197 use different keys; desktop_shortcuts.dart:146-149/:213-225; desktop_tray.dart:197; desktop_updater.dart:61, :71, :139-163, :296-317.

## What Changes

- Choose one window-state owner/key format and persist resize/move/maximize/close lifecycle events with off-screen recovery.
- Register real shortcuts and tray actions against command intents and valid routes.
- Implement secure updater download, real signature verification, install, and retry behavior.

## Capabilities

- Complete desktop lifecycle persistence and command integrations
- Priority: High
- Dependencies: runtime-composition-and-database-lifecycle; primary-workspace-exposure; finalized-document-artifact-lifecycle.

## Impact

lib/main.dart, features/desktop/window_state.dart, desktop_shortcuts.dart, desktop_tray.dart, desktop_updater.dart, and desktop integration tests.
