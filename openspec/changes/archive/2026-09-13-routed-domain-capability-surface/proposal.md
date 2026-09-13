## Why

Several routes render raw `SELECT *` records or generic “database query complete” screens. Important accounting, contact, tax, report, setup, and dashboard capabilities exist in code but are not reachable through a typed, useful user workflow.

## What Changes

- Define and implement an explicit canonical route inventory with route-specific actions and state boundaries.
- Replace generic list/detail screens with typed capability surfaces and scalable queries.
- Make dashboard cards route to real destinations and recover from hidden-widget or persistence failures.
- Complete setup and bank-import recovery states, including profile/account/category visibility.
- Preserve deep-link aliases while keeping IDs and query parameters.
- Keep unavailable database, capability, and persistence states distinct so recovery never masquerades as first-run setup.

## Capabilities

### New Capabilities

- `typed-route-workspaces`: Canonical route inventory, typed data, domain actions, list paging, and route-specific states.
- `dashboard-and-setup-workflows`: Actionable dashboard cards, configuration recovery, setup data visibility, and profile context.
- `bank-import-recovery-surface`: Retry, manual-review, history actions, and reconciliation entry points.

### Modified Capabilities

None. Existing route and feature specs remain authoritative for domain calculations; these capabilities define the missing user-facing surface.

## Impact

- `lib/core/router/`, `lib/core/app_services.dart`, `lib/features/dashboard/`, `lib/features/setup/`, `lib/features/bank_import/`, and typed feature repositories.
- Route/widget/integration tests with fake services and explicit query/pagination boundaries.
- No database schema change is required unless a typed projection proves a missing field. Focused widget/integration tests cover every route row, alias form, inventory guard, setup rollback, dashboard persistence failure, and bank-import status action.
