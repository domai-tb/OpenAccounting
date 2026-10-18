## ADDED Requirements

### Requirement: Cash posting and receipt reference commit atomically

When a user confirms a cashbook income or expense and selects an existing receipt, the accepted balanced `cash_payment` posting group and the receipt-to-posting reference SHALL be written in the same SQLite transaction against the active profile database. Success SHALL be returned only after both the balanced journal group and the receipt reference commit. If posting, receipt lookup, or reference persistence fails, the transaction SHALL roll back every journal line, posting-group root, receipt relationship, and resulting cash-balance change; the operation SHALL return a retryable failure with no committed cash event. The existing receipt row and original source artifact SHALL remain unchanged. This transaction boundary covers the database relationship only; it SHALL NOT claim a filesystem/database atomic transaction for receipt intake.

#### Scenario: Failed receipt reference rolls back the balanced cash posting

- **GIVEN** the user confirms a balanced cash event with a selected existing receipt
- **WHEN** the receipt-to-posting reference fails to persist after journal lines are prepared
- **THEN** the cash posting group, every journal line, receipt reference, and balance effect SHALL roll back together
- **AND** the receipt inbox row and original source bytes SHALL remain unchanged with no success result.
