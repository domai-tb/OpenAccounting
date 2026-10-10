## Context

DESIGN.md §13 describes local page search plus a `Ctrl/Cmd+K` global palette for invoices, contacts, receipts, transactions, settings, and commands. Feature-map §65 adds document number, party, date, status, and amount search with combinable filters. Current production code has no global search provider or route query service; `RouteDataRepository` is a bounded generic table reader with only invoice type/status predicates. The current route inventory has a `/banking` list but no selected-transaction route-query contract. The maintained desktop command spec already requires production-wired intents, while the typed workspace spec requires searchable paginated lists.

The current active proposals separately own invoice editing, master-data CRUD, bank import, and receipt workflows. This proposal supplies search/discovery across their reachable typed surfaces; it does not duplicate those workflows or make unavailable routes appear implemented.

## Goals / Non-Goals

**Goals:**

- Provide the search palette and searchable destinations shown in DESIGN.md.
- Search only records and fields exposed by supported typed projections, across the active profile.
- Give invoices, receipts, and bank transactions combinable filters using only their named persisted fields: invoice number/party/date/status/gross total, receipt number/description/supplier/date/status/amount, and transaction counterparty/remittance/date/status/amount.
- Keep result navigation, page filters, accessibility, and localization consistent with the existing route and design contracts.

**Non-Goals:**

- Replace contact CRUD/pagination, invoice authoring, receipt capture, or bank reconciliation.
- Search arbitrary SQL columns, files outside the active profile, or secrets and credentials.
- Add remote search, write actions from result rows, or new accounting calculations.
- Promise supplier/document fields on record types that do not have them.

## Decisions

1. **Use typed query boundaries.** Each searched domain supplies a bounded query and a small typed result projection. The palette composes those results; it does not query tables directly or return generic maps. This follows the page → use case → repository boundary and avoids coupling the search UI to database schemas. Rejected: extending `RouteDataRepository` with broad `SELECT *` and field-name guessing.
2. **Scope every result to the active profile.** Search uses the same registered database/profile provider as the current route. Switching profiles invalidates in-flight queries and results. Rejected: indexing or searching profile directories outside the active database lifecycle.
3. **Treat global search as discovery and page filters as work surfaces.** The palette returns typed record destinations and registered commands. The invoice, receipt, and banking pages own structured list filters, visible chips, and page counts. Contacts retain the separate CRUD proposal's list behavior. This keeps result navigation useful without duplicating list state in a modal.
4. **Select bank transactions through the existing route.** Selecting a typed bank result navigates to `/banking?transactionId=<id>` and asks the banking workspace to load/select that record in its inspector. It does not add a canonical path, alter a transaction, or create a posting. The selection query parameter must compose with existing banking query state such as history search, page, or import ID.
5. **Use canonical routes and registered intents.** Selecting an invoice/contact/receipt navigates through its canonical typed route; selecting a command dispatches a registered intent. Unsupported routes or actions never appear as results. This avoids stale destinations and empty callbacks.
6. **Make search bounded and deterministic without speculative ranking policy.** Queries return a capped result count per supported type and order exact identifiers ahead of partial matches, then use stable type/date/ID tie-breaks. Do not search all database columns or materialize entire tables. The UI labels result types and exact matching fields.
7. **Use only explicit persisted filter meanings.** Invoice amount filtering compares the stored gross `brutto_betrag`, date compares `datum`, and status compares the exact persisted `status`; party text searches the linked customer or supplier name/company. Receipt filters compare `belegnummer`, `beschreibung`, linked supplier, `datum`, exact `status`, and stored `betrag`. Banking filters compare `gegenkonto_name`, `gegenkonto`, `verwendungszweck`, `datum`, exact transaction `status`, and stored `betrag`. No totals or status categories are calculated by search. The parser validates localized date/amount inputs, and repositories bind query values.
8. **Wire both platform shortcuts explicitly.** Bind `Ctrl+K` on Windows/Linux and `Cmd+K` on macOS to one `globalSearch` intent. Extend the shortcut key parser with a real `K` mapping instead of its current unknown-key fallback. If OS-level registration is unavailable, keep the visible shell entry point and report the failure; the app must not claim the shortcut is active.
9. **Follow DESIGN.md overlay and keyboard behavior.** The palette is a transient shell surface, keeps focus inside while open, supports keyboard selection and Escape, returns focus to its invoker, and adapts to narrow widths. It does not replace a page or lose its query state.

## Risks / Trade-offs

- [Some owned workflows are not yet reachable] → Register only domains with a typed production surface; show no claim of support for unavailable modules and add each domain when its owning proposal exposes it.
- [Search across multiple sources may partially fail] → Preserve successful typed groups, mark the failed source explicitly, and offer per-source retry; never label a partial result set as complete.
- [Substring search can be costly on large local profiles] → Bound results, use existing indexes or add justified indexes after query-plan review, and keep pagination on list pages.
- [Localized amount/date entry is ambiguous] → Reuse shared parsing and formatters, show field errors before querying, and keep canonical stored values for comparison.
- [Shortcut behavior conflicts with text entry or OS reservations] → Reuse the production shortcut focus guard and keep the visible shell search entry point available if registration fails.

## Migration Plan

No data migration is expected. Add the typed query/use-case boundary and its providers, wire the visible palette and desktop command, then add document-list filters to supported typed workspaces. Search remains optional presentation state; rollback removes the entry point and providers without changing persisted accounting data.

## Open Questions

- Which search fields merit database indexes after representative profile query plans are measured? Add indexes only if measured query plans justify them.
