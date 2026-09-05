# OpenInvoices — PDF Generation Specification

## ADDED Requirements

### Requirement: Document Type Coverage

The system SHALL generate PDFs for seven document types: Rechnung (invoice), Storno (credit note reversal), Gutschrift (credit note), Angebot (quote), Auftrag (order), Proforma (proforma invoice), and Lieferschein (delivery note).

#### Scenario: Rechnung generation

- GIVEN a finalized Rechnung with positions, customer data, and company data
- WHEN the Rechnung PDF is requested
- THEN the system SHALL produce a PDF with document type label "Rechnung", the document number from the Nummernkreis, and all position lines with netto/brutto/USt columns

#### Scenario: Unsupported document type

- GIVEN a document type not in the supported set (e.g., "Gutschein")
- WHEN PDF generation is requested for that type
- THEN the system SHALL reject the request with an error and SHALL NOT produce a PDF

### Requirement: Storno PDF

The system SHALL generate a Stornorechnung PDF with negative amounts and mandatory reversal metadata.

#### Scenario: Storno generation

- GIVEN a finalized Storno linked to an original Rechnung, with storno_datum, storno_grund, and storno_rechnungsnummer set
- WHEN the Storno PDF is requested
- THEN the system SHALL produce a PDF titled "Stornorechnung" with negative amounts, the storno_rechnungsnummer, storno_datum, storno_grund, and without a Zahlungsblock

#### Scenario: Missing storno_grund

- GIVEN a Storno with storno_grund = NULL or empty
- WHEN the Storno PDF is requested
- THEN the system SHALL reject generation with an error indicating storno_grund is required

### Requirement: Gutschrift PDF

The system SHALL generate a Gutschrift PDF with negative amounts and a GS- Nummernkreis prefix.

#### Scenario: Gutschrift generation

- GIVEN a finalized Gutschrift with a GS- Nummernkreis number
- WHEN the Gutschrift PDF is requested
- THEN the system SHALL produce a PDF titled "Gutschrift" with negative amounts and the GS- prefixed document number

#### Scenario: Gutschrift without reference Rechnung

- GIVEN a Gutschrift not linked to a reference Rechnung
- WHEN the Gutschrift PDF is requested
- THEN the system SHALL produce the PDF without a reference invoice section

### Requirement: Angebot PDF

The system SHALL generate an Angebot (quote) PDF with validity date and without Leistungszeitraum.

#### Scenario: Angebot generation

- GIVEN a finalized Angebot with gueltig_bis date
- WHEN the Angebot PDF is requested
- THEN the system SHALL produce a PDF titled "Angebot" with gueltig_bis date displayed, without Leistungszeitraum

#### Scenario: Angebot without gueltig_bis

- GIVEN a Angebot with gueltig_bis = NULL
- WHEN the Angebot PDF is requested
- THEN the system SHALL produce the PDF without a validity date line

### Requirement: Auftrag PDF

The system SHALL generate an Auftrag (order) PDF with auftrag_status.

#### Scenario: Auftrag generation

- GIVEN a finalized Auftrag with auftrag_status set
- WHEN the Auftrag PDF is requested
- THEN the system SHALL produce a PDF titled "Auftrag" with the auftrag_status displayed

#### Scenario: Auftrag without linked documents

- GIVEN an Auftrag with no linked Rechnung, Lieferschein, or Proforma
- WHEN the Auftrag PDF is requested
- THEN the system SHALL produce the PDF without a linked-documents section

### Requirement: Proforma PDF

The system SHALL generate a Proforma-Rechnung PDF with PRF- Nummernkreis prefix.

#### Scenario: Proforma generation

- GIVEN a finalized Proforma with a PRF- Nummernkreis number
- WHEN the Proforma PDF is requested
- THEN the system SHALL produce a PDF titled "Proforma-Rechnung" with the PRF- prefixed document number

#### Scenario: Proforma without Leistungszeitraum

- GIVEN a Proforma with leistung_von and leistung_bis both NULL
- WHEN the Proforma PDF is requested
- THEN the system SHALL produce the PDF without a Leistungszeitraum line

### Requirement: Lieferschein PDF

