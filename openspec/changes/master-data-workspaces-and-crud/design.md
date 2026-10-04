## Context

The current desktop shell exposes `/contacts` as a generic list backed by the `kunden` table and a generic read-only detail. The dedicated create page persists only a subset of customer fields. `RouteDataRepository` allows `kunden` but not `lieferanten` and limits each list request to 100 rows; supplier, article, company, category, account, tax-rate, and number-range data have repositories or persistence contracts without complete production entry points. The existing `typed-route-workspaces` capability already requires typed route ownership, explicit projections, search, sorting, pagination, and truthful loading/empty/error states; this change makes those requirements concrete for master data.

The implementation must retain the Flutter desktop shell, active-profile SQLite database, and Page → UseCase → Repository → DataSource dependency direction. UI code must use the established app-service boundary. `DESIGN.md` requires searchable tables with sticky headers, sorting, filters, result counts, multi-select and context actions; contact details may open in the optional 360–440 px inspector. Forms should use the regular page canvas and remain within the 720–900 px width guidance. No rendered visual review is included in this proposal.

## Goals / Non-Goals

**Goals:**

- Make customer and supplier lists, record details, create/update forms, and archive actions reachable from Contacts.
- Provide production routes and Settings links for articles/article groups, company data, categories, bank accounts, tax rates, and number ranges documented in feature 03.
- Replace generic row dumps with typed projections and typed use-case/repository actions.
- Keep list search, active filters, sort order, selected tab, and page in route state so opening/closing a record does not reset the workspace.
- Preserve existing record identifiers, references, and accounting behavior; add only the defined archive state.

**Non-Goals:**

- No REST API, web/backend service, multi-user model, or new client dependency.
- No change to tax, accounting, invoice, payment, dunning, or number-generation semantics in this proposal.
- No database schema change beyond the two defined nullable archive columns and their migration.
- No redesign of unrelated shell pages or implementation of global search, profile management, or customer-document upload.
- No unapproved BZSt network verification or claim of legal compliance.

## Decisions

### Use existing shell destinations and typed feature services

Keep `/contacts` as the customer/supplier workspace and encode the selected sibling tab plus list state in its query parameters. `/contacts/new` requires `kind=customer|supplier`, and `/contacts/:id` requires the same discriminator; unqualified legacy detail links render a type-selection state and never guess between independently allocated customer and supplier IDs. Add `/articles`, `/articles/new`, and `/articles/:id`; item/group editor routes require `kind=item|group`, and `/articles?view=groups` exposes the group workspace. Add `/settings/company`, `/settings/categories`, `/settings/accounts`, `/settings/tax-rates`, and `/settings/number-ranges`; the existing `/settings` page links to these, and to `/articles`, as a clearly grouped master-data section. These routes belong to the current app shell, not a second navigation or service stack. The delta modifies `Canonical route inventory` to include `/articles` and the listed typed master-data routes; concurrent route changes must be reconciled before main-spec sync.

### Typed route matrix

Every row uses the common route state contract: loading shows a localized skeleton; populated shows the typed projection and visible primary actions; empty shows a localized create/setup action; failure shows a localized retryable unavailable state and preserves the URI. Detail routes additionally show not-found for an absent typed record. The matrix assigns the service owner and the behavior for each new surface:

| Route / state | Typed owner and projection/actions | Empty or unavailable boundary |
|---|---|---|
| `/contacts` with `tab=customers|suppliers` and list query | `CustomerWorkspaceUseCase` or `SupplierWorkspaceUseCase`; paged typed rows, search/filter/sort, create, inspect, archive, restore | Empty state offers matching create action; repository failure preserves the tab and query and offers retry |
| `/contacts/new?kind=customer|supplier` | `ContactFormUseCase`; typed customer or supplier fields, validate, create | Missing/invalid `kind` shows a type choice; write failure retains input |
| `/contacts/:id?kind=customer|supplier` | `ContactDetailUseCase`; lookup exactly one entity type, detail/edit/archive/restore | Missing/invalid `kind` shows a type-selection state without lookup; missing record shows not-found; lookup failure offers retry |
| `/articles?view=items` | `ArticleWorkspaceUseCase`; paged article rows, search/sort/filter, create/detail/update and existing lifecycle actions | Empty state offers article creation; loading/error follow common states |
| `/articles?view=groups` | `ArticleGroupWorkspaceUseCase`; typed group rows, create/detail/update and existing lifecycle actions | Empty state offers group creation; unavailable repository never falls back to raw columns |
| `/articles/new?kind=item|group` | `ArticleFormUseCase` or `ArticleGroupFormUseCase`; typed create form | Missing/invalid `kind` offers item/group choice; write failure retains input |
| `/articles/:id?kind=item|group` | `ArticleDetailUseCase` or `ArticleGroupDetailUseCase`; type-qualified detail/edit and existing lifecycle actions | Missing/invalid `kind` shows type choice; missing record shows not-found |
| `/settings/company` | `CompanySettingsUseCase`; singleton company projection and update action | Missing record shows setup-needed state; failure offers retry |
| `/settings/categories` | `CategoryWorkspaceUseCase`; typed categories, create/update and currently allowed guarded deletion | Empty state offers category creation; unavailable repository offers retry |
| `/settings/accounts` | `BankAccountWorkspaceUseCase`; typed account rows, create/update and currently allowed guarded deletion | Empty state offers account creation; unavailable repository offers retry |
| `/settings/tax-rates` | `TaxRateWorkspaceUseCase`; typed rate rows, create/update and currently allowed guarded deletion | Empty state offers rate creation; unavailable repository offers retry |
| `/settings/number-ranges` | `NumberRangeWorkspaceUseCase`; typed range rows, create/update and currently allowed guarded deletion | Empty state offers range creation; unavailable repository offers retry |

