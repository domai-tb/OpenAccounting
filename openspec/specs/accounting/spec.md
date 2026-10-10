# OpenInvoices — Accounting Specification

## Purpose
Double-entry journal accounting with GoBD-compliant audit trail, account plan management, and fiscal period controls.

## Requirements

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

The system SHALL provide categories with stable IDs, name, description, activation status, optional SKR03/SKR04/EÜR/EKS mappings, and mapping provenance. It MUST NOT claim a fixed minimum count or present mappings as standard unless they came from an approved, versioned catalog manifest. Each category SHALL distinguish `catalog_verified`, `user_confirmed`, `legacy_unverified`, `review_required`, and `unmapped` status as applicable. A manual edit to any mapping field SHALL set the category to `review_required`; `user_confirmed` requires an explicit review of every populated mapping field. User-confirmed mappings MUST remain distinguishable from catalog-verified mappings. A posting or output that requires category mapping values SHALL consume only `catalog_verified` or `user_confirmed` values; no mappings SHALL be inferred for `legacy_unverified`, `review_required`, or `unmapped`. A balanced posting with independently supplied account and tax data MAY retain an unmapped category as a descriptive label without consuming its mapping fields. The review action SHALL be reachable from the accepted `/settings/categories` workspace specified by `master-data-workspaces-and-crud`; until that workspace is accepted and available, provenance remains read-only and untrusted mappings stay blocked from mapping-dependent operations.

#### Scenario: Approved catalog category has traceable mappings

- **GIVEN** an approved manifest entry supplies a category and applicable accounting mappings
- **WHEN** the category is persisted
- **THEN** its values match the manifest entry and it records the stable entry key, source version, and `catalog_verified` status

#### Scenario: Category with SKR mapping

- **GIVEN** an approved manifest entry supplies applicable SKR03 and SKR04 mappings
- **WHEN** a category is created from that entry
- **THEN** both account values match the entry and the category records its source version and `catalog_verified` status

#### Scenario: User-defined category is not described as a standard mapping

- **GIVEN** a user creates a category without an approved manifest entry and enters accounting mapping values
- **WHEN** the category is persisted
- **THEN** it is marked `user_confirmed` only after the user explicitly reviews all populated mappings
- **AND** the UI identifies it as user-configured rather than catalog-verified

#### Scenario: Unmapped user category remains explicitly unmapped

- **GIVEN** a user creates a category without accounting mapping values
- **WHEN** the category is persisted
- **THEN** it has `unmapped` status and no generated mapping value

#### Scenario: Editing a catalog mapping requires review

- **GIVEN** a category has `catalog_verified` status and a user edits any accounting mapping field
- **WHEN** the edit is saved
- **THEN** its status becomes `review_required` while the prior catalog source/version remains recorded as baseline provenance
- **AND** it is not represented as catalog-verified until reviewed

#### Scenario: User-modified SKR account

- **GIVEN** a user overrides the SKR03 account for a category
- **WHEN** the override is saved
- **THEN** the entered value is preserved and the category becomes `review_required`
- **AND** it cannot be used as a catalog-verified mapping until all populated mapping fields are explicitly reviewed

#### Scenario: Legacy category values are retained but untrusted

- **GIVEN** a category existed before provenance migration
- **WHEN** the category is loaded after migration
- **THEN** all pre-migration values and references remain unchanged and its status is `legacy_unverified`
- **AND** it remains readable in historical journal views

#### Scenario: Legacy mapping cannot drive a new posting before review

- **GIVEN** a category has `legacy_unverified` status
- **WHEN** the user attempts a new journal entry whose account or tax treatment depends on the category mapping
- **THEN** the entry is rejected with that category's ID and a mapping-review action

#### Scenario: Unmapped category labels an independently balanced posting

- **GIVEN** a category has `unmapped` status and the posting request supplies all required balanced account and tax data independently
- **WHEN** the journal entry is validated
- **THEN** the entry MAY retain the category as a descriptive label without deriving an account or tax value from it
- **AND** the category status remains `unmapped`

#### Scenario: Inactive category

- **GIVEN** a category with `aktiv=0`
- **WHEN** the booking form is displayed
- **THEN** the category does not appear in new-entry dropdowns, but existing journal entries referencing it remain visible