The system SHALL generate a Lieferschein (delivery note) PDF without price columns.

#### Scenario: Lieferschein generation

- GIVEN a finalized Lieferschein with positions
- WHEN the Lieferschein PDF is requested
- THEN the system SHALL produce a PDF titled "Lieferschein" showing only Pos., Beschreibung, and Menge columns (no pricing)

#### Scenario: Lieferschein with linked Rechnung

- GIVEN a Lieferschein linked to a Rechnung via lieferschein_zu_rechnung_id
- WHEN the Lieferschein PDF is requested
- THEN the system SHALL produce the PDF referencing the linked Rechnung number

### Requirement: PDF Templates

The system SHALL support two PDF templates: Standard and Grün/Kleinunternehmer. The template is selected based on company configuration.

#### Scenario: Standard template rendering

- GIVEN a company with pdf_vorlage = 'standard'
- WHEN a document is rendered
- THEN the system SHALL render with full color scheme, company logo, and standard layout

#### Scenario: Grün/Kleinunternehmer template rendering

- GIVEN a company with pdf_vorlage = 'gruen' (Kleinunternehmer §19 UStG)
- WHEN a document is rendered
- THEN the system SHALL render with Kleinunternehmer styling, no USt columns, and the label "Gemäß §19 UStG wird keine Umsatzsteuer berechnet"

#### Scenario: Unknown template value

- GIVEN a company with pdf_vorlage set to an unrecognized value (e.g., "neon")
- WHEN a document is rendered
- THEN the system SHALL fall back to the Standard template and log a warning

### Requirement: Company Header

The system SHALL render a company header containing the company logo, company name, address, and contact information on every page.

#### Scenario: Logo present

- GIVEN a company with a logo configured and uploaded
- WHEN a document PDF is rendered
- THEN the header SHALL include the logo image at the top of the first page

#### Scenario: No logo configured

- GIVEN a company with no logo configured (logo_pfad = NULL)
- WHEN a document PDF is rendered
- THEN the header SHALL render without the logo area, shifting content to fill the space

### Requirement: Customer Address Block

The system SHALL render a destination address block with customer name, company, street, postal code, city, country, and optional z_hd salutation.

#### Scenario: Standard customer address

- GIVEN a Rechnung linked to a customer with full address and z_hd set
- WHEN the document PDF is rendered
- THEN the address block SHALL show name, z_hd, street, PLZ Ort, and country (if not DE)

#### Scenario: Einmalkunde address

- GIVEN a document rendered for a one-time customer (einmalkunde) with inline address fields
- WHEN the document PDF is rendered
- THEN the address block SHALL use inline address fields from the rechnungen record instead of a customer lookup

#### Scenario: Missing customer address fields

- GIVEN a customer with incomplete address (e.g., strasse = NULL, plz = NULL)
- WHEN the document PDF is rendered
- THEN the system SHALL render the address block with available fields only and SHALL NOT fail

### Requirement: Position Table

The system SHALL render a position table with columns appropriate to the document type. All monetary values SHALL be displayed with two decimal places and comma as decimal separator.

#### Scenario: Rechnung position table

- GIVEN a Rechnung with positions
- WHEN the document PDF is rendered
- THEN the position table SHALL include columns for Pos., Beschreibung, Menge, Einzelpreis, Rabatt, Netto, USt-Satz, USt, and Brutto

#### Scenario: Differenzbesteuerung §25a display

- GIVEN a position with differenzbesteuerung = true
- WHEN the document PDF is rendered
- THEN the system SHALL display "Differenzbesteuerung §25a UStG" in the position row and hide the USt column for that row

#### Scenario: Position with zero quantity

- GIVEN a position with menge = 0
- WHEN the document PDF is rendered
- THEN the position row SHALL display with Menge 0,00 and all calculated columns as 0,00

#### Scenario: Position with negative menge (Storno)

- GIVEN a Storno position with menge = -1 and negative Einzelpreis
- WHEN the document PDF is rendered
- THEN the position row SHALL display negative values with minus sign and all calculated columns SHALL reflect the negative amounts

### Requirement: Payment Block

