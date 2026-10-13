## ADDED Requirements

### Requirement: Buchungsvorlagen occurrence review-state persistence

The system SHALL persist occurrence review state on `buchungsvorlagen_occurrences` with `review_status TEXT NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','blocked','ready','handed_off','posted','failed'))`, durable `block_reason TEXT NULL`, and durable `handoff_error TEXT NULL`, preserving the existing unique `(vorlage_id, faelligkeit)` key and linked journal/invoice references. Existing rows SHALL backfill to `pending` with NULL reasons. Blocking and handoff-failure displays SHALL read the persisted reason; a missing contract, mapping, or draft failure MUST leave a non-terminal status with that reason stored.

#### Scenario: Existing occurrences backfill without losing links
- **GIVEN** existing occurrence rows with journal/invoice links and no review columns
- **WHEN** the migration runs
- **THEN** each row keeps its identity and links with `pending` status and NULL reasons

#### Scenario: Blocked occurrence persists its reason
- **GIVEN** a due occurrence cannot execute because the shared contract or required mapping is unavailable
- **WHEN** the workspace records the block
- **THEN** the row persists a non-terminal status with the missing contract or mapping named in `block_reason` and creates no financial record

#### Scenario: Failed handoff persists its error
- **GIVEN** Beleg draft creation fails or its use case is unavailable
- **WHEN** the handoff is attempted
- **THEN** the row persists `failed` with the failure in `handoff_error`, remains reviewable, and the stored template date does not advance
