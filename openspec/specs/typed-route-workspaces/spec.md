# typed-route-workspaces Specification

## Purpose
TBD - created by archiving change routed-domain-capability-surface. Update Purpose after archive.

## Requirements

### Requirement: Canonical route inventory

The application SHALL expose typed pages for exactly these canonical routes: `/`, `/invoices`, `/invoices/new`, `/invoices/:id`, `/receipts`, `/banking`, `/contacts`, `/taxes`, `/reports`, `/settings`, `/help`, `/setup`, and `/inventory`. Each route SHALL implement the service owner, typed projection/actions, and empty/unavailable boundary in the route matrix. Each route SHALL define loading, populated, empty, and failure states plus a primary action or explicit read-only/unavailable boundary. German aliases SHALL preserve IDs and the complete query string when redirecting.

#### Scenario: Every canonical route has a useful surface
- **GIVEN** an active profile is available
- **WHEN** the user visits every route in the inventory
- **THEN** each page SHALL show its typed title, route-specific state, and documented primary action or truthful boundary

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
