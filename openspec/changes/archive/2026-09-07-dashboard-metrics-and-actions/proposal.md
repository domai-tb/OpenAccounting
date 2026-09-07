# Proposal: Make dashboard metrics and actions truthful and navigable

## Why

Dashboard queries do not consistently exclude drafts/cancellations or apply a period, income/expense treats positive/negative values inconsistently with journal art, the VAT deadline is hardcoded, and several cards/quick links point to unrelated routes. Configuration changes are optimistic without rollback.

Evidence: lib/features/dashboard/dashboard_repository.dart:150-236; :214-224 hardcodes deadline and :227-236 lacks period; dashboard_widgets.dart:48-63 maps inventory/dunning incorrectly; dashboard_entity.dart:110-115 maps Artikel/Journal incorrectly; dashboard_page.dart:42-52 lacks period/primary action and :122-139 fire-and-forget config.

## What Changes

- Define KPI scopes for document state, period, company/profile, booking direction, and filing configuration.
- Correct card/quick-link destinations and add the designed primary action and period controls.
- Give dashboard configuration persistence visible success/failure feedback and rollback.

## Capabilities

- Make dashboard metrics and actions truthful and navigable
- Priority: High
- Dependencies: runtime-composition-and-database-lifecycle; invoice-accounting-posting-lifecycle; receivables-ledger-integrity; primary-workspace-exposure.

## Impact

lib/features/dashboard/dashboard_repository.dart, dashboard_entity.dart, dashboard_widgets.dart, dashboard_page.dart, dashboard configuration tests, and route integration.
