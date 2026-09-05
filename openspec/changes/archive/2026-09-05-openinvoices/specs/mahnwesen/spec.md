# Mahnwesen

## ADDED Requirements

### Requirement: Four Dunning Levels

The system SHALL define 4 standard Mahnstufen: "Mahnung 1", "Mahnung 2", "Mahnung 3", "Letzte Mahnung vor Inkasso".

#### Scenario: Standard levels exist

GIVEN the system initializes with a fresh database
WHEN the seed runs
THEN all 4 standard levels are created with system_stufe = true.

#### Scenario: User cannot delete system level

GIVEN a standard level with system_stufe = true exists
WHEN the user attempts to delete it
THEN the operation is rejected with an error indicating system levels are protected.

### Requirement: Dunning Level Configuration

Each Mahnstufe SHALL have: name, Mahngebühr (fixed amount), Verzugszinsen (percentage), multiplier flag (whether fees multiply from previous levels).

#### Scenario: Configure level with multiplier

GIVEN level 2 has open Mahngebühr=10€ and level 3 has multiplier=true
WHEN level 3 Mahngebühr is calculated
THEN level 3 Mahngebühr includes the 10€ from level 2.

#### Scenario: Configure level without multiplier

GIVEN level 3 has multiplier=false
WHEN level 3 Mahngebühr is calculated
THEN level 3 Mahngebühr uses only its own configured amount, ignoring prior levels.

### Requirement: System Level Protection

The system SHALL flag standard levels with `system_stufe = true`. These MUST NOT be deletable, only editable (name, amounts).

#### Scenario: Edit system level amounts

GIVEN "Mahnung 1" is a system level with Mahngebühr=5€
WHEN the user changes Mahngebühr to 10€
THEN the change applies to new dunning letters created after the edit.

#### Scenario: Attempt to delete system level

GIVEN "Mahnung 1" has system_stufe = true
WHEN the user attempts to delete it
THEN the system rejects the operation and displays a protection message.

### Requirement: Mahnung Snapshot

Each created Mahnung SHALL snapshot the rechnung data at creation time: Rechnungsnummer, Betrag, Fälligkeitsdatum, Mahnstufe.

#### Scenario: Create dunning letter

GIVEN Rechnung R-2026-001 has outstanding amount 500€
WHEN a Mahnung is created for that Rechnung
THEN a snapshot stores current Rechnung fields at that moment.

#### Scenario: Rechnung changes after snapshot

GIVEN a Mahnung was created for Rechnung R-2026-001 with snapshot data
WHEN Rechnung R-2026-001 is edited (e.g., amount changed to 600€)
THEN the Mahnung retains original snapshot data, not the updated values.

### Requirement: Mahngebühr Tracking

The system SHALL track Mahngebühr as two fields: `mahngebuehr_bezahlt` and `mahngebuehr_unbezahlt` per Mahnung.

#### Scenario: Partial payment of fee

GIVEN a Mahnung has Mahngebühr=10€
WHEN the user records 5€ paid
THEN mahngebuehr_bezahlt=5 and mahngebuehr_unbezahlt=5.

#### Scenario: Full payment of fee

GIVEN a Mahnung has Mahngebühr=10€
WHEN the user records 10€ paid
THEN mahngebuehr_bezahlt=10 and mahngebuehr_unbezahlt=0.

### Requirement: Verzugszinsen Tracking

The system SHALL track Verzugszinsen as `verzugszinsen_bezahlt` and `verzugszinsen_unbezahlt` per Mahnung.

#### Scenario: Interest calculation

GIVEN Rechnung has 1000€ outstanding for 30 days and level rate=8%
WHEN the system calculates Verzugszinsen
THEN Verzugszinsen = 1000 × 0.08 × 30/365 ≈ 6.58€.

#### Scenario: Zero outstanding amount

GIVEN a Rechnung has 0€ outstanding
WHEN the system calculates Verzugszinsen
THEN Verzugszinsen = 0€.

### Requirement: Fee/Interest Carry-Over

The system SHALL carry over open Mahngebühr and Verzugszinsen from previous Mahnstufen into the newest Mahnung.

#### Scenario: Carry-over on new dunning

GIVEN level 2 has open Mahngebühr=10€ and open Verzugszinsen=3€
WHEN level 3 is created for the same Rechnung
THEN level 3 shows carried amounts from level 2.

#### Scenario: No carry-over when fully paid

GIVEN level 2 has Mahngebühr=10€ fully paid and Verzugszinsen=3€ fully paid
WHEN level 3 is created
THEN level 3 shows 0€ carried amounts.

### Requirement: Mail-Versand via SMTP

The system SHALL send dunning letters via configured SMTP with PDF attachment.

#### Scenario: Send dunning letter

GIVEN SMTP is configured and a Mahnung has a generated PDF
WHEN the user clicks "Senden"
THEN the system attaches the PDF and sends via SMTP.

#### Scenario: SMTP not configured

GIVEN SMTP is not configured
WHEN the user attempts to send a Mahnung
THEN the system displays a configuration hint and blocks the send.

