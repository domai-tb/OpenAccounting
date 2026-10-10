## ADDED Requirements

### Requirement: Company fiscal-year settings

The company settings use case SHALL expose the persisted fiscal-year start month as typed company profile data and accept updates only for integer months 1 through 12. Settings SHALL default missing legacy values to the migration-provided January value, require explicit user confirmation before a change, and report persistence errors without presenting an unsaved value as active. UI code SHALL use the injected company settings boundary rather than issuing database queries.

#### Scenario: Company settings display saved fiscal year

- **GIVEN** a company profile has a valid saved start month
- **WHEN** the user opens company settings
- **THEN** the control SHALL show that month as the active business-year start

#### Scenario: Company settings reject an invalid update

- **GIVEN** a save request contains a month outside 1 through 12
- **WHEN** the company settings use case validates the request
- **THEN** it SHALL reject the request without modifying the company row
- **AND** Settings SHALL show a localized validation error
