# OpenInvoices — Accounting Specification

## ADDED Requirements

### Requirement: Journal Entries

The system SHALL maintain a journal of all booking entries with GoBD-immutable protection via database triggers. Each entry SHALL contain date, description, category_id, betrag (brutto), art (Einnahme/Ausgabe), and optional fields for konto_skr03/04, vorsteuer_betrag, ust_satz, and partner references.

#### Scenario: Booking creation

- GIVEN a valid category, art, and brutto_betrag
- WHEN a new journal entry is created
- THEN the system SHALL insert a row with auto-generated id, current date, description, category_id, brutto_betrag, art, and GoBD trigger protection (immutable=0 initially)

#### Scenario: GoBD immutability

- GIVEN a journal entry with immutable=1 (finalized)
- WHEN an UPDATE or DELETE operation is attempted on that row
- THEN the GoBD trigger SHALL prevent the operation and return an error

#### Scenario: Storno entry

- GIVEN a finalized journal entry to be reversed
- WHEN a Storno is created
- THEN the system SHALL create a new entry with negative betrag, reference to the original entry via id, and immutability flag

#### Scenario: Buchungsgruppen

- GIVEN a journal entry that is part of a booking group (original + storno + new)
- WHEN the entry is created
- THEN the system SHALL link original, storno, and new entries via gruppe_id (FK → journal.id)

#### Scenario: Missing required fields

- GIVEN a journal entry creation request with category_id = NULL or brutto_betrag = NULL
- WHEN the entry is submitted
- THEN the system SHALL reject creation with a validation error

### Requirement: Kategorien

The system SHALL provide 65+ predefined categories with SKR03/SKR04 account mapping, euer_zeile (Anlage EÜR line number), eks_kategorie (Anlage EKS field), and activation status.

#### Scenario: Category with SKR mapping

- GIVEN a category is created or seeded
- WHEN the category is persisted
- THEN it SHALL have konto_skr03, konto_skr04, euer_zeile, eks_kategorie, and aktiv fields populated

#### Scenario: User-modified SKR account

- GIVEN a user overrides the SKR03 account for a category
- WHEN the override is saved
- THEN the system SHALL store the override in user_modified_skr03 and use it for all future entries while preserving the original default

#### Scenario: Inactive category

- GIVEN a category with aktiv=0
- WHEN the booking form is displayed
- THEN the category SHALL not appear in dropdowns, but existing journal entries referencing it SHALL remain visible

#### Scenario: Category description

- GIVEN a category with beschreibung set
- WHEN a user selects the category in the booking form
- THEN the booking form SHALL display the description as a hint

#### Scenario: Category with missing SKR mapping

- GIVEN a category with konto_skr03 = NULL or konto_skr04 = NULL
- WHEN a journal entry uses that category
- THEN the system SHALL use a default account or flag the entry for review

### Requirement: EÜR (Einnahmen-Überschuss-Rechnung)

The system SHALL generate Anlage EÜR 2025 with 60+ line items (Zeilen 12–107), computing totals from journal entries grouped by euer_zeile.

#### Scenario: EÜR Zeile 12 — Kleinunternehmer §19

- GIVEN journal entries exist for categories with euer_zeile=12 (Betriebseinnahmen without USt)
- WHEN the EÜR is generated
- THEN Zeile 12 SHALL show the sum of those entries' brutto_betrag

#### Scenario: EÜR Zeile 15 — Umsatzsteuerpflichtige Betriebseinnahmen

- GIVEN journal entries exist for categories with euer_zeile=15 (19% + 7% Betriebseinnahmen combined)
- WHEN the EÜR is generated
- THEN Zeile 15 SHALL show the sum of those entries' brutto_betrag

#### Scenario: EÜR Zeile 16 — Steuerfreie Betriebseinnahmen §4

- GIVEN journal entries exist for categories with euer_zeile=16 (steuerfreie innergemeinschaftliche Lieferungen)
- WHEN the EÜR is generated
- THEN Zeile 16 SHALL show the sum of those entries' brutto_betrag

