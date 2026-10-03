## ADDED Requirements

### Requirement: Business-year report consumers use fiscal boundaries

Any accounting report that offers company business-year, business-month, or business-quarter periods SHALL obtain the exact half-open calendar-date range from the shared fiscal-calendar service and identify the selected period in its result. Explicit calendar-month, calendar-quarter, and custom-date filters SHALL retain distinct period semantics. EÜR SHALL use the configured fiscal-year range when its accepted calculation supports it; while its source or calculation only supports calendar-year filtering, EÜR for a non-January fiscal year SHALL be unavailable and SHALL NOT be relabeled as a business-year result. This requirement SHALL NOT shift or recalculate statutory tax filing periods.

#### Scenario: Report consumer displays its fiscal boundary

- **GIVEN** a report supports business-fiscal periods and the company has a valid fiscal calendar
- **WHEN** the user selects a fiscal month, quarter, or year
- **THEN** the report SHALL request and display the exact selected range from the shared fiscal-calendar service
- **AND** SHALL distinguish it from calendar-period filters

#### Scenario: EÜR does not relabel a calendar year

- **GIVEN** the company uses a non-January fiscal-year start and EÜR calculation remains calendar-year-only
- **WHEN** the user selects a configured fiscal year
- **THEN** the report SHALL be unavailable for that selection
- **AND** SHALL NOT show a calendar-year result with the fiscal-year label
