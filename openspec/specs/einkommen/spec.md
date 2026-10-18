# Receivables and Income Monitoring

## Purpose
Receivables tracking with Forderungen table, dunning integration, and income monitoring.

## Requirements

### Requirement: Forderungen table for open items

The system SHALL maintain a `forderungen` table tracking open receivable/posting items with fields: `id`, `typ` (rechnung/rechnung_eingang/journal), `status` (offen/teilbezahlt/bezahlt/ausgebucht), `betrag` (remaining amount), `partner_typ` (kunde/lieferant), `partner_id`, `rechnung_id` (nullable FK), `journal_id` (nullable FK), `ausgleich_journal_id` (nullable FK for payment posting), `erstellt_am`, `aktualisiert_am`. The system SHALL create a Forderung automatically when an invoice is finalized and update it on payment.

#### Scenario: Forderung created on invoice finalization

GIVEN an outgoing invoice is finalized (status changed to final)
WHEN the finalization completes
THEN a Forderung of type `rechnung` with status `offen` SHALL be created
AND `betrag` SHALL equal the invoice total (brutto)
AND `partner_typ` SHALL be `kunde` with the customer's ID.

#### Scenario: Forderung updated on partial payment

GIVEN a Forderung with betrag=100.00 and status=offen
WHEN a payment of 50.00 is posted against it
THEN the Forderung `betrag` SHALL be updated to 50.00
AND `status` SHALL change to `teilbezahlt`.

#### Scenario: Forderung closed on full payment

GIVEN a Forderung with betrag=100.00 and status=teilbezahlt
WHEN a payment of 100.00 is posted against it
THEN the Forderung `status` SHALL change to `bezahlt`
AND `ausgleich_journal_id` SHALL reference the payment journal entry.

#### Scenario: Duplicate Forderung prevented

GIVEN an invoice already has a linked Forderung with status offen or teilbezahlt
WHEN the invoice is finalized again
THEN the system SHALL NOT create a second Forderung for the same invoice.

### Requirement: Überzahlungs-Protokoll (overpayment tracking)

When a payment exceeds the Forderung betrag, the system SHALL split the payment: the Forderung amount closes the receivable, and the excess creates a new journal entry recording the overpayment. The overpayment SHALL be visible in the customer's Kontokorrent and in the Forderungen list.

#### Scenario: Overpayment detected

GIVEN a Forderung with betrag=100.00
WHEN a payment of 120.00 is posted against it
THEN 100.00 SHALL close the Forderung (status `bezahlt`)
AND 20.00 SHALL be posted as a separate journal entry (overpayment/Einlage)
AND the Forderung `betrag` SHALL be 0.00.

#### Scenario: Overpayment in Kontokorrent

GIVEN a customer has an overpayment recorded
WHEN the customer's Kontokorrent is generated
THEN the overpayment SHALL appear as a credit line with type `ueberzahlung`
AND the running balance SHALL reflect the credit.

#### Scenario: Exact payment does not trigger overpayment

GIVEN a Forderung with betrag=100.00
WHEN a payment of exactly 100.00 is posted
THEN no overpayment journal entry SHALL be created.

### Requirement: Forderungsausfall (write-off)

The system SHALL support writing off uncollectible receivables. A write-off SHALL change the Forderung status to `ausgebucht`, create a journal entry debiting an expense category (Forderungsausfall), and clear the remaining betrag. Write-off SHALL require a reason (Grund) field.

#### Scenario: Write off receivable

GIVEN a Forderung with betrag=75.00 and status offen or teilbezahlt
WHEN the user clicks "Ausbuchen" and enters reason "Kunde zahlungsunfähig"
THEN the Forderung status SHALL change to `ausgebucht`
AND a journal entry SHALL be created with the write-off amount and reason
AND the Forderung betrag SHALL be set to 0.00.

#### Scenario: Write-off requires reason

GIVEN a Forderung with betrag=75.00
WHEN the user attempts to write off the Forderung without entering a reason
THEN the system SHALL prevent the action and display a validation error.

#### Scenario: Write-off of already-paid Forderung

GIVEN a Forderung with status=bezahlt and betrag=0.00
WHEN the user attempts to write off the Forderung
THEN the system SHALL display an error indicating the receivable is already settled.

### Requirement: Zufluss-Monitor (cash flow monitor)

The system SHALL provide a Zufluss-Monitor showing payments received (Einnahmen) and payments made (Ausgaben) over time. The monitor SHALL support two views: (1) Monat (calendar month aggregation) and (2) Leistungszeitraum (service period aggregation based on invoice `leistung_von`/`leistung_bis`). The default view SHALL be "Monat".

#### Scenario: Monthly view

GIVEN the Zufluss-Monitor is set to "Monat" view
WHEN the monitor loads
THEN it SHALL aggregate all journal entries by their `buchungsdatum` month
AND display income and expense bars per month.

#### Scenario: Service period view

GIVEN the Zufluss-Monitor is set to "Leistungszeitraum" view
WHEN the monitor loads
THEN it SHALL aggregate income entries by the invoice's `leistung_von`/`leistung_bis` period
AND entries without a linked invoice SHALL fall back to `buchungsdatum`.

#### Scenario: Period navigation

GIVEN the Zufluss-Monitor is displaying data for the current year
WHEN the user navigates to a different year
THEN the data SHALL refresh to show only entries within that year's range.

#### Scenario: Empty period shows no data

GIVEN the Zufluss-Monitor is set to "Monat" view
WHEN a month has no journal entries
THEN the monitor SHALL display zero values for both income and expenses in that month.

