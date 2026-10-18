## Why

Business mileage currently has no entry workflow. The accounting model and EKS calculator contain a distance field, but users cannot record and trace a business trip or safely distinguish captured facts from an approved deduction.

## What Changes

- Add a localized, keyboard-accessible mileage workspace to record, review, and find dated business trips by purpose, distance, and business context.
- Persist each trip as an immutable-after-posting source record with explicit lifecycle state, policy snapshot fields, and a unique accounting-event reference.
- Keep captured trips unresolved and out of monetary totals until their structured trip type, vehicle source, and vehicle class qualify under `DE-private-business-travel/1` (version 1, effective 2025-01-01 through 2026-12-31). Keep posting unavailable until the required mapping and atomic accounting boundary exist.
- Define append-only correction and undo records for posted trips. Apply them only through an accepted accounting correction operation; never edit or delete the original trip or posting.
- Keep the existing EKS travel allowance rule scoped to EKS. Do not reuse its €0.10/km calculation as the general business-trip amount.
- Define mileage posting as a debit to the mapped travel-expense account and a credit to the mapped private-contribution account, with no cash or VAT leg.

## Capabilities

### New Capabilities

- `mileage-entry`: Traceable capture and controlled accounting of business mileage.

### Modified Capabilities

- `db`: Keep the 55-name v19 inventory contract and the v13 mileage tables. The active `profile-data-portability` and `customer-data-disclosure-export` changes currently disagree (46 names/v13 versus 55 names/v19); record this dependency as open and block any claim of complete mileage export until both owners accept the same inventory and version-aware presence rules.

## Impact

The change covers the mileage workspace and its durable trip/correction records. The shared table inventory is 39 legacy tables plus 16 feature-managed tables (including `feature_table_state`), for 55 known names at v19. Mileage tables are required at v13 and are not lazy-marker tables. The active portability and customer-export contracts disagree about that inventory, so the dependency remains open; mileage export completeness and follow-up migration work stay gated until both owners accept one matching contract. Policy version 1 is explicit and source-backed; calculation remains fail-closed for commuting, company vehicles, EKS, unsupported or unknown vehicle classes, and trips outside its effective dates. Posting and correction execution remain gated on the required mappings and atomic accounting operations.
