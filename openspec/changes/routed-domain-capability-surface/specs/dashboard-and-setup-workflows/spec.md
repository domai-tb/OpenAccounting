## ADDED Requirements

### Requirement: Dashboard cards lead to real capabilities

Every clickable dashboard card SHALL navigate to a reachable route whose content matches the card’s metric. Cards for unavailable capabilities SHALL be hidden or show an explicit unavailable state without fetching inaccessible data.

#### Scenario: Open invoices card opens receivables
- **GIVEN** the Open Invoices card has data
- **WHEN** the user activates it
- **THEN** the app SHALL open the invoice receivables view with the matching status filter

#### Scenario: Unavailable inventory card is truthful
- **GIVEN** inventory is not wired for the current target
- **WHEN** the dashboard loads
- **THEN** inventory cards SHALL not construct or invoke an inventory query, SHALL show an unavailable explanation, and SHALL provide a safe return action

#### Scenario: Dashboard configuration failure is recoverable
- **GIVEN** persisted dashboard widget configuration cannot be loaded or saved
- **WHEN** the dashboard resolves its configuration
- **THEN** it SHALL show a localized retryable configuration error, SHALL not silently replace user choices, and SHALL retry the same operation

### Requirement: Setup exposes persisted configuration

Setup SHALL show real company, account, tax/category, and profile data from typed services. Finish, skip, and retry controls SHALL lock during writes and surface unexpected failures without duplicate records.

#### Scenario: Setup summary shows real names
- **GIVEN** seeded categories and a configured account exist
- **WHEN** the summary step renders
- **THEN** it SHALL display their names and values rather than generated labels or database IDs

#### Scenario: Setup write failure is recoverable
- **GIVEN** setup persistence fails during finish
- **WHEN** the failure is returned
- **THEN** controls SHALL unlock, company/account/category/profile/completion writes SHALL roll back atomically, no duplicate account SHALL be created, and the user SHALL receive a retryable error

#### Scenario: Successful profile switch rebinds services
- **GIVEN** setup finishes for a selected profile
- **WHEN** the transaction commits
- **THEN** the typed service registry SHALL rebind to that profile before navigating, and the summary SHALL show persisted values after reload
