# Recurring

## Purpose
Rechnungsvorlagen lifecycle for recurring invoice generation with scheduling and draft automation.

## Requirements

### Requirement: Rechnungsvorlagen Lifecycle

The system SHALL support three template states: aktiv (laufend), pausiert, beendet.

#### Scenario: Activate template

GIVEN the user is creating a new Rechnungsvorlage
WHEN they save with interval "monatlich"
THEN status is aktiv and first generation is scheduled.

#### Scenario: Pause template

GIVEN an active Rechnungsvorlage exists
WHEN the user pauses it
THEN generation stops and template retains its positionen.

#### Scenario: End template

GIVEN an active or paused Rechnungsvorlage exists
WHEN the user ends it
THEN status becomes beendet, no further generation occurs, and template is retained for history.

### Requirement: Invoice Generation Interval

Rechnungsvorlagen SHALL support intervals: monatlich, quartalsweise, jährlich.

#### Scenario: Monthly generation

GIVEN a template with interval "monatlich"
WHEN today is the 1st of the month
THEN a new Rechnung is generated.

#### Scenario: Quarterly generation

GIVEN a template with interval "quartalsweise"
WHEN today is Jan 1, Apr 1, Jul 1, or Oct 1
THEN a new Rechnung is generated.

#### Scenario: Yearly generation

GIVEN a template with interval "jährlich"
WHEN today matches the template creation date month+day
THEN a new Rechnung is generated.

### Requirement: Invalid Interval Rejection

The system SHALL reject templates with intervals not in (monatlich, quartalsweise, jährlich).

#### Scenario: Invalid interval

GIVEN the user is creating a Rechnungsvorlage
WHEN they select interval "wöchentlich"
THEN the system shows a validation error and rejects save.

#### Scenario: Empty interval

GIVEN the user is creating a Rechnungsvorlage
WHEN they leave the interval field empty
THEN the system shows a validation error and rejects save.

### Requirement: Template Positionen as JSON

The system SHALL store template positions as JSON array with fields: artikel_id, bezeichnung, menge, einzelpreis, kategorie_id.

#### Scenario: Save template with positions

GIVEN the user adds 2 positions to a template
WHEN they save the template
THEN positions are stored as JSON and used for generation.

#### Scenario: Save template with no positions

GIVEN the user creates a template with 0 positions
WHEN they save the template
THEN an empty JSON array is stored and a warning is shown that no items will be generated.

### Requirement: Price Comparison via Artikel

The system SHALL compare template position prices against current `artikel.vk_brutto` at generation time.

#### Scenario: Price mismatch warning

GIVEN a template position has 10€ and current artikel.vk_brutto is 12€
WHEN generation runs
THEN the system warns the user of the price difference.

#### Scenario: Price matches

GIVEN a template position has 10€ and current artikel.vk_brutto is 10€
WHEN generation runs
THEN no price warning is shown and the invoice uses the template price.

### Requirement: Auftrag-Verknüpfung

Rechnungsvorlagen SHALL link to an Auftrag via `auftrag_id` FK. Status syncs between template and order.

#### Scenario: Template linked to order

GIVEN a template is linked to Auftrag A-2026-001 and Auftrag status is "laufend"
WHEN a new Rechnung is generated from the template
THEN the generated invoice inherits the order link.

#### Scenario: Order completed clears template

GIVEN an Auftrag has status "abgeschlossen" and all linked templates are beendet
WHEN the system checks Auftrag status
THEN the Auftrag status remains abgeschlossen.

### Requirement: Auto-Generation from Templates

The system SHALL automatically generate Rechnungen from active templates on schedule during app startup or via cron.

#### Scenario: Auto-generate on startup

GIVEN a template is active and its scheduled date is today or earlier
WHEN the app starts
THEN a new Rechnung is generated.

#### Scenario: Missed generation

GIVEN a template was inactive for 3 months and is reactivated
WHEN the system runs generation
THEN it generates backdated invoices for missed months.

### Requirement: Generated Invoice Tracking

Each generated Rechnung SHALL have `vorlage_id` FK linking back to the generating template.

