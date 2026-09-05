# Stammdaten — OpenInvoices Spec

## ADDED Requirements

### Requirement: Kunden — CRUD

The system SHALL provide full create, read, update, and delete operations for customer records (Kunden). Each customer MUST have a unique id, an auto-assigned Debitor-Nr (sequential, format configurable per number range), Anrede, Name, Strasse, PLZ, Ort, and Land. Optional fields include Steuernummer Ausland and USt-IdNr. Deleting a customer MUST be blocked if referenced by existing documents.

#### Scenario: Create customer with auto-assigned Debitor-Nr
- GIVEN the debitor number range has letze_nummer = 10049
- WHEN a user creates a new customer with valid required fields
- THEN the system assigns Debitor-Nr 10050, persists the record, and returns the created customer with the assigned number

#### Scenario: Delete customer with active documents
- GIVEN a customer "Müller GmbH" is referenced by Rechnung #2001
- WHEN a user attempts to delete "Müller GmbH"
- THEN the system rejects the deletion and returns an error listing Rechnung #2001 as the referencing document

### Requirement: Kunden — Kreditlimit

Each customer MAY have a Kreditlimit (credit limit) in NUMERIC(12,2). When the total outstanding (unpaid) invoice sum for a customer exceeds the Kreditlimit, the system MUST warn the user during invoice finalization. The warning MUST be dismissible but logged.

#### Scenario: Invoice finalization exceeds credit limit
- GIVEN a customer has Kreditlimit = 5000 and outstanding invoices totaling 4800
- WHEN a user finalizes an invoice for 500 EUR (total would be 5300)
- THEN the system displays a warning listing the current outstanding sum (4800) and the limit (5000), and requires explicit confirmation before proceeding

#### Scenario: Invoice within credit limit proceeds without warning
- GIVEN a customer has Kreditlimit = 5000 and outstanding invoices totaling 3000
- WHEN a user finalizes an invoice for 500 EUR (total would be 3500)
- THEN the system finalizes without warning or confirmation prompt

### Requirement: Kunden — Mahngesperrt

Each customer MAY be flagged as Mahngesperrt (dunning-blocked). When Mahngesperrt is true, the system MUST exclude the customer from automated dunning runs and MUST prevent manual dunning letter generation.

#### Scenario: Dunning run skips blocked customer
- GIVEN a customer "Schmidt KG" has Mahngesperrt = true
- WHEN the automated dunning process runs
- THEN the system skips "Schmidt KG" and logs the skip reason as "Mahngesperrt"

#### Scenario: Manual dunning blocked for Mahngesperrt customer
- GIVEN a customer "Schmidt KG" has Mahngesperrt = true and an unpaid invoice
- WHEN a user attempts to generate a dunning letter for "Schmidt KG"
- THEN the system rejects the action with error "Kunde ist mahngesperrt"

### Requirement: Kunden — Zugferd aktiv

Each customer MAY have Zugferd aktiv (ZUGFeRD e-invoicing enabled). When true, generated PDF/A invoices MUST include an embedded ZUGFeRD XML invoice document in the PDF/A-3 container.

#### Scenario: ZUGFeRD invoice generation
- GIVEN a customer has Zugferd aktiv = true
- WHEN an invoice is finalized for that customer
- THEN the system generates a PDF/A-3 file with the ZUGFeRD XML embedded and marks the document as e-invoicing ready

#### Scenario: ZUGFeRD not generated when disabled
- GIVEN a customer has Zugferd aktiv = false
- WHEN an invoice is finalized for that customer
- THEN the system generates a standard PDF without ZUGFeRD XML embedding

### Requirement: Kunden — USt-IdNr validation

The system MUST validate USt-IdNr format per EU country when the customer Land is an EU member state. Validation MUST follow the country-specific pattern (e.g., DE: DE followed by 9 digits, AT: ATU followed by 8 digits, FR: FR followed by 13 characters). Invalid formats MUST be rejected with a descriptive error. For non-EU countries, USt-IdNr MUST be accepted as free text.

#### Scenario: Invalid DE USt-IdNr rejected
- GIVEN a customer with Land = DE
- WHEN a user enters USt-IdNr "DE123"
- THEN the system rejects the input with error "USt-IdNr ungültig: Erwartet DE gefolgt von 9 Ziffern"