### Requirement: Kontokorrent (customer statement)

The system SHALL generate a Kontokorrent (customer statement) showing all invoices, payments, and balance per customer. The statement SHALL display a running balance (Saldo) that updates with each transaction. The Kontokorrent SHALL be filterable by date range and exportable as PDF.

#### Scenario: Generate Kontokorrent

GIVEN a customer has invoices and payments
WHEN the user opens the Kontokorrent for that customer
THEN the system SHALL list all invoices and payments in chronological order
AND display a running Saldo column.

#### Scenario: Kontokorrent date filter

GIVEN the user sets a date range of 2026-01-01 to 2026-06-30
WHEN the Kontokorrent is generated
THEN only transactions within that range SHALL be displayed
AND the opening and closing balances SHALL be calculated from entries outside the range.

#### Scenario: Kontokorrent for customer with no transactions

GIVEN a customer has no invoices or payments
WHEN the Kontokorrent is generated for that customer
THEN the system SHALL display an empty statement with a zero balance.

### Requirement: Verbindlichkeiten (payables)

The system SHALL track payables (Verbindlichkeiten) from incoming invoices (Eingangsrechnungen). A Forderung of type `rechnung_eingang` SHALL be created when an incoming invoice is recorded. Payment SHALL update the Forderung status. Overpayment to suppliers SHALL be handled symmetrically to customer overpayments.

#### Scenario: Payable created on incoming invoice

GIVEN an incoming invoice (Eingangsrechnung) is recorded
WHEN the invoice is saved
THEN a Forderung of type `rechnung_eingang` with status `offen` SHALL be created
AND `partner_typ` SHALL be `lieferant`.

#### Scenario: Payable payment

GIVEN a Forderung of type `rechnung_eingang` with betrag=200.00
WHEN a payment of 200.00 is posted against it
THEN the Forderung betrag SHALL decrease to 0.00
AND status SHALL update to `bezahlt`.

#### Scenario: Supplier overpayment creates credit

GIVEN a Forderung of type `rechnung_eingang` with betrag=100.00
WHEN a payment of 130.00 is posted against it
THEN 100.00 SHALL close the payable
AND 30.00 SHALL be posted as a separate journal entry (supplier credit).

### Requirement: Dashboard integration

The dashboard SHALL display open receivables and payables counts and totals in dedicated widgets. The Offene Rechnungen widget SHALL show the sum of all `offen`/`teilbezahlt` receivables. The Offene Verbindlichkeiten widget SHALL show the sum of all open payables.

#### Scenario: Dashboard widget reflects current state

GIVEN the dashboard loads
WHEN the widgets render
THEN the "Offene Rechnungen" widget SHALL display the count and total betrag of open receivables
AND the "Offene Verbindlichkeiten" widget SHALL display the count and total of open payables.

#### Scenario: Dashboard widgets update after payment

GIVEN a receivable with betrag=100.00 is open
WHEN the user posts a full payment and returns to the dashboard
THEN the "Offene Rechnungen" widget SHALL no longer include that receivable in its total.

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


### Requirement: Exactly-once mileage EÜR source recognition

The EÜR SHALL read a posted mileage trip through one mileage-specific source path in both legacy and settlement-based report modes. The generic journal query excludes non-null `source_kind`, and mileage has no cash settlement allocation, so the mileage reader SHALL identify the canonical group by `(source_kind = 'mileage_trip', source_id = trip UUID)` and require its stored event ID to match `mileage_trips.posting_event_id`. It SHALL include the group by trip date, exactly once per unique source, without requiring or creating a settlement allocation and without also processing its legs through generic journal or settlement totals. The two-leg group SHALL be structurally complete, balanced, and contain the expected expense and private-contribution roles. The expense debit SHALL use its immutable snapshotted EÜR line 71; the private-contribution credit SHALL use its immutable snapshotted EÜR line 107 and SHALL NOT be treated as operating income or profit. A missing, duplicate, unbalanced, malformed, or snapshot-incomplete group SHALL make the EÜR result unavailable or incomplete rather than partially counted. Journal snapshots SHALL preserve each leg's role, category ID and label, category `art`, EÜR line, category SKR mappings, mapping status, mapping source reference/version, and mapping-history ID. Mileage EÜR output SHALL use those stored values and SHALL NOT join current category or mapping-history values; later edits to categories SHALL NOT change historical output. Mileage source legs SHALL NOT create an input-VAT claim. Correction treatment SHALL follow its separately accepted atomic correction contract.

#### Scenario: Include a mileage trip exactly once in either EÜR mode
- **GIVEN** an in-period posted trip has one balanced two-leg group under `(mileage_trip, trip UUID)` with a matching posting-event ID and complete snapshots
- **WHEN** EÜR is generated in legacy or settlement-based mode
- **THEN** the expense debit appears once by trip date under its snapshotted EÜR line 71
- **AND** the private-contribution credit appears once under snapshotted line 107 but is excluded from operating income and profit
- **AND** neither leg is also processed through the generic journal or settlement path

#### Scenario: Mileage category edits do not rewrite historical EÜR output
- **GIVEN** a posted mileage group has category label, EÜR/SKR lines, and mapping provenance in immutable journal snapshots
- **WHEN** the mapped category is later edited or its current mapping history changes
- **THEN** generated EÜR output for that mileage group remains based on the stored snapshots

#### Scenario: Fail closed for an invalid mileage report group
- **GIVEN** an in-period mileage trip has a missing, duplicate, unbalanced, or snapshot-incomplete source group
- **WHEN** EÜR is generated
- **THEN** the report is unavailable or incomplete and does not partially count either leg
