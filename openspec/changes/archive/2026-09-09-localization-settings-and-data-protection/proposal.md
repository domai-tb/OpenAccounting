# Proposal: Expose settings, language, integrations, and local data protection

## Why

The app declares German and English but fixes the runtime locale to de-DE. Sidebar/router/dashboard strings bypass generated localization, and Settings is a placeholder. Theme/backup/API/SMTP/profile state exists in isolation but is not reachable; backup tests have shown failures, and SMTP testing reports success without connecting.

Evidence: lib/core/app.dart:22-25 fixes locale; lib/design_system/components/app_sidebar.dart:5 and :35-91 hardcodes shared UI; lib/core/router/app_router.dart:240-249 is a placeholder; lib/core/db/backup_service.dart:20; lib/pages/stammdaten/unternehmen_repository.dart:180-187 reports SMTP success without connection.

## What Changes

- Build a production Settings workspace for appearance, language/region, company/tax, storage, privacy, backup, and integrations.
- Make locale/theme/privacy state live and persistent while retaining route/filter state.
- Make backup and integration operations opt-in, local-first, and truthful about failures.

## Capabilities

- Expose settings, language, integrations, and local data protection
- Priority: High
- Dependencies: runtime-composition-and-database-lifecycle.

## Impact

lib/core/app.dart, l10n ARB/generated output, settings route, sidebar/dashboard/shared widgets, backup service/UI, integration adapters, and settings tests.
