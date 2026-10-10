## ADDED Requirements

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
