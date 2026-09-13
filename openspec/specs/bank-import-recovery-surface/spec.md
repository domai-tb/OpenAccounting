# bank-import-recovery-surface Specification

## Purpose
TBD - created by archiving change routed-domain-capability-surface. Update Purpose after archive.

## Requirements

### Requirement: Bank import retry and outcome fidelity

Bank import SHALL preserve the service result, including manual-review counts and partial status, through the outcome UI. Initial-data failures SHALL provide a retry that reloads the failed data while preserving user input.

#### Scenario: Manual review count is shown
- **GIVEN** the import service returns a manual-review count
- **WHEN** the import result renders
- **THEN** the outcome SHALL show that exact count and a route to review affected transactions

#### Scenario: Initial data retry reloads
- **GIVEN** accounts or templates fail to load before file selection
- **WHEN** the user selects Retry
- **THEN** the page SHALL call its initial-data loader again, preserve selected input where valid, and show the resulting state

### Requirement: Import history is actionable

Import history SHALL show typed rows with status, counts, timestamp, and available detail/retry/filter/pagination actions. Retry SHALL be available only for `partial` or `failed` imports, manual review SHALL be available when the stored manual-review count is greater than zero, and completed imports SHALL be read-only. Empty history SHALL explain how to start an import.

#### Scenario: History row opens details
- **GIVEN** a completed or partial import exists
- **WHEN** the user activates its row
- **THEN** the page SHALL show the import summary, failures, manual-review items, and retry/review actions allowed by status

#### Scenario: Empty history offers import
- **GIVEN** no imports exist
- **WHEN** history renders
- **THEN** it SHALL show an explanatory empty state and a primary action to select a file

#### Scenario: Status policy controls actions
- **GIVEN** history contains completed, partial, failed, and manual-review imports
- **WHEN** a row renders
- **THEN** completed rows SHALL not offer retry, partial/failed rows SHALL offer retry with the original import identity, and rows with manual-review items SHALL offer review while preserving pagination/query state