#### Scenario: Category description

- **GIVEN** a category with `beschreibung` set
- **WHEN** a user selects the category in the booking form
- **THEN** the booking form displays the description as a hint

#### Scenario: Unmapped category does not receive an invented account

- **GIVEN** a category has no SKR mapping
- **WHEN** a journal entry or export resolves its category account
- **THEN** the mapping remains absent and no default or formula-generated account number is substituted

#### Scenario: Category with missing SKR mapping

- **GIVEN** a category has `konto_skr03` or `konto_skr04` set to NULL
- **WHEN** a DATEV export requires that account mapping
- **THEN** export resolution reports the category as unresolved and does not substitute a default account

#### Scenario: Category review is unavailable until its workspace is accepted

- **GIVEN** a category has `legacy_unverified` or `review_required` status and the accepted `/settings/categories` workspace is not available
- **WHEN** a user attempts to review its mapping
- **THEN** the system SHALL keep the category status unchanged and identify the unavailable review workflow
- **AND** new postings and mapping-dependent output SHALL remain blocked for that category

#### Scenario: Inactive category warning does not replace mapping review

- **GIVEN** a recurring booking references a deactivated category whose status is `legacy_unverified` or `review_required` and whose mapping is required by the posting
- **WHEN** the user confirms the reviewed occurrence
- **THEN** the mapping status SHALL block posting even if the occurrence also displays the inactive-category warning
- **AND** the category SHALL remain blocked until its mapping provenance is explicitly reviewed

#### Scenario: Eligible inactive category keeps the recurring warning policy

- **GIVEN** a recurring booking references a deactivated category with `catalog_verified` or `user_confirmed` mapping status
- **WHEN** the accepted shared posting contract permits the confirmed occurrence
- **THEN** the inactive category SHALL retain the existing warning behavior
- **AND** deactivation SHALL NOT change or upgrade its mapping provenance status

#### Scenario: Unmapped inactive category is used only without category mappings

- **GIVEN** a recurring booking references a deactivated `unmapped` category
- **WHEN** its accepted posting contract receives all required account and tax data independently
- **THEN** the occurrence MAY proceed with the existing inactive-category warning
- **AND** no category mapping value SHALL be inferred or persisted as verified

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

The system SHALL compute monthly or quarterly Umsatzsteuer-Voranmeldung with every statutory Kennzahl required by the configured scenarios, including KZ 12, 61, 66, 81, 83, 89, and 93, configurable by Voranmeldungsrhythmus (monatlich/quartal). The output SHALL not be limited to KZ 1–22.

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
- THEN KZ 18 SHALL show the USt on the taxable margin base `max(marge_25a_brutto, 0)` using `base × ust_satz_25a / (100 + ust_satz_25a)`

#### Scenario: KZ 61 — Vorsteuerabzug ig Erwerb

- GIVEN journal entries with ust_sonderfall='ig_erwerb' in a filing period
- WHEN the UStVA is computed
- THEN KZ 61 SHALL show the Vorsteuer from those entries (not KZ 66)

#### Scenario: KZ 66 — Allgemeiner Vorsteuerabzug

- GIVEN domestic input-tax claims in `vorsteuer_ansprueche` for a filing period
- WHEN the UStVA is computed
- THEN KZ 66 SHALL show the eligible Vorsteuer from those claims
- AND KZ 66 SHALL exclude claims belonging to the ig Erwerb KZ 61 scenario

#### Scenario: KZ 89/93 — Reverse Charge

- GIVEN journal entries with `ust_sonderfall` set to a configured §13b or other Reverse-Charge case in a filing period
- WHEN the UStVA is computed
- THEN the applicable tax base and tax SHALL be reported in KZ 89 and KZ 93
- AND the same entries SHALL NOT be reported as ordinary domestic turnover

#### Scenario: KZ 81/83 — Differenzbetrag §25a

- GIVEN a UStVA period including §25a entries
- WHEN the UStVA is computed
- THEN KZ 81 SHALL show the sum of `max(marge_25a_brutto, 0)`
- AND KZ 83 SHALL show `KZ 81 × ust_satz_25a / (100 + ust_satz_25a)`

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