#### Scenario: EÜR Zeile 33 — Abschreibungen (AfA)

- GIVEN Anlagenverzeichnis entries exist with AfA
- WHEN the EÜR is generated
- THEN Zeile 33 SHALL show the total AfA from the Anlagenverzeichnis, not from journal entries

#### Scenario: EÜR Zeile 60 — Sonstige Betriebsausgaben

- GIVEN journal entries exist for categories with euer_zeile=60 (e.g., Bauleistungen §13b, EU-DL §13b)
- WHEN the EÜR is generated
- THEN Zeile 60 SHALL show the sum of those entries' betrag

#### Scenario: EÜR Zeile 106/107 — Privatentnahme/Privateinlage

- GIVEN journal entries exist for Privatentnahme (euer_zeile=106) or Privateinlage (euer_zeile=107)
- WHEN the EÜR is generated
- THEN these SHALL appear as Hinweiszeilen (note lines) in the EÜR without affecting the Gewinn/Verlust computation

#### Scenario: Vorsteuerabzug Soll-Prinzip

- GIVEN a period ab CUTOVER_DATUM with vorsteuer_ansprueche entries
- WHEN the EÜR is generated
- THEN Vorsteuer SHALL be sourced from vorsteuer_ansprueche (Soll-Prinzip §15 UStG), not from journal.vorsteuer_betrag (Zahlungsprinzip)

#### Scenario: EÜR with no journal entries

- GIVEN a period with no journal entries
- WHEN the EÜR is generated
- THEN all Zeilen SHALL show 0,00 € and the Gewinn/Verlust SHALL be 0,00 €

### Requirement: UStVA (Umsatzsteuer-Voranmeldung)

The system SHALL compute monthly or quarterly Umsatzsteuer-Voranmeldung with Kennzahlen (KZ) 1–22, configurable by Voranmeldungsrhythmus (monatlich/quartal).

#### Scenario: KZ 1 — Gesamtumsatz steuerpflichtig

- GIVEN journal entries with taxable turnover in a filing period
- WHEN the UStVA is computed
- THEN KZ 1 SHALL show the total taxable turnover from journal entries in that period

#### Scenario: KZ 3 — Umsatzsteuer (19%)

- GIVEN journal entries with ust_satz=19% in a filing period
- WHEN the UStVA is computed
- THEN KZ 3 SHALL show the USt amount from those entries

#### Scenario: KZ 4 — Umsatzsteuer (7%)

- GIVEN journal entries with ust_satz=7% in a filing period
- WHEN the UStVA is computed
- THEN KZ 4 SHALL show the USt amount from those entries

#### Scenario: KZ 18 — Differenzsteuer §25a

- GIVEN a UStVA period including Differenzbesteuerung entries
- WHEN the UStVA is computed
- THEN KZ 18 SHALL show the margin-based USt (marge_25a_brutto × ust_satz_25a / (100 + ust_satz_25a))

#### Scenario: KZ 61 — Vorsteuerabzug ig Erwerb

- GIVEN journal entries with ust_sonderfall='ig_erwerb' in a filing period
- WHEN the UStVA is computed
- THEN KZ 61 SHALL show the Vorsteuer from those entries (not KZ 66)

#### Scenario: KZ 81/83 — Differenzbetrag §25a

- GIVEN a UStVA period including §25a entries
- WHEN the UStVA is computed
- THEN KZ 81 SHALL show the margin (marge_25a_brutto) and KZ 83 SHALL show the USt on the margin

#### Scenario: Quarterly filing

- GIVEN voranmeldungsrhythmus='quartal'
- WHEN the UStVA is computed
- THEN the system SHALL aggregate data for the quarter (3 months) and file for that period

#### Scenario: No transactions in period

- GIVEN a filing period with no journal entries
- WHEN the UStVA is computed
- THEN all Kennzahlen SHALL show 0 and the filing SHALL be a zero-returns