#### Scenario: Non-EU free text accepted
- GIVEN a customer with Land = CH
- WHEN a user enters USt-IdNr "CHE-123.456.789"
- THEN the system accepts the value without format validation

### Requirement: Kunden — Steuernummer Ausland

Each customer MAY have a Steuernummer Ausland (foreign tax number) stored as VARCHAR(50). This field is independent of USt-IdNr and MUST be displayed on invoices to Drittland customers where required by local law.

#### Scenario: Drittland invoice shows foreign tax number
- GIVEN a customer with Land = CH and Steuernummer Ausland = "CHE-123.456.789 MWST"
- WHEN an invoice is generated for that customer
- THEN the invoice PDF includes the tax number in the recipient address block

#### Scenario: EU customer omits foreign tax number
- GIVEN a customer with Land = DE and Steuernummer Ausland = NULL
- WHEN an invoice is generated for that customer
- THEN the invoice PDF does not include a Steuernummer Ausland field

### Requirement: Lieferanten — CRUD

The system SHALL provide full CRUD for supplier records (Lieferanten). Each supplier MUST have a unique id, an auto-assigned Kreditor-Nr (sequential), Name, and optional USt-IdNr with the same EU validation rules as customers. Deleting a supplier MUST be blocked if referenced by existing purchase records or journal entries.

#### Scenario: Create supplier with auto-assigned Kreditor-Nr
- GIVEN the kreditor number range has letze_nummer = 70009
- WHEN a user creates a new supplier with valid required fields
- THEN the system assigns Kreditor-Nr 70010 and persists the record

#### Scenario: Delete supplier with journal references
- GIVEN a supplier "Bürobedarf AG" is referenced by 3 journal entries
- WHEN a user attempts to delete "Bürobedarf AG"
- THEN the system rejects the deletion and returns an error listing the referencing journal entries

### Requirement: Lieferanten — USt-IdNr validation

The system MUST validate USt-IdNr format per EU country when the supplier Land is an EU member state, following the same country-specific patterns as customers. Invalid formats MUST be rejected. For non-EU countries, USt-IdNr MUST be accepted as free text.

#### Scenario: Invalid AT USt-IdNr rejected
- GIVEN a supplier with Land = AT
- WHEN a user enters USt-IdNr "AT12345678"
- THEN the system rejects the input with error "USt-IdNr ungültig: Erwartet ATU gefolgt von 8 Ziffern"

#### Scenario: Valid EU USt-IdNr accepted
- GIVEN a supplier with Land = NL
- WHEN a user enters USt-IdNr "NL123456789B01"
- THEN the system accepts the value

### Requirement: Artikel — CRUD

The system SHALL provide full CRUD for article/service records (Artikel). Each article MUST have a unique id, a Bezeichnung (name), a Typ enum (Artikel, Dienstleistung, Fremdleistung, Eigenleistung), and Verkaufspreise. Deleting an article MUST be blocked if referenced by existing invoice positions or templates.

#### Scenario: Create article with all types
- GIVEN no articles exist yet
- WHEN a user creates articles of each type (Artikel, Dienstleistung, Fremdleistung, Eigenleistung)
- THEN the system persists all four records with their respective type values

#### Scenario: Delete article referenced by invoice position
- GIVEN article "Widget A" is referenced by Rechnung #300 position 1
- WHEN a user attempts to delete "Widget A"
- THEN the system rejects the deletion with error "Artikel wird von Rechnung #300 verwendet"

### Requirement: Artikel — VK-Preise

Each article MUST have vk_brutto (NUMERIC(12,4)) and vk_netto (NUMERIC(12,4)). The field vk_eingabe (ENUM 'netto', 'brutto', default 'brutto') indicates which price the user entered directly. The other price MUST be derived: if vk_eingabe = 'brutto', vk_netto = vk_brutto / (1 + ust_satz); if vk_eingabe = 'netto', vk_brutto = vk_netto × (1 + ust_satz). Derived prices MUST NOT be rounded during calculation; rounding occurs only at position level during invoice computation.

