## ADDED Requirements

### Requirement: accounting-tax-polish capability

The system SHALL implement accounting-tax-polish per deferred specs.

#### Scenario: Happy path

- **GIVEN** precondition for accounting-tax-polish
- **WHEN** user triggers accounting-tax-polish
- **THEN** system SHALL produce expected accounting-tax-polish outcome

#### Scenario: Failure path

- **GIVEN** invalid input for accounting-tax-polish
- **WHEN** user triggers accounting-tax-polish with error
- **THEN** system SHALL show validation error and not corrupt data
