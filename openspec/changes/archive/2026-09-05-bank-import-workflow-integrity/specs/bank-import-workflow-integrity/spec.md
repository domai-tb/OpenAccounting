## ADDED Requirements

### Requirement: Banking exposes a reviewable import lifecycle

The banking workspace MUST support file selection/template selection, parse preview, row review/edit/manual categorization, explicit confirmation, and an import history showing source, time, template, counts, and status.

Implementation evidence: The service has parser/import logic but no production route or workflow UI.

#### Scenario: User reviews before import

- Given a supported bank file is selected
- When parsing completes
- Then the user sees transaction rows and can confirm, edit, skip, or categorize them before persistence

#### Scenario: Unsupported input remains safe

- Given the file format is unknown or malformed
- When the user attempts import
- Then no transaction is persisted and the history/result identifies the unsupported input with a recovery action

### Requirement: Import outcomes are truthful and recoverable

Import persistence MUST either commit the confirmed batch atomically or record each failed row and a partial status; imported, duplicate, auto-categorized, manual-review, and failed counts MUST describe rows actually persisted.

Implementation evidence: The current implementation catches insert errors, increments categorization before insertion, and updates history without failed-row diagnostics.

#### Scenario: Successful batch counts persisted rows

- Given a confirmed batch contains new, duplicate, and categorized rows
- When import completes
- Then history counts match database rows and duplicates are not inserted twice

#### Scenario: A row failure is surfaced

- Given one confirmed row violates a constraint or cannot be inserted
- When the batch imports
- Then the failure is visible with row/error context, history is partial/failed according to policy, and the result does not claim the row was imported

#### Scenario: Retry does not duplicate rows

- Given a partial import is retried after correction
- When the user retries the failed rows
- Then already persisted rows remain deduplicated and only corrected failures are added