The system SHALL render a payment block containing Betreff, IBAN, BIC, Kontoinhaber, and optionally a QR code or SEPA QR code.

#### Scenario: Standard payment block

- GIVEN a Rechnung with company payment data (IBAN, BIC, Kontoinhaber)
- WHEN the document PDF is rendered
- THEN the payment block SHALL show the Betreff referencing the document number, IBAN, BIC, and Kontoinhaber

#### Scenario: QR code payment

- GIVEN a company with qr_zahlung_aktiv = true
- WHEN a document PDF is rendered
- THEN the payment block SHALL include a QR code encoding the payment data (amount, IBAN, BIC, reference)

#### Scenario: SEPA QR code

- GIVEN a SEPA-compatible QR code is generated
- WHEN the QR code is rendered
- THEN the system SHALL encode EPC069-12 compliant data with SmBZ (Verwendungszweck) containing the document number

#### Scenario: Missing IBAN

- GIVEN a company with IBAN = NULL or empty
- WHEN a document PDF is rendered
- THEN the payment block SHALL render without IBAN/BIC fields and SHALL NOT produce a QR code

### Requirement: Einleitungstext and Schlusstext

The system SHALL support per-document-type Einleitungstext (introductory text) and Schlusstext (closing text). Each document type (Rechnung, Angebot, Auftrag, Proforma, Lieferschein) SHALL have independent text fields with no cross-fallback to other document types.

#### Scenario: Per-type text rendering

- GIVEN a Rechnung with a Rechnung-specific Einleitungstext set
- WHEN the document PDF is rendered
- THEN the text SHALL appear between the address block and the position table, using only the Rechnung text field, not falling back to Angebot or other types

#### Scenario: Empty text field

- GIVEN a document type with an empty Schlusstext
- WHEN the document PDF is rendered
- THEN no closing text SHALL be rendered, and the system SHALL NOT fall back to another document type's Schlusstext

#### Scenario: Markdown formatting

- GIVEN text containing Markdown bold/italic markers (e.g., **fett** *kursiv*)
- WHEN the document PDF is rendered
- THEN the system SHALL render **bold** and *italic** formatting in the PDF text

#### Scenario: Text with only whitespace

- GIVEN a Schlusstext containing only whitespace characters
- WHEN the document PDF is rendered
- THEN no closing text SHALL be rendered (whitespace-only is treated as empty)

### Requirement: Unterschrift Image

The system SHALL embed the company Unterschrift (signature) image at the bottom of the document when configured.

#### Scenario: Signature present

- GIVEN a company with unterschrift_auf_rechnung = true and unterschrift_bild set
- WHEN a document PDF is rendered
- THEN the system SHALL render the unterschrift_bild image at the bottom of the first page, before the footer

#### Scenario: Signature disabled

- GIVEN a company with unterschrift_auf_rechnung = false
- WHEN a document PDF is rendered
- THEN no signature image SHALL appear in the PDF

### Requirement: KOPIE Watermark

The system SHALL render a "KOPIE" watermark on document copies.

#### Scenario: Copy generation

- GIVEN a document copy is requested (original_pdf_pfad is set)
- WHEN the copy PDF is rendered
- THEN the system SHALL render "KOPIE" as a diagonal watermark across the page content

#### Scenario: Original document

- GIVEN the original document is rendered (not a copy)
- WHEN the document PDF is rendered
- THEN no watermark SHALL appear

### Requirement: ZUGFeRD and XRechnung E-Invoicing

The system SHALL generate ZUGFeRD-compliant and XRechnung-compliant e-invoice XML embedded in PDF/A-3 files.

#### Scenario: ZUGFeRD PDF generation

- GIVEN a finalized Rechnung with ZUGFeRD export requested
- WHEN the ZUGFeRD export is generated
- THEN the system SHALL produce a PDF/A-3 file with an embedded Factur-X XML (ZUGFeRD profile) containing all invoice data per EN 16931

#### Scenario: XRechnung generation

- GIVEN a finalized Rechnung with XRechnung export requested
- WHEN the XRechnung export is generated
- THEN the system SHALL produce an XML file conforming to XRechnung 3.0 specification with mandatory fields (BT-1 through BT-152)