The app-service aggregate exposes these typed use cases to the route builders. No route in this matrix reads `SELECT *` or obtains GetIt directly from a widget.

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

Company remains a singleton edit workspace. Categories, bank accounts, tax rates, number ranges, articles, and article groups use their current domain fields and documented create/read/update actions; seeded/reference deletion follows its existing capability guard. Workspaces use the active profile database and do not seed or recreate records as part of page loading. This proposal does not infer archive behavior from generic `aktiv` fields.

Customer and supplier archive state is represented by nullable `archived_at TEXT` columns. A single ordered schema migration adds the columns to `kunden` and `lieferanten`, backfills existing rows as active (`NULL`), and preserves all IDs, values, and foreign-key references. The migration SHALL be the next schema version after the accepted v10 migration; if migration order changes before implementation, it must be reassigned to the next sequential version. Archive writes a UTC timestamp once; restore clears it. Permanent deletion is not offered by these workspaces. Existing guarded repository deletion remains available only through its existing explicit operation and continues rejecting referenced rows. New customer/supplier pickers exclude archived records by default; historical detail reads and reports continue resolving archived identities, and picker results may include archived rows only through an explicit include-archived filter.

The workspace form uses the existing country-specific USt-IdNr format validation only. It does not call BZSt/eVatR and does not display or persist a claim that an ID was externally verified; live verification, external-link evidence, and validation-date fields are deferred to a separately specified change. Customer and supplier number fields preserve existing values. Creation continues the current contract: allocate the debtor/creditor number from its existing range and store the same allocated value in the corresponding customer/supplier number field. Independent `kunde` and `lieferant` sequences, backfill, and renumbering are deferred; this change does not rewrite historical identifiers or references.

Add typed page/use-case wiring for repositories that currently exist outside the production app-service graph. No other data migration, renumbering, or tax behavior change is in scope.

## Risks / Trade-offs

- **[Risk]** Customer and supplier forms drift into unapproved numbering, VAT verification, or deletion behavior. → **Mitigation:** follow the explicit current-numbering and local-validation contract; defer separate sequences and external verification; expose archive/restore without permanent deletion.
- **[Risk]** Search results remain incomplete for large profiles if filtering is applied after fetching. → **Mitigation:** execute filtering, stable ordering, and bounded pagination in the typed repository query and return total/has-more metadata.
- **[Risk]** A workspace is reachable but still uses a generic fallback in an error path. → **Mitigation:** route failures render a typed localized unavailable/retry state and never display raw table data.
- **[Risk]** Archive controls could make referenced customers or suppliers appear to vanish from historical documents. → **Mitigation:** archive preserves IDs and historical reads; test that linked documents still resolve before accepting the implementation.
- **[Risk]** A single broad settings page becomes difficult to scan. → **Mitigation:** keep company, category, account, tax-rate, and number-range destinations grouped and directly addressable under Settings.

## Migration Plan

1. Add the `archived_at` customer/supplier columns through the specified next-sequential schema migration; preserve every existing row and verify historical foreign-key reads.
2. Add typed page projections and use-case entry points over the active-profile repositories, with current local VAT format checks and current single-allocation numbering behavior.
3. Implement customer/supplier lists and editor flows with bounded queries, archive/restore confirmation, default exclusion of archived picker results, and query-state preservation.
4. Add the article and Settings master-data routes using shared list/form components and each repository's existing allowed actions.
5. Verify route behavior, service composition, empty/error/retry states, and table/inspector constraints at desktop and narrow widths. Rollback removes route wiring and UI; it must not delete or rewrite master-data rows. Before removing archive columns in a recovery operation, restore all archived customers and suppliers to active so no archive state is lost.

## Explicitly Deferred

- Live BZSt/eVatR verification, external-validation status, and validation-date persistence remain outside this proposal. `docs/03-kunden-stammdaten.md` describes these independently and requires a separate decision/spec before they are implemented.
- Independent customer/supplier number ranges and any reassignment/backfill remain outside this proposal. This proposal preserves current number values and current single-range allocation; a separate change must define migration and reference-preservation rules before implementing separate sequences.