#### Scenario: View generated invoices

GIVEN a template has generated at least one Rechnung
WHEN the user opens the template detail
THEN they see a list of all generated invoices with status.

#### Scenario: Template with no generated invoices

GIVEN a template has never generated an invoice
WHEN the user opens the template detail
THEN the generated invoices list is empty.

### Requirement: Buchungsvorlagen for Fixed Costs

The system SHALL support Buchungsvorlagen for recurring journal entries (fixed costs/revenue).

#### Scenario: Create booking template

GIVEN the user is on the Buchungsvorlagen screen
WHEN they create a Buchungsvorlage with interval "monatlich", art "Ausgabe", kategorie "Miete"
THEN it generates monthly journal entries.

#### Scenario: Delete booking template

GIVEN a Buchungsvorlage exists with no generated journal entries
WHEN the user deletes it
THEN the template is removed and no future entries are generated.

### Requirement: Buchungsvorlage Modus

Buchungsvorlagen SHALL support two configured modes: `direkt` for a due instance that can be reviewed and then submitted through the accepted shared accounting posting boundary, and `beleg` for a reviewed handoff to the incoming-invoice draft workflow. Schedule detection SHALL NOT itself write a journal entry, input-tax claim, or finalized invoice. Direct mode MUST remain pending without financial side effects until the shared posting contract is accepted and available. Beleg mode MAY create only a draft through its owning use case, supplying the occurrence identity `(vorlage_id, faelligkeit)` as its idempotency source with at most one linked draft per occurrence; finalization and any financial effect remain governed by the invoice and accounting contracts.

#### Scenario: Direkt mode
- **GIVEN** a `direkt` template has a due instance
- **WHEN** the schedule is detected
- **THEN** the due instance is available for review and no journal entry or input-tax claim is created

#### Scenario: Beleg mode
- **GIVEN** a `beleg` template has a due instance
- **WHEN** the user reviews it and requests draft creation
- **THEN** the existing incoming-invoice draft use case receives the template data with the occurrence identity and no journal entry is created

#### Scenario: Beleg retry reuses the linked draft
- **GIVEN** a `beleg` occurrence already links a draft, including a draft created before the link was saved
- **WHEN** draft creation is requested again for the same occurrence
- **THEN** the existing draft found by occurrence identity is reused and no second draft is created

#### Scenario: Financial effect is blocked without the shared contract
- **GIVEN** a `direkt` due instance has not been submitted through an accepted shared posting contract
- **WHEN** execution is requested
- **THEN** the occurrence remains pending and no journal row, input-tax claim, or finalized invoice is created

### Requirement: Buchungsvorlage Art

Buchungsvorlagen SHALL store and display `art` as the configured `Einnahme` or `Ausgabe` classification. This classification alone MUST NOT create a posting, choose debit/credit accounts, calculate VAT, or create an input-tax claim. Financial and tax effects SHALL be determined only by the accepted shared posting and tax contracts.

#### Scenario: Ausgabe direction
- **GIVEN** a template is configured as `Ausgabe`
- **WHEN** its due instance is displayed for review
- **THEN** the instance shows `Ausgabe` and no VAT amount, account effect, or financial event is inferred from the type alone

#### Scenario: Einnahme direction
- **GIVEN** a template is configured as `Einnahme`
- **WHEN** its due instance is displayed for review
- **THEN** the instance shows `Einnahme` and no VAT amount, account effect, or financial event is inferred from the type alone

#### Scenario: Reject an unresolved tax or account interpretation
- **GIVEN** the shared contracts do not define the required tax or account effect for a template
- **WHEN** a user attempts to execute its due instance
- **THEN** execution remains pending and no journal entry or input-tax claim is created

### Requirement: Buchungsvorlage Auto-Generation

