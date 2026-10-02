## Context

The current desktop shell exposes `/contacts` as a generic list backed by the `kunden` table and a generic read-only detail. The dedicated create page persists only a subset of customer fields. `RouteDataRepository` allows `kunden` but not `lieferanten` and limits each list request to 100 rows; supplier, article, company, category, account, tax-rate, and number-range data have repositories or persistence contracts without complete production entry points. The existing `typed-route-workspaces` capability already requires typed route ownership, explicit projections, search, sorting, pagination, and truthful loading/empty/error states; this change makes those requirements concrete for master data.

The implementation must retain the Flutter desktop shell, active-profile SQLite database, and Page → UseCase → Repository → DataSource dependency direction. UI code must use the established app-service boundary. `DESIGN.md` requires searchable tables with sticky headers, sorting, filters, result counts, multi-select and context actions; contact details may open in the optional 360–440 px inspector. Forms should use the regular page canvas and remain within the 720–900 px width guidance. No rendered visual review is included in this proposal.

## Goals / Non-Goals

**Goals:**

- Make customer and supplier lists, record details, create/update forms, and archive actions reachable from Contacts.
- Provide production routes and Settings links for articles/article groups, company data, categories, bank accounts, tax rates, and number ranges documented in feature 03.
- Replace generic row dumps with typed projections and typed use-case/repository actions.
- Keep list search, active filters, sort order, selected tab, and page in route state so opening/closing a record does not reset the workspace.
- Preserve existing record identifiers, references, and accounting behavior while the open policy conflicts are resolved.

**Non-Goals:**

- No REST API, web/backend service, multi-user model, or new client dependency.
- No change to tax, accounting, invoice, payment, dunning, or number-generation semantics in this proposal.
- No change to the database schema unless a resolved archival or identifier decision demonstrates that existing columns cannot represent it.
- No redesign of unrelated shell pages or implementation of global search, profile management, or customer-document upload.
- No unapproved BZSt network verification or claim of legal compliance.

## Decisions

### Use existing shell destinations and typed feature services

Keep `/contacts` as the customer/supplier workspace and encode the selected sibling tab plus list state in its query parameters. Retain `/contacts/new` and `/contacts/:id`, extending their typed service input to support both customer and supplier records. Add `/articles`, `/articles/new`, and `/articles/:id`. Add `/settings/company`, `/settings/categories`, `/settings/accounts`, `/settings/tax-rates`, and `/settings/number-ranges`; the existing `/settings` page links to these, and to `/articles`, as a clearly grouped master-data section. These routes belong to the current app shell, not a second navigation or service stack. This change adds only the uniquely named master-data route/action requirement; it does not modify the shared `Canonical route inventory` requirement, which must be reconciled with concurrent route changes before main-spec sync.

Each route obtains a typed projection and actions from its owning use cases/repositories through the app-service boundary. The generic SQL route reader is not extended for write workflows. UI widgets do not access GetIt directly. The repositories own list filtering, deterministic sorting, bounded page reads, validation, and writes. A page response contains typed rows, total/has-more metadata, and the effective query so that pagination and result counts remain correct.

Rejected alternatives:

- Adding supplier records to the generic table/column dump would expose implementation fields and still provide no typed edits or validation.
- Loading every record and filtering client-side would keep the current 100-row cap and return incomplete search results.
- Putting full customer or supplier forms in small dialogs would conflict with the form-width and destructive-action guidance in `DESIGN.md`.

### Keep list, inspector, and form behavior aligned with DESIGN.md

Use a page header with one primary create action, a search/filter toolbar with removable filter chips and result count, a sticky sortable table, and an explicit empty state with a create action. Customer and supplier rows support keyboard navigation, selection, context-menu actions, and bulk archive; core actions remain visible without hover or right-click. Row selection may open the shared inspector for quick review; the full detail and create/update forms remain normal routed pages. Archive requires a confirmation dialog and leaves historical references readable. Forms group address, tax, contact, payment, and restrictions fields according to the current data model, label controls, preserve entered values after validation errors, and keep archive controls visually separate from Save.

At narrow widths, the shared inspector becomes an overlay per the existing shell contract. The route URI retains the active tab, search, filters, sort and page when opening a detail and returning to the list. The table uses the shared density, focus, and empty/error patterns instead of defining a separate design language.

