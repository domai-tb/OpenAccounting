## ADDED Requirements

### Requirement: pdf-template-polish capability

The system SHALL implement pdf-template-polish per deferred specs.

#### Scenario: Happy path

- **GIVEN** precondition for pdf-template-polish
- **WHEN** user triggers pdf-template-polish
- **THEN** system SHALL produce expected pdf-template-polish outcome

#### Scenario: Failure path

- **GIVEN** invalid input for pdf-template-polish
- **WHEN** user triggers pdf-template-polish with error
- **THEN** system SHALL show validation error and not corrupt data