#### Scenario: Brutto input preserves exact netto
- GIVEN an article with vk_eingabe = 'brutto', vk_brutto = 3.50, and USt = 19%
- WHEN the article is saved
- THEN vk_netto is stored as approximately 2.9412 (unrounded), not 2.94

#### Scenario: Netto input preserves exact brutto
- GIVEN an article with vk_eingabe = 'netto', vk_netto = 2.94, and USt = 19%
- WHEN the article is saved
- THEN vk_brutto is stored as approximately 3.4986 (unrounded), not 3.50

### Requirement: Artikel — Differenzbesteuerung

Each article MAY have differenzbesteuerung (margin scheme, §25a UStG) set to true. When true, the article's USt MUST be calculated on the margin (VK - EK) rather than on the full selling price. The article MUST optionally store ek_netto (purchase price) for margin calculation. Invoices carrying differenzbesteuerung positions MUST display "Differenzbesteuerung §25a UStG" on the PDF.

#### Scenario: Margin scheme invoice calculation
- GIVEN an invoice with a differenzbesteuerung article (VK netto 100, EK netto 60, Menge 1, USt 19%)
- WHEN the invoice is finalized
- THEN USt = (100 - 60) × 19% = 7.60, and the invoice total is 107.60

#### Scenario: Margin scheme without EK price
- GIVEN an article with differenzbesteuerung = true and ek_netto = NULL
- WHEN a user attempts to finalize an invoice with this article
- THEN the system blocks finalization with error "EK-Preis fehlt für Differenzbesteuerung"

### Requirement: Artikel — Lagerführung

Each article MAY have lager_aktiv (boolean). When true, the system MUST track bestand_aktuell (current stock, NUMERIC(10,3)), mindestbestand (minimum stock, NUMERIC(10,3)), and minusbestand_erlaubt (allow negative stock, boolean, default false). On invoice finalization, stock MUST be decremented by the ordered quantity. On storno, stock MUST be restored. If stock would go below mindestbestand, the system MUST display a warning. If minusbestand_erlaubt is false and stock would go below zero, the system MUST block finalization.

#### Scenario: Stock decrement on finalization
- GIVEN an article has bestand_aktuell = 20 and lager_aktiv = true
- WHEN an invoice with 5 units of that article is finalized
- THEN bestand_aktuell becomes 15

#### Scenario: Negative stock blocked
- GIVEN an article has bestand_aktuell = 3, minusbestand_erlaubt = false, and lager_aktiv = true
- WHEN a user finalizes an invoice with 10 units of that article
- THEN the system blocks finalization with error "Bestand nicht ausreichend (3 vorhanden, 10 benötigt)"

### Requirement: Artikel — Lieferantenverknüpfung

Each Artikel of type Artikel or Fremdleistung MAY be linked to a supplier (lieferant_id FK) with a lieferanten_artikelnr (supplier article number). This link is used for purchase tracking and EK-price history. Dienstleistung and Eigenleistung types MUST NOT have a supplier link.

#### Scenario: Dienstleistung rejects supplier link
- GIVEN a Dienstleistung article with lieferant_id set
- WHEN the article is saved
- THEN the system clears lieferant_id and lieferanten_artikelnr to NULL and persists the record

#### Scenario: Fremdleistung preserves supplier link
- GIVEN a Fremdleistung article with lieferant_id = 5 and lieferanten_artikelnr = "L-001"
- WHEN the article is saved
- THEN the supplier link and article number are persisted as provided

### Requirement: Artikelgruppen

Articles MAY be assigned to Artikelgruppen (article groups). Artikelgruppen have id, typ (string), name, and aktiv flag. Articles reference groups via gruppe_id FK. Groups are used for categorization and filtering in reports and invoice forms.

#### Scenario: Inactive group hidden from selection
- GIVEN an article group "Büromaterial" exists with aktiv = false
- WHEN a user creates an invoice position and the article group list is loaded
- THEN "Büromaterial" is not shown in the dropdown

#### Scenario: Active group visible in selection
- GIVEN an article group "Büromaterial" exists with aktiv = true
- WHEN a user creates an invoice position and the article group list is loaded
- THEN "Büromaterial" is shown in the dropdown

### Requirement: Unternehmen — CRUD

