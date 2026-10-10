## MODIFIED Requirements

### Requirement: GuV (Gewinn- und Verlustrechnung)

The system SHALL compute GuV per the maintained accounting requirement when annual turnover exceeds €800,000 or annual profit exceeds €80,000. The `guv` catalog entry SHALL own the user's durable GuV preference. When either threshold is exceeded, the accounting module SHALL display the GuV warning and ask the catalog state writer to persist `guv=true`; no independent `guv_aktiv` runtime flag SHALL be read or written. GuV SHALL be generated when the catalog resolves `guv` as effectively enabled and the GuV calculator provider is available.

#### Scenario: Threshold exceeded

- **GIVEN** annual turnover exceeds €800,000 or annual profit exceeds €80,000
- **WHEN** the Dashboard is loaded and evaluates the accounting threshold
- **THEN** the system displays a GuV warning and persists `guv=true` through the module catalog state writer

#### Scenario: GuV computation

- **GIVEN** the catalog resolves `guv` as effectively enabled and its calculator provider is available
- **WHEN** the GuV is generated
- **THEN** the system computes it from journal entries grouped by SKR03/SKR04 account ranges (income 1–4, expenses 5–8)

#### Scenario: Threshold not exceeded

- **GIVEN** annual turnover is below €800,000 and annual profit is below €80,000
- **AND** the catalog preference for `guv` is disabled
- **WHEN** the Dashboard is loaded
- **THEN** the GuV section is not displayed

#### Scenario: GuV preference is independent of a missing provider

- **GIVEN** the catalog preference for `guv` is enabled but the GuV calculator provider is unavailable
- **WHEN** the Dashboard resolves optional modules
- **THEN** `guv` is effectively disabled with an unavailable reason
- **AND** no GuV computation is attempted
