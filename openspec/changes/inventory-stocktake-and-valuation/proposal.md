## Why

The `/inventory` route currently stops at an unavailable page, and the inventory data model records live quantities and movements without physical count records or an approved valuation basis. Add a date-selected count workflow that persists what was counted while failing closed wherever historical book quantities or monetary values cannot be substantiated.

## What Changes

- Replace the unavailable inventory boundary with a typed, profile-local stocktake workspace when global inventory is enabled; keep a truthful unavailable state when it is disabled or its data service cannot be opened.
- Persist stocktake reporting date, capture time, article identity/description/unit snapshots, and explicit counted quantities. A recorded count is evidence only: it does not change live stock, append movement rows, or create accounting entries.
- Show recorded quantities in the result list. Do not represent current stock as historical book stock, and show inventory values as unavailable until a reviewed valuation policy and its required data are specified.
- Add named, versioned stocktake tables without rewriting existing article quantities or movement history.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `inventory`: add persistent physical counts and explicit fail-closed rules for as-of quantities, valuation, and side effects.
- `db`: declare the stocktake tables and migration boundary.

## Impact

The inventory route, app-service/use-case/repository/data-source wiring, profile-local SQLite migrations, and German/English localized desktop UI. Existing movement and invoice stock effects remain governed by the current inventory contract. Valuation and count-to-ledger posting policy remain open decisions.