The system SHALL maintain a single Unternehmen (company) record as a singleton (id=1). The record MUST contain at minimum: Firmenname, Strasse, Hausnummer, PLZ, Ort, Land, Bundesland, Steuernummer, USt-IdNr, w_idnr (Wirtschafts-IdNr.), berufsbezeichnung, bezeichnung_des_gewerbes, kammer_mitgliedschaft, Geburtsdatum, bg_nummer, jobcenter_name. The system MUST allow updating any field and persist changes immediately.

#### Scenario: Update company logo
- GIVEN the Unternehmen record exists with logo_pfad = NULL
- WHEN a user uploads a new logo image via the company settings form
- THEN the system stores the image file in the uploads directory, updates logo_pfad, and returns the new path

#### Scenario: Update non-existent field rejected
- GIVEN the Unternehmen record has no field named "fake_field"
- WHEN a user submits a form with an unknown field
- THEN the system ignores the unknown field and persists only valid fields

### Requirement: Unternehmen — SMTP-Konfiguration

The Unternehmen record MUST store SMTP configuration: smtp_aktiv, smtp_host, smtp_port, smtp_ssl, smtp_user, smtp_passwort (encrypted at rest), smtp_von_adresse, smtp_zertifikat_ignorieren, smtp_zertifikat_fingerprint. The system MUST provide a test-connection endpoint that validates credentials without sending mail.

#### Scenario: SMTP test connection with invalid host
- GIVEN SMTP is configured with smtp_host = "invalid.local"
- WHEN a user triggers SMTP test connection
- THEN the system returns error "Verbindung fehlgeschlagen: Host nicht erreichbar" within 10 seconds

#### Scenario: SMTP test connection succeeds
- GIVEN SMTP is configured with valid host, port, and credentials
- WHEN a user triggers SMTP test connection
- THEN the system returns success "Verbindung erfolgreich hergestellt"

### Requirement: Unternehmen — PDF-Vorlage

The Unternehmen record MUST store `pdf_vorlage` as the template identifier `standard` or `gruen`. `standard` is the default full-color template; `gruen` is the Kleinunternehmer template. Unknown values MUST fall back to `standard` and log a warning. The system MUST apply this representation when generating all document PDFs.

#### Scenario: Grün template selection affects PDF output
- GIVEN pdf_vorlage = 'gruen' and a Kleinunternehmer invoice is finalized
- WHEN the PDF is generated
- THEN the generated PDF uses the Grün/Kleinunternehmer template without USt columns

#### Scenario: Standard template applied
- GIVEN pdf_vorlage = 'standard' and an invoice is finalized
- WHEN the PDF is generated
- THEN the generated PDF uses the standard template
### Requirement: Unternehmen — Unterschrift

The Unternehmen record MAY store unterschrift_bild (path to signature image) and unterschrift_auf_rechnung (boolean). When both are set, the signature image MUST appear at the bottom of generated invoice PDFs.

#### Scenario: Signature on invoice PDF
- GIVEN unterschrift_auf_rechnung = true and unterschrift_bild points to a valid image
- WHEN an invoice PDF is generated
- THEN the PDF includes the signature image above the Schlusstext

#### Scenario: Signature omitted when disabled
- GIVEN unterschrift_auf_rechnung = false and unterschrift_bild points to a valid image
- WHEN an invoice PDF is generated
- THEN the PDF does not include the signature image

### Requirement: Unternehmen — QR-Zahlung

The Unternehmen record MAY have qr_zahlung_aktiv (boolean). When true, generated invoice PDFs MUST include a QR code containing the payment data (IBAN, Betrag, Empfänger, Verwendungszweck) conforming to EPC QR Code standard (ISO 13616).

#### Scenario: QR code on invoice
- GIVEN qr_zahlung_aktiv = true
- WHEN an invoice is finalized
- THEN the PDF contains a scannable EPC QR code in the payment section

#### Scenario: QR code omitted when disabled
- GIVEN qr_zahlung_aktiv = false
- WHEN an invoice is finalized
- THEN the PDF does not include a QR code

### Requirement: Unternehmen — Skonto

