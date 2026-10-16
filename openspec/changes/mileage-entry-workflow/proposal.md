## Why

Business mileage currently has no entry workflow. The accounting model and EKS calculator contain a distance field, but users cannot record and trace a business trip or safely distinguish captured facts from an approved deduction.

## What Changes

- Add a localized, keyboard-accessible mileage workspace to record, review, and find dated business trips by purpose, distance, and business context.
- Persist each trip as an immutable-after-posting source record with explicit lifecycle state, policy snapshot fields, and a unique accounting-event reference.
- Keep newly captured trips unresolved and out of monetary totals until a separately accepted mileage policy defines eligibility and calculation. Keep accounting posting unavailable until the required mapping and accepted posting contract exist.
- Define append-only correction and undo records for posted trips. Apply them only through an accepted accounting correction operation; never edit or delete the original trip or posting.
- Keep the existing EKS travel allowance rule scoped to EKS. Do not reuse its €0.10/km calculation as the general tax-deductible mileage rate.

## Capabilities

### New Capabilities

- `mileage-entry`: Traceable capture and controlled accounting of business mileage.

### Modified Capabilities

- `db`: Add the two migration-required mileage tables to the shared inventory of 39 pre-existing base tables, one shared health table, and six feature-owned tables (55 known application-table names at v19). Keep migration disabled and prevent complete exports for profiles containing undeclared mileage tables until both inventory owners accept the same 55-name v19 contract.

## Impact

Adds a mileage route and form, a mileage entity/repository/use case, two durable feature-owned tables, and a coordinated schema migration. The shared inventory contains 39 pre-existing base tables, one shared health table, and six feature-owned tables (55 known names at v19). The mileage tables are required at schema version 13 and are not lazy-marker tables. The migration remains gated until the portability and customer-export inventory owners accept that same 55-name v19 inventory; exports fail closed for profiles containing undeclared mileage tables. Capture is usable while policy decisions remain open. Monetary calculation, posting, report inclusion, and correction execution remain gated on separately accepted policy, mapping, posting, and correction contracts. No policy rate, deductible percentage, account mapping, or rounding rule is selected here.
