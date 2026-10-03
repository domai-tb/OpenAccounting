## ADDED Requirements

### Requirement: Business-document search and combined filters

Invoice, receipt, and banking list workspaces SHALL search only fields supported by their typed domain projections. Where present, users SHALL be able to search by document or transaction number and customer or supplier, and filter by date range, status, and amount range. Applicable filters SHALL be combinable, visible as removable chips, and reflected in the result count. Queries SHALL be bounded and use explicit typed projections; changing search or filters SHALL reset the result page while preserving the selected criteria during pagination and detail navigation.

#### Scenario: Combine document filters
- **GIVEN** documents include different parties, dates, statuses, and amounts
- **WHEN** the user combines a party query, date range, status, and amount range
- **THEN** the list SHALL contain only records satisfying all selected criteria
- **AND** the active criteria and matching result count SHALL be visible

#### Scenario: Search a supported party or identifier
- **GIVEN** an invoice or receipt has a supported document number or party field
- **WHEN** the user enters a partial identifier or party name
- **THEN** matching typed rows SHALL appear without requiring an exact full-string match

#### Scenario: Invalid filter or query failure
- **GIVEN** an amount/date filter is invalid or a list query fails
- **WHEN** the user applies the criteria
- **THEN** invalid criteria SHALL show a localized field error, or a failed query SHALL show a retryable error
- **AND** existing valid criteria SHALL remain available and no fabricated or partial rows SHALL be shown

#### Scenario: Clear one or all filters
- **GIVEN** the list has multiple active search criteria
- **WHEN** the user removes one chip or selects reset
- **THEN** only that criterion or all criteria respectively SHALL be cleared
- **AND** the updated typed result count SHALL be shown
