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

The workspace SHALL make each due template instance visible with its template reference, stored due date, configured mode, booking values, and review state. A due instance SHALL have a stable identity unique to its template and due date. Review state and blocking/handoff reasons SHALL be the persisted `review_status`, `block_reason`, and `handoff_error` values defined by the `db` delta; a refresh that only displays an instance MUST NOT change its persisted state. Detecting or displaying a due instance MUST NOT create a journal entry, finalize an invoice, advance an accounting balance, or otherwise produce a financial effect. Paused templates SHALL NOT produce newly actionable due instances.

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

#### Scenario: Blocked instance shows its persisted reason
- **GIVEN** a due instance cannot execute because the shared contract or required mapping is unavailable
- **WHEN** the workspace refreshes its due list
- **THEN** the instance shows the persisted non-terminal status with the missing contract or mapping named, and no financial record is created

### Requirement: Confirmed direct bookings use the shared posting boundary

The workspace SHALL allow a reviewed direct-mode instance to request execution only through the accepted shared accounting posting boundary. The occurrence identity SHALL be supplied as the idempotency source for that request. Until the boundary and its required amount, account, tax, and date contracts are accepted and available, execution MUST fail closed: the instance remains pending, no journal row or input-tax claim is created, and the user sees the blocking reason. A successful posting SHALL persist `posted` status with its result link and advance the template's stored next due date by one interval step per the `recurring` schedule rules; a failed or blocked attempt SHALL persist a non-terminal status with its reason and SHALL NOT advance the date. The workspace MUST NOT add a separate journal writer.

#### Scenario: Confirm a ready direct-mode instance
- **GIVEN** a due direct-mode instance has complete values and an accepted shared posting contract is available
- **WHEN** the user reviews and confirms it
- **THEN** the workspace requests one posting through that boundary using the occurrence identity and displays the resulting posting state

#### Scenario: Keep direct mode pending without the shared contract
- **GIVEN** a due direct-mode instance exists but the shared posting contract or a required mapping is unavailable
- **WHEN** the user attempts execution
- **THEN** no journal row or input-tax claim is created, the instance remains pending, and the missing contract or mapping is shown

#### Scenario: Successful posting advances the schedule
- **GIVEN** a reviewed direct-mode instance has been posted through the accepted shared posting contract
- **WHEN** the posting result is recorded
- **THEN** the occurrence persists `posted` status with its result link and the template stored date advances by one interval step, with no second posting for that occurrence

### Requirement: Beleg mode hands off to incoming-invoice drafting

A reviewed due instance in Beleg mode SHALL hand template data to the existing incoming-invoice draft use case. Each draft request SHALL supply the occurrence identity as its idempotency source. An occurrence SHALL link at most one draft; a repeated request for an already-linked occurrence SHALL reuse that draft and create no second draft. Recovery after a successful draft creation with an unsaved occurrence link SHALL attach the existing draft found by occurrence identity rather than creating another draft. A successful link SHALL persist `handed_off` status and advance the template's stored next due date by one interval step per the `recurring` schedule rules. Draft creation SHALL NOT itself create a journal posting or input-tax claim. Finalization and any resulting financial effect SHALL remain with the owning invoice workflow and accepted shared posting boundary. If that draft use case is unavailable or creation fails, the due instance MUST remain reviewable with its persisted `handoff_error`, without a direct SQL invoice write and without advancing the stored date.

#### Scenario: Create an incoming-invoice draft from a reviewed instance
- **GIVEN** a due Beleg-mode instance has been reviewed and the incoming-invoice draft use case is available
- **WHEN** the user requests draft creation
- **THEN** one linked incoming-invoice draft is created through that use case, and no journal posting or input-tax claim is created

#### Scenario: Keep Beleg mode reviewable when draft handoff is unavailable
- **GIVEN** a due Beleg-mode instance exists but the incoming-invoice draft use case is unavailable
- **WHEN** the user requests draft creation
- **THEN** no invoice or journal row is written by the recurring workspace and the instance remains reviewable with the handoff failure shown

#### Scenario: Repeated draft request reuses the linked draft
- **GIVEN** a Beleg-mode occurrence already links one incoming-invoice draft, including a draft created before the occurrence link was saved
- **WHEN** the user requests draft creation again for the same occurrence
- **THEN** the workspace reuses the existing draft found by occurrence identity, persists its link with `handed_off` status, and creates no second draft
