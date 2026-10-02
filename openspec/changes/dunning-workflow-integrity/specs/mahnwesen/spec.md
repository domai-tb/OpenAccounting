## MODIFIED Requirements

### Requirement: Dunning Level Configuration

The system SHALL provide four protected standard levels and allow custom levels. Each level SHALL configure an escalation wait in days, a fixed currency fee (`gebuehr`), an annual percentage interest rate (`zinssatz`), and a multiplier flag. A multiplier SHALL add the immediately preceding level's configured fixed fee to the current level's fixed fee; it SHALL NOT turn a fee into a percentage. A created Mahnung SHALL snapshot its effective fee and rate so later edits affect only new letters. On a fresh profile, the standard defaults SHALL be: level 1 = 7 days, €5.00, 0%, multiplier off; level 2 = 21 days, €10.00, 5%, off; level 3 = 35 days, €15.00, 8%, off; level 4 = 49 days, €25.00, 8%, off. These configurable sample defaults are not a declaration that the rates are statutory. Existing user-edited values SHALL be preserved during initialization.

#### Scenario: Fresh profile seeds the documented fixed-fee model
- **GIVEN** a new profile has no dunning levels
- **WHEN** the standard levels are initialized
- **THEN** all four levels SHALL match the stated day, fixed-euro-fee, annual-percentage, and multiplier defaults

#### Scenario: Configure level with multiplier
- **GIVEN** level 2 has a fixed fee of €10.00 and level 3 has a fixed fee of €5.00 with multiplier enabled
- **WHEN** a new level 3 Mahnung is calculated
- **THEN** its level fee SHALL be €15.00 and SHALL NOT depend on a percentage of the invoice amount

#### Scenario: Configure level without multiplier
- **GIVEN** level 3 has a fixed fee of €5.00 with multiplier disabled
- **WHEN** a new level 3 Mahnung is calculated
- **THEN** its level fee SHALL be €5.00 and SHALL ignore the prior level's configured fee

#### Scenario: Editing a level does not rewrite prior letters
- **GIVEN** a Mahnung has snapshotted a level fee and rate
- **WHEN** the level configuration is changed
- **THEN** the stored Mahnung values SHALL remain unchanged and the new values SHALL apply only to later Mahnungen

#### Scenario: Initialization preserves customized levels
- **GIVEN** a standard level already exists with a user-edited fee or rate
- **WHEN** dunning initialization runs again
- **THEN** the customized values SHALL remain unchanged

### Requirement: Mahnung Snapshot

Each created Mahnung SHALL snapshot the invoice number, invoice due date, customer identity, applicable dunning level, current outstanding principal, effective fixed fee, configured annual percentage rate, interest period, and carried unpaid fees and interest. Snapshot values SHALL be immutable after creation. A Mahnung SHALL NOT be created from an invoice total when its receivable has no positive outstanding balance.

#### Scenario: Create dunning letter
- **GIVEN** a finalized invoice has a positive settled outstanding principal and has reached the configured stage date
- **WHEN** a Mahnung is created
- **THEN** the immutable snapshot SHALL contain that outstanding principal and the applicable level inputs

#### Scenario: Rechnung changes after snapshot
- **GIVEN** a Mahnung has been created with invoice and stage data
- **WHEN** the invoice or stage configuration changes
- **THEN** the existing Mahnung SHALL retain its original snapshot values

#### Scenario: No balance cannot produce a reminder
- **GIVEN** an invoice's settled outstanding principal is zero or negative
- **WHEN** a dunning run evaluates it
- **THEN** no new Mahnung SHALL be created for that invoice

### Requirement: Dunning Evaluation and Exclusions

