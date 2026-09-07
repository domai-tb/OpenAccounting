# Proposal: Replace primary-route placeholders with real workspaces

## Why

The router explicitly labels invoices, receipts, banking, contacts, taxes, reports, settings, and help as placeholders. Several corresponding backends exist and are tested, but users cannot reach them; current router tests assert placeholder text instead of behavior.

Evidence: lib/core/router/app_router.dart:139-260 contains placeholder pages; lib/pages/rechnungen/rechnungen_usecases.dart and lib/features/bank_import/bank_import_service.dart provide existing backend capabilities; test/core/router_test.dart:61-94 asserts placeholder output.

## What Changes

- Replace text-only primary destinations with data-backed pages and nested detail/create routes.
- Expose the existing invoice, bank/receipt, master-data, accounting/reporting, and settings/help capabilities through the shell.
- Provide explicit loading, empty, error, search/filter, and primary-action states for each workspace.

## Capabilities

- Replace primary-route placeholders with real workspaces
- Priority: High
- Dependencies: runtime-composition-and-database-lifecycle; localization-settings-and-data-protection.

## Impact

lib/core/router/app_router.dart and new/connected page widgets; depends on runtime composition and interacts with dashboard, localization, and settings changes.
