## ADDED Requirements

### Requirement: Business-year report availability is explicit

Annual EÜR is the only accounting report consumer in scope. It SHALL use the exact half-open range from the shared fiscal-calendar service only after its accepted calculation supports that range. Until then, EÜR for a non-January fiscal year SHALL be unavailable and SHALL NOT be relabeled as a business-year result. Dashboard period summaries and all other reports SHALL keep business-fiscal filters unavailable until their source and calculation contracts are accepted and integrated with the service. Explicit calendar-month, calendar-quarter, and custom-date filters SHALL retain distinct period semantics. This requirement SHALL NOT shift or recalculate statutory tax filing periods.

#### Scenario: Dashboard business-fiscal filter remains unavailable

- **GIVEN** dashboard period metrics do not yet have an accepted source and calculation contract integrated with the fiscal-calendar service
- **WHEN** the company has a non-January start month
- **THEN** the dashboard SHALL NOT offer a business-fiscal period filter or label a calendar-based result as a fiscal period

#### Scenario: EÜR does not relabel a calendar year

- **GIVEN** the company uses a non-January fiscal-year start and EÜR calculation remains calendar-year-only
- **WHEN** the user selects a configured fiscal year
- **THEN** the report SHALL be unavailable for that selection
- **AND** SHALL NOT show a calendar-year result with the fiscal-year label
