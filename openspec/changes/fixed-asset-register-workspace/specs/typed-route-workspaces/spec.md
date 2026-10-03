## MODIFIED Requirements

### Requirement: Canonical route inventory

The application SHALL expose typed pages for exactly these canonical routes: `/`, `/invoices`, `/invoices/new`, `/invoices/:id`, `/receipts`, `/banking`, `/contacts`, `/mahnwesen`, `/taxes`, `/reports`, `/assets`, `/settings`, `/help`, `/setup`, `/inventory`, and `/recurring`. Each route SHALL implement the service owner, typed projection/actions, and empty/unavailable boundary in the route matrix. Each route SHALL define loading, populated, empty, and failure states plus a primary action or explicit read-only/unavailable boundary. German aliases SHALL preserve IDs and the complete query string when redirecting; `/anlagen` SHALL redirect to `/assets`.

#### Scenario: Every canonical route has a useful surface

- **GIVEN** an active profile is available
- **WHEN** the user visits every route in the inventory, including `/assets`
- **THEN** each page SHALL show its typed title, route-specific state, and documented primary action or truthful boundary

#### Scenario: Database outage is not an empty route

- **GIVEN** the active database cannot be opened
- **WHEN** any canonical route, including `/assets`, is requested
- **THEN** the page SHALL show a localized unavailable/retry state, SHALL preserve the requested canonical route and query, and SHALL not redirect the user to first-run setup

#### Scenario: Alias matrix preserves deep links

- **GIVEN** a user opens `/rechnungen/123?status=offen&seite=2`, `/belege/456?filter=unbezahlt`, or `/anlagen?jahr=2025&status=aktiv`
- **WHEN** the router canonicalizes the path
- **THEN** it SHALL preserve every query parameter and redirect to `/invoices/123?status=offen&seite=2`, `/receipts/456?filter=unbezahlt`, or `/assets?jahr=2025&status=aktiv` respectively

#### Scenario: Route matrix exposes a truthful boundary

- **GIVEN** a canonical route has no registered typed service
- **WHEN** the route loads
- **THEN** it SHALL render a localized unavailable/read-only state with a safe action and SHALL not invoke a generic `SELECT *` fallback