### Requirement: EKS (Anlage EKS — Einnahmen-Kostenübersicht)

The system SHALL generate a 9-page Anlage EKS for Jobcenter Transferleistungen, populating sections A–I from company, customer, and journal data.

#### Scenario: EKS Section D — Company data

- GIVEN an EKS generation request
- WHEN the EKS is generated
- THEN Section D SHALL be populated from unternehmen fields (berufsbezeichnung, kammer_mitgliedschaft, geburtsdatum, bg_nummer, jobcenter_name)

#### Scenario: EKS Section F — Income and costs

- GIVEN journal entries mapped via eks_kategorie
- WHEN the EKS is generated
- THEN Section F (Zeilen 23–41) SHALL be populated from those journal entries

#### Scenario: EKS B6_5 — Travel costs

- GIVEN journal entries with km_anzahl set
- WHEN the EKS is generated
- THEN EKS B6_5 SHALL show km_anzahl × 0.10 (Jobcenter travel allowance)

#### Scenario: EKS B6_4_priv — Private car deduction

- GIVEN a Betriebs-KFZ with privat_anteil_prozent
- WHEN the EKS is generated
- THEN EKS B6_4_priv SHALL show the deduction for privately driven kilometers from Betriebs-KFZ entries

#### Scenario: EKS Page 9 — Summary

- GIVEN an EKS generation request
- WHEN the EKS is generated
- THEN Page 9 SHALL show the EKS summary with total income, total costs, and net result

#### Scenario: Missing EKS required data

- GIVEN an EKS request for a customer with missing bg_nummer or jobcenter_name
- WHEN the EKS is generated
- THEN the system SHALL render those fields as empty and log a warning, without failing the entire generation

### Requirement: GuV (Gewinn- und Verlustrechnung)

The system SHALL compute GuV per §141 AO when Buchführungspflicht thresholds are exceeded (800,000 € Umsatz or 80,000 € Gewinn).

#### Scenario: Threshold exceeded

- GIVEN annual Umsatz exceeds 800,000 € or annual Gewinn exceeds 80,000 €
- WHEN the Dashboard is loaded
- THEN the system SHALL display a GuV warning and auto-enable GuV computation

#### Scenario: GuV computation

- GIVEN guv_aktiv=true
- WHEN the GuV is generated
- THEN the system SHALL compute a GuV from journal entries grouped by SKR03/SKR04 account ranges (Erträge 1–4, Aufwendungen 5–8)

#### Scenario: Threshold not exceeded

- GIVEN annual Umsatz < 800,000 € and annual Gewinn < 80,000 €
- WHEN guv_aktiv=false
- THEN the GuV section SHALL not be displayed on the Dashboard

### Requirement: ZM (Zusammenfassende Meldung)

The system SHALL generate a Zusammenfassende Meldung for EU intra-community transactions (§18 UStG).

#### Scenario: ZM with ig Lieferungen

- GIVEN journal entries for innergemeinschaftliche Lieferungen (ust_sonderfall=NULL, ist_eu_lieferung=true)
- WHEN the ZM is generated
- THEN the ZM SHALL include those amounts with correct country codes and USt-IdNr of the customer

#### Scenario: ZM with ig Erwerb

- GIVEN journal entries for innergemeinschaftlicher Erwerb (ust_sonderfall='ig_erwerb')
- WHEN the ZM is generated
- THEN the ZM SHALL include those amounts separately

#### Scenario: No EU transactions in period

- GIVEN a period with no EU intra-community transactions
- WHEN the ZM is generated
- THEN the system SHALL generate an empty ZM or indicate no reportable transactions

### Requirement: DATEV EXTF Export

The system SHALL export journal entries in DATEV EXTF (Buchungsstapel) format with configurable company identifiers.

#### Scenario: DATEV export generation

