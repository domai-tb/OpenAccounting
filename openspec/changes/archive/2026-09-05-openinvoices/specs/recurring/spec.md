# Recurring

## ADDED Requirements

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

Buchungsvorlagen SHALL support two modes: direkt (creates journal entry directly) and beleg (pre-fills an incoming invoice).

#### Scenario: Direkt mode

GIVEN a Buchungsvorlage has modus "direkt"
WHEN the scheduled date arrives
THEN a journal entry is created automatically.

#### Scenario: Beleg mode

GIVEN a Buchungsvorlage has modus "beleg"
WHEN the scheduled date arrives
THEN a Rechnung draft is created with pre-filled fields.

### Requirement: Buchungsvorlage Art

Buchungsvorlagen SHALL have art field: Einnahme or Ausgabe, determining USt direction (Vorsteuer vs Umsatzsteuer).

#### Scenario: Ausgabe direction

GIVEN a Buchungsvorlage has art "Ausgabe"
WHEN a journal entry is generated
THEN USt is booked as Vorsteuer (KZ 66).

#### Scenario: Einnahme direction

GIVEN a Buchungsvorlage has art "Einnahme"
WHEN a journal entry is generated
THEN USt is booked as Umsatzsteuer (KZ 81).

### Requirement: Buchungsvorlage Auto-Generation

The system SHALL automatically create journal entries from active Buchungsvorlagen on schedule.

#### Scenario: Auto-generate journal entry

GIVEN a Buchungsvorlage is active and scheduled date is today
WHEN the generation cycle runs
THEN a journal entry is created with correct USt direction.

#### Scenario: Inactive template skipped

GIVEN a Buchungsvorlage is pausiert (aktiv=false)
WHEN the generation cycle runs
THEN no journal entry is created.

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
