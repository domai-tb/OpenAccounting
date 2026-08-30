# Documents — OpenInvoices Spec

## ADDED Requirements

### Requirement: Document Types

The system SHALL support exactly seven document types: Rechnung (invoice), Storno (storno invoice), Gutschrift (credit note), Angebot (quote/proposal), Auftrag (work order), Proforma (pro forma invoice), and Lieferschein (delivery note). Each type has its own number range, PDF template, and lifecycle rules.

#### Scenario: All types have number ranges
- GIVEN the system starts for the first time with a fresh database
- WHEN the seed process completes
- THEN number ranges exist for all seven document types plus debitor and kreditor

#### Scenario: Unknown document type rejected
- GIVEN the system supports exactly seven document types
- WHEN an API call references a document type not in the supported set
- THEN the system returns an error "Unbekannter Dokumenttyp"

### Requirement: Document Lifecycle — Entwurf

Every document MUST begin in Entwurf (draft) state with ist_entwurf = true. Drafts MUST be fully editable: fields can be changed, positions added/removed, and the document can be deleted. Drafts MUST NOT appear in financial reports (EÜR, UStVA, EKS), MUST NOT affect stock levels, and MUST NOT be sent to customers. Only Rechnung, Angebot, Auftrag, and Proforma support draft mode; Lieferschein and Storno are created finalized.

#### Scenario: Draft not in EÜR
- GIVEN a Rechnung in Entwurf state has a total of 5000 EUR
- WHEN the Eür report is generated
- THEN this Rechnung is not included in the report

#### Scenario: Draft editable
- GIVEN a user opens a draft Rechnung
- WHEN the user modifies positions, dates, and text fields
- THEN all changes are saved and the document remains in Entwurf state

#### Scenario: Lieferschein created without draft state
- GIVEN a user creates a new Lieferschein
- WHEN the Lieferschein is saved
- THEN ist_entwurf is false and the document is finalized immediately (no draft mode)

### Requirement: Document Lifecycle — Finalization

Finalization is an irreversible action that MUST: set ist_entwurf to false, assign a nummer from the nummernkreis, lock all fields against further editing, generate the PDF, store the Absender_snapshot (company data at finalization time), and record ausgegeben_am (first print/email timestamp). Finalization MUST be confirmed by the user via a confirmation dialog.

#### Scenario: Finalization locks document
- GIVEN a user finalizes a draft Rechnung
- WHEN finalization completes
- THEN the nummer is assigned, ist_entwurf becomes false, all form fields become read-only, and the PDF is generated and stored

#### Scenario: Finalization captures company snapshot
- GIVEN a Rechnung is in draft state and company address is "Musterstraße 1"
- WHEN the Rechnung is finalized
- THEN absender_snapshot contains the company address "Musterstraße 1", and a subsequent company address change does not affect the finalized PDF

#### Scenario: Re-finalization blocked
- GIVEN a Rechnung has been finalized (ist_entwurf = false)
- WHEN a user attempts to finalize it again
- THEN the system rejects the action with error "Dokument ist bereits finalisiert"

### Requirement: Document Lifecycle — Bezahlt

A finalized Rechnung, Gutschrift, or Storno can be marked as Bezahlt (paid). The system MUST record zahlungsdatum (payment date), zahlungsbetrag (paid amount), and optionally link to a journal entry. When zahlungsbetrag exceeds the invoice total, the system MUST handle Überzahlung (see Überzahlung handling).

#### Scenario: Full payment
- GIVEN a finalized Rechnung with total 1000 EUR
- WHEN a user marks it as paid with zahlungsbetrag = 1000
- THEN zahlungsstatus becomes "bezahlt", zahlungsdatum is set, and a journal entry is created

#### Scenario: Partial payment keeps status open
- GIVEN a finalized Rechnung with total 1000 EUR
- WHEN a user marks it as paid with zahlungsbetrag = 500
- THEN zahlungsstatus remains "teilweise bezahlt" and the outstanding 500 EUR is tracked

### Requirement: Storno

A finalized Rechnung or Gutschrift can be storniert (cancelled). Storno MUST: create a new Stornorechnung document with negative amounts, require a storno_grund (VARCHAR(500), mandatory), set storno_datum to the current date, assign a nummer from the stornorechnung number range, link to the original via storno_rechnungsnummer, and restore any stock that was decremented. The Stornorechnung PDF MUST display title "Stornorechnung", show the storno_datum, original date, negative amounts, and MUST NOT include a payment block. The original document MUST remain visible but marked as storniert.

