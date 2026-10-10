# typed-route-workspaces Specification

## Purpose
TBD - created by archiving change routed-domain-capability-surface. Update Purpose after archive.

## Requirements

### Requirement: Canonical route inventory

The application SHALL expose typed pages for exactly these canonical routes: `/`, `/invoices`, `/invoices/new`, `/invoices/:id`, `/receipts`, `/banking`, `/contacts`, `/contacts/new`, `/contacts/:id`, `/articles`, `/articles/new`, `/articles/:id`, `/taxes`, `/reports`, `/settings`, `/settings/company`, `/settings/categories`, `/settings/accounts`, `/settings/tax-rates`, `/settings/number-ranges`, `/help`, `/setup`, and `/inventory`. `/contacts/new` and `/contacts/:id` SHALL require the query discriminator `kind=customer|supplier`; article editor routes SHALL require `kind=item|group`, and `/articles` SHALL expose the article-group subview as `view=groups`. Every new route and article-group subview SHALL have an owning typed service, projection/actions, and loading/populated/empty/failure boundary in the `master-data-workspaces-and-crud` route matrix. Each route SHALL define a primary action or explicit read-only/unavailable boundary. German aliases SHALL preserve IDs and the complete query string when redirecting.

#### Scenario: Every canonical route has a useful surface
- **GIVEN** an active profile is available
- **WHEN** the user visits every route in the inventory
- **THEN** each page SHALL show its typed title, route-specific state, and documented primary action or truthful boundary

#### Scenario: Contact detail discriminator selects the correct record type

- **GIVEN** customer ID `42` and supplier ID `42` both exist
- **WHEN** the user opens `/contacts/42?kind=supplier`
- **THEN** the route resolves only the supplier record with ID `42`
- **AND** opening `/contacts/42?kind=customer` resolves only the customer with that ID
- **AND** list return state remains in the other query parameters

#### Scenario: Missing or invalid contact discriminator does not guess

- **GIVEN** a contact detail route has no `kind` query or an unsupported value
- **WHEN** the route resolves
- **THEN** it shows a localized type-selection state without querying either entity table
- **AND** it preserves the requested ID and other query parameters

#### Scenario: Article and article-group routes use their typed owner

- **GIVEN** an article and article group can share the same numeric ID
- **WHEN** the user opens `/articles/42?kind=group` or `/articles/42?kind=item`
- **THEN** each route resolves only the selected entity type
- **AND** `/articles?view=groups` exposes the typed group list and its documented create/update/lifecycle actions

#### Scenario: Database outage is not an empty route
- **GIVEN** the active database cannot be opened
- **WHEN** any canonical route is requested
- **THEN** the page SHALL show a localized unavailable/retry state, SHALL preserve the requested canonical route and query, and SHALL not redirect the user to first-run setup

#### Scenario: Alias matrix preserves deep links
- **GIVEN** a user opens `/rechnungen/123?status=offen&seite=2`, `/belege/456?filter=unbezahlt`, or any alias in the documented matrix
- **WHEN** the router canonicalizes the path
- **THEN** the result SHALL be `/invoices/123?status=offen&seite=2`, `/receipts/456?filter=unbezahlt`, or the exact canonical equivalent with every parameter unchanged

#### Scenario: Route matrix exposes a truthful boundary
- **GIVEN** a canonical route has no registered typed service
- **WHEN** the route loads
- **THEN** it SHALL render a localized unavailable/read-only state with a safe action and SHALL not invoke a generic `SELECT *` fallback

### Requirement: Typed domain data and actions

Primary pages SHALL consume typed use cases and repositories. They SHALL show domain fields and valid actions instead of raw SQL columns, table names, or arbitrary value dumps.

#### Scenario: Invoice detail exposes lifecycle actions
- **GIVEN** a persisted invoice is opened
- **WHEN** its detail page loads
- **THEN** it SHALL show typed positions, status, totals, and available edit/finalize/payment/copy/artifact actions