The system SHALL compute GuV per the maintained accounting requirement when annual turnover exceeds €800,000 or annual profit exceeds €80,000. The `guv` catalog entry SHALL own the user's durable GuV preference. When either threshold is exceeded, the accounting module SHALL display the GuV warning and ask the catalog state writer to persist `guv=true`; no independent `guv_aktiv` runtime flag SHALL be read or written. GuV SHALL be generated when the catalog resolves `guv` as effectively enabled and the GuV calculator provider is available.

#### Scenario: Threshold exceeded

- **GIVEN** annual turnover exceeds €800,000 or annual profit exceeds €80,000
- **WHEN** the Dashboard is loaded and evaluates the accounting threshold
- **THEN** the system displays a GuV warning and persists `guv=true` through the module catalog state writer

#### Scenario: GuV computation

- **GIVEN** the catalog resolves `guv` as effectively enabled and its calculator provider is available
- **WHEN** the GuV is generated
- **THEN** the system computes it from journal entries grouped by SKR03/SKR04 account ranges (income 1–4, expenses 5–8)

#### Scenario: Threshold not exceeded

- **GIVEN** annual turnover is below €800,000 and annual profit is below €80,000
- **AND** the catalog preference for `guv` is disabled
- **WHEN** the Dashboard is loaded
- **THEN** the GuV section is not displayed

#### Scenario: GuV preference is independent of a missing provider

- **GIVEN** the catalog preference for `guv` is enabled but the GuV calculator provider is unavailable
- **WHEN** the Dashboard resolves optional modules
- **THEN** `guv` is effectively disabled with an unavailable reason
- **AND** no GuV computation is attempted

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

The system SHALL provide reusable quick-booking presets for frequent transactions. An executable preset SHALL preserve transaction direction, explicit payment account, active category, tax-rate reference, amount basis, optional default amount, and description. Execution SHALL call the accepted typed accounting posting service, which owns posting legs, tax behavior, snapshots, idempotency, and correction identity. The quick-booking feature SHALL NOT insert directly into `journal` or execute an incomplete legacy preset. Presets missing newly required direction/tax/basis values SHALL remain unchanged and require user review. Tax-rate identity and effective-date applicability SHALL be resolved by the posting owner; the preset SHALL NOT assume an `aktiv` flag because the `ust_saetze` schema has none. Execution SHALL remain unavailable until the accepted posting service supports direct cash/bank events and all preset inputs.

#### Scenario: Quick booking preset

- **GIVEN** a user creates a complete Schnellbuchung with name, direction, payment account, category, tax rate, amount basis, optional amount, and description
- **WHEN** the preset is saved
- **THEN** the typed use case SHALL store those explicit values after reference validation.

#### Scenario: Quick booking execution

- **GIVEN** a complete preset and an accepted posting service for its exact transaction type
- **WHEN** the user activates the preset
- **THEN** the posting service SHALL create and return one committed posting group with those inputs
- **AND** the system SHALL not create a direct, unbalanced journal row.

#### Scenario: Quick booking with invalid preset

- **GIVEN** a preset has missing legacy inputs, an inactive/deleted category, a missing or unsupported account/payment type, or a tax rate the posting owner cannot resolve as configured and supported for the business date
- **WHEN** it is displayed or executed
- **THEN** the preset SHALL be marked for review and no posting SHALL be created until its inputs are valid.

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

### Requirement: Input-tax claim direction during generic finalization

The shared generic finalizer SHALL create an independent `vorsteuer_anspruch` only for an incoming invoice with deductible input VAT. It SHALL NOT create an input-tax claim for outgoing invoices or non-invoice documents, regardless of a supplier link. Dedicated correction operations remain governed by the existing Storno correction requirement.

#### Scenario: Incoming invoice alias creates input-tax claim
- **GIVEN** an `eingangsrechnung` linked to a supplier is finalized with deductible input VAT
- **WHEN** generic finalization commits
- **THEN** exactly one `vorsteuer_anspruch` is linked to the incoming invoice with the input-tax amount

