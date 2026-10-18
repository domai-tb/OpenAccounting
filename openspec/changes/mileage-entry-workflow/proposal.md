## Why

Business mileage currently has no entry workflow. The accounting model and EKS calculator contain a distance field, but users cannot record and trace a business trip or safely distinguish captured facts from an approved deduction.

## What Changes

- Add a localized, keyboard-accessible mileage workspace to record, review, and find dated business trips by purpose, distance, and business context.
- Persist each trip as an immutable-after-posting source record with explicit lifecycle state, policy snapshot fields, and a unique accounting-event reference.
- Keep captured trips unresolved and out of monetary totals until their structured trip type, vehicle source, and vehicle class qualify under `DE-private-business-travel/1` (version 1, effective 2025-01-01 through 2026-12-31). Keep posting unavailable until a user-configured, reviewed travel-expense/private-contribution mapping and atomic accounting boundary exist. Each role uses an explicit `Sachkonto` and category; never infer a default account or category.
- Define append-only correction and undo records for posted trips. Apply them only through an accepted accounting correction operation; never edit or delete the original trip or posting.
- Keep the existing EKS travel allowance rule scoped to EKS. Do not reuse its €0.10/km calculation as the general business-trip amount.
- Define mileage posting as a debit to the explicitly mapped travel-expense `Sachkonto`/category and a credit to the explicitly mapped private-contribution `Sachkonto`/category, with no bank, cash, or VAT leg.

## Capabilities

### New Capabilities

- `mileage-entry`: Traceable capture and controlled accounting of business mileage.

### Modified Capabilities

- `db`: Preserve the reconciled 55-name inventory through v19 and add `mileage_posting_account_mapping` and `mileage_posting_period_closures` at v25, bringing the known inventory to 57. Both tables are not required before v25 and are schema-checked from v25 onward; role mappings remain empty until explicitly reviewed, while an empty closure table means every trip date is open.
- `stammdaten`: Extend the existing `konten` account-type contract with explicitly created `Sachkonto` ledger accounts, preserving existing bank/cash types and rows.
- `einkommen`: Include each posted mileage source exactly once in EÜR by trip date using immutable journal mapping snapshots, including the expense on line 71 and the private contribution on line 107.

## Impact

The shared inventory remains 55 known application-table names through v19; v25 adds the profile-local mileage role-mapping and inclusive date-range closure tables, bringing the known inventory to 57. Mileage tables remain required from v13. The account workspace needs explicit `Sachkonto` CRUD and bank-specific selector filtering; mileage posting needs user-reviewed expense and private-contribution account/category pairs with no defaults. A calculated trip remains unposted until both pairs and an open trip-date range are verified in the same atomic posting operation. With no closure rows, all trip dates are open; a trip whose date falls within a closed inclusive range is rejected. EÜR must include the mileage expense and private contribution exactly once by trip date from immutable per-leg mapping snapshots; it must not depend on mutable category joins or ordinary settlement allocations. Correction execution remains gated on its accepted atomic accounting operation.
