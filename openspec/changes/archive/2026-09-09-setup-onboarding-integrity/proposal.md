# Proposal: Make first-run setup complete, atomic, and accounting-safe

## Why

Setup skip and successful completion only show a snackbar, while the router treats the skip sentinel company Meine Firma as unconfigured and redirects back to setup. Completion writes company, accounts, cash, and categories independently; the opening cash journal is classified as income while the account saldo remains zero. The wizard also omits documented invoice numbering/payment terms, privacy, and backup concepts and uses fake IBAN fallback values.

Evidence: lib/features/setup/wizard_page.dart:111-132; lib/core/router/app_router.dart:37-60; lib/features/setup/wizard_service.dart:149-188; lib/features/setup/setup_repository.dart:81-150; DESIGN.md:1889-1942.

## What Changes

- Define one persisted setup state and make Skip/Finish transition to the dashboard without sentinel loops.
- Persist company, accounts, categories, and opening balances atomically with truthful accounting semantics.
- Add or explicitly defer the documented first-run concepts and remove fake financial identity defaults.

## Capabilities

- Make first-run setup complete, atomic, and accounting-safe
- Priority: High
- Dependencies: runtime-composition-and-database-lifecycle; profile-workspace-lifecycle; seed-master-data-contract.

## Impact

lib/features/setup/wizard_page.dart, wizard_service.dart, setup_repository.dart, app_router.dart, setup preferences, and end-to-end onboarding tests.