- GIVEN journal entries in a selected period
- WHEN a DATEV export is requested
- THEN the system SHALL produce a CSV file in DATEV EXTF format with header record, debit/credit records, and account mappings from konto_skr03/04 or konto_id.datev_kontonummer

#### Scenario: DATEV account mapping

- GIVEN a journal entry with konto_id referencing a konten record with datev_kontonummer set
- WHEN the DATEV export is generated
- THEN the export SHALL use that konto.datev_kontonummer instead of the global datev_konto_bank

#### Scenario: DATEV metadata

- GIVEN a DATEV export is requested
- WHEN the export header is generated
- THEN the system SHALL include datev_beraternummer and datev_mandantennummer from unternehmen in the export header

#### Scenario: DATEV export with missing company config

- GIVEN a company with datev_beraternummer or datev_mandantennummer = NULL
- WHEN the DATEV export is generated
- THEN the system SHALL reject generation with an error indicating missing DATEV configuration

### Requirement: GoBD Export

The system SHALL generate a complete GoBD-compliant audit trail export as a ZIP file containing all documents, journal entries, and metadata.

#### Scenario: GoBD ZIP generation

- GIVEN a period selected for GoBD export
- WHEN the GoBD export is requested
- THEN the system SHALL produce a ZIP containing all finalized document PDFs, the journal ledger, EÜR/UStVA reports, and a manifest with SHA-256 hashes for each file

#### Scenario: GoBD integrity verification

- GIVEN a previously generated GoBD export
- WHEN the export is verified
- THEN the system SHALL recompute SHA-256 hashes for each file and compare against the manifest, reporting any mismatches

#### Scenario: GoBD export with missing documents

- GIVEN a period where some finalized documents lack PDFs (e.g., deleted files)
- WHEN the GoBD export is generated
- THEN the system SHALL include a manifest entry noting the missing file and log a warning

### Requirement: Vorsteueransprüche

The system SHALL maintain independent Vorsteueransprüche (input tax claims) per Soll-Prinzip §15 UStG, separate from journal.vorsteuer_betrag (Zahlungsprinzip).

#### Scenario: Eingangsrechnung booked

- GIVEN an Eingangsrechnung is finalized with Vorsteuer
- WHEN the finalization is committed
- THEN the system SHALL create a vorsteuer_anspruch entry with the full Vorsteuer amount, independent of payment status

#### Scenario: Vorsteuerabzug ab CUTOVER

- GIVEN UStVA computed ab CUTOVER_DATUM
- WHEN KZ 66/61/62/67 are calculated
- THEN Vorsteuer SHALL be sourced from vorsteuer_ansprueche, not from journal entries

#### Scenario: Storno correction

- GIVEN a Storno created for an Eingangsrechnung
- WHEN the Storno is committed
- THEN the system SHALL create a negative vorsteuer_anspruch at the Storno date, not retroactively

#### Scenario: Duplicate vorsteuer_anspruch prevention

- GIVEN a vorsteuer_anspruch already exists for a specific Eingangsrechnung
- WHEN a duplicate creation is attempted
- THEN the system SHALL reject the duplicate and preserve the existing entry

### Requirement: SKR03/SKR04 Parallel Display

The system SHALL display both SKR03 and SKR04 account numbers in parallel across all accounting views.

#### Scenario: Dual SKR display

- GIVEN the Kontenübersicht view
- WHEN a category is displayed
- THEN both konto_skr03 and konto_skr04 SHALL be shown side by side

#### Scenario: SKR toggle

- GIVEN the user toggles between SKR03 and SKR04 view
- WHEN the toggle is applied
- THEN all account references SHALL switch to the selected SKR system

### Requirement: Tax Calculation

The system SHALL calculate Umsatzsteuer for 19%, 7%, and 0% rates, Kleinunternehmer §19 (no USt), and Differenzbesteuerung §25a (margin scheme).

#### Scenario: Standard 19% USt

