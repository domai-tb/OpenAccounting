## Why

Feature-map item 37 requires reusable presets for frequent transactions, including description, category, payment account/type, tax treatment, and an optional default amount. The maintained accounting specification promises immediate execution, but `schnellbuchungen` has no production CRUD or execution use case, omits the documented direction/tax fields, and currently has no Banking UI. Its specified direct journal insert also bypasses the unresolved balanced-posting contract.

## What Changes

- Add a Quick Bookings view to the existing `/banking` workspace with typed preset creation, editing, review, and execution.
- Persist explicit transaction direction, account/payment type, category, tax treatment, description, and optional amount basis/value; mark legacy presets with missing required fields for review rather than infer their meaning. Tax-rate validity is resolved by the accepted posting owner for the business date; do not invent an `aktiv` flag absent from `ust_saetze`.
- Execute a selected preset only through the accepted typed accounting posting service, returning its committed posting identity; never insert directly into `journal`.
- Keep execution unavailable until the posting contract accepts direct cash/bank transaction inputs and the preset contains every required posting field.
- Follow `DESIGN.md` keyboard, focus, localization, form, and narrow-window requirements.

## Capabilities

### New Capabilities

- `quick-booking-workspace`: Defines preset lifecycle and contract-gated one-action execution for frequent transactions.

### Modified Capabilities

- `accounting`: Reconcile the existing Schnellbuchungen requirement with the persisted schema and route execution through the accepted posting boundary.
- `db`: Add explicit preset fields and migrate legacy presets without guessing direction or tax treatment.
- `typed-route-workspaces`: Add a query-backed Quick Bookings view to the existing Banking route.

## Impact

The Banking workspace, `schnellbuchungen` typed repository/use case, additive table migration, accounting posting integration, and `docs/02-buchhaltung.md`. Cashbook and daily-close remain separate views; quick bookings reuse the same accepted transaction writer and do not create a second ledger or booking path.
