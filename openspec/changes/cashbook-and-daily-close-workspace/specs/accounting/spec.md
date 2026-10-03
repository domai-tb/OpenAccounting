## MODIFIED Requirements

### Requirement: Tagesabschluss

The system SHALL support daily cash close for an explicit company, cash account, and selected date only through an approved typed balance/close use case that returns a complete, verified expected amount and discrepancy result with a source reference. Expected cash SHALL NOT be derived by summing all journal entries for the selected date or by substituting `konten.saldo` without the approved as-of source contract. A finalized close SHALL preserve the expected result, actual count, discrepancy result, explanation when a discrepancy is reported, company/account/date, and SHA-256 signature in the existing close record. The accounting workspace SHALL NOT calculate tax or post a journal adjustment for a close discrepancy. A missing or incomplete source, unresolved persistence mapping, or unavailable signature contract SHALL prevent finalization and PDF generation. The finalization identity SHALL be `(unternehmen_id, konto_id, datum)`; duplicate lookup and signed insert SHALL use one SQLite `BEGIN IMMEDIATE` transaction. Any matching unsigned legacy row, multiple rows, or ambiguous legacy identity SHALL block finalization for that identity while preserving the old rows. Exactly one matching signed row with no other matching rows SHALL be returned read-only. Finalized closes SHALL remain immutable history.

#### Scenario: Tagesabschluss creation

- **GIVEN** an approved close use case returns a complete, verified expected balance for a selected cash account and date
- **WHEN** the user starts Tagesabschluss
- **THEN** the returned expected amount and source status SHALL be presented for manual count entry
- **AND** the workspace SHALL NOT derive it from same-day journal rows or `konten.saldo`.

#### Scenario: Counting discrepancy

- **GIVEN** the approved close use case reports a discrepancy between expected and counted amounts
- **WHEN** the user finalizes the Tagesabschluss with an explanation
- **THEN** the discrepancy and explanation SHALL be preserved in `zaehlung_json` and flagged in the Tagesabschluss PDF
- **AND** no journal adjustment SHALL be created.

#### Scenario: GoBD signature

- **GIVEN** a complete Tagesabschluss snapshot with approved persistence mapping is ready to commit
- **WHEN** the close is finalized
- **THEN** the system SHALL compute a SHA-256 signature over the approved canonical snapshot and store it as `signatur`
- **AND** the signed record SHALL be immutable.

#### Scenario: Double close prevention

- **GIVEN** a signed Tagesabschluss already exists for the selected company, cash account, and date
- **WHEN** another close is initiated for that account/date
- **THEN** the system SHALL open the existing record read-only
- **AND** SHALL NOT create a second close or reopen the signed record for editing.

#### Scenario: Concurrent finalization is serialized

- **GIVEN** two close requests target the same company/account/date
- **WHEN** the requests attempt finalization concurrently
- **THEN** the transaction guard SHALL persist at most one signed close
- **AND** any later request SHALL return the existing record read-only.

#### Scenario: Ambiguous legacy close identity

- **GIVEN** an unsigned legacy close, multiple close rows, or ambiguous legacy identity matches the selected company/account/date
- **WHEN** finalization is requested
- **THEN** the system SHALL return an unverified-history state
- **AND** SHALL NOT sign or add a close until a separately approved history correction resolves the ambiguity.

#### Scenario: Expected cash source is unavailable

- **GIVEN** no approved close use case is registered or its result is incomplete, ambiguous, or unverified
- **WHEN** the user attempts to finalize a Tagesabschluss
- **THEN** the system SHALL show a localized unavailable state
- **AND** SHALL NOT persist a close, calculate a fallback amount, or generate a PDF.
