## ADDED Requirements

### Requirement: Tagesabschluss PDF renders the finalized snapshot

The Tagesabschluss PDF SHALL render date, cash account, expected amount, actual counted amount, discrepancy result, explanation, and signature from one complete finalized `tagesabschluesse` snapshot and its `zaehlung_json`. PDF generation SHALL NOT query or sum journal rows, derive a balance or discrepancy, recalculate tax, alter the source close, or create accounting effects. The action SHALL remain unavailable when the close lacks a verified source result, required evidence, or signature.

#### Scenario: Complete signed close produces its PDF

- **GIVEN** a finalized signed close contains the approved expected result, actual count, discrepancy result, explanation, account/date, and count evidence
- **WHEN** the user generates the Tagesabschluss PDF
- **THEN** the PDF SHALL render those values and the stored signature from that close snapshot
- **AND** the close row SHALL remain unchanged.

#### Scenario: Incomplete or unsigned close has no PDF

- **GIVEN** a close is unsigned, lacks required evidence, or has an unavailable/unverified expected-balance source
- **WHEN** PDF generation is requested
- **THEN** generation SHALL return a localized unavailable result
- **AND** no incomplete PDF artifact SHALL be written.
