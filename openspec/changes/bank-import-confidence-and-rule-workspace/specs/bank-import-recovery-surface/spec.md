## MODIFIED Requirements

### Requirement: Import history is actionable

Import history SHALL show typed rows with status, counts, timestamp, and available detail, retry, filter, and pagination
actions. Retry SHALL be available only for `partial` or `failed` imports and SHALL resume only the persisted failed
rows under the original `bank_imports.id`; successfully imported rows and their transaction identifiers SHALL remain
unchanged. Manual review SHALL be available when the stored manual-review count is greater than zero and SHALL open
only unresolved transactions for that import. Completed imports SHALL be read-only. Empty history SHALL explain how to
start an import. Detail and retry views SHALL preserve the current query and page when the user returns to history.
The manual-review view SHALL display imported transaction fields and any available score suggestion; a user may
correct classification or explicitly associate a selected existing journal entry. It SHALL NOT create journal entries
or apply payments.

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

#### Scenario: Failed-row retry preserves the original import identity
- **GIVEN** a partial import has persisted failed-row payloads and successful transaction rows
- **WHEN** the user corrects and retries the failed rows
- **THEN** only failed rows are submitted under the original `bank_imports.id`, successful transaction IDs remain unchanged, and the original history row reports the updated result

#### Scenario: Manual review is scoped to the selected import
- **GIVEN** two imports contain unresolved transactions
- **WHEN** the user selects Review from one history row
- **THEN** the review view shows only unresolved transactions whose `import_id` matches the selected row

#### Scenario: Manual review does not create a posting
- **GIVEN** an unresolved imported transaction is open in its manual-review view
- **WHEN** the user corrects its category or associates an existing journal entry
- **THEN** only the selected bank transaction's classification or existing journal link is updated; no journal entry or payment is created

#### Scenario: History search and pagination retain the selected query
- **GIVEN** history has multiple pages and a search query is active
- **WHEN** the user opens an import detail and returns to history
- **THEN** the same query, page, and selected import context are restored
