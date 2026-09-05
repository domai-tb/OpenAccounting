# Receivables and Income Monitoring

## ADDED Requirements

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
