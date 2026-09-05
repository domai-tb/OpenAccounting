# Design: Expose settings, language, integrations, and local data protection

## Context

The app declares German and English but fixes the runtime locale to de-DE. Sidebar/router/dashboard strings bypass generated localization, and Settings is a placeholder. Theme/backup/API/SMTP/profile state exists in isolation but is not reachable; backup tests have shown failures, and SMTP testing reports success without connecting.

## Goals

Users can control the app and protect local data through reachable, truthful settings.

## Non-Goals

Making cloud sync mandatory; local-first remains the default.

## Decisions

Drive MaterialApp locale/theme from a persisted controller, localize all user-facing shared copy through ARB, and keep integration adapters injectable/opt-in.

## Risks / Trade-offs

Localization expands ARB scope and can expose untranslated domain pages; missing translations must have an explicit fallback policy.

## Migration Plan

Create settings state/controller and production route, migrate shared strings, add locale/theme/backup/SMTP tests, then connect profile and integration actions.

## Open Questions

Which settings may require a restart on each supported desktop platform?
