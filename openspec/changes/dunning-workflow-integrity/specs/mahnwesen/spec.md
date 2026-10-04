## MODIFIED Requirements

### Requirement: Dunning Level Configuration

The system SHALL provide four protected standard levels and allow custom levels. Each level SHALL configure an absolute calendar-day offset from the invoice due date, a fixed currency fee (`gebuehr`), an annual percentage interest rate (`zinssatz`), and a multiplier flag. A multiplier SHALL add the immediately preceding level's configured fixed fee to the current level's fixed fee; it SHALL NOT turn a fee into a percentage. A created Mahnung SHALL snapshot its effective fee and interest calculation inputs so later edits affect only new letters. On a fresh profile, the standard defaults SHALL be: level 1 = 7 days, €5.00, 0%, multiplier off; level 2 = 21 days, €10.00, 5%, off; level 3 = 35 days, €15.00, 8%, off; level 4 = 49 days, €25.00, 8%, off. These configurable product defaults are not statutory rates. Existing user-edited values SHALL be preserved during initialization.

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

#### Scenario: Stage date uses one absolute threshold
- **GIVEN** an invoice is due on 2026-01-01, stage 1 is configured for 7 days after due, and the initial grace setting is 30 days
- **WHEN** manual or assisted eligibility is evaluated on 2026-01-07 and 2026-01-08
- **THEN** stage 1 SHALL be ineligible on 2026-01-07 and eligible on 2026-01-08, with no additional grace days added

### Requirement: Mahnung Snapshot

Each created Mahnung SHALL link to exactly one invoice and snapshot the invoice number, due date, customer identity, applicable dunning level, current outstanding principal, effective fixed fee, ordered interest calculation segments (date range, stage, configured annual rate, and principal), calculated interest total, and carried unpaid fees and interest. Snapshot values SHALL be immutable after creation. A Mahnung SHALL NOT be created from an invoice total when its receivable has no positive outstanding balance.

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

The system SHALL evaluate only finalized outgoing invoices whose settled outstanding principal is positive and whose current business date is on or after `due_date + stage.days_after_due`. Stage offsets are absolute calendar-day thresholds; `initial_grace_days` SHALL NOT be added to or used to defer them. A later stage SHALL be eligible only after its preceding stage has a transport-accepted Mahnung. This change SHALL support manual and assisted runs only; it SHALL NOT schedule or trigger automatic evaluation from a dashboard load or background task. Assisted mode SHALL show a reviewable preview and create letters only after confirmation. Both modes SHALL respect customer and invoice exclusions and SHALL not bypass an active Mahnsperre. Each Mahnung SHALL reference one invoice; a run MAY group separate letters for review but SHALL NOT create a consolidated customer letter. For each invoice and stage, a repeated run SHALL reuse an existing unsent Mahnung or report an already transport-accepted Mahnung rather than create a duplicate.

#### Scenario: Assisted run creates confirmed eligible reminders
- **GIVEN** two overdue invoices are eligible and one is excluded from dunning
- **WHEN** the user reviews and confirms an assisted run
- **THEN** the confirmed eligible invoices SHALL produce linked Mahnungen and the excluded invoice SHALL remain unchanged

#### Scenario: Full payment or exclusion prevents a new reminder
- **GIVEN** an invoice is fully paid, not yet due, or explicitly excluded
- **WHEN** a manual or assisted run evaluates it
- **THEN** the invoice SHALL not appear among created reminders

#### Scenario: Stage transition is exact and ordered
- **GIVEN** an invoice is due on 2026-01-01, stage 1 is 7 days after due, stage 2 is 21 days after due, and stage 1 was transport-accepted
- **WHEN** a run evaluates the invoice on 2026-01-21 and 2026-01-22
- **THEN** stage 2 SHALL be ineligible on 2026-01-21 and eligible on 2026-01-22

#### Scenario: Repeated run does not duplicate a stage reminder
- **GIVEN** an unsent Mahnung already exists for an invoice and stage
- **WHEN** the same stage is evaluated again
- **THEN** the run SHALL reuse the existing unsent draft or report the existing transport-accepted reminder and SHALL not create another Mahnung

### Requirement: Late-Payment Interest Uses the Settled Open Principal

The system SHALL accrue no interest before the first stage's absolute threshold. For each eligible overdue calendar day through the as-of date, it SHALL use the annual rate of the highest stage whose threshold is on or before that day; rate changes SHALL apply prospectively and SHALL NOT reprice earlier days. It SHALL calculate interest only on unpaid invoice principal using a 365-day year. A posted partial payment SHALL reduce principal starting on its effective settlement date, before that date's accrual; full settlement SHALL stop accrual on that date. Previously accrued interest and fees SHALL remain separate from principal and SHALL NOT compound. The system SHALL accumulate exact decimal daily amounts and round the per-invoice total once to two decimal places using half-up rounding; it SHALL NOT use floating point or round each day. Configured rates SHALL be described as product values, not statutory rates.