### Requirement: Configurable Attachments Per Level

Each Mahnstufe SHALL allow attaching: Rechnung, bisherige Mahnungen, Kontokorrent as PDF attachments.

#### Scenario: Configure attachments

GIVEN level 2 has "Rechnung" and "bisherige Mahnungen" enabled
WHEN sending level 2
THEN the email includes both attachment types as PDF.

#### Scenario: No attachments configured

GIVEN a Mahnstufe has all attachment types disabled
WHEN sending that level
THEN the email contains only the dunning letter body without additional PDFs.

### Requirement: Customer Blocking (Kundensperrung)

The system SHALL support two-threshold customer blocking: `warnung_ab_stufe` (dashboard warning) and `sperrung_ab_stufe` (blocks new invoices).

#### Scenario: Warning threshold

GIVEN a customer has warnung_ab_stufe set to level 2
WHEN the customer reaches dunning level 2
THEN dashboard shows warning widget for that customer.

#### Scenario: Blocking threshold

GIVEN a customer has sperrung_ab_stufe set to level 3
WHEN the customer reaches dunning level 3
THEN new invoice creation for that customer is blocked with error message.

### Requirement: Manual Customer Block (Mahnsperre)

The system SHALL allow manual per-customer blocking with reason and optional end date.

#### Scenario: Set manual block

GIVEN a customer exists
WHEN user sets Mahnsperre with reason "Streitfall" and date 2026-12-31
THEN no dunning runs for that customer until the date.

#### Scenario: Manual block without date

GIVEN a customer exists
WHEN user sets Mahnsperre without end date
THEN block persists until manually removed.

#### Scenario: Block expires automatically

GIVEN a customer has Mahnsperre until 2026-12-31
WHEN the date 2027-01-01 is reached
THEN the block is automatically lifted and dunning can resume.

### Requirement: Dunning Audit Trail

The system SHALL maintain complete history of all dunning actions: created, sent, paid, escalated, blocked.

#### Scenario: View dunning history

GIVEN at least one dunning action has occurred for a customer
WHEN user opens Mahnung history for that customer
THEN they see chronological list of all dunning events.

#### Scenario: Empty history

GIVEN a customer has no dunning history
WHEN user opens Mahnung history
THEN the system displays an empty-state message.

### Requirement: Invoice Dunning Level

Each Rechnung SHALL have `mahnstufe_aktuell` field tracking its current dunning level.

#### Scenario: Invoice at level 2

GIVEN Rechnung R-2026-001 has no prior dunning
WHEN the second dunning letter is sent
THEN mahnstufe_aktuell is set to level 2 id.

#### Scenario: Invoice payment resets level

GIVEN Rechnung R-2026-001 has mahnstufe_aktuell = level 3
WHEN the Rechnung is fully paid
THEN mahnstufe_aktuell is cleared (set to NULL).

### Requirement: Dashboard Overdue Widget

The system SHALL display a dashboard widget showing overdue invoices grouped by dunning level.

#### Scenario: Overdue widget shows data

GIVEN there are invoices past due
WHEN the user opens the dashboard
THEN the widget shows count and total per Mahnstufe.

#### Scenario: No overdue invoices

GIVEN all invoices are paid or not yet due
WHEN the user opens the dashboard
THEN the widget displays an empty state indicating no overdue invoices.

### Requirement: Mahnwesen Settings Singleton

The system SHALL store dunning settings in a singleton table: initial_grace_days, email_template, default_interest_rate.

#### Scenario: Configure grace period

GIVEN the dunning settings singleton exists
WHEN user sets grace period to 14 days
THEN invoices are not dunned until 14 days past due.

#### Scenario: Default settings on fresh install

GIVEN a fresh database with no dunning settings
WHEN the system initializes
THEN default values are created (e.g., grace_days=0, default_interest_rate=0%).

### Requirement: Dunning Letter PDF Generation

The system SHALL generate PDF dunning letters with: company header, customer address, Rechnung details, Mahngebühr, Verzugszinsen, total due, payment deadline.

#### Scenario: Generate PDF

GIVEN a Mahnung exists with all required data
WHEN user clicks "PDF erstellen"
THEN a PDF is generated with all required fields and available for download/print.

#### Scenario: Missing company data

GIVEN company header data is incomplete (e.g., no address)
WHEN user clicks "PDF erstellen"
THEN the system displays a warning about missing fields and generates the PDF with placeholders.

### Requirement: Custom Dunning Levels

The system SHALL allow users to add custom Mahnstufen beyond the 4 standard levels.

#### Scenario: Add custom level

GIVEN the 4 standard levels exist
WHEN user creates "Mahnung 4 - Inkasso-Vorbereitung"
THEN it appears in the level list and can be used for dunning.

#### Scenario: Custom level is deletable

GIVEN a custom level "Mahnung 4 - Inkasso-Vorbereitung" exists
WHEN the user deletes it
THEN the level is removed and no longer available for dunning.
