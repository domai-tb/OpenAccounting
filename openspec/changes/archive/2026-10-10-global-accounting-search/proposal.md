## Why

DESIGN.md §13 describes a global search palette, and feature-map §65 describes searchable business documents, but production has no global query workflow. The routed record repository only lists rows with invoice type/status filters, so users cannot find documents by number, party, date, status, or amount across the application.

## What Changes

- Add the DESIGN.md `Ctrl/Cmd+K` search palette for typed, read-only results from supported invoices, contacts, receipts, and bank transactions, plus supported settings destinations and commands.
- Add bounded, combinable filters over the persisted invoice, receipt, and bank-transaction fields defined in the typed search contract.
- Open a selected bank transaction through `/banking?transactionId=<id>` so search results target the actual record without inventing a new canonical route.
- Route results through typed destinations and retain the existing local-first, profile-scoped data boundary.
- Follow DESIGN.md search, command-palette, localization, keyboard-accessibility, and responsive-layout requirements.

## Capabilities

### New Capabilities

- `global-business-search`: Defines the global search palette, typed results, supported destinations and commands, and safe behavior for empty, unavailable, and failed queries.

### Modified Capabilities

- `typed-route-workspaces`: Specify searchable business-document lists and combinable document filters.
- `desktop-lifecycle-and-command-wiring`: Bind `Ctrl/Cmd+K` to the global search intent in the production command registry.

## Impact

Desktop command registration, typed search use cases/repositories and projections, invoice/receipt/banking list workspaces and selection state, contacts lookup, canonical routing, localization, and search-related specifications. Search remains local to the active profile, uses explicit domain projections, and never writes accounting data. Contact-list CRUD and its local pagination remain owned by `master-data-workspaces-and-crud`.
