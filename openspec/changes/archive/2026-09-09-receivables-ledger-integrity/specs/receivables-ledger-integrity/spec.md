## ADDED Requirements

### Requirement: Statements account for every payment exactly once

A receivable statement MUST derive closing balance from the signed invoice/correction and all dated payments in scope, with opening balance and period activity partitioned without double-counting.

Implementation evidence: The current query includes the current remaining Forderung and only the latest ausgleich_journal_id payment.

#### Scenario: Partial payment leaves the remainder

- Given a 100 euro receivable has a 50 euro payment before period end
- When the statement is generated
- Then the statement shows one 100 euro invoice, one 50 euro payment, and a 50 euro closing balance

#### Scenario: Full and overpayment are represented

- Given a receivable is fully paid or paid above its face value
- When the statement is generated
- Then all payments are listed once and the resulting zero or credit balance is mathematically consistent

#### Scenario: Opening balance includes prior activity

- Given invoice and payment events occur before the requested opening date
- When the statement starts at that date
- Then both prior debits and credits are reflected in opening balance and are not repeated in in-period activity

### Requirement: Receivables schema is ready after normal startup

A freshly opened or migrated production database MUST contain every table and column required by ForderungenRepository before any receivable query or invoice finalization can run.

Implementation evidence: Production ensureOpen does not invoke the Forderungen schema bootstrap, while the test fixture does so explicitly.

#### Scenario: Fresh startup supports receivables

- Given a new profile database is opened only through AppDatabase.ensureOpen
- When a receivable is created and queried
- Then no missing-table/column error occurs and no test-only schema call is needed

#### Scenario: Legacy startup migrates safely

- Given an older profile lacks the receivable fields
- When the profile is opened
- Then the migration adds compatible fields before use and preserves existing receivable rows