#### Scenario: Storno with stock restoration
- GIVEN a Rechnung with 10 units of an article (stock was 20, now 10 after finalization)
- WHEN the Rechnung is storniert
- THEN the Stornorechnung is created, stock for the article is restored to 20, and the original Rechnung shows "Storniert" badge

#### Scenario: Storno requires reason
- GIVEN a finalized Rechnung exists
- WHEN a user attempts to storno it without entering a storno_grund
- THEN the system blocks the action with error "Stornogrund ist Pflicht"

#### Scenario: Storno of already-storned invoice blocked
- GIVEN a Rechnung has already been storniert (storno_datum is set)
- WHEN a user attempts to storno it again
- THEN the system rejects the action with error "Rechnung ist bereits storniert"

### Requirement: Gutschrift

A Gutschrift (credit note) can be created from a finalized Rechnung or as a standalone document. When created from a Rechnung, it MUST reference the original via gutschrift_zu_rechnung_id. The Gutschrift has its own nummernkreis (GS-YY####) and PDF template. Gutschrift amounts are negative relative to the original invoice. A Gutschrift CAN be storniert following the same rules as Rechnung.

#### Scenario: Gutschrift from invoice
- GIVEN a finalized Rechnung with total 500 EUR
- WHEN a user creates a Gutschrift for that Rechnung
- THEN the Gutschrift has negative amounts (-500 EUR), references the original Rechnung, and has its own GS-number

#### Scenario: Standalone Gutschrift without invoice reference
- GIVEN no specific invoice is selected
- WHEN a user creates a standalone Gutschrift
- THEN the Gutschrift has its own nummer and gutschrift_zu_rechnung_id is NULL

### Requirement: Ersatzrechnung

After a Rechnung is storniert, the user CAN create an Ersatzrechnung (replacement invoice). The system MUST link bidirectionally: the Ersatzrechnung has ersatzrechnung_id pointing to the new document, and the original has ersatz_fuer_rechnung_id pointing back. The Ersatzrechnung is a new standalone document with its own nummer and positions (may differ from the original). The original stornoed invoice MUST remain visible with a "Storniert → Ersatz" link.

#### Scenario: Ersatzrechnung bidirectional link
- GIVEN a storniert Rechnung (id=42)
- WHEN a user creates an Ersatzrechnung from Rechnung #42
- THEN the new Rechnung has ersatz_fuer_rechnung_id = 42, and Rechnung #42 has ersatzrechnung_id = <new_id>

#### Scenario: Ersatzrechnung from non-storned invoice blocked
- GIVEN a finalized Rechnung (id=50) that is not storniert
- WHEN a user attempts to create an Ersatzrechnung from Rechnung #50
- THEN the system rejects the action with error "Ersatzrechnung nur aus stornierter Rechnung möglich"

### Requirement: Conversion Chains

The system MUST support the following conversion chains:
- Angebot → Auftrag → Lieferschein → Rechnung
- Angebot → Proforma → Rechnung
- Angebot → Rechnung (direct)
- Angebot → Auftrag → Rechnung (direct)
- Proforma → Rechnung

When converting, positions MUST be propagated to the target document. The source document MUST record the target document ID (e.g., rechnung_zu_angebot_id). The target document MUST record the source (e.g., angebot_zu_rechnung_id). Each conversion step MUST be confirmable by the user.

#### Scenario: Angebot → Auftrag conversion
- GIVEN a finalized Angebot (id=10) with 3 positions
- WHEN a user converts it to an Auftrag
- THEN a new Auftrag is created with the same 3 positions, the Auftrag has angebot_zu_auftrag_id = 10, and the Angebot has auftrag_zu_angebot_id = <new_auftrag_id>

#### Scenario: Lieferschein → Rechnung conversion
- GIVEN a finalized Lieferschein with 2 positions and lieferadresse_id = 3
- WHEN a user converts it to a Rechnung
- THEN a new Rechnung is created with the same positions, lieferadresse_id = 3 is propagated, and the Rechnung has lieferschein_zu_rechnung_id pointing to the Lieferschein

#### Scenario: Unsupported conversion blocked
- GIVEN a finalized Lieferschein
- WHEN a user attempts to convert it directly to an Angebot
- THEN the system rejects the action with error "Lieferschein kann nicht in Angebot konvertiert werden"

### Requirement: Position Propagation

When converting between document types, positions MUST be copied with all fields: Bezeichnung, Menge, Einzelpreis, USt-Satz, Rabatt, and Differenzbesteuerung flag. The Eingabemodus (netto/brutto) of the source document MUST be preserved. Position IDs are regenerated (new documents get new IDs). Quantities and prices MUST NOT be altered during propagation.

#### Scenario: Position fields preserved
- GIVEN a Rechnung position has Bezeichnung "Website-Design", Menge 10, Einzelpreis 150.00, USt 19%, Rabatt 5%
- WHEN this position is propagated to a target document
- THEN the propagated position has identical values for all fields

#### Scenario: Position IDs regenerated
- GIVEN a source document position with id = 999
- WHEN the position is propagated to a new document
- THEN the new position has a different id (not 999) but all other fields match

### Requirement: Dokumentenpakete

The system MUST support Dokumentenpakete (document bundles). A Dokumentenpaket groups multiple documents (e.g., Rechnung + Lieferschein + Angebot) under a single entity. Each package has id and bezeichnung. Documents reference the package via dokumentenpaket_id FK. Packages are used for organized display and batch operations (e.g., print all, email all).

#### Scenario: Create package from multiple documents
- GIVEN a user selects a Rechnung, Lieferschein, and Angebot
- WHEN the user creates a Dokumentenpaket
- THEN all three documents have dokumentenpaket_id pointing to the new package, and the package page shows all three

#### Scenario: Empty package creation blocked
- GIVEN no documents are selected
- WHEN a user attempts to create a Dokumentenpaket
- THEN the system rejects the action with error "Mindestens ein Dokument auswählen"

### Requirement: Belege — Upload and Attach

The system MUST support uploading Belege (receipts/proof documents) and attaching them to invoices or journal entries. Each Beleg has id, dateiname, original_name, mime_type, dateigroesse, sha256, hochgeladen_am, and optionally beleg_pdfa_pfad (PDF/A-3 path for GoBD archiving). Belege can be viewed inline, downloaded, renamed, or deleted. Attaching a Beleg to an invoice sets beleg_id FK on the rechnungen record.

#### Scenario: Attach receipt to invoice
- GIVEN a user uploads a PDF receipt
- WHEN the user attaches it to Rechnung #100
- THEN Rechnung #100 has beleg_id pointing to the uploaded Beleg, and the receipt is viewable from the invoice detail page

#### Scenario: Unsupported file type rejected
- GIVEN a user attempts to upload a .exe file as a Beleg
- WHEN the upload is processed
- THEN the system rejects the file with error "Dateityp nicht unterstützt"

### Requirement: Original PDF Storage

When a Rechnung is finalized, the system MUST store the generated PDF at original_pdf_pfad. When a user requests a copy (e.g., "Kopie drucken"), the system MUST load the original PDF and add a "KOPIE" watermark. This ensures copies are visually distinct from the original.

#### Scenario: Kopie with watermark
- GIVEN a finalized Rechnung with original_pdf_pfad stored
- WHEN a user clicks "Kopie drucken"
- THEN the system generates a PDF from the original with "KOPIE" watermark overlaid and presents it for download/print

#### Scenario: Original PDF preserved on copy
- GIVEN a finalized Rechnung has original_pdf_pfad pointing to a valid file
- WHEN a user generates a Kopie
- THEN the original PDF file is unchanged and the Kopie is a separate output

### Requirement: Absender_snapshot

At finalization, the system MUST capture absender_snapshot: a JSON serialization of all relevant Unternehmen fields (name, address, tax data, logo path, etc.). This snapshot MUST be used for PDF generation of that specific document, ensuring finalized documents reflect company data at the time of creation (GoBD compliance). The snapshot MUST NOT be editable after finalization.

#### Scenario: Company change does not affect old invoices
- GIVEN a finalized invoice has absender_snapshot with address "Alte Straße 1"
- WHEN the company address changes to "Neue Straße 2"
- THEN the finalized invoice PDF still shows "Alte Straße 1" from the snapshot

#### Scenario: Snapshot immutable after finalization
- GIVEN a finalized invoice has absender_snapshot stored
- WHEN any API call attempts to modify absender_snapshot on a finalized document
- THEN the system rejects the update with error "Absender-Snapshot ist nach Finalisierung unveränderlich"

### Requirement: Überzahlung Handling

When a payment exceeds the invoice total (zahlungsbetrag > rechnungsbetrag), the system MUST handle the Überzahlung (overpayment). The user MUST be given options: (1) acknowledge and close, (2) create a Forderung (receivable) for the difference. If a Forderung is created, it is linked to the invoice and appears in the Forderungsmanagement dashboard widget. The invoice MUST have überzahlung_anerkannt flag to track acknowledgment.

#### Scenario: Overpayment creates Forderung
- GIVEN a 1000 EUR Rechnung
- WHEN a user records zahlungsbetrag = 1200 and chooses "Forderung erstellen"
- THEN a Forderung of 200 EUR is created linked to the Rechnung, and überzahlung_anerkannt = false

#### Scenario: Overpayment acknowledged without Forderung
- GIVEN a 1000 EUR Rechnung
- WHEN a user records zahlungsbetrag = 1200 and chooses "Kein Handlungsbedarf"
- THEN überzahlung_anerkannt is set to true and no Forderung is created

### Requirement: Skonto Handling

Skonto (cash discount) MUST be configurable at three levels: company standard (Unternehmen), per customer (Kunden), and per invoice (Rechnungen). Each level has skonto_prozent (NUMERIC(5,2)) and skonto_tage (INTEGER). Priority: invoice level > customer level > company level. When Skonto applies, the system MUST calculate the discounted amount and display it on the invoice. The Skonto amount MUST be booked to a separate "Erhaltene Skonti" / "Gewährte Skonti" category in the journal, NOT as a reduction of revenue/expense (Zuflussprinzip).

#### Scenario: Invoice-level skonto overrides customer default
- GIVEN a customer has skonto_prozent = 2 and an invoice sets skonto_prozent = 5
- WHEN the invoice is finalized
- THEN the invoice shows 5% Skonto, and the Eür entry for "Gewährte Skonti" records the 5% discount amount on the correct line

#### Scenario: No skonto when not configured
- GIVEN standard_skonto_prozent = 0 and the customer and invoice have no skonto set
- WHEN an invoice is finalized
- THEN no Skonto line appears on the invoice

### Requirement: Eingabemodus — Netto/Brutto

Each document MUST have eingabemodus (ENUM: 'netto', 'brutto', default 'netto'). This determines the "source of truth" for calculations:
- netto mode: user enters net prices, USt is derived, Brutto = Netto + USt
- brutto mode: user enters gross prices, Netto is derived, USt = Brutto - Netto

All calculations MUST happen server-side via a single preview endpoint (POST /vorschau). Rounding MUST occur at position level (Einzelpreis × Menge), not per item. The preview endpoint is the single source of truth for form display, save, and PDF generation.

#### Scenario: Netto mode calculation
- GIVEN a document with eingabemodus = 'netto'
- WHEN a position has Einzelpreis netto = 100.00, Menge = 3, USt = 19%
- THEN position netto = 300.00, ust_betrag = 57.00, brutto = 357.00

#### Scenario: Brutto mode calculation
- GIVEN a document with eingabemodus = 'brutto'
- WHEN a position has Einzelpreis brutto = 119.00, Menge = 3, USt = 19%
- THEN position brutto = 357.00, netto = 300.00, ust_betrag = 57.00

### Requirement: Rabatt — Position and Document Level

The system MUST support two levels of Rabatt (discount):
- Position-level: rabatt_prozent per position (NUMERIC(5,2)), applied to that position's line total
- Document-level: either rabatt_prozent (percentage of subtotal) or rabatt_betrag (fixed EUR amount), mutually exclusive

Document-level Rabatt is applied after summing all position totals. The PDF MUST show the Rabatt line and Zwischensumme when any Rabatt is active.

#### Scenario: Position Rabatt
- GIVEN a position has Einzelpreis 200, Menge 2, Rabatt 10%
- WHEN the position total is calculated
- THEN position total = 200 × 2 × 0.90 = 360.00

#### Scenario: Document-level fixed Rabatt
- GIVEN a document subtotal is 1000 and rabatt_betrag = 50
- WHEN the document total is calculated
- THEN the document total is 950.00 (before USt)

#### Scenario: Conflicting document-level Rabatt rejected
- GIVEN a document has rabatt_prozent = 10
- WHEN a user sets rabatt_betrag = 50 (both non-zero)
- THEN the system rejects the save with error "Nur ein Rabatt pro Dokument erlaubt (Prozent ODER Betrag)"

### Requirement: Einleitungstext und Schlusstext

Each document type (Rechnung, Angebot, Auftrag, Proforma, Lieferschein) MUST have its own default einleitungstext and schlusstext stored in the Unternehmen record. Each document MAY override these with document-specific text. Markdown formatting (bold, italic) MUST be supported. Texts appear in the PDF: einleitungstext before the position table, schlusstext after totals.

#### Scenario: Document overrides company default
- GIVEN the company default einleitungstext for Rechnung is "Vielen Dank für Ihren Auftrag"
- WHEN a specific invoice sets einleitungstext to "Für die Hearing-Sitzung vom 15.03."
- THEN the PDF shows "Für die Hearing-Sitzung vom 15.03.", not the company default

#### Scenario: Empty document text falls back to default
- GIVEN the company default schlusstext for Rechnung is "Mit freundlichen Grüßen"
- WHEN a specific invoice has schlusstext = NULL
- THEN the PDF shows "Mit freundlichen Grüßen" from the company default

### Requirement: Lagerführung — Stock auf Finalisierung

When a document with lager_aktiv positions is finalized, the system MUST decrement stock (bestand_aktuell) by the ordered Menge for each position. If minusbestand_erlaubt is false and any position would cause negative stock, finalization MUST be blocked. Stock restoration on storno follows Storno rules. Stock changes MUST be logged with document reference.

#### Scenario: Multi-position stock update
- GIVEN an invoice with Position A (Menge 5, article Alpha) and Position B (Menge 3, article Beta)
- WHEN the invoice is finalized
- THEN stock for article Alpha is decremented by 5 and stock for article Beta is decremented by 3

#### Scenario: Stock change logged with reference
- GIVEN an invoice #500 with article "Widget" (Menge 10) is finalized
- WHEN the stock decrement occurs
- THEN the stock log entry references Rechnung #500 and records the quantity change

### Requirement: Lageradresse

A Rechnung or Lieferschein MAY reference a Lageradresse (delivery address) from kunden_lieferadressen via lieferadresse_id FK. When set, the delivery address appears in the PDF address block instead of the customer's billing address. Lieferschein MUST always show the delivery address. During conversion from Lieferschein to Rechnung, lieferadresse_id MUST be propagated.

#### Scenario: Lieferschein shows delivery address
- GIVEN a Lieferschein has lieferadresse_id pointing to "Werkstatt Hamburg"
- WHEN the Lieferschein PDF is generated
- THEN the PDF header shows the Werkstatt Hamburg address, not the customer's billing address

#### Scenario: Delivery address propagated to Rechnung
- GIVEN a Lieferschein has lieferadresse_id = 5
- WHEN the Lieferschein is converted to a Rechnung
- THEN the Rechnung has lieferadresse_id = 5

### Requirement: Angebot — Status

Each Angebot MUST have angebot_status (ENUM: offen, angenommen, abgelehnt, abgelaufen). Status transitions: offen → angenommen (user action), offen → abgelehnt (user action), offen → abgelaufen (automatic when gueltig_bis passes). An angenommen Angebot CAN be converted to Auftrag or Rechnung. An abgelehnt or abgelaufen Angebot is read-only.

#### Scenario: Angebot expires automatically
- GIVEN an Angebot with gueltig_bis = 2026-01-31 and status = "offen"
- WHEN the date becomes 2026-02-01
- THEN angebot_status changes to "abgelaufen" and the document becomes read-only

#### Scenario: Expired Angebot cannot be accepted
- GIVEN an Angebot with angebot_status = "abgelaufen"
- WHEN a user attempts to set status to "angenommen"
- THEN the system rejects the action with error "Angebot ist abgelaufen und nicht mehr bearbeitbar"

### Requirement: Auftrag — Status

Each Auftrag MUST have auftrag_status (ENUM: offen, in_bearbeitung, rechnung_gestellt, abgeschlossen). Transitions: offen → in_bearbeitung (manual), in_bearbeitung → rechnung_gestellt (when linked Rechnung is finalized), rechnung_gestellt → abgeschlossen (when linked Rechnung is bezahlt). The system MUST auto-update status based on linked document states.

#### Scenario: Auftrag auto-completes on payment
- GIVEN an Auftrag in "rechnung_gestellt" has a linked Rechnung
- WHEN the linked Rechnung is marked as bezahlt
- THEN auftrag_status automatically changes to "abgeschlossen"

#### Scenario: Manual status regression blocked
- GIVEN an Auftrag has auftrag_status = "abgeschlossen"
- WHEN a user attempts to set status to "offen"
- THEN the system rejects the action with error "Abgeschlossener Auftrag kann nicht zurückgesetzt werden"

### Requirement: Lieferschein — Preise

A Lieferschein PDF MUST NOT show prices or USt. It shows only positions with Bezeichnung and Menge. The Lieferschein is a non-financial document used for goods delivery confirmation. Converting a Lieferschein to a Rechnung adds prices during the conversion.

#### Scenario: Lieferschein PDF without prices
- GIVEN a Lieferschein with 3 positions
- WHEN the Lieferschein PDF is generated
- THEN the PDF shows position names and quantities only, no Einzelpreis, USt, or total columns

#### Scenario: Lieferschein → Rechnung adds prices
- GIVEN a Lieferschein with 3 positions (no prices shown)
- WHEN the Lieferschein is converted to a Rechnung
- THEN the Rechnung positions include Einzelpreis, USt-Satz, and calculated totals