The system SHALL evaluate only finalized outgoing invoices whose settled outstanding principal is positive and whose due date plus the configured grace period and next-stage waiting period has elapsed. Manual, assisted, and automatic modes SHALL use the same eligibility rules. Assisted mode SHALL show a reviewable preview and create letters only after confirmation. Automatic mode SHALL respect customer and invoice exclusions and SHALL not bypass an active Mahnsperre. A repeated run SHALL reuse or report an existing unsent Mahnung for the same receivable and stage rather than create a duplicate. An optional consolidated Mahnung SHALL link every included invoice and its balance snapshot to the customer-level letter.

#### Scenario: Assisted run creates confirmed eligible reminders
- **GIVEN** two overdue invoices are eligible and one is excluded from dunning
- **WHEN** the user reviews and confirms an assisted run
- **THEN** the confirmed eligible invoices SHALL produce linked Mahnungen and the excluded invoice SHALL remain unchanged

#### Scenario: Full payment or exclusion prevents a new reminder
- **GIVEN** an invoice is fully paid, not yet due, or explicitly excluded
- **WHEN** any dunning mode evaluates it
- **THEN** the invoice SHALL not appear among created reminders

#### Scenario: Repeated run does not duplicate a stage reminder
- **GIVEN** an unsent Mahnung already exists for an invoice and stage
- **WHEN** the same stage is evaluated again
- **THEN** the run SHALL return the existing draft or a typed already-pending result and SHALL not create another Mahnung

#### Scenario: Consolidated letter preserves invoice links
- **GIVEN** a customer has multiple eligible overdue invoices and consolidation is selected
- **WHEN** the confirmed run creates a consolidated Mahnung
- **THEN** the letter SHALL reference every included invoice and preserve each outstanding amount in its snapshot

### Requirement: Late-Payment Interest Uses the Settled Open Principal

The system SHALL calculate configured per-stage annual percentage interest only on the invoice's unpaid principal for each elapsed overdue day, using a 365-day year. A posted partial payment SHALL reduce the principal for subsequent days from its effective settlement date; a full payment SHALL stop further accrual. Previously accrued interest and fees SHALL be carried as separate unpaid amounts and SHALL NOT be included in interest principal. Currency rounding SHALL follow the accepted invoice-money contract. The system SHALL NOT describe the configured percentage as a statutory rate unless a separately approved rate-source policy is implemented.

#### Scenario: Partial settlement reduces later interest
- **GIVEN** a €1,000.00 principal accrues at 8% annually and a €400.00 payment settles after 10 overdue days
- **WHEN** interest is calculated through overdue day 20
- **THEN** the first 10 days SHALL use €1,000.00 principal and the next 10 days SHALL use €600.00 principal

#### Scenario: Full settlement stops later accrual
- **GIVEN** an overdue invoice is fully settled on a recorded settlement date
- **WHEN** interest is calculated for a period after that date
- **THEN** no interest SHALL accrue after the settlement date

#### Scenario: Unpaid fees are not compounded
- **GIVEN** a prior Mahnung has carried unpaid fees or interest
- **WHEN** the next interest amount is calculated
- **THEN** its principal SHALL include only the settled open invoice principal

### Requirement: Dunning Operations Have a Typed Workspace

The application SHALL expose a `/mahnwesen` workspace with typed, searchable dunning records, eligible-run preview, stage configuration, customer and invoice exclusions, customer history, and actionable empty, loading, unavailable, and failure states. The workspace SHALL display outstanding principal, fixed fee, configured annual rate, accrued interest, delivery state, and the linked invoice or invoices. It SHALL not present an unavailable run, PDF, or send action as successful.

#### Scenario: User reviews an eligible dunning run
- **GIVEN** the profile has eligible overdue receivables
- **WHEN** the user opens `/mahnwesen` and requests a preview
- **THEN** the workspace SHALL show the eligible invoices, next stages, balances, and exclusion reasons before confirmation

#### Scenario: Dunning data source is unavailable
- **GIVEN** the active profile database cannot be read
- **WHEN** the user opens `/mahnwesen`
- **THEN** the workspace SHALL show a retryable unavailable state and SHALL not show an empty list or fabricated zero balances

### Requirement: Mail-Versand via SMTP

