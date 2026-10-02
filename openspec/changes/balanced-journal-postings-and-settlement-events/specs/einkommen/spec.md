## ADDED Requirements

### Requirement: Cash-basis EÜR settlement timing

For ordinary cash-basis items, the EÜR SHALL recognize invoice income only for amounts actually received and expenses only for amounts actually paid, using the settlement date and settled portion. Invoice issue date alone SHALL NOT recognize unpaid income. Any statutory timing exception SHALL be applied only through an explicit, auditable tax-period rule. The existing separate Soll-principle input-tax claim timing SHALL remain independent of cash-basis settlement timing.

#### Scenario: Include an ordinary receipt in its settlement period
- **GIVEN** an invoice is issued in March and 40.00 is received on April 2
- **WHEN** the April EÜR period is generated
- **THEN** 40.00 SHALL be included in April receipts
- **AND** the unpaid remainder SHALL remain excluded until received

#### Scenario: Exclude an unpaid invoice
- **GIVEN** an invoice is issued but has no settled payment
- **WHEN** the EÜR is generated for the invoice period
- **THEN** the invoice amount SHALL NOT be counted as received income

#### Scenario: Split a settlement across reporting periods
- **GIVEN** two portions of one invoice are received on different dates
- **WHEN** EÜR periods containing those dates are generated
- **THEN** each period SHALL include only the portion settled in that period
- **AND** their combined recognized amount SHALL equal the total settled amount

#### Scenario: Keep input-tax claim timing independent
- **GIVEN** an eligible input-tax claim exists before its supplier invoice is paid
- **WHEN** EÜR and UStVA are computed for the claim period
- **THEN** the EÜR expense SHALL follow the recorded payment date
- **AND** the UStVA SHALL continue to use the separate approved claim date/basis

#### Scenario: Apply an approved statutory timing exception
- **GIVEN** a regularly recurring income or expense qualifies for a statutory year-boundary timing rule and has an audited rule result
- **WHEN** EÜR is generated for the affected year
- **THEN** the item SHALL be included in the legally attributed year
- **AND** the report SHALL retain a trace to the settlement and timing rule result

#### Scenario: Do not infer an exception
- **GIVEN** a year-boundary settlement lacks an approved statutory timing-rule result
- **WHEN** EÜR is generated
- **THEN** the item SHALL remain assigned by its actual settlement date
- **AND** no timing exception SHALL be inferred from its description alone
