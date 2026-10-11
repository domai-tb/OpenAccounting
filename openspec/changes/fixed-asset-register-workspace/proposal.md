## Why

The database contains an `anlageverzeichnis` table and EÜR reads it for AfA, but users have no asset-management route or production CRUD service. Stored field names and semantics do not match the maintained asset contract, and the EÜR reader applies undocumented partial-year disposal rules without calculating book values.

## What Changes

- Add a reachable asset-register workspace with typed create, view, update, and safe delete/archive actions.
- Add a traceable per-asset annual linear-AfA schedule using only inputs and formulas defined by the maintained accounting contract; mark unresolved legacy, partial-year, disposal, and book-value calculations unavailable.
- Add the asset route to the canonical route inventory.
- Keep acquisition, depreciation, disposal, and account assignment out of direct journal writes. Feed the owning EÜR workflow only a complete, contract-backed schedule result under its independently accepted reporting contract; this change defines no report output on its own and waits on no other change.
- Reconcile asset fields and behavior without copying the documentation's unsupported degressive method or inventing disposal/account-mapping rules.
- Add an additive migration for canonical asset fields and immutable, source-traceable annual schedule snapshots; retain every existing legacy value.

## Capabilities

### New Capabilities

- `fixed-asset-register-workspace`: Manage fixed-asset records and inspect a traceable annual depreciation schedule.

### Modified Capabilities

- `accounting`: Gate asset AfA and AVEÜR output on explicit, contract-backed inputs and fail closed for unresolved calculations.
- `db`: Declare the asset-register additions, schedule-snapshot table, migration preservation, and deletion constraints.
- `typed-route-workspaces`: Add the canonical `/assets` route and its localized alias.

## Impact

Adds a typed asset repository/data source, use case, service registration, `/assets` page, and narrowly scoped additive persistence for canonical asset fields and traceable schedule results. `accounting-reporting-workspaces` owns the EÜR report, tax export, and report status; this change owns asset CRUD and its annual schedule source. The EÜR workspace, under its independently accepted reporting contract, may consume only complete supported values, and no new journal writer or account mapping is introduced. Every canonical write sets both `kaufpreis_netto` and the legacy required `anschaffungskosten` with the same amount. The profile portability inventory must declare `anlage_afa_jahreswerte`, owned by this change at its accepted sequential schema version, before a release creates it.
