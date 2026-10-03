## ADDED Requirements

### Requirement: Manage recurring booking templates

The application SHALL provide the canonical `/recurring` workspace to create and inspect recurring booking templates. A template SHALL expose its name, configured type (`Einnahme` or `Ausgabe`), execution mode, interval, explicit next due date, and configured booking values and links. The interval SHALL be one of the existing supported values: monthly, quarterly, or yearly. The workspace MUST present configured amount, tax inputs, category, account, and supplier as stored template data; it MUST NOT infer a tax or posting result from those fields. Creating or viewing a template SHALL NOT create a journal entry or other financial event.

#### Scenario: Create and review a scheduled template
- **GIVEN** the user supplies a name, supported type and mode, supported interval, explicit next due date, and the configured booking values
- **WHEN** the user saves the template and opens its detail
- **THEN** the workspace shows the persisted values and next due date, with no journal entry created

#### Scenario: Reject an invalid template schedule
- **GIVEN** the template has an unsupported interval, missing required name/type/mode, or no explicit next due date
- **WHEN** the user saves it
- **THEN** the template is not created and the workspace identifies the invalid field

### Requirement: Surface due booking instances for review

The workspace SHALL make each due template instance visible with its template reference, stored due date, configured mode, booking values, and review state. A due instance SHALL have a stable identity unique to its template and due date. Detecting or displaying a due instance MUST NOT create a journal entry, finalize an invoice, advance an accounting balance, or otherwise produce a financial effect. Paused templates SHALL NOT produce newly actionable due instances.

#### Scenario: Review a due instance
- **GIVEN** an active template has a stored next due date that is due
- **WHEN** the workspace refreshes its due list
- **THEN** one reviewable due instance is shown with that date and the template's configured values, and no financial record is created

#### Scenario: Repeated refresh does not duplicate a due instance
- **GIVEN** a due instance already exists for a template and due date
- **WHEN** the workspace refreshes the same schedule again
- **THEN** it shows the existing instance with the same identity and creates no second instance or financial record

#### Scenario: Paused template has no actionable due instance
- **GIVEN** a template is paused before its stored next due date
- **WHEN** the workspace refreshes its due list
- **THEN** the template does not produce a new actionable due instance

### Requirement: Confirmed direct bookings use the shared posting boundary

The workspace SHALL allow a reviewed direct-mode instance to request execution only through the accepted shared accounting posting boundary. The occurrence identity SHALL be supplied as the idempotency source for that request. Until the boundary and its required amount, account, tax, and date contracts are accepted and available, execution MUST fail closed: the instance remains pending, no journal row or input-tax claim is created, and the user sees the blocking reason. The workspace MUST NOT add a separate journal writer.

#### Scenario: Confirm a ready direct-mode instance
- **GIVEN** a due direct-mode instance has complete values and an accepted shared posting contract is available
- **WHEN** the user reviews and confirms it
- **THEN** the workspace requests one posting through that boundary using the occurrence identity and displays the resulting posting state

#### Scenario: Keep direct mode pending without the shared contract
- **GIVEN** a due direct-mode instance exists but the shared posting contract or a required mapping is unavailable
- **WHEN** the user attempts execution
- **THEN** no journal row or input-tax claim is created, the instance remains pending, and the missing contract or mapping is shown

### Requirement: Beleg mode hands off to incoming-invoice drafting

A reviewed due instance in Beleg mode SHALL hand template data to the existing incoming-invoice draft use case. Draft creation SHALL NOT itself create a journal posting or input-tax claim. Finalization and any resulting financial effect SHALL remain with the owning invoice workflow and accepted shared posting boundary. If that draft use case is unavailable, the due instance MUST remain reviewable without a direct SQL invoice write.

#### Scenario: Create an incoming-invoice draft from a reviewed instance
- **GIVEN** a due Beleg-mode instance has been reviewed and the incoming-invoice draft use case is available
- **WHEN** the user requests draft creation
- **THEN** one linked incoming-invoice draft is created through that use case, and no journal posting or input-tax claim is created

#### Scenario: Keep Beleg mode reviewable when draft handoff is unavailable
- **GIVEN** a due Beleg-mode instance exists but the incoming-invoice draft use case is unavailable
- **WHEN** the user requests draft creation
- **THEN** no invoice or journal row is written by the recurring workspace and the instance remains reviewable with the handoff failure shown
