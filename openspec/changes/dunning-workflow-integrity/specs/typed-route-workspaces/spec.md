## MODIFIED Requirements

### Requirement: Canonical route inventory

The application SHALL expose typed pages for exactly these canonical routes: `/`, `/invoices`, `/invoices/new`, `/invoices/:id`, `/receipts`, `/banking`, `/contacts`, `/mahnwesen`, `/taxes`, `/reports`, `/settings`, `/help`, `/setup`, and `/inventory`. Each route SHALL implement the service owner, typed projection/actions, and empty/unavailable boundary in the route matrix. Each route SHALL define loading, populated, empty, and failure states plus a primary action or explicit read-only/unavailable boundary. German aliases SHALL preserve IDs and the complete query string when redirecting.

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

#### Scenario: Dunning route exposes its typed workspace
- **GIVEN** an active profile is available
- **WHEN** the user opens `/mahnwesen`
- **THEN** the route SHALL render the typed dunning workspace and SHALL preserve its search, status, and stage query parameters

#### Scenario: Dunning route database outage remains actionable
- **GIVEN** the active profile database cannot be opened
- **WHEN** the user opens `/mahnwesen?status=offen`
- **THEN** the route SHALL show a localized retryable unavailable state and preserve the requested path and query