#### Scenario: Invalid invoice data for e-invoicing

- GIVEN a Rechnung with missing mandatory fields for XRechnung (e.g., customer USt-IdNr for EU trade)
- WHEN the XRechnung export is generated
- THEN the system SHALL reject generation with an error listing the missing mandatory fields

### Requirement: PDF/A-3 Archival

The system SHALL support generating PDF/A-3 formatted files for GoBD-compliant long-term archival.

#### Scenario: PDF/A-3 output

- GIVEN a finalized document with beleg_pdfa_pfad requested
- WHEN the PDF/A-3 archival file is generated
- THEN the system SHALL produce a PDF/A-3b file with embedded metadata conforming to PDF/A-3 requirements, suitable for GoBD Langzeitarchivierung

#### Scenario: PDF/A-3 with attachments

- GIVEN a document with a Beleg (receipt) attachment
- WHEN the PDF/A-3 archival file is generated
- THEN the system SHALL embed the attachment within the PDF/A-3 container

### Requirement: GoBD Signatures

The system SHALL generate GoBD-compliant digital signatures for finalized documents.

#### Scenario: Document finalization signature

- WHEN a document is finalized
- THEN the system SHALL compute a SHA-256 hash of the document content and store it as a GoBD signature in the database

#### Scenario: Signature verification

- GIVEN a finalized document with a stored GoBD signature
- WHEN the signature is verified
- THEN the system SHALL recompute the hash and compare it against the stored signature, returning valid or invalid

#### Scenario: Tampered document detection

- GIVEN a finalized document whose PDF content has been modified after finalization
- WHEN the signature is verified
- THEN the system SHALL return invalid and flag the document as tampered

### Requirement: Mahnung PDF

The system SHALL generate dunning letter PDFs (Mahnung) with configurable content per Mahnstufe.

#### Scenario: Mahnung generation

- GIVEN a Mahnung generated for a customer with outstanding invoices and Mahnstufe designation
- WHEN the Mahnung PDF is rendered
- THEN the system SHALL produce a PDF containing the customer address, outstanding invoices, Mahnstufe designation, Betreff, Einleitungstext, and payment block

#### Scenario: Mahnung with attachments

- GIVEN a Mahnstufe with anhang_rechnung or anhang_bisherige_mahnungen enabled
- WHEN the Mahnung PDF is rendered
- THEN the system SHALL include attached Rechnung copies or previous Mahnung copies as additional pages

#### Scenario: Mahnung with Kontokorrent

- GIVEN a Mahnstufe with anhang_kontokorrent enabled
- WHEN the Mahnung PDF is rendered
- THEN the system SHALL include a Kontokorrent summary page showing all transactions

#### Scenario: No outstanding invoices

- GIVEN a Mahnung generated for a customer with no outstanding invoices
- WHEN the Mahnung PDF is rendered
- THEN the system SHALL reject generation or render an empty invoice list with a notice

### Requirement: Anlage EKS PDF

The system SHALL generate a 9-page Anlage EKS PDF for Jobcenter Transferleistungen.

#### Scenario: EKS generation

- GIVEN an EKS PDF requested for a customer with complete EKS-FELDER_META
- WHEN the EKS PDF is generated
- THEN the system SHALL produce a 9-page PDF conforming to the Jobcenter Anlage EKS form with all sections (A through I) filled from customer and company data

#### Scenario: EKS field population

- GIVEN EKS-FELDER_META defined for a field with a computed value
- WHEN the EKS PDF is generated
- THEN the system SHALL populate the field with the computed value (e.g., EKS B6_5 = km × 0.10) at the correct position on the correct page

#### Scenario: Missing EKS customer data

- GIVEN an EKS requested for a customer with missing required fields (e.g., bg_nummer = NULL)
- WHEN the EKS PDF is generated
- THEN the system SHALL render the field as empty and log a warning, without failing the entire generation

### Requirement: Tagesabschluss PDF

The system SHALL generate a daily cash close PDF (Tagesabschluss) with counted amounts and discrepancy notes.

#### Scenario: Tagesabschluss generation