- GIVEN a Rechnung with positions having ust_satz=19%
- WHEN the Rechnung is calculated
- THEN the system SHALL compute USt = sum(position_netto × 19/100) per position, rounded to 2 decimals

#### Scenario: 7% USt

- GIVEN a Rechnung with positions having ust_satz=7%
- WHEN the Rechnung is calculated
- THEN the system SHALL compute USt = sum(position_netto × 7/100) per position, rounded to 2 decimals

#### Scenario: Kleinunternehmer §19

- GIVEN unternehmen uses Kleinunternehmer §19
- WHEN a Rechnung is calculated
- THEN no USt SHALL be computed or displayed on any document, and KZ 12 in UStVA SHALL be used

#### Scenario: Differenzbesteuerung §25a

- GIVEN a position with differenzbesteuerung=true
- WHEN the position is calculated
- THEN USt SHALL be computed on the margin (VK_brutto - EK_netto × menge) at the nominal ust_satz_25a, and the invoice SHALL show 0% USt with a §25a note

#### Scenario: Mixed document

- GIVEN a Rechnung with both standard and §25a positions
- WHEN the Rechnung is calculated
- THEN standard positions SHALL compute USt normally, §25a positions SHALL compute USt on margin, and the total USt SHALL be the sum of both

#### Scenario: Invalid ust_satz

- GIVEN a position with ust_satz not in {0, 7, 19} (e.g., 10%)
- WHEN the Rechnung is calculated
- THEN the system SHALL reject the calculation with a validation error for the invalid tax rate

### Requirement: Skonto

The system SHALL apply Skonto (cash discount) at company, customer, or invoice level, reducing the payment amount.

#### Scenario: Company-level Skonto

- GIVEN a company with standard_skonto_prozent=2 and standard_skonto_tage=10
- WHEN a Rechnung is created
- THEN the Rechnung SHALL offer 2% Skonto when paid within 10 days

#### Scenario: Customer-level Skonto

- GIVEN a customer with skonto_prozent=3 and skonto_tage=14
- WHEN a Rechnung for that customer is created
- THEN the Rechnung SHALL override company defaults with 3% within 14 days

#### Scenario: Invoice-level Skonto

- GIVEN a Rechnung with skonto_prozent=1 and skonto_tage=7
- WHEN the Rechnung is finalized
- THEN that specific Rechnung SHALL offer 1% within 7 days, overriding all defaults

#### Scenario: Skonto payment

- GIVEN a payment received within the Skonto period
- WHEN the payment is recorded
- THEN the system SHALL record the reduced amount and book the Skonto as "Gewährte Skonti" (euer_zeile=NULL, no EÜR impact)

#### Scenario: Skonto expiry

- GIVEN a payment received after the Skonto period
- WHEN the payment is recorded
- THEN the system SHALL charge the full invoice amount without Skonto discount

### Requirement: Payment Processing

The system SHALL handle partial payments, Überzahlungen (overpayments), and Forderungen (receivables).

#### Scenario: Partial payment

- GIVEN a 100€ Rechnung with a 50€ payment received
- WHEN the payment is recorded
- THEN the system SHALL record 50€ as bezahlt_betrag, set zahlungsstatus='teilbezahlt', and the Rechnung SHALL remain in the offene Posten list

#### Scenario: Full payment

- GIVEN a 100€ Rechnung with a 100€ payment received
- WHEN the payment is recorded
- THEN the system SHALL set bezahlt_betrag=100, zahlungsstatus='bezahlt', and remove the Rechnung from offene Posten

#### Scenario: Überzahlung recognized

- GIVEN a payment exceeding the Rechnungsbetrag with überzahlung_anerkannt=true
- WHEN the payment is recorded
- THEN the system SHALL remove the Rechnung from the Dashboard Überzahlungs-Widget

#### Scenario: Überzahlung not recognized

- GIVEN a payment exceeding the Rechnungsbetrag with überzahlung_anerkannt=false
- WHEN the payment is recorded
- THEN the system SHALL keep the Rechnung in the Überzahlungs-Widget until acknowledged

