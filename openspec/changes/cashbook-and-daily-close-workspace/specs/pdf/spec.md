## ADDED Requirements

### Requirement: Tagesabschluss PDF renders the verified stored snapshot

The Tagesabschluss PDF SHALL render its date, explicit company and cash account, expected amount, counted amount, counted-minus-expected difference, explanation, currency, and source reference only from one stored version-1 `zaehlung_json` snapshot after its canonical UTF-8 SHA-256 `integrity_hash` has been verified under the accounting contract. PDF generation SHALL NOT query or sum journal rows, derive a balance or difference, recalculate tax, reinterpret legacy fields, alter the close, or create accounting effects. New PDFs SHALL label the digest as an integrity check only and SHALL NOT claim that a person signed or authenticated the close. The PDF action SHALL remain unavailable when the source result, snapshot, or digest is absent, unknown, malformed, or unverified.

#### Scenario: Complete verified close produces its PDF

- **GIVEN** one finalized close has a complete account/date source result and its stored version-1 snapshot matches its integrity digest
- **WHEN** the user generates the Tagesabschluss PDF
- **THEN** the PDF SHALL render the values from that stored snapshot, including expected, counted, difference, account/date, currency, source reference, and explanation
- **AND** it SHALL describe the digest only as an integrity check and leave the close row unchanged.

#### Scenario: Incomplete or legacy close has no PDF

- **GIVEN** a close is a legacy row, lacks required evidence or an integrity digest, or has an unavailable/unverified balance source
- **WHEN** PDF generation is requested
- **THEN** generation SHALL return a localized unavailable result
- **AND** no incomplete PDF artifact SHALL be written.

#### Scenario: Changed snapshot has no PDF

- **GIVEN** a stored snapshot is malformed, has an unsupported version, is not in canonical form, or its digest does not match
- **WHEN** PDF generation is requested
- **THEN** the close SHALL be reported as unverified and PDF generation SHALL be rejected
- **AND** no artifact SHALL be created from the changed values.