#### Scenario: Outgoing VAT is not an input-tax claim
- **GIVEN** an outgoing invoice is finalized with output VAT
- **WHEN** generic finalization commits
- **THEN** no `vorsteuer_anspruch` is linked to that invoice

#### Scenario: Non-invoice supplier link does not create input tax
- **GIVEN** an offer with a supplier link and VAT is finalized
- **WHEN** generic finalization commits
- **THEN** no `vorsteuer_anspruch` is linked to the offer

#### Scenario: Incoming input-tax claim failure rolls back
- **GIVEN** an incoming invoice uses the incoming number range and has a supplier and deductible input VAT
- **WHEN** a transaction failure occurs after its claim is inserted
- **THEN** no input-tax claim, journal entry, supplier payable, document state change, counter increment, or PDF from the failed attempt remains

#### Scenario: Storno still reverses an existing input-tax claim
- **GIVEN** a finalized incoming invoice has an input-tax claim
- **WHEN** its dedicated Storno operation commits
- **THEN** the existing correction behavior creates one linked reversal claim for the negated amount

### Requirement: Anlage S/G values require an accepted source contract

Anlage S/G numeric fields SHALL be returned only when an accepted tax-year form and line mapping, schedule-period contract, explicit classification evidence, and complete approved accounting source exist for the selected schedule. This change defines none of those value contracts, so its S/G availability result SHALL remain unavailable and SHALL NOT query an approximate source or relabel another report. An accepted future delta may replace this boundary only by specifying each source, field, formula, version, and completeness rule.

#### Scenario: S/G source mapping is not accepted

- **GIVEN** the selected schedule has no accepted mapping from accounting records to its tax-year form fields
- **WHEN** a user requests S/G availability
- **THEN** the service SHALL return an unavailable result naming the missing form/source contract
- **AND** SHALL NOT copy EÜR/EKS/GuV totals or compute an undocumented substitute.

#### Scenario: S/G completeness cannot be established

- **GIVEN** no accepted S/G period and source-coverage contract exists
- **WHEN** a user requests S/G availability
- **THEN** the service SHALL report `periodContractUnavailable` and `accountingSourceContractUnavailable`
- **AND** SHALL NOT emit a zero, estimate, completeness count, or numeric tax field.

#### Scenario: Schedule choice is explicit

- **GIVEN** the profile has no accepted schedule-classification contract
- **WHEN** the user opens the supporting-report view
- **THEN** the user SHALL choose Anlage S or Anlage G explicitly
- **AND** the application SHALL NOT infer eligibility from profile text or transaction descriptions.

### Requirement: Business-year report availability is explicit

Annual EÜR is the only accounting report consumer in scope. It SHALL use the exact half-open range from the shared fiscal-calendar service only after its accepted calculation supports that range. Until then, EÜR for a non-January fiscal year SHALL be unavailable and SHALL NOT be relabeled as a business-year result. Dashboard period summaries and all other reports SHALL keep business-fiscal filters unavailable until their source and calculation contracts are accepted and integrated with the service. Explicit calendar-month, calendar-quarter, and custom-date filters SHALL retain distinct period semantics. This requirement SHALL NOT shift or recalculate statutory tax filing periods.

#### Scenario: Dashboard business-fiscal filter remains unavailable

- **GIVEN** dashboard period metrics do not yet have an accepted source and calculation contract integrated with the fiscal-calendar service
- **WHEN** the company has a non-January start month
- **THEN** the dashboard SHALL NOT offer a business-fiscal period filter or label a calendar-based result as a fiscal period

#### Scenario: EÜR does not relabel a calendar year

- **GIVEN** the company uses a non-January fiscal-year start and EÜR calculation remains calendar-year-only
- **WHEN** the user selects a configured fiscal year
- **THEN** the report SHALL be unavailable for that selection
- **AND** SHALL NOT show a calendar-year result with the fiscal-year label

#### Scenario: Explicit calendar-year EÜR remains available

- **GIVEN** the company has a non-January business-year start and the user explicitly selects a calendar-year period for EÜR
- **WHEN** the accepted EÜR calculation supports that calendar-year period
- **THEN** EÜR SHALL remain available for the selected calendar year
- **AND** the result SHALL be labeled as a calendar year, not as a configured business year

