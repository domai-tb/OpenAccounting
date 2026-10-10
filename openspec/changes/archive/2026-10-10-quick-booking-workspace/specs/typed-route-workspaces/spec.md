## ADDED Requirements

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
