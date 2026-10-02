## Why

Customers, suppliers, articles, company settings, categories, accounts, tax rates, and number ranges have documented data contracts, but several have no reachable production workspace and contacts are not a complete searchable, paginated CRUD surface. This change makes those existing master-data capabilities usable through the desktop shell while preserving the current local-first architecture and DESIGN.md interaction patterns.

## What Changes

- Turn `/contacts` into searchable, filterable, paginated customer and supplier workspaces with typed list rows, record details, create/update forms, and a confirmed archive action.
- Add reachable production workspaces for articles and article groups, company data, categories, bank accounts, tax rates, and number ranges where those records are documented in `docs/03-kunden-stammdaten.md`.
- Provide typed route projections and repository/use-case actions for these workspaces; keep table queries bounded and retain search/filter/page state while users inspect or edit records.
- Align customer and supplier forms with the existing master-data model and validation contracts after resolving the open VAT, deletion/archive, and number-allocation conflicts listed in the design.
- Do not introduce REST endpoints, backend services, new accounting semantics, or a database migration unless the resolved contract proves one is necessary.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `stammdaten`: require reachable customer/supplier CRUD and archive workspaces, plus production entry points for the documented master-data records.
- `typed-route-workspaces`: add a uniquely scoped requirement for typed, reachable master-data route actions; the shared canonical route inventory remains unchanged by this proposal.

## Impact

- Flutter routing, sidebar/settings entry points, list/detail/editor widgets, and localized route states.
- Master-data repositories/use cases and typed list/detail projections for customers, suppliers, articles, company data, categories, accounts, tax rates, and number ranges.
- Existing SQLite records and validations remain the source of truth; resolve the documented/specification conflicts before changing persistence or numbering behavior.
- No new dependency or remote API is assumed.