### Requirement: EÜR and DATEV disclose or reject category mapping provenance

EÜR and DATEV SHALL use only `catalog_verified` or explicitly `user_confirmed` category mappings. Before grouping or filtering, EÜR SHALL left-join every journal row selected by its existing accepted period, posting, and correction rules to its category and validate provenance and required `euer_zeile`; a missing category, missing required mapping, or ineligible provenance status MUST block output with the affected journal/category IDs. DATEV SHALL resolve its `Konto` and `Gegenkonto` slots independently from their corresponding posting legs. Each slot SHALL use an explicit account mapping or an eligible category mapping explicitly attached to that leg; a configured company account MAY be used only when the posting leg explicitly selects it. A company default SHALL NOT resolve both slots implicitly. The persisted export snapshot SHALL contain one record per emitted account slot with `journal_id`, slot name, exact account number, resolution source, and category ID plus immutable category-history row ID when a category mapping contributes. Output using user-confirmed mappings MUST identify them as user-configured and not source-verified in the preview and persisted export metadata. GuV is outside this requirement and remains governed by its maintained report contract. If either DATEV slot has no eligible source, or EÜR/DATEV depends on a `legacy_unverified`, `review_required`, or `unmapped` mapping, generation MUST fail with the affected journal/category IDs and MUST NOT silently omit those entries or substitute a default account.

#### Scenario: User-configured output is identified

- **GIVEN** a requested report or export uses only `catalog_verified` and `user_confirmed` mappings
- **WHEN** the output is generated
- **THEN** output metadata lists the catalog source version for verified mappings and identifies user-confirmed mappings as not source-verified

#### Scenario: Unresolved mapping stops the output

- **GIVEN** a requested report or export includes a contributing `legacy_unverified`, `review_required`, or `unmapped` category
- **WHEN** generation is requested
- **THEN** generation fails with those category IDs
- **AND** no successful report/export is recorded and no fallback account is emitted

#### Scenario: EÜR detects categories missing a report line

- **GIVEN** an in-scope journal entry in the selected EÜR period references a category with no `euer_zeile` or a provenance status other than `catalog_verified` or `user_confirmed`
- **WHEN** the EÜR source rows are left-joined to categories before mapping filters or grouping
- **THEN** generation fails with the affected journal and category IDs
- **AND** the entry is not silently excluded from the report

#### Scenario: EÜR detects a missing category reference

- **GIVEN** an in-scope journal entry in the selected EÜR period has no category or references a missing category row
- **WHEN** EÜR completeness is checked before calculation
- **THEN** generation fails with the affected journal entry ID
- **AND** the entry is not silently excluded from the report

#### Scenario: DATEV detects missing category account mappings

- **GIVEN** an in-scope DATEV journal row has no explicit `konto_id.datev_kontonummer` and requires a category SKR account that is absent or has a provenance status other than `catalog_verified` or `user_confirmed`
- **WHEN** DATEV account resolution runs
- **THEN** export fails with the affected category IDs
- **AND** no fallback account such as `1200` or `8400` is emitted

#### Scenario: DATEV records both account slot sources

- **GIVEN** a DATEV booking has distinct `Konto` and `Gegenkonto` source legs, with one explicit account mapping and one eligible category mapping
- **WHEN** each slot is resolved independently
- **THEN** the CSV row contains each exact account number in its corresponding slot
- **AND** the persisted provenance snapshot records one account-slot entry per emitted value with its source, journal ID, and category/history reference when used
- **AND** neither slot is labeled catalog-verified unless its category mapping is catalog-verified

#### Scenario: DATEV rejects an unresolved account slot

- **GIVEN** either DATEV account slot has no explicit account mapping or eligible category mapping attached to its posting leg
- **WHEN** the export is generated
- **THEN** generation fails with the journal ID and unresolved slot name
- **AND** no company default or synthetic account is substituted

#### Scenario: User-confirmed mapping is visible and recorded

- **GIVEN** an EÜR or DATEV output uses one or more `user_confirmed` category mappings
- **WHEN** the preview and persisted export are produced
- **THEN** both identify those mappings as user-configured and not source-verified
- **AND** the export metadata records the category IDs and mapping status snapshot