The system SHALL identify due occurrences from an active Buchungsvorlage's stored schedule and expose them as durable review instances. The schedule scan MUST NOT automatically create journal entries, input-tax claims, or finalized invoices. A scan or review SHALL NOT advance the stored next due date. Only a completed posting (`posted`) or draft link (`handed_off`) SHALL advance it, by one interval step computed from the prior stored date with month-end clamping: monthly advances one calendar month, quarterly three months, yearly twelve months (31 Jan monthly → 28/29 Feb; 29 Feb yearly → 28 Feb in non-leap years). Overdue templates SHALL expose only the single oldest uncompleted occurrence; the next period becomes eligible only after that occurrence completes. Failed or blocked attempts SHALL leave the stored date unchanged. A reviewed direct-mode instance may create a financial event only through the accepted shared posting contract after explicit user confirmation. Repeated schedule scans SHALL reuse the same occurrence identity. Inactive templates SHALL produce no new actionable occurrence.

#### Scenario: Auto-generate journal entry
- **GIVEN** a Buchungsvorlage is active and its stored next due date is due
- **WHEN** the due-instance workflow runs
- **THEN** one durable review instance is available for that template and due date, with no financial event created

#### Scenario: Repeated scan is idempotent
- **GIVEN** a due review instance already exists for a template and due date
- **WHEN** the due-instance workflow runs again for the same date
- **THEN** it reuses the same occurrence and does not create a duplicate instance or financial event

#### Scenario: Inactive template skipped
- **GIVEN** a Buchungsvorlage is paused (`aktiv=false`)
- **WHEN** the due-instance workflow runs
- **THEN** no new actionable occurrence or financial event is created

#### Scenario: Missing posting contract blocks execution
- **GIVEN** an active template has a due review instance but the accepted shared posting contract is unavailable
- **WHEN** the due-instance workflow runs
- **THEN** the instance remains pending and no journal entry or input-tax claim is created

#### Scenario: Successful completion advances by one interval step
- **GIVEN** a due occurrence has reached `posted` or `handed_off`
- **WHEN** the schedule update is recorded
- **THEN** the template stored date advances by exactly one interval step from its prior stored date and no financial event is created by the advancement itself

#### Scenario: Overdue catch-up exposes one instance at a time
- **GIVEN** a template is overdue by multiple periods with its oldest occurrence still uncompleted
- **WHEN** the due-instance workflow runs
- **THEN** only that oldest occurrence is actionable and the next period becomes eligible only after it completes

#### Scenario: Month-end date clamps to the shorter month
- **GIVEN** a monthly template has stored due date 31 Jan
- **WHEN** its occurrence completes
- **THEN** the next stored date is 28 Feb (29 Feb in a leap year)

#### Scenario: Failed attempt does not advance the schedule
- **GIVEN** a due occurrence attempt is blocked or fails
- **WHEN** the failure is recorded with its durable reason
- **THEN** the template stored date is unchanged and the same occurrence remains retryable

### Requirement: Supplier and Account Linking

Buchungsvorlagen SHALL optionally link to a Lieferant and/or Konto.

#### Scenario: Linked supplier

GIVEN a Buchungsvorlage has lieferant_id set
WHEN a journal entry is generated
THEN the generated entry inherits the supplier reference.

#### Scenario: Linked account

GIVEN a Buchungsvorlage has konto_id set
WHEN a journal entry is generated
THEN the generated entry uses the specified bank account for DATEV export.

### Requirement: Template Edit Propagation

Editing a Rechnungsvorlage SHALL NOT affect already-generated invoices; changes apply only to future generations.

#### Scenario: Edit template price

GIVEN a template has position priced at 10€ and 3 invoices were already generated at 10€
WHEN the user changes position price to 15€
THEN existing generated invoices retain 10€ and next generation uses 15€.

#### Scenario: Edit template interval

GIVEN a template has interval "monatlich" and invoices were generated monthly
WHEN the user changes interval to "quartalsweise"
THEN existing invoices are unchanged and future generation follows the new interval.

### Requirement: Template Deletion Protection

The system SHALL prevent deletion of templates that have generated invoices (vorlage_id referenced in rechnungen).

#### Scenario: Attempt delete with invoices

GIVEN a template has 5 generated invoices
WHEN the user tries to delete it
THEN the operation is rejected with count of linked invoices.

#### Scenario: Delete template without invoices

GIVEN a template has 0 generated invoices
WHEN the user deletes it
THEN the template is removed successfully.