- GIVEN a Tagesabschluss finalized with zaehlung_json containing counted amounts
- WHEN the Tagesabschluss PDF is rendered
- THEN the system SHALL produce a PDF showing the date, expected cash amount, actual counted amount, discrepancy, and a GoBD signature

#### Scenario: Counting discrepancy

- GIVEN a Tagesabschluss where counted amount differs from expected amount
- WHEN the Tagesabschluss PDF is rendered
- THEN the discrepancy SHALL be prominently flagged in the PDF

### Requirement: Content-Disposition Inline

All PDF responses consumed by the in-app Flutter viewer SHALL use `Content-Disposition: inline` with a filename parameter. `attachment` disposition SHALL NOT be used for PDFs displayed in that viewer.

#### Scenario: PDF via Flutter viewer

- GIVEN a PDF response returning a document for display in the app's Flutter viewer
- WHEN the HTTP response is sent
- THEN the response SHALL have `Content-Disposition: inline; filename="<dateiname>"`

#### Scenario: Non-PDF download

- GIVEN an endpoint returning CSV, ZIP, JSON, or backup files
- WHEN the HTTP response is sent
- THEN the response SHALL have `Content-Disposition: attachment; filename="<dateiname>"`

#### Scenario: PDF with attachment disposition (forbidden)

- GIVEN a PDF endpoint using `Content-Disposition: attachment`
- WHEN the response is sent to the Flutter viewer
- THEN the viewer SHALL display the PDF inline rather than treating it as a download
### Requirement: Footer with Page Numbers

The system SHALL render a footer on every page containing the company name, page number, and total page count.

#### Scenario: Multi-page document

- GIVEN a document spanning 3 pages
- WHEN the PDF is rendered
- THEN each page footer SHALL show "Seite X von 3" (where X is the current page) with the company name

#### Scenario: Single-page document

- GIVEN a document spanning 1 page
- WHEN the PDF is rendered
- THEN the footer SHALL show "Seite 1 von 1" with the company name

### Requirement: Nummernkreise for Document Numbers

