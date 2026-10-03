## MODIFIED Requirements

### Requirement: Buchungsvorlage Modus

Buchungsvorlagen SHALL support two configured modes: `direkt` for a due instance that can be reviewed and then submitted through the accepted shared accounting posting boundary, and `beleg` for a reviewed handoff to the incoming-invoice draft workflow. Schedule detection SHALL NOT itself write a journal entry, input-tax claim, or finalized invoice. Direct mode MUST remain pending without financial side effects until the shared posting contract is accepted and available. Beleg mode MAY create only a draft through its owning use case; finalization and any financial effect remain governed by the invoice and accounting contracts.

#### Scenario: Direkt mode
- **GIVEN** a `direkt` template has a due instance
- **WHEN** the schedule is detected
- **THEN** the due instance is available for review and no journal entry or input-tax claim is created

#### Scenario: Beleg mode
- **GIVEN** a `beleg` template has a due instance
- **WHEN** the user reviews it and requests draft creation
- **THEN** the existing incoming-invoice draft use case receives the template data and no journal entry is created

#### Scenario: Financial effect is blocked without the shared contract
- **GIVEN** a `direkt` due instance has not been submitted through an accepted shared posting contract
- **WHEN** execution is requested
- **THEN** the occurrence remains pending and no journal row, input-tax claim, or finalized invoice is created

### Requirement: Buchungsvorlage Art

Buchungsvorlagen SHALL store and display `art` as the configured `Einnahme` or `Ausgabe` classification. This classification alone MUST NOT create a posting, choose debit/credit accounts, calculate VAT, or create an input-tax claim. Financial and tax effects SHALL be determined only by the accepted shared posting and tax contracts.

#### Scenario: Ausgabe direction
- **GIVEN** a template is configured as `Ausgabe`
- **WHEN** its due instance is displayed for review
- **THEN** the instance shows `Ausgabe` and no VAT amount, account effect, or financial event is inferred from the type alone

#### Scenario: Einnahme direction
- **GIVEN** a template is configured as `Einnahme`
- **WHEN** its due instance is displayed for review
- **THEN** the instance shows `Einnahme` and no VAT amount, account effect, or financial event is inferred from the type alone

#### Scenario: Reject an unresolved tax or account interpretation
- **GIVEN** the shared contracts do not define the required tax or account effect for a template
- **WHEN** a user attempts to execute its due instance
- **THEN** execution remains pending and no journal entry or input-tax claim is created

### Requirement: Buchungsvorlage Auto-Generation

The system SHALL identify due occurrences from an active Buchungsvorlage's stored schedule and expose them as durable review instances. The schedule scan MUST NOT automatically create journal entries, input-tax claims, or finalized invoices. A reviewed direct-mode instance may create a financial event only through the accepted shared posting contract after explicit user confirmation. Repeated schedule scans SHALL reuse the same occurrence identity. Inactive templates SHALL produce no new actionable occurrence.

#### Scenario: Auto-generate journal entry
- **GIVEN** a Buchungsvorlage is active and its stored next due date is due
- **WHEN** the due-instance workflow runs
- **THEN** one durable review instance is available for that template and due date, with no financial event created

#### Scenario: Repeated scan is idempotent
- **GIVEN** a due review instance already exists for a template and due date
- **WHEN** the due-instance workflow runs again for the same date
- **THEN** it reuses the same occurrence and does not create a duplicate instance or financial event

#### Scenario: Inactive template skipped
- **GIVEN** a Buchungsvorlage is paused (`aktiv=false`)
- **WHEN** the due-instance workflow runs
- **THEN** no new actionable occurrence or financial event is created

#### Scenario: Missing posting contract blocks execution
- **GIVEN** an active template has a due review instance but the accepted shared posting contract is unavailable
- **WHEN** the due-instance workflow runs
- **THEN** the instance remains pending and no journal entry or input-tax claim is created