#### Scenario: Tier transition and partial payment have deterministic cents
- **GIVEN** an invoice is due on 2026-01-01, stage 1/2 thresholds are 7/21 days at 0%/5%, its €1,000.00 balance is reduced by a €400.00 settlement effective 2026-01-25, and the as-of date is 2026-01-27
- **WHEN** interest is calculated
- **THEN** no interest SHALL accrue before day 7; days 21–23 SHALL use €1,000.00 at 5%; days 24–26 SHALL use €600.00 at 5%; and `(3 × €1,000 × 0.05 + 3 × €600 × 0.05) / 365` SHALL round once from €0.6575… to €0.66

#### Scenario: Full settlement stops accrual on its effective date
- **GIVEN** an eligible overdue invoice is fully settled on a recorded settlement date
- **WHEN** interest is calculated for that date and later dates
- **THEN** no interest SHALL accrue on the settlement date or afterward

#### Scenario: Unpaid fees are not compounded
- **GIVEN** a prior Mahnung has carried unpaid fees or interest
- **WHEN** the next interest amount is calculated
- **THEN** its principal SHALL include only the settled open invoice principal

### Requirement: Dunning Operations Have a Typed Workspace

The application SHALL expose a `/mahnwesen` workspace with typed, searchable dunning records, manual/assisted eligible-run preview, stage configuration, customer and invoice exclusions, customer history, and actionable empty, loading, unavailable, and failure states. Each row SHALL display one linked invoice, its outstanding principal, fixed fee, configured annual rate, accrued interest, and transport state. The workspace SHALL not present an unavailable run, PDF, or send action as successful.

#### Scenario: User reviews an eligible dunning run
- **GIVEN** the profile has eligible overdue receivables
- **WHEN** the user opens `/mahnwesen` and requests a preview
- **THEN** the workspace SHALL show the eligible invoices, next stages, balances, and exclusion reasons before confirmation

#### Scenario: Dunning data source is unavailable
- **GIVEN** the active profile database cannot be read
- **WHEN** the user opens `/mahnwesen`
- **THEN** the workspace SHALL show a retryable unavailable state and SHALL not show an empty list or fabricated zero balances

#### Scenario: Narrow window remains keyboard accessible
- **GIVEN** the application window is narrower than 900 logical pixels
- **WHEN** the user opens `/mahnwesen` and navigates its list and invoice detail by keyboard
- **THEN** the workspace SHALL use a full-width list and focused detail view, preserve logical keyboard order and visible focus, and localize its loading, empty, and failure states

### Requirement: Dunning Balance Source Fails Closed

The dunning monetary path SHALL remain disabled until both `invoice-money-invariants` and `balanced-journal-postings-and-settlement-events` are accepted through independent review. Every operation that needs a current balance or interest SHALL use the settled-receivable projection and dated settlement events from `balanced-journal-postings-and-settlement-events` with the accepted amount/sign rules from `invoice-money-invariants`. If that source is missing, invalid, or conflicting, balance-dependent preview, calculation, reminder creation, PDF/package creation, and any send that needs a current balance or interest SHALL return an actionable typed unavailable result and SHALL perform no persistent write, artifact generation/write, stage-state update, or transport call. The system SHALL NOT fall back to invoice gross/net totals, bank-import rows, or fabricated zero balances.

#### Scenario: Missing or conflicting balance source blocks every balance-dependent operation
- **GIVEN** the accepted settlement source is unavailable or its projected balance conflicts with its dated events
- **WHEN** the user requests preview, reminder creation, current-balance PDF generation, package creation, or a balance-dependent send
- **THEN** each operation SHALL return a retryable actionable unavailable result and SHALL create no reminder/artifact, update no stage state, and call no mail transport

#### Scenario: Invalid settlement event is not replaced by invoice totals
- **GIVEN** the accepted source contains an invalid or conflicting settlement event for an invoice
- **WHEN** a dunning calculation is requested
- **THEN** the operation SHALL fail closed with the source error and SHALL not substitute the invoice gross or net total

### Requirement: Mail-Versand via SMTP

The system SHALL send a dunning letter only when SMTP is configured and a readable generated PDF artifact is available. It SHALL record transport acceptance only after the mail transport accepts the message with the expected attachment. UI and history SHALL say “transport accepted” and SHALL NOT claim delivered or read. A failed or unavailable send SHALL leave the Mahnung unsent and retryable; it SHALL not advance the invoice's current dunning level.

#### Scenario: Send dunning letter
- **GIVEN** SMTP is configured and the Mahnung has a readable PDF artifact
- **WHEN** the user sends it and the transport accepts the message
- **THEN** the message SHALL contain the PDF and the Mahnung SHALL record transport acceptance and its timestamp

#### Scenario: SMTP not configured
- **GIVEN** SMTP is missing, the PDF is unavailable, or the transport rejects the message
- **WHEN** the user attempts to send the Mahnung
- **THEN** the system SHALL show an actionable error and SHALL leave the Mahnung unsent and retryable

