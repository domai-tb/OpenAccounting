## ADDED Requirements

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

## MODIFIED Requirements

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