#### Scenario: Invalid record is safely reported
- **GIVEN** a route receives a missing or invalid record ID
- **WHEN** the detail page loads
- **THEN** it SHALL show a typed not-found state with a return action and SHALL not expose SQL or stack traces

### Requirement: Scalable domain lists

Lists SHALL use explicit projections, search, sorting, pagination, and a has-more/total indicator. Empty states SHALL offer the domain’s create/import action.

#### Scenario: Contact search paginates
- **GIVEN** more contacts exist than fit on one page
- **WHEN** the user searches and advances pagination
- **THEN** matching typed rows SHALL appear, the search SHALL persist, and the page/remaining count SHALL be visible

#### Scenario: List query failure is retryable
- **GIVEN** a paginated query fails
- **WHEN** the list renders its error state
- **THEN** it SHALL preserve query controls and retry the same page without showing partial fabricated rows

### Requirement: Income-tax schedule selection is a typed Taxes route state

The existing `/taxes` route SHALL expose `view=income-tax-schedules` with `schedule=s|g` as a typed route state and SHALL preserve unrelated tax query parameters. It SHALL use `IncomeTaxScheduleAvailabilityUseCase` through the application scope. In this change it SHALL render only an availability/selection state; it SHALL NOT expose a form period or numeric report until an accepted S/G form/source contract exists. Missing or invalid query state or an unavailable service SHALL render a localized typed state, not a generic table or raw SQL projection.

#### Scenario: Open an S/G availability state

- **GIVEN** the Taxes workspace is open
- **WHEN** the user selects `view=income-tax-schedules` and Anlage S or G
- **THEN** the route SHALL render the matching typed availability state and preserve unrelated query parameters.

#### Scenario: S/G availability service is unavailable

- **GIVEN** no `IncomeTaxScheduleAvailabilityUseCase` is registered
- **WHEN** the S/G route state is requested
- **THEN** the Taxes page SHALL show a localized unavailable state
- **AND** SHALL NOT fall back to an untyped database table or guessed report result.

### Requirement: Quick-booking Banking view state

The application SHALL retain `/banking` as the canonical Banking route and SHALL expose `view=quick-bookings` as a typed sibling page state alongside imports, history, cashbook, and daily close. Quick-booking view state SHALL preserve all unrelated Banking query parameters when switching between sibling views. The route SHALL use the registered quick-booking service and its empty, error, unavailable, and action boundaries.

#### Scenario: Quick-booking view uses typed route state

- **GIVEN** an active profile is available
- **WHEN** the user opens `/banking?view=quick-bookings`
- **THEN** the Banking host SHALL render the typed preset workspace
- **AND** show its documented primary action or truthful unavailable boundary.

#### Scenario: Database outage is not an empty quick-booking view

- **GIVEN** the active database cannot be opened
- **WHEN** the Banking quick-booking state is requested
- **THEN** the requested Banking view and query SHALL be preserved with a localized unavailable/retry state
- **AND** the workspace SHALL not redirect to setup or show an empty preset list.

### Requirement: Business-document search and combined filters

The invoice, receipt, and banking list workspaces SHALL use these persisted typed fields for search and filtering:

- Invoices: partial text search on `rechnungsnummer`, linked customer/supplier name or company, and date text; inclusive date range on `datum`; exact filter on the persisted `status`; and inclusive amount range on persisted gross `brutto_betrag`.
- Receipts: partial text search on `belegnummer`, `beschreibung`, and linked supplier name or company; inclusive date range on `datum`; exact filter on persisted `status`; and inclusive amount range on persisted `betrag`.
- Bank transactions: partial text search on `gegenkonto_name`, `gegenkonto`, and `verwendungszweck`; inclusive date range on `datum`; exact filter on the persisted transaction `status`; and inclusive amount range on persisted `betrag`.