The system SHALL use configurable Nummernkreise (number sequences) for document numbering with format patterns (e.g., RE-YY####, ANG-YY####).

#### Scenario: Number generation

- GIVEN a new Rechnung being finalized with a configured rechnung_ausgang Nummernkreis
- WHEN the document is finalized
- THEN the system SHALL assign the next number from the Nummernkreis, formatted per the configured pattern

#### Scenario: Number uniqueness

- GIVEN two documents being finalized concurrently
- WHEN both documents are assigned numbers
- THEN the system SHALL guarantee unique document numbers via atomic increment

#### Scenario: Nummernkreis exhausted

- GIVEN a Nummernkreis where all numbers in the pattern range have been assigned
- WHEN a new document requests a number
- THEN the system SHALL reject finalization with an error indicating the Nummernkreis is exhausted

### Requirement: Differenzbesteuerung §25a Display

The system SHALL handle Differenzbesteuerung (margin scheme) per §25a UStG with correct display and calculation.

#### Scenario: §25a position display

- GIVEN a position with differenzbesteuerung = true
- WHEN the document PDF is rendered
- THEN the PDF SHALL display the USt-Satz as 0% on the position line, show a note referencing §25a UStG, and compute the margin-based USt internally

#### Scenario: §25a summary

- GIVEN a document containing §25a positions
- WHEN the document PDF is rendered
- THEN the summary section SHALL show the Gesamtbrutto, EK-Netto, and Marge (brutto - ek_netto_25a × menge) separately

#### Scenario: Mixed document with §25a and standard positions

- GIVEN a Rechnung with both standard and §25a positions
- WHEN the document PDF is rendered
- THEN standard positions SHALL show normal USt, §25a positions SHALL show 0% USt with §25a note, and the summary SHALL separate both types

### Requirement: Leistungszeitraum

The system SHALL display the service period (Leistungszeitraum) on documents when leistung_von and leistung_bis dates are provided.

#### Scenario: Service period on Rechnung

- GIVEN a Rechnung with leistung_von = 2026-01-01 and leistung_bis = 2026-01-31
- WHEN the document PDF is rendered
- THEN the PDF SHALL display "Leistungszeitraum: 01.01.2026 bis 31.01.2026" below the position table

#### Scenario: No service period

- GIVEN a document with leistung_von and leistung_bis both NULL
- WHEN the document PDF is rendered
- THEN no Leistungszeitraum line SHALL be rendered

#### Scenario: Partial service period

- GIVEN a document with leistung_von set but leistung_bis = NULL
- WHEN the document PDF is rendered
- THEN the system SHALL display only the start date or omit the line entirely (not show "von 01.01.2026 bis ")

### Requirement: Absender Snapshot

The system SHALL freeze company data (absender_snapshot) at document finalization time and use that snapshot for PDF generation, ensuring finalized documents remain unchanged per GoBD.

#### Scenario: Finalized document PDF

- GIVEN a finalized document with absender_snapshot populated
- WHEN a PDF is generated for that document
- THEN the system SHALL use the absender_snapshot JSON for company data instead of current company data

#### Scenario: Draft document PDF

- GIVEN a draft document (ist_entwurf = true) with no absender_snapshot
- WHEN a PDF is generated for that document
- THEN the system SHALL use current company data (no snapshot)

#### Scenario: Absender snapshot missing on finalized document

- GIVEN a finalized document with absender_snapshot = NULL (legacy data)
- WHEN a PDF is generated for that document
- THEN the system SHALL fall back to current company data and log a warning

### Requirement: Rabatt Display

The system SHALL display per-position Rabatt (as percentage or fixed amount) and optional Rechnungsrabatt on documents.

#### Scenario: Percentage rabatt

- GIVEN a position with rabatt_prozent = 10
- WHEN the document PDF is rendered
- THEN the position row SHALL show "10%" in the Rabatt column and the discounted Netto amount

#### Scenario: Fixed amount rabatt

- GIVEN a position with rabatt_betrag = 5.00
- WHEN the document PDF is rendered
- THEN the position row SHALL show "5,00 €" as Abzug and the discounted Netto amount

#### Scenario: Rechnungsrabatt

- GIVEN a document with rechnung.rabatt_prozent = 5
- WHEN the document PDF is rendered
- THEN the PDF SHALL show a Zwischensumme, Rabatt line, and Gesamtbetrag nach Rabatt

#### Scenario: No rabatt

- GIVEN a position with rabatt_prozent = NULL and rabatt_betrag = NULL
- WHEN the document PDF is rendered
- THEN the Rabatt column SHALL be empty or omitted, and Netto SHALL equal Einzelpreis × Menge

### Requirement: Logo Embedding

The system SHALL embed the company logo as an image in the PDF header. Supported formats: PNG, JPEG, SVG.

#### Scenario: PNG logo

- GIVEN a company logo file in PNG format
- WHEN the document PDF is rendered
- THEN the system SHALL embed it at the top-left of the header at the configured dimensions

#### Scenario: Logo exceeds header area

- GIVEN a logo image exceeding the maximum header height
- WHEN the document PDF is rendered
- THEN the system SHALL scale the logo proportionally to fit within the header bounds

#### Scenario: Unsupported logo format

- GIVEN a logo file in an unsupported format (e.g., BMP, TIFF)
- WHEN the document PDF is rendered
- THEN the system SHALL skip logo embedding and render the header without the logo, logging a warning

### Requirement: GoBD Integrity Hashes

The system SHALL generate GoBD-compliant tamper-evident integrity hashes for finalized documents. An unkeyed SHA-256 hash SHALL NOT be described or treated as a digital signature.

#### Scenario: Document finalization integrity hash

- WHEN a document is finalized
- THEN the system SHALL compute a SHA-256 hash of the document content and store it as the document's GoBD integrity hash in the database

#### Scenario: Integrity hash verification

- GIVEN a finalized document with a stored GoBD integrity hash
- WHEN the integrity hash is verified
- THEN the system SHALL recompute the hash and compare it against the stored hash, returning valid or invalid

#### Scenario: Tampered document detection

- GIVEN a finalized document whose PDF content has been modified after finalization
- WHEN the integrity hash is verified
- THEN the system SHALL return invalid and flag the document as tampered