#### Scenario: Forderungsausfall

- GIVEN a Forderung marked as Forderungsausfall
- WHEN the Ausbuchung is committed
- THEN the system SHALL book the loss as a journal entry and remove it from offene Posten

#### Scenario: Eingangsrechnung Überzahlung

- GIVEN an Eingangsrechnung that is overpaid
- WHEN the Überzahlung is processed
- THEN the system SHALL create a Split-Buchung with the invoice amount and a Forderung for the overpayment as Lieferantenguthaben

### Requirement: Tagesabschluss

The system SHALL support daily cash close (Tagesabschluss) with expected vs. counted amounts and discrepancy notes.

#### Scenario: Tagesabschluss creation

- GIVEN a Tagesabschluss initiated for a specific date
- WHEN the expected cash amount is computed
- THEN the system SHALL compute the expected cash amount from all journal entries for that day and present it for manual counting entry

#### Scenario: Counting discrepancy

- GIVEN a counted amount differing from the expected amount
- WHEN the Tagesabschluss is finalized
- THEN the system SHALL record the discrepancy in zaehlung_json and flag it in the Tagesabschluss PDF

#### Scenario: GoBD signature

- GIVEN a Tagesabschluss with zaehlung_json finalized
- WHEN the Tagesabschluss is committed
- THEN the system SHALL compute a SHA-256 signature and store it as signatur in the database

#### Scenario: Double close prevention

- GIVEN a Tagesabschluss already finalized for a specific date
- WHEN another Tagesabschluss is initiated for the same date
- THEN the system SHALL reject creation or allow reopening the existing one

### Requirement: Steuersätze Management

The system SHALL manage a configurable set of Steuersätze (tax rates) with 0%, 7%, and 19% as defaults.

#### Scenario: Default tax rates

- WHEN a new database is seeded
- THEN the system SHALL create Steuersätze for 0%, 7%, and 19%

#### Scenario: Custom tax rate

- GIVEN a user adds a custom Steuersatz (e.g., 5% for specific goods)
- WHEN the custom rate is saved
- THEN the system SHALL allow it in Kategorien and document position calculations

#### Scenario: Tax rate snapshot

- WHEN a journal entry is created
- THEN the system SHALL snapshot the ust_satz in the journal entry to preserve historical accuracy

#### Scenario: Deleting a tax rate in use

- GIVEN a Steuersatz referenced by existing journal entries
- WHEN deletion is attempted
- THEN the system SHALL reject deletion and indicate the rate is in use

### Requirement: Buchungsvorlagen

The system SHALL support recurring booking templates (Buchungsvorlagen) for fixed costs and regular income.

#### Scenario: Template creation

- GIVEN a Buchungsvorlage created with art='Ausgabe', category, and betrag
- WHEN the template is saved
- THEN the system SHALL store the template with interval configuration and position data as JSON

#### Scenario: Template execution

- GIVEN a Buchungsvorlage that is due
- WHEN the execution is triggered
- THEN the system SHALL create a journal entry (or Eingangsrechnung) from the template, using the current art-korrekte USt-Konten

#### Scenario: Template with article

- GIVEN a Buchungsvorlage referencing an artikel_id
- WHEN the template is executed
- THEN the system SHALL use the article's current price for the booking, not the price at template creation time

#### Scenario: Template lifecycle

- GIVEN a Buchungsvorlage paused (aktiv=false, beendet=false)
- WHEN the scheduled execution date arrives
- THEN no new bookings SHALL be created until reactivated. When beendet=true, the template SHALL be archived

#### Scenario: Template with deleted category

- GIVEN a Buchungsvorlage referencing a category that has been deactivated (aktiv=0)
- WHEN the template is executed
- THEN the system SHALL still create the booking using the deactivated category and log a warning

### Requirement: Schnellbuchungen

The system SHALL provide quick booking presets (Schnellbuchungen) for frequent bar transactions.

