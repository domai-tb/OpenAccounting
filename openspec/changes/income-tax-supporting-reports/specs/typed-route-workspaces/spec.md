## ADDED Requirements

### Requirement: Income-tax supporting report view

The existing `/taxes` route SHALL expose `view=income-tax-schedules` as a typed report view with explicit Anlage S or Anlage G selection and a supported period. It SHALL preserve unrelated tax route query state and SHALL use the registered report service through the application scope. Missing or unaccepted service/form mapping SHALL render a localized unavailable state, not a generic table or raw SQL projection.

#### Scenario: Open an S/G supporting report

- **GIVEN** the Taxes workspace is open
- **WHEN** the user selects `view=income-tax-schedules` and Anlage S or G
- **THEN** the route SHALL render the typed report state and its accepted period/source boundary.

#### Scenario: Report service is unavailable

- **GIVEN** no accepted S/G report service is registered
- **WHEN** the S/G route state is requested
- **THEN** the Taxes page SHALL show a localized unavailable state
- **AND** SHALL NOT fall back to an untyped database table.
