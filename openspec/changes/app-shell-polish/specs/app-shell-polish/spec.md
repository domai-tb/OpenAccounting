## ADDED Requirements

### Requirement: app-shell-polish capability

The system SHALL implement app-shell-polish per deferred specs.

#### Scenario: Happy path

- **GIVEN** precondition for app-shell-polish
- **WHEN** user triggers app-shell-polish
- **THEN** system SHALL produce expected app-shell-polish outcome

#### Scenario: Failure path

- **GIVEN** invalid input for app-shell-polish
- **WHEN** user triggers app-shell-polish with error
- **THEN** system SHALL show validation error and not corrupt data