#### Scenario: Quick booking preset

- GIVEN a user creates a Schnellbuchung preset with category, art, betrag, and description
- WHEN the preset is saved
- THEN it SHALL store the values for one-click booking

#### Scenario: Quick booking execution

- GIVEN a Schnellbuchung preset activated by the user
- WHEN the execution is triggered
- THEN the system SHALL create a journal entry immediately with the preset values

#### Scenario: Quick booking with invalid preset

- GIVEN a Schnellbuchung preset with an inactive category
- WHEN the preset is executed
- THEN the system SHALL still create the booking and log a warning about the inactive category

### Requirement: Reverse Charge

The system SHALL handle Reverse Charge scenarios per §13b UStG for innergemeinschaftliche Dienstleistungen, Bauleistungen, and ig Erwerb.

#### Scenario: §13b Abs. 1 — EU-Dienstleistungen

- GIVEN a journal entry with ust_sonderfall='13b_abs1'
- WHEN the entry is created
- THEN USt SHALL be 0% on the invoice, and the buyer SHALL account for USt via Reverse Charge (KZ 89/93 in UStVA)

#### Scenario: §13b Abs. 2 — Bauleistungen

- GIVEN a journal entry with ust_sonderfall='13b_abs2'
- WHEN the entry is created
- THEN USt SHALL be 0% on the invoice, and the buyer SHALL account for USt via Reverse Charge

#### Scenario: Innergemeinschaftlicher Erwerb

- GIVEN a journal entry with ust_sonderfall='ig_erwerb'
- WHEN the entry is created
- THEN the Vorsteuer SHALL be booked via KZ 61 (not KZ 66) in UStVA

#### Scenario: Invalid ust_sonderfall value

- GIVEN a journal entry with ust_sonderfall set to an unrecognized value (e.g., '13b_abs3')
- WHEN the entry is created
- THEN the system SHALL reject the entry with a validation error for the invalid sonderfall value

### Requirement: Anlagenverzeichnis

The system SHALL maintain an Anlagenverzeichnis (fixed asset register) for AVEÜR with linear AfA, supporting KFZ, EDV, and sonstig asset types.

#### Scenario: Asset registration

- GIVEN an asset registered with kaufpreis_netto=1000, nutzungsdauer_jahre=3, and afa_methode='linear'
- WHEN the asset is saved
- THEN the system SHALL compute annual AfA = 1000/3 = 333.33 €

#### Scenario: KFZ with private share

- GIVEN a KFZ asset with privat_anteil_prozent=30
- WHEN the AfA for AVEÜR is computed
- THEN the AfA SHALL be reduced by 30%, showing only the business portion

#### Scenario: Asset disposal

- GIVEN an asset marked as verkauft_am
- WHEN the Anlagenverzeichnis is viewed
- THEN the system SHALL stop AfA from that date and show the remaining book value

#### Scenario: AVEÜR integration

- GIVEN active assets in the Anlagenverzeichnis
- WHEN the Anlage AVEÜR is generated
- THEN all active assets' AfA SHALL appear in the Abschreibungen section (Zeile 33 of EÜR)

### Requirement: Kontenübersicht

The system SHALL display a Kategorien-Summenliste (Kontenübersicht) with SKR03/SKR04 account numbers and period totals.

#### Scenario: Period summary

- GIVEN a period selected in the Kontenübersicht
- WHEN the view is loaded
- THEN each category SHALL show its SKR03/SKR04 account number, total Einnahmen, total Ausgaben, and net balance

#### Scenario: Inactive categories excluded

- GIVEN a category with aktiv=0
- WHEN the Kontenübersicht is viewed
- THEN it SHALL not appear unless it has journal entries in the selected period

#### Scenario: Empty period

- GIVEN a period with no journal entries
- WHEN the Kontenübersicht is viewed
- THEN the view SHALL show an empty list or a "no data" message

### Requirement: Steuersätze Snapshot in Journal

