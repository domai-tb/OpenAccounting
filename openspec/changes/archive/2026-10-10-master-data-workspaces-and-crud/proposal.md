## Why

Customers, suppliers, articles, company settings, categories, accounts, tax rates, and number ranges have documented data contracts, but several have no reachable production workspace and contacts are not a complete searchable, paginated CRUD surface. This change makes those existing master-data capabilities usable through the desktop shell while preserving the current local-first architecture and DESIGN.md interaction patterns.

## What Changes

- Turn `/contacts` into searchable, filterable, paginated customer and supplier workspaces with typed list rows, record details, create/update forms, and a confirmed archive action.
- Add reachable production workspaces for articles and article groups, company data, categories, bank accounts, tax rates, and number ranges where those records are documented in `docs/03-kunden-stammdaten.md`.
- Provide typed route projections and repository/use-case actions for these workspaces; keep table queries bounded and retain search/filter/page state while users inspect or edit records.
- Persist customer and supplier archive state with a backward-compatible nullable timestamp migration; keep archived rows available to historical documents and out of new-document pickers by default.
- Keep customer and supplier numbering aligned with current persisted behavior in this change; defer independent customer/supplier number sequences and BZSt verification evidence as separate specification work.
- Do not introduce REST endpoints, backend services, new accounting semantics, or a database migration beyond the specified archive-state migration.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `stammdaten`: require reachable customer/supplier CRUD and archive workspaces, plus production entry points for the documented master-data records.
- `typed-route-workspaces`: add typed master-data route actions, a service/state matrix for each new route and article-group view, and extend the canonical route inventory with article and Settings subroutes.
- `db`: define the customer/supplier archive columns and their ordered schema migration.

## Impact

- Flutter routing, sidebar/settings entry points, list/detail/editor widgets, and localized route states.
- Master-data repositories/use cases and typed list/detail projections for customers, suppliers, articles, company data, categories, accounts, tax rates, and number ranges.
- Existing SQLite records and validations remain the source of truth; archive migration preserves identifiers and references while this proposal explicitly defers independent numbering and external VAT verification.
- No new dependency or remote API is assumed.