The system SHALL send a dunning letter only when SMTP is configured and a readable generated PDF artifact is available. It SHALL mark a Mahnung as sent and record its send time only after the mail transport confirms acceptance of the message with the expected attachment. A failed or unavailable send SHALL leave the Mahnung unsent and retryable; it SHALL not advance the invoice's current dunning level.

#### Scenario: Send dunning letter
- **GIVEN** SMTP is configured and the Mahnung has a readable PDF artifact
- **WHEN** the user sends it and the transport accepts the message
- **THEN** the message SHALL contain the PDF and the Mahnung SHALL record sent status and timestamp

#### Scenario: SMTP not configured
- **GIVEN** SMTP is missing, the PDF is unavailable, or the transport rejects the message
- **WHEN** the user attempts to send the Mahnung
- **THEN** the system SHALL show an actionable error and SHALL leave the Mahnung unsent and retryable

#### Scenario: Retrying a pending letter does not create a second record
- **GIVEN** a Mahnung exists but its previous send attempt failed
- **WHEN** the user retries the send
- **THEN** the existing Mahnung SHALL be retried and no duplicate Mahnung record SHALL be created

### Requirement: Invoice Dunning Level

Each eligible invoice SHALL retain its current dunning level as the highest level with a successfully sent Mahnung. A level SHALL not advance while its letter is only a draft or its send failed. Full settlement SHALL clear the current level; partial settlement SHALL preserve the level while reducing outstanding principal and future interest.

#### Scenario: Invoice at level 2
- **GIVEN** an invoice has no current dunning level and a level 1 Mahnung is delivered successfully
- **WHEN** the send operation completes
- **THEN** the invoice's current dunning level SHALL become level 1

#### Scenario: Failed send does not advance the level
- **GIVEN** a Mahnung exists for the next level but its send failed
- **WHEN** the send operation returns failure
- **THEN** the invoice's current dunning level SHALL remain unchanged

#### Scenario: Invoice payment resets level
- **GIVEN** an invoice has a current dunning level
- **WHEN** its settled outstanding principal becomes zero
- **THEN** the current dunning level SHALL be cleared

### Requirement: Collection Package

For a customer selected for collection preparation, the system SHALL produce a customer-linked package containing the current account statement, selected open invoices, previous Mahnungen, and the as-of outstanding balance. Every included artifact SHALL resolve to a readable stored document; an unavailable required artifact SHALL be reported and SHALL not be represented by a placeholder.

#### Scenario: Package contains selected customer evidence
- **GIVEN** the customer has selected open invoices, prior Mahnungen, and readable artifacts
- **WHEN** the user creates a collection package
- **THEN** the package SHALL link the account statement, selected invoices, prior reminders, and balance snapshot to that customer

#### Scenario: Missing required artifact blocks a complete package
- **GIVEN** a selected prior Mahnung has no readable artifact
- **WHEN** the user creates a collection package
- **THEN** the system SHALL report the missing artifact and SHALL not label the package complete

## ADDED Requirements

### Requirement: Dunning Reference Documentation Matches the Runtime Contract

The dunning documentation SHALL describe `gebuehr` as a fixed currency amount per level, `zinssatz` as a configurable annual percentage, and `multiplier` as an optional fixed-fee carry into the next configured level. It SHALL use the canonical fresh-profile defaults in `Dunning Level Configuration`, SHALL not show a percentage fee, and SHALL not claim legal compliance from those defaults alone.

#### Scenario: Documentation exposes the canonical model
- **GIVEN** the dunning documentation and fresh-profile seed are checked against the specification
- **WHEN** the dunning contract parity check runs
- **THEN** the documented fields, units, and standard values SHALL match the specification and seed values

#### Scenario: Percentage-fee example is rejected
- **GIVEN** the documentation contains a fee expressed as a percent of invoice principal
- **WHEN** the dunning contract parity check runs
- **THEN** the check SHALL fail with the mismatched documented field or unit