The system SHALL snapshot tax rate values (ust_satz, konto_skr03, konto_skr04, konto_ust_skr03, konto_ust_skr04) in each journal entry at creation time.

#### Scenario: Historical accuracy

- GIVEN a journal entry created with ust_satz=19
- WHEN the category's default rate is later changed to 7%
- THEN the entry SHALL retain ust_satz=19

#### Scenario: SKR account snapshot

- WHEN a journal entry is created
- THEN the entry SHALL snapshot konto_skr03 and konto_skr04 from the category's current values at that moment

#### Scenario: Snapshot on creation only

- GIVEN a journal entry with snapshot values already set
- WHEN the category's SKR accounts are updated
- THEN existing journal entries SHALL NOT be affected (snapshots are immutable after creation)

### Requirement: Voranmeldungsrhythmus

The system SHALL support monthly or quarterly UStVA filing rhythm, configurable per company.

#### Scenario: Monthly rhythm

- GIVEN voranmeldungsrhythmus='monatlich'
- WHEN UStVA is computed
- THEN the system SHALL compute and file for each calendar month individually

#### Scenario: Quarterly rhythm

- GIVEN voranmeldungsrhythmus='quartal'
- WHEN UStVA is computed
- THEN the system SHALL compute and file for each quarter (Q1: Jan–Mar, Q2: Apr–Jun, Q3: Jul–Sep, Q4: Oct–Dec)

#### Scenario: Rhythm change

- GIVEN voranmeldungsrhythmus changed from monthly to quarterly
- WHEN the next filing period begins
- THEN the system SHALL apply the new rhythm starting from the next filing period, not retroactively

### Requirement: Differenzbesteuerung §25a Accounting

The system SHALL compute Differenzbesteuerung (margin scheme) per §25a UStG with correct journal entries and UStVA reporting.

#### Scenario: §25a journal entry

- GIVEN a Rechnung with §25a positions finalized
- WHEN the journal entry is created
- THEN the system SHALL create entries with marge_25a_brutto (VK_brutto - EK_netto × menge) and ust_satz_25a

#### Scenario: §25a UStVA KZ 81/83

- GIVEN a UStVA period including §25a entries
- WHEN the UStVA is computed
- THEN KZ 81 SHALL show the total margin (marge_25a_brutto) and KZ 83 SHALL show the USt computed on the margin

#### Scenario: §25a EÜR treatment

- GIVEN §25a journal entries in a period
- WHEN the EÜR is generated
- THEN §25a entries SHALL appear in their normal EÜR lines (e.g., Betriebseinnahmen Zeile 15) with the full brutto_betrag, not the margin

#### Scenario: §25a with negative margin

- GIVEN a §25a position where VK_brutto < EK_netto × menge (negative margin)
- WHEN the journal entry is created
- THEN the marge_25a_brutto SHALL be negative, and no USt SHALL be charged (margin is zero or negative)

### Requirement: Storno Correction

The system SHALL support Storno (reversal) of journal entries with correct tax period handling.

#### Scenario: Storno at original period

- GIVEN a journal entry from January storno'd in March
- WHEN the Storno is committed
- THEN the system SHALL create the Storno entry in March (not January) with the original entry's data for reference

#### Scenario: Storno EÜR impact

- GIVEN a Storno created in March for a January entry
- WHEN the EÜR is generated for March
- THEN the EÜR SHALL reflect the negative entry in March, not retroactively adjust January

#### Scenario: Storno of already-storno'd entry

- GIVEN a journal entry that has already been storno'd
- WHEN another Storno is attempted on the same entry
- THEN the system SHALL reject the duplicate Storno and indicate the entry is already reversed

#### Scenario: Storno with Gruppenverknüpfung

- GIVEN a journal entry that is part of a Buchungsgruppe (gruppe_id set)
- WHEN a Storno is created
- THEN the system SHALL link the Storno to the same gruppe_id as the original entry
