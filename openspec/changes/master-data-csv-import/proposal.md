## Why

Users moving existing customer, supplier, and article data into a profile currently have no typed CSV import workflow. The documented migration path promises column mapping, header handling, reusable mappings, duplicate choices, and progress, but no production workflow owns those actions.

## What Changes

- Add a localized CSV import workflow for customers, suppliers, and articles from their master-data workspaces.
- Provide explicit header handling, manual source-to-field mapping, a row preview, field validation, and a reviewable import summary before any record is written.
- Let users save and reuse profile-local mapping templates without retaining uploaded source files or row contents.
- Define duplicate handling and row-level outcomes so ambiguous or invalid rows cannot silently update or create records.
- Keep article updates from changing selling prices: any supplied selling-price or derivation field produces a row-level unsupported-field error, while existing prices are preserved.
- Keep imported data within the existing master-data capabilities; do not create business documents, journal entries, payments, or inventory movements.

## Capabilities

### New Capabilities

- `master-data-csv-import`: Profile-local CSV mapping, preview, validation, duplicate review, and import for customer, supplier, and article records.

### Modified Capabilities

None. Customer, supplier, and article persistence remains governed by `stammdaten`; this change adds a separate import workflow that uses those existing record contracts.

## Impact

Adds import actions and an accessible review flow to the customer, supplier, and article workspaces; a typed use-case/repository boundary over the existing profile database; localized import UI; and profile-scoped mapping-template persistence. The flow depends on the typed master-data workspaces in `master-data-workspaces-and-crud`. It is separate from bank statement parsing, bank history, and transaction reconciliation. Any template schema change must use a named backward-compatible migration. No network service or new parser dependency is assumed.