The Unternehmen record MUST store standard_skonto_prozent (NUMERIC(5,2)) and standard_skonto_tage (INTEGER) as company-wide defaults. These defaults apply to all invoices unless overridden at customer or invoice level. Skonto calculation MUST reduce the invoice total by the percentage when paid within the specified days.

#### Scenario: Company default skonto applied
- GIVEN standard_skonto_prozent = 3 and standard_skonto_tage = 10
- WHEN an invoice of 1000 EUR is finalized
- THEN the invoice shows "Skonto: 3% bei Zahlung innerhalb 10 Tagen = 970,00 EUR" and the payment amount is 970.00 EUR if paid within 10 days

#### Scenario: Customer-level skonto overrides company default
- GIVEN standard_skonto_prozent = 3 and a customer has skonto_prozent = 5
- WHEN an invoice for that customer is finalized
- THEN the invoice shows 5% Skonto (customer override), not 3%

### Requirement: Unternehmen — Zahlungsziel

The Unternehmen record MUST store standard_zahlungsziel (INTEGER, days) as the default payment term. This value MUST be used as the DueDate offset from Rechnungsdatum when generating invoices, unless overridden per invoice.

#### Scenario: Default payment term
- GIVEN standard_zahlungsziel = 14
- WHEN an invoice is created on 2026-01-15
- THEN Faelligkeitsdatum is set to 2026-01-29

#### Scenario: Per-invoice override
- GIVEN standard_zahlungsziel = 14
- WHEN an invoice is created on 2026-01-15 with zahlungsziel = 30
- THEN Faelligkeitsdatum is set to 2026-02-14 (invoice override)

### Requirement: Unternehmen — Steuer-Fristen

The Unternehmen record MUST store bundesland (VARCHAR(2)), dauerfristverlaengerung_ust (boolean), est_vorauszahlungen_aktiv (boolean), and gewst_vorauszahlungen_aktiv (boolean). These fields drive the Steuerfristen calendar on the dashboard, showing upcoming tax deadlines for USt-Voranmeldung, ESt-Vorauszahlungen, and GewSt-Vorauszahlungen.

#### Scenario: Tax calendar shows state-specific deadlines
- GIVEN bundesland = "BY" and dauerfristverlaengerung_ust = true
- WHEN the tax deadline calendar is rendered
- THEN the UStVA deadline shows the extended deadline for Bavaria (10th of the month following the quarter + Dauerfristverlängerung)

#### Scenario: Tax deadlines hidden when features inactive
- GIVEN est_vorauszahlungen_aktiv = false and gewst_vorauszahlungen_aktiv = false
- WHEN the tax deadline calendar is rendered
- THEN only USt-Voranmeldung deadlines are shown (ESt and GewSt sections are hidden)

### Requirement: Unternehmen — Dashboard-Konfiguration

The Unternehmen record MUST store dashboard_config (TEXT, JSON). This JSON defines widget order, visibility, and shortcut links. The system MUST render the dashboard according to this configuration. Default configuration MUST be provided on first run.

#### Scenario: Custom dashboard layout
- GIVEN dashboard_config = {"widgets": ["einnahmen", "ausgaben", "lager"], "shortcuts": ["rechnung_neu"]}
- WHEN the dashboard is rendered
- THEN exactly those three widgets appear in order with the shortcut button visible

#### Scenario: Missing config falls back to default
- GIVEN dashboard_config = NULL
- WHEN the dashboard is rendered
- THEN the system applies the default dashboard layout

### Requirement: Unternehmen — Profilmanager

The Unternehmen record MUST store profilmanager_aktiv (boolean, default false). When true, the Profile menu item is visible. When false, it is hidden unless more than one profile exists. Profile switching requires a process restart.

#### Scenario: Single profile hides menu
- GIVEN profilmanager_aktiv = false and only one profile exists
- WHEN the navigation is rendered
- THEN the Profile menu item is not shown

#### Scenario: Multiple profiles force menu visible
- GIVEN profilmanager_aktiv = false and two profiles exist
- WHEN the navigation is rendered
- THEN the Profile menu item is shown (forced by multiple profiles)

### Requirement: Kategorien — CRUD