Search SHALL not calculate or reinterpret persisted amounts/statuses. Multiple search/filter criteria SHALL be combined with AND semantics, visible as removable chips, and reflected in the matching count. Queries SHALL be bounded and use explicit typed projections; changing criteria SHALL reset pagination while pagination and detail navigation retain the selected criteria.

#### Scenario: Combine invoice criteria
- **GIVEN** persisted invoices have distinct document numbers, linked parties, dates, statuses, and gross amounts
- **WHEN** the user combines a partial party query, inclusive date range, exact persisted status, and gross-amount range
- **THEN** the result SHALL contain only invoices matching all criteria
- **AND** the active criteria and matching count SHALL be visible

#### Scenario: Combine receipt and banking criteria
- **GIVEN** receipts and bank transactions have persisted descriptions/parties, dates, statuses, and amounts
- **WHEN** the user combines text, date, status, and amount criteria on either list
- **THEN** only typed rows matching all selected criteria SHALL appear, using the fields named above
- **AND** a bank transaction result selected from global search SHALL open as `/banking?transactionId=<id>` with its typed details selected

#### Scenario: Invalid filter or query failure
- **GIVEN** an amount/date input is invalid or a list query fails
- **WHEN** the user applies the criteria
- **THEN** invalid input SHALL show a localized field error, or the failed query SHALL show a retryable error
- **AND** valid criteria SHALL remain available and no fabricated or partial rows SHALL be shown

#### Scenario: Clear one or all filters
- **GIVEN** the list has multiple active search criteria
- **WHEN** the user removes one chip or selects reset
- **THEN** only that criterion or all criteria respectively SHALL be cleared
- **AND** the updated typed result count SHALL be shown

### Requirement: Banking selection is addressable through the canonical route

The existing `/banking` route SHALL accept an optional positive integer `transactionId` query parameter. When present, the banking workspace SHALL load the typed transaction and show it as the selected record in the workspace inspector. The selection SHALL coexist with other supported banking query parameters and SHALL not change the transaction or create a posting. A missing, malformed, or unavailable transaction ID SHALL produce a localized typed not-found/unavailable state without exposing raw SQL or changing the route's other query state.

#### Scenario: Open a selected bank transaction
- **GIVEN** transaction 42 exists in the active profile
- **WHEN** the user opens `/banking?transactionId=42`
- **THEN** the banking workspace SHALL select transaction 42 and show its typed details
- **AND** the URL SHALL retain `transactionId=42` while the selection is open

#### Scenario: Invalid or missing transaction selection
- **GIVEN** `/banking` receives a non-positive, malformed, or nonexistent `transactionId`
- **WHEN** the route resolves the selection
- **THEN** it SHALL show a localized typed not-found state
- **AND** it SHALL preserve unrelated banking query parameters and SHALL NOT expose raw database rows

### Requirement: Master-data route actions are typed and reachable

The customer, supplier, article, company, category, account, tax-rate, and number-range routes SHALL be registered in the production router and resolve to their owning typed use cases and repositories. List and detail routes SHALL expose the domain actions defined by the `stammdaten` capability. Customer/supplier permanent deletion is not a workspace action; archive and restore are the workspace lifecycle actions. Settings subroutes SHALL be directly addressable and reachable from `/settings`; workspace create, edit, archive, and restore controls SHALL preserve the current route and query context on success or failure.

#### Scenario: Settings link opens a typed master-data surface
- **GIVEN** the user is on `/settings`
- **WHEN** the user opens the Number Ranges entry
- **THEN** the router resolves `/settings/number-ranges` to the number-range workspace and shows its typed records and actions

#### Scenario: Invalid master-data record is safely reported
- **GIVEN** a user opens `/contacts/missing?kind=customer` or `/articles/missing?kind=item`
- **WHEN** the typed detail lookup returns no record
- **THEN** the route shows a localized not-found state with a return action and does not expose SQL or a stack trace
