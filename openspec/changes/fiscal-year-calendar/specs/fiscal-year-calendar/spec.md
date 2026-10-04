## ADDED Requirements

### Requirement: Company fiscal-year configuration

The application SHALL store one company-level fiscal-year start month in the active profile. The value SHALL be an integer from 1 through 12, SHALL default to January for new and migrated company records, and SHALL be changed only through the typed company-settings action. Settings SHALL label this value as the business-year start month and explain that changing it changes the date boundaries of historical and future business-year reports. The operation SHALL NOT modify journal entries, invoices, or previously exported report snapshots. A consumer that cannot read a valid company setting SHALL report the period as unavailable and SHALL NOT silently substitute a different configured value.

#### Scenario: Existing profile retains calendar year default

- **GIVEN** an existing company record has no fiscal-year start month
- **WHEN** the fiscal-calendar migration and service are used
- **THEN** the company SHALL use January as its start month
- **AND** calendar-year boundaries SHALL remain unchanged

#### Scenario: User configures an alternate start month

- **GIVEN** a valid company profile is open in Settings
- **WHEN** the user selects and confirms a start month from 1 through 12
- **THEN** the setting SHALL be saved through the company use case
- **AND** Settings SHALL explain that all selected historical business-year boundaries use the new month
- **AND** no accounting source record or previously exported period snapshot SHALL be rewritten

#### Scenario: Invalid configuration is rejected

- **GIVEN** a stored or requested start month is outside 1 through 12
- **WHEN** a report requests a business-year boundary
- **THEN** the fiscal-calendar service SHALL return a typed unavailable/error result
- **AND** the report SHALL NOT substitute January or display a fabricated period

#### Scenario: Save failure retains the persisted setting

- **GIVEN** the company has a persisted fiscal-year start month
- **WHEN** saving a different valid start month fails
- **THEN** the persisted month SHALL remain active for all period calculations
- **AND** Settings SHALL show a localized retryable error and SHALL NOT report the unsaved month as saved

### Requirement: Shared fiscal-year boundaries

The injected fiscal-calendar service SHALL resolve a requested business date, fiscal-month index, fiscal-quarter index, or fiscal-year label to an immutable label and inclusive-start/exclusive-end calendar-date range using the configured company start month. Fiscal month 1 SHALL begin at that configured month, the next 11 fiscal months SHALL be consecutive calendar months, and each of the four fiscal quarters SHALL contain three consecutive fiscal months. Fiscal month and quarter labels SHALL identify their position and containing fiscal-year label. A fiscal-year label SHALL be the calendar year in which that fiscal year starts. Report consumers that offer a company business-period filter SHALL obtain its range from this service and expose that selected range. Explicit user-selected calendar date ranges SHALL remain unchanged. A service result SHALL represent calendar dates without a time zone and SHALL use a half-open interval `[startDate, endDateExclusive)`.

#### Scenario: Date belongs to a fiscal year starting in January

- **GIVEN** the company start month is January
- **WHEN** the service resolves a date in any month
- **THEN** it SHALL return January 1 of that calendar year as the inclusive start
- **AND** January 1 of the next calendar year as the exclusive end

#### Scenario: Date before the configured start month

- **GIVEN** the company start month is April
- **WHEN** the service resolves 2026-02-15
- **THEN** it SHALL return label 2025, inclusive start 2025-04-01, and exclusive end 2026-04-01

#### Scenario: Date on the configured start month boundary

- **GIVEN** the company start month is April
- **WHEN** the service resolves 2026-04-01
- **THEN** it SHALL return label 2026, inclusive start 2026-04-01, and exclusive end 2027-04-01

#### Scenario: Fiscal month and quarter follow the configured start

- **GIVEN** the company start month is April and the fiscal-year label is 2026
- **WHEN** the service resolves fiscal month 1 and fiscal quarter 1
- **THEN** fiscal month 1 SHALL cover `[2026-04-01, 2026-05-01)`
- **AND** fiscal quarter 1 SHALL cover `[2026-04-01, 2026-07-01)`
- **AND** the month and quarter SHALL identify fiscal year 2026

#### Scenario: Invalid fiscal month or quarter index is rejected

- **GIVEN** the company has a valid fiscal-year start month
- **WHEN** the service receives a fiscal-month index outside 1 through 12 or a fiscal-quarter index outside 1 through 4
- **THEN** it SHALL return a typed invalid-period result
- **AND** it SHALL NOT substitute a calendar month or quarter

#### Scenario: Tax filing period remains separately owned

- **GIVEN** a tax-report capability requests a statutory filing period
- **WHEN** its period is resolved
- **THEN** it SHALL use that capability's accepted filing-period configuration
- **AND** it SHALL NOT shift the filing period solely because the business-year start month differs from January

#### Scenario: Calendar-only EÜR is unavailable for an alternate fiscal year

- **GIVEN** the company start month is not January and the EÜR consumer still only supports calendar-year calculations
- **WHEN** the user requests EÜR for a configured fiscal-year label
- **THEN** EÜR SHALL report that period as unavailable
- **AND** SHALL NOT return a calendar-year result under the configured fiscal-year label

#### Scenario: EÜR consumes the configured fiscal boundary

- **GIVEN** the company start month is not January and an accepted EÜR calculation supports an explicit half-open date range
- **WHEN** the user requests EÜR for a configured fiscal-year label
- **THEN** the consumer SHALL pass the exact range returned by the fiscal-calendar service
- **AND** SHALL display the range and its fiscal-year label

### Requirement: Fiscal-year configuration follows the design system

Settings SHALL provide a localized, keyboard-accessible company business-year control with visible focus, a semantic label, an explicit Save action, and a confirmation of the historical reporting effect. The control SHALL follow the standard Settings form and responsive layout in `DESIGN.md`, use active-locale date formatting, and provide loading, unavailable, validation, save-success, and retryable failure states. English and German strings SHALL be available.

#### Scenario: User saves a setting with keyboard controls

- **GIVEN** the company fiscal-year control is focused
- **WHEN** the user selects a valid month and activates Save by keyboard
- **THEN** the same typed save and confirmation flow SHALL run as for pointer input
- **AND** the resulting state SHALL be announced with a localized semantic status
