## MODIFIED Requirements

### Requirement: Tagesabschluss PDF

The system SHALL generate a daily cash close PDF (Tagesabschluss) only from a complete account/date result and one stored version-1 `zaehlung_json` snapshot whose canonical UTF-8 SHA-256 `integrity_hash` has been verified under the accounting contract. The opening source SHALL be supplied by `account-opening-balance-source` after its v24 contract receives fresh independent approval and is implemented; until then PDF generation SHALL remain unavailable. The PDF SHALL show the date, explicit company and cash account, expected amount, actual counted amount, counted-minus-expected difference, explanation, currency, and source reference from that stored snapshot only. It SHALL NOT query or sum journal rows, derive a balance or difference, recalculate tax, reinterpret legacy fields, alter the close, or create accounting effects. The digest SHALL be described only as an integrity check and SHALL NOT be represented as an authenticated signature, signer identity, or proof that a person approved the close. PDF generation SHALL remain unavailable when the source result, snapshot, or digest is absent, unknown, malformed, changed, or unverified.

#### Scenario: Tagesabschluss generation

- **GIVEN** `account-opening-balance-source` is independently approved and implemented at v24, and one finalized close has a complete account/date result and a stored version-1 snapshot matching its integrity digest
- **WHEN** the Tagesabschluss PDF is rendered
- **THEN** the PDF SHALL show the date, expected amount, actual counted amount, counted-minus-expected difference, company, cash account, currency, source reference, and explanation from the stored snapshot
- **AND** it SHALL describe the digest only as an integrity check without claiming signer identity or authentication.

#### Scenario: Counting discrepancy

- **GIVEN** a verified finalized close has a counted amount that differs from the expected amount
- **WHEN** the Tagesabschluss PDF is rendered
- **THEN** the discrepancy SHALL be prominently flagged using the stored expected, counted, and difference values
- **AND** PDF rendering SHALL NOT recalculate or post the difference.

#### Scenario: Incomplete or legacy close has no PDF

- **GIVEN** the v24 opening-source prerequisite is unapproved or unavailable, or a close is a legacy row, lacks required evidence or an integrity digest, or has an unavailable/unverified balance source
- **WHEN** PDF generation is requested
- **THEN** generation SHALL return a localized unavailable result
- **AND** no incomplete PDF artifact SHALL be written.

#### Scenario: Changed snapshot has no PDF

- **GIVEN** a stored snapshot is malformed, has an unsupported version, is not in canonical form, or its digest does not match
- **WHEN** PDF generation is requested
- **THEN** the close SHALL be reported as unverified and PDF generation SHALL be rejected
- **AND** no artifact SHALL be created from the changed values.
