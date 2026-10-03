## MODIFIED Requirements

### Requirement: Buchungsvorlagen

The system SHALL support recurring booking templates for fixed costs and regular income. Saving a template SHALL store its configured type, category, amount, interval, and position data without creating a financial event. When a template is due, execution SHALL first create or reuse one durable review instance identified by the template and stored due date. Schedule detection MUST NOT write a journal entry, input-tax claim, or finalized incoming invoice. After explicit user confirmation, a direct booking SHALL use the accepted shared accounting posting contract; Beleg mode SHALL hand off to the existing incoming-invoice draft use case. If the posting contract, a mapping required by that contract, or a required tax interpretation is unavailable, the instance MUST remain pending with no financial side effect. A template referencing an article SHALL use the article's current price when preparing a confirmed booking, as defined by this maintained requirement. A paused template SHALL create no new actionable instances. A deactivated category SHALL retain the behavior defined by this maintained requirement: use it with a warning when an accepted shared posting contract permits the booking.

#### Scenario: Template creation
- **GIVEN** a template is created with `art`, category, amount, interval, and optional position data
- **WHEN** the template is saved
- **THEN** those values are stored and no journal entry or input-tax claim is created

#### Scenario: Due template is staged for review
- **GIVEN** a Buchungsvorlage is due under its stored schedule
- **WHEN** the due-instance workflow runs
- **THEN** one durable review instance is available and no financial event is created

#### Scenario: Template execution
- **GIVEN** a reviewed direct-mode instance has complete mappings and the accepted shared posting contract is available
- **WHEN** the user confirms execution
- **THEN** the resulting financial event is created through that contract and linked to the due occurrence

#### Scenario: Template with article
- **GIVEN** a template references an article whose current price differs from the stored template price
- **WHEN** a booking is prepared for user confirmation
- **THEN** the current article price is used in the review data, and no event is posted before confirmation

#### Scenario: Template lifecycle
- **GIVEN** a template is paused (`aktiv=false`, `beendet=false`) or ended (`beendet=true`)
- **WHEN** its scheduled date arrives
- **THEN** the paused template produces no new booking until reactivated, while the ended template remains archived

#### Scenario: Unavailable mapping or shared contract fails closed
- **GIVEN** a due template has a deactivated/unresolved category or the shared posting contract or tax interpretation is unavailable
- **WHEN** execution is requested
- **THEN** the occurrence remains pending, identifies the missing mapping or contract, and no journal entry or input-tax claim is created

#### Scenario: Template with deleted category
- **GIVEN** a Buchungsvorlage references a category that has been deactivated (`aktiv=0`)
- **WHEN** the user confirms the reviewed occurrence and the accepted shared posting contract permits the configured category
- **THEN** the booking uses the deactivated category and the workspace records or displays the warning required by this maintained category policy