#### Scenario: Retrying a pending letter does not create a second record
- **GIVEN** a Mahnung exists but its previous send attempt failed
- **WHEN** the user retries the send
- **THEN** the existing Mahnung SHALL be retried and no duplicate Mahnung record SHALL be created

### Requirement: Invoice Dunning Level

Each eligible invoice SHALL retain its current dunning level as the highest level with a transport-accepted Mahnung. A level SHALL not advance while its letter is only a draft or its send failed. Full settlement SHALL clear the current level; partial settlement SHALL preserve the level while reducing outstanding principal and future interest.

#### Scenario: Invoice at level 2
- **GIVEN** an invoice has no current dunning level and the transport accepts a level 1 Mahnung
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

For a customer selected for collection preparation, the system SHALL produce a customer-linked package containing the current account statement, selected open invoices, previous Mahnungen, and the as-of outstanding balance from the accepted settlement source. Every included artifact SHALL resolve to a readable stored document; an unavailable required artifact SHALL be reported and SHALL not be represented by a placeholder. An unavailable, invalid, or conflicting balance source SHALL block package creation without writing an artifact.

#### Scenario: Package contains selected customer evidence
- **GIVEN** the customer has selected open invoices, prior Mahnungen, and readable artifacts
- **WHEN** the user creates a collection package
- **THEN** the package SHALL link the account statement, selected invoices, prior reminders, and balance snapshot to that customer

#### Scenario: Missing required artifact blocks a complete package
- **GIVEN** a selected prior Mahnung has no readable artifact
- **WHEN** the user creates a collection package
- **THEN** the system SHALL report the missing artifact and SHALL not label the package complete

### Requirement: Mahnwesen Settings Singleton

The system SHALL continue storing `initial_grace_days`, `email_template`, and `default_interest_rate` in the singleton for profile compatibility. `initial_grace_days` SHALL be deprecated and non-operative: no dunning eligibility, preview, calculation, creation, or send SHALL use it, and the dunning settings UI SHALL NOT present it as an active control. Stage eligibility SHALL use only the absolute `due_date + days_after_due` threshold. Existing values SHALL be preserved during initialization.

#### Scenario: Configure grace period

- **GIVEN** an existing profile stores `initial_grace_days = 14` and stage 1 is configured for 7 days after an invoice due date
- **WHEN** manual or assisted eligibility is evaluated on the day before and on the absolute stage threshold
- **THEN** the invoice SHALL be ineligible before `due_date + 7` and eligible on that threshold when other stage rules are met
- **AND** the stored 14-day compatibility value SHALL NOT defer eligibility
- **AND** the settings UI SHALL show the saved value only as deprecated, non-editable compatibility data

#### Scenario: Default settings on fresh install

- **GIVEN** a fresh database has no dunning settings
- **WHEN** the system initializes the singleton
- **THEN** it SHALL create default settings with `initial_grace_days = 0` and the documented default interest rate
- **AND** the zero grace value SHALL remain non-operative

## ADDED Requirements

### Requirement: Dunning Reference Documentation Matches the Runtime Contract

The dunning documentation SHALL describe `gebuehr` as a fixed currency amount per level, `zinssatz` as a configurable annual percentage, `multiplier` as an optional fixed-fee carry, and configured stage days as absolute offsets from the invoice due date. It SHALL use the canonical fresh-profile defaults in `Dunning Level Configuration`, SHALL not show a percentage fee or claim statutory compliance, and SHALL describe rates as configured product values. It SHALL describe this change's scope as manual/assisted with separate invoice letters and SHALL remove or mark unsupported dashboard-triggered or scheduled runs and automatic customer-block/release behavior. It SHALL state that invoice stage advances only after transport acceptance; creating a draft or a failed send does not advance the stage.

#### Scenario: Documentation exposes the canonical model
- **GIVEN** the dunning documentation and fresh-profile seed are checked against the specification
- **WHEN** the dunning contract parity check runs
- **THEN** the documented fields, units, and standard values SHALL match the specification and seed values

#### Scenario: Percentage-fee example is rejected
- **GIVEN** the documentation contains a fee expressed as a percent of invoice principal
- **WHEN** the dunning contract parity check runs
- **THEN** the check SHALL fail with the mismatched documented field or unit

#### Scenario: Documentation describes stage progression

- **GIVEN** the dunning documentation describes when an invoice advances to another stage
- **WHEN** the dunning contract parity check runs
- **THEN** it SHALL state that transport acceptance advances the stage
- **AND** it SHALL state that a draft or failed send does not advance the stage

#### Scenario: Unsupported automation and legal claims are not documented as available
- **GIVEN** the dunning documentation is checked against this change's scope
- **WHEN** it claims a dashboard or scheduled automatic run, automatic customer-block release, statutory rate behavior, or consolidated letters are available
- **THEN** the parity check SHALL fail with the unsupported behavior claim
