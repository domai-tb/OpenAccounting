## ADDED Requirements

### Requirement: Cash-basis EÜR settlement timing

For ordinary cash-basis items, the EÜR SHALL recognize invoice income only for amounts actually received and expenses only for amounts actually paid, using the settlement date and settled portion. The authoritative settlement date is the bank booking/value date for imported transactions and the manual payment date for cash; the reconciliation-confirmation date SHALL NOT be used, and the date is preserved verbatim from allocation to report. Each settled portion SHALL inherit the invoice's persisted category/`euer_zeile`/tax proportions in integer cents under the approved money-contract remainder rule. Direct cash receipts/expenses posted as settlement events SHALL be recognized on their settlement date. Write-offs SHALL NOT be recognized as operating receipts and follow the maintained write-off contract; customer-overpayment excess and supplier credits SHALL be classified per the maintained receivables contract; refunds and corrections SHALL be recognized only via their own settlement or correction records; reversed settlements SHALL be reclassified in the reversal period. Rows carrying the `legacy_unverified` marker SHALL be excluded from settlement-based totals. Invoice issue date alone SHALL NOT recognize unpaid income. Any statutory timing exception SHALL be applied only through an explicit, auditable tax-period rule carrying rule id/version, legal basis, affected year, approver, and source trace. The existing separate Soll-principle input-tax claim timing SHALL remain independent of cash-basis settlement timing.

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

#### Scenario: Allocate a mixed-category partial settlement
- **GIVEN** an invoice with two persisted category/`euer_zeile`/tax proportions has a partial settlement of 40.00
- **WHEN** EÜR is generated for the settlement period
- **THEN** the 40.00 SHALL be split across those proportions in integer cents under the approved remainder rule
- **AND** each portion SHALL appear under its mapped `euer_zeile` with VAT following the persisted tax treatment

#### Scenario: Recognize a direct cash receipt without an invoice
- **GIVEN** a direct cash receipt settlement event of 25.00 exists with no linked invoice
- **WHEN** EÜR is generated for the settlement period
- **THEN** 25.00 SHALL be included as a cash-basis receipt on its settlement date

#### Scenario: Exclude a write-off from operating receipts
- **GIVEN** a receivable balance was written off under the maintained write-off contract
- **WHEN** EÜR is generated
- **THEN** the written-off amount SHALL NOT be counted as received income
- **AND** its expense treatment SHALL follow the write-off contract

#### Scenario: Classify an overpayment credit separately
- **GIVEN** a 120.00 receipt settled a 100.00 receivable with a 20.00 separately classified credit
- **WHEN** EÜR is generated for the settlement period
- **THEN** only the 100.00 applied portion SHALL be recognized as invoice income
- **AND** the 20.00 credit SHALL follow the maintained receivables-contract classification

#### Scenario: Reclassify a reversed settlement in the reversal period
- **GIVEN** a settlement recognized in April is reversed in May
- **WHEN** the May EÜR period is generated
- **THEN** May SHALL reflect the negative reclassification
- **AND** April SHALL remain unchanged

#### Scenario: Exclude legacy unverified rows from settlement totals
- **GIVEN** a period contains `legacy_unverified` journal rows
- **WHEN** settlement-based EÜR is generated
- **THEN** those rows SHALL be excluded from the settled totals
- **AND** generation SHALL fail closed when they mix with settlement data in an in-scope period
