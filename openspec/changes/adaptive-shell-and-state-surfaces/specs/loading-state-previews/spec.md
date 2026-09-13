## ADDED Requirements

### Requirement: Content-shaped loading previews

Async pages SHALL keep their final structure while loading and show content-shaped skeletons for titles, controls, rows, and metrics. Loading transitions SHALL not replace the page with an unbounded spinner or cause layout shift; skeleton dimensions SHALL match the settled controls within 4 logical pixels.

#### Scenario: Dashboard card shows skeleton content
- **GIVEN** a visible dashboard card is fetching data
- **WHEN** the request is pending
- **THEN** the card SHALL retain its title and dimensions and show skeleton shapes for the metric and supporting content

#### Scenario: Skeleton resolves to an error state
- **GIVEN** a card request fails after its skeleton is shown
- **WHEN** the failure state renders
- **THEN** the skeleton SHALL be removed and a localized retryable error SHALL be shown

#### Scenario: Routed page keeps title and controls while loading
- **GIVEN** `/contacts` is waiting for its typed list request
- **WHEN** the request is pending
- **THEN** the page heading, search control, primary action slot, and at least three row placeholders SHALL remain at their settled positions without an unbounded spinner

### Requirement: State transition identity

Loading, populated, empty, and error views SHALL use stable keys and preserve focus and route identity when data settles. Empty and error views SHALL expose the next valid action. Failed optimistic mutations SHALL restore the last confirmed view model and retain the original command input for retry.

#### Scenario: Empty list offers a primary action
- **GIVEN** a route has no records
- **WHEN** its empty state renders
- **THEN** the page SHALL explain what is missing and expose the route’s create/import/configure action

#### Scenario: Failed request preserves context
- **GIVEN** a filtered route request fails
- **WHEN** the error state renders
- **THEN** the active route and filters SHALL remain and retry SHALL repeat the same request

#### Scenario: Failed mutation rolls back safely
- **GIVEN** a user submits a valid form and the persistence command fails after an optimistic preview
- **WHEN** the error state renders
- **THEN** the preview SHALL be removed or restored to its last confirmed value, no duplicate optimistic record SHALL remain, and Retry SHALL resubmit the same input