The system SHALL provide full CRUD for Kategorien (booking categories). Each category MUST have id, name, art (Einnahme/Ausgabe), konto_skr03 (VARCHAR, SKR03 account number), konto_skr04 (VARCHAR, SKR04 account number), euer_zeile (INTEGER, EÜR line assignment), eks_kategorie (VARCHAR, EKS section), aktiv (boolean, default true), and beschreibung (TEXT). System-seeded categories MUST be deletable only if not referenced by journal entries.

#### Scenario: Create custom category
- GIVEN the user is on the category management page
- WHEN a user creates a category with name "Bürobedarf", art = "Ausgabe", konto_skr03 = "0660", konto_skr04 = "0660"
- THEN the category is persisted and available for journal booking selection

#### Scenario: Delete system-seeded category with references
- GIVEN the system-seeded category "Sonstige betriebl. Ausgaben" is referenced by 5 journal entries
- WHEN a user attempts to delete "Sonstige betriebl. Ausgaben"
- THEN the system rejects the deletion with error "Kategorie wird von 5 Journalbuchungen verwendet"

### Requirement: Kategorien — SKR-Kontonummern

Each category MUST have konto_skr03 and konto_skr04 fields. The system MUST use the active SKR (selected in company settings) to determine which account number is used for DATEV export and financial reports. Categories MUST also store konto_ust_skr03/konto_ust_skr04 for the USt-Gegenkonto.

#### Scenario: SKR03 category used in DATEV export
- GIVEN the company uses SKR03 and a journal entry is booked to category "Bürobedarf" (konto_skr03 = "0660")
- WHEN the DATEV export runs
- THEN the export uses account 0660 as the Hauptkonto

#### Scenario: SKR04 category used in DATEV export
- GIVEN the company uses SKR04 and a journal entry is booked to category "Bürobedarf" (konto_skr04 = "0660")
- WHEN the DATEV export runs
- THEN the export uses account 0660 as the Hauptkonto

### Requirement: Kategorien — EÜR-Zeilenzuordnung

Each category MUST have euer_zeile (INTEGER, nullable). When set, journal entries on this category appear on the corresponding EÜR line in the Einnahmenüberschussrechnung report. When NULL, the category does not appear in EÜR.

#### Scenario: Category appears on correct EÜR line
- GIVEN the category "Betriebseinnahmen" has euer_zeile = 12
- WHEN a journal entry is booked to "Betriebseinnahmen"
- THEN the EÜR report shows this amount on line 12 (Einnahmen Kleinunternehmer §19)

#### Scenario: Category with NULL euer_zeile excluded from EÜR
- GIVEN the category "Privatentnahme" has euer_zeile = NULL
- WHEN a journal entry is booked to "Privatentnahme"
- THEN the EÜR report does not include this amount

### Requirement: Kategorien — eks_kategorie

Each category MAY have eks_kategorie (VARCHAR, nullable). When set, journal entries are included in the EKS (Einnahmen-Kosten-Spiegel) report under the specified section. The EKS section identifier maps to the Anlage EKS form sections (e.g., B6_5 for Fahrtkosten).

#### Scenario: EKS section assignment
- GIVEN the category "Fahrtkosten" has eks_kategorie = "B6_5"
- WHEN a journal entry is booked to "Fahrtkosten"
- THEN the EKS report includes this amount under section B6_5 (Fahrkosten)

#### Scenario: Category without eks_kategorie excluded from EKS
- GIVEN the category "Bürobedarf" has eks_kategorie = NULL
- WHEN a journal entry is booked to "Bürobedarf"
- THEN the EKS report does not include this amount

### Requirement: Konten — CRUD

The system SHALL provide CRUD for bank accounts (Konten). Each account MUST have id, bezeichnung, iban (nullable), bic (nullable), kontoart (ENUM: Girokonto, Sparkonto, Kreditkarte, Paypal, Sonstiges), anbieter (VARCHAR), kennung (VARCHAR), and datev_kontonummer (VARCHAR(8), nullable). IBAN MUST be nullable for non-IBAN accounts (PayPal, Kreditkarte). A partial unique index prevents duplicate IBANs when not null.

#### Scenario: PayPal account without IBAN
- GIVEN a user creates a Konto with kontoart = "Paypal"
- WHEN iban is left NULL and the account is saved
- THEN the account is persisted without IBAN validation