Rejected alternatives:

- A separate contact-management shell would duplicate navigation, interaction, and localization behavior.
- Making every row action a hover-only icon would make core actions hard to discover and inaccessible by keyboard.
- Treating a query or storage error as an empty list would risk users mistaking missing data for an empty profile.

### Reuse existing master-data records and expose only documented operations

Company remains a singleton edit workspace. Categories, bank accounts, tax rates, number ranges, articles, and article groups use their current domain fields and documented create/read/update actions; seeded/reference deletion follows its existing capability guard. Workspaces use the active profile database and do not seed or recreate records as part of page loading. Existing active-state columns may supply current activation controls where that is already a documented field, but this proposal does not infer that every inactive record has the same archival meaning.

No new database schema is planned initially. Add typed page/use-case wiring for repositories that currently exist outside the production app-service graph. If a missing data contract is discovered, stop and update the specification before adding a migration or changing existing values.

## Risks / Trade-offs

- **[Risk]** Customer and supplier numbering, VAT verification, or deletion behavior is chosen implicitly while creating forms. → **Mitigation:** keep each conflict below as a blocking open question; do not implement a guessed persistence policy.
- **[Risk]** Search results remain incomplete for large profiles if filtering is applied after fetching. → **Mitigation:** execute filtering, stable ordering, and bounded pagination in the typed repository query and return total/has-more metadata.
- **[Risk]** A workspace is reachable but still uses a generic fallback in an error path. → **Mitigation:** route failures render a typed localized unavailable/retry state and never display raw table data.
- **[Risk]** Archive controls could make referenced customers or suppliers appear to vanish from historical documents. → **Mitigation:** archive preserves IDs and historical reads; test that linked documents still resolve before accepting the implementation.
- **[Risk]** A single broad settings page becomes difficult to scan. → **Mitigation:** keep company, category, account, tax-rate, and number-range destinations grouped and directly addressable under Settings.

## Migration Plan

1. Resolve the VAT/BZSt, archive/delete, and identifier-allocation questions below and update the affected docs/spec contracts before implementation begins.
2. Add typed page projections and use-case entry points over the existing active-profile repositories; add any required schema change only through a named, backward-compatible migration after the resolved contract requires it.
3. Implement customer/supplier workspace and editor flows first, including query-backed pagination, detail/inspector return state, validation failures, archive confirmation, and linked-document reads.
4. Add the article and Settings master-data routes using the same shared list/form components and each repository's existing allowed actions.
5. Verify route behavior, service composition, empty/error/retry states, and the relevant table/inspector constraints at desktop and narrow widths. Rollback removes the new route wiring and UI; it must not delete or rewrite master-data rows. Any schema migration requires a separate compatible rollback/forward-recovery plan.

## Open Questions

These decisions block implementation of the related behavior; this proposal deliberately does not resolve them:

1. **VAT/BZSt:** `docs/03-kunden-stammdaten.md:49-52` promises a BZSt/eVatR verification link and stores a validation confirmation/date, while its technical notes at `:324-328` and the current `stammdaten` spec describe local country-format validation without a BZSt API. Should the UI only expose a link/manual confirmation, or is a live external verification integration required? Which statuses and evidence may be persisted?
2. **Archive/delete:** Feature 03 says customer deletion is a soft delete (`docs/03-kunden-stammdaten.md:54-60`), while the existing `stammdaten` spec blocks deletion when documents reference the customer and the repository currently performs a guarded row delete. Should the new Archive action set the existing `aktiv` flag, use a distinct archived/tombstone state, or map to soft deletion? Should permanent deletion remain available, and how should archived contacts behave in new document pickers? Supplier reference rules need the same decision.
3. **Customer/supplier numbering:** Feature 03 describes distinct `kundennummer` and `debitor_nr` ranges, and `lieferantennummer` and `kreditor_nr` ranges (`docs/03-kunden-stammdaten.md:47-48,75-83`), while the current spec and repository allocate a single debtor/creditor number for both visible fields. Should these be independent identifiers? If so, how are existing records migrated without changing invoice, bank, or journal references, and which range is authoritative for search/display?

Until those answers are recorded in the main docs/specs, implementations must preserve current persisted values and must not add an unreviewed BZSt request, hard-delete path, or second numbering sequence.