#### Scenario: Duplicate IBAN rejected
- GIVEN an existing Girokonto has iban = "DE89370400440532013000"
- WHEN a user creates a second account with iban = "DE89370400440532013000"
- THEN the system rejects the save with error "IBAN bereits vergeben"

### Requirement: Nummernkreise — Format-based numbering

The system MUST maintain Nummernkreise (number ranges) for each document type: rechnung_ausgang (RE-YY####), angebot (ANG-YY####), auftrag (AU-YY####), proforma (PRF-YY####), lieferschein (LS-YY####), stornorechnung (STORNO-YY####), gutschrift (GS-YY####), debitor (1####), kreditor (7####). Each range has id, typ, bezeichnung, format (e.g., "RE-YY####"), letzte_nummer, and aktiv (boolean). The system MUST auto-generate the next number on document finalization using the format template. YY = 2-digit year, #### = sequential 4-digit counter, auto-resetting yearly.

#### Scenario: Year rollover resets counter
- GIVEN the last rechnung_ausgang number in 2025 was RE-250100 and it is now 2026
- WHEN the first invoice of 2026 is finalized
- THEN the new invoice receives number RE-260001

#### Scenario: Format template applied correctly
- GIVEN the angebot format is "ANG-YY####", the current year is 2026, and letzte_nummer = 6
- WHEN the next Angebot is finalized
- THEN it receives number "ANG-260007"

### Requirement: Steuersätze

The system MUST maintain a seeded set of tax rates (USt-Sätze): 0%, 7%, and 19%. Each rate has id, satz (NUMERIC(5,2)), and bezeichnung. These rates are used for invoice position taxation and EÜR/UStVA calculations. Users MUST NOT be able to delete system-seeded rates; custom rates MAY be added.

#### Scenario: Create custom tax rate
- GIVEN the system has the three seeded rates (0%, 7%, 19%)
- WHEN a user adds a 5.5% tax rate for a specific use case
- THEN the rate is available for selection on invoice positions

#### Scenario: System-seeded rate deletion blocked
- GIVEN the 19% tax rate is a system-seeded rate
- WHEN a user attempts to delete the 19% rate
- THEN the system rejects the deletion with error "System-seed Steuersatz kann nicht gelöscht werden"

### Requirement: Kunden-Lieferadressen

Each customer MAY have multiple Lieferadressen (delivery addresses). Each address has id, kunde_id FK, bezeichnung, z_hd (recipient), strasse, hausnummer, plz, ort, land, and ist_standard (boolean). One address per customer MUST be marked as standard. Delivery addresses appear on Lieferschein and can be selected during invoice creation.

#### Scenario: Select non-standard delivery address
- GIVEN a customer has 3 delivery addresses (1 standard, 2 non-standard)
- WHEN a user creates a Lieferschein for that customer
- THEN the system shows all 3 addresses and allows selection; the standard address is pre-selected

#### Scenario: Multiple standard addresses prevented
- GIVEN a customer has a delivery address "Werkstatt" marked as ist_standard = true
- WHEN a user sets a second address "Büro" as ist_standard = true
- THEN the system clears ist_standard on "Werkstatt" and only "Büro" remains standard

### Requirement: Kunden-Belege

Each customer MAY have associated Belege (customer documents: contracts, certificates, etc.). Each Beleg has id, kunde_id FK, dateiname, original_name, mime_type, dateigroesse, sha256, hochgeladen_am, and loeschdatum (DATE, nullable for DSGVO). The system MUST provide upload, inline preview, rename, and delete operations. Documents past their loeschdatum MUST be flagged visually (red if overdue, yellow if ≤ 30 days).

#### Scenario: DSGVO expiry warning
- GIVEN a customer document has loeschdatum = 2026-02-15 and today is 2026-02-10
- WHEN the customer document list is rendered
- THEN the document is displayed with a yellow warning badge "Löschen in 5 Tagen"

#### Scenario: DSGVO overdue flag
- GIVEN a customer document has loeschdatum = 2026-02-15 and today is 2026-02-20
- WHEN the customer document list is rendered
- THEN the document is displayed with a red warning badge indicating it is overdue for deletion
