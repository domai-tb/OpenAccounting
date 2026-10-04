## MODIFIED Requirements

### Requirement: EÜR (Einnahmen-Überschuss-Rechnung)

The system SHALL expose only the official Anlage EÜR form version 2025 for tax year 2025, covering the calendar period `[2025-01-01, 2026-01-01)`. Its form source is the BMF notice of 29 August 2025 and its published 2025 Anlage EÜR ([official form](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Einkommensteuer/2025-08-29-anlage-EUER-2025.html)). Each internal `euer_zeile` mapping SHALL identify the corresponding 2025 form line and official field identifier, label, source event type, amount/sign rule, and whether an inactive value is blank or zero. Internal line numbers SHALL NOT be treated as official field identifiers without that mapping. The versioned mapping fixture SHALL cover every supported line and validate field identifiers, labels, and representative amounts against the official 2025 form.

The inherited scenario labels `EÜR Zeile 12`, `15`, `16`, `33`, `60`, `106`, and `107` identify existing internal `euer_zeile` values only; they do not assert official form row numbers or field identifiers. The versioned 2025 mapping fixture is normative for the form mapping.

EÜR income and expense recognition SHALL use settlement dates and source amounts from the accepted balanced-posting/settlement and invoice-money contracts. Input-tax amounts SHALL follow the maintained `vorsteuer_ansprueche`/cutover rule. The reports SHALL be unavailable until both source contracts and the matching year-specific form mapping are independently approved; no journal-date, invoice-total, or unconfirmed-bank fallback is permitted. The 2026 form was published separately on 1 September 2026 ([official form](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Einkommensteuer/2026-09-01-anlage-EUER-2026.html)); tax year 2026 and any year without its own accepted form mapping and fixture SHALL be unavailable, never rendered with the 2025 schema.

#### Scenario: EÜR Zeile 12 — Kleinunternehmer §19

- **GIVEN** the selected report is tax year 2025 and accepted source events map to the official 2025 Kleinunternehmer line
- **WHEN** EÜR is generated from approved settlement data
- **THEN** the 2025 field mapping displays the sum of eligible recognized amounts
- **AND** the result records the 2025 form/source versions

#### Scenario: EÜR Zeile 15 — Umsatzsteuerpflichtige Betriebseinnahmen

- **GIVEN** approved 2025 source events map to the official 2025 taxable operating-income line
- **WHEN** EÜR is generated
- **THEN** the field displays the eligible amount under the versioned line mapping

#### Scenario: EÜR Zeile 16 — Steuerfreie Betriebseinnahmen §4

- **GIVEN** approved 2025 source events map to the official 2025 tax-exempt operating-income line
- **WHEN** EÜR is generated
- **THEN** the field displays the eligible amount under the versioned line mapping

#### Scenario: EÜR Zeile 33 — Abschreibungen (AfA)

- **GIVEN** approved fixed-asset data provides the 2025 AfA amount and its source records
- **WHEN** EÜR is generated
- **THEN** the mapped 2025 field displays that amount and identifies the fixed-asset source
- **AND** it does not substitute a journal total for the fixed-asset calculation

#### Scenario: EÜR Zeile 60 — Sonstige Betriebsausgaben

- **GIVEN** approved 2025 source events map to the official 2025 other-operating-expense line
- **WHEN** EÜR is generated
- **THEN** the field displays the eligible amount under the versioned line mapping

#### Scenario: EÜR Zeile 106/107 — Privatentnahme/Privateinlage

- **GIVEN** approved 2025 source events map to the official 2025 private-withdrawal or private-contribution fields
- **WHEN** EÜR is generated
- **THEN** the mapped fields are displayed as the form specifies
- **AND** they affect profit only as defined by the official 2025 form contract

#### Scenario: Vorsteuerabzug Soll-Prinzip

- **GIVEN** the selected 2025 period is after the configured and accepted cutover date
- **WHEN** EÜR is generated
- **THEN** input tax is sourced from eligible `vorsteuer_ansprueche` records under the accepted recognition rule
- **AND** it is not inferred from `journal.vorsteuer_betrag` or invoice totals

#### Scenario: EÜR with no journal entries

- **GIVEN** the supported 2025 period has complete source coverage and no eligible EÜR events
- **WHEN** EÜR is generated
- **THEN** all mapped amount fields show the official form's required empty/zero representation
- **AND** the result records that source coverage was complete

#### Scenario: EÜR 2026 has no accepted mapping

- **GIVEN** the selected tax year is 2026 and no accepted 2026 field map and fixture exist
- **WHEN** EÜR is requested
- **THEN** the result is unavailable and identifies the missing 2026 form contract
- **AND** no 2025 fields or calculations are reused

#### Scenario: EÜR source contract is unapproved

- **GIVEN** the balanced-posting/settlement or invoice-money prerequisite is not independently approved
- **WHEN** EÜR is requested for 2025
- **THEN** the result is unavailable with the blocking prerequisite identified
- **AND** it exposes no calculated, estimated, or complete amount

### Requirement: UStVA (Umsatzsteuer-Voranmeldung)

UStVA SHALL be previewed for one explicitly configured calendar month or one explicitly configured three-month calendar quarter. A result SHALL carry the tax year, configured `monatlich`/`quartal` rhythm, exact start-inclusive/end-exclusive period, and accepted year-specific UStVA field-map version. Period inclusion SHALL use the tax event date defined by that accepted field map; invoice dates or bank dates SHALL NOT be substituted. The preview SHALL include the complete accepted Kennzahl set, including KZ 12, 61, 66, 81, 83, 89, and 93, with explicit zero values only when source coverage is complete and the field map requires them. Each populated key SHALL map to an eligible source event and tax classification. The versioned map SHALL resolve whether margin taxation uses KZ 18, KZ 81/83, or both for the selected form year; the same base SHALL NOT be duplicated unless the official accepted year mapping explicitly requires it.

UStVA SHALL be unavailable when the year-specific field map or configured rhythm is missing, source coverage is incomplete, or either the balanced-posting/settlement or invoice-money prerequisite is unapproved. No partial or estimate SHALL be presented as a complete filing preview. This change provides an on-screen preview only, not an official filing dataset or submission.

#### Scenario: KZ 1 — Gesamtumsatz steuerpflichtig

- **GIVEN** approved tax events with taxable domestic turnover fall within the selected supported period
- **WHEN** UStVA is computed
- **THEN** KZ 1 shows only the amount mapped to domestic taxable turnover by the accepted year-specific field map

#### Scenario: KZ 3 — Umsatzsteuer (19%)

- **GIVEN** approved tax events with `ust_satz=19%` fall within the selected supported period
- **WHEN** UStVA is computed
- **THEN** the key assigned to those events by the accepted year-specific field map shows their tax amount

#### Scenario: KZ 4 — Umsatzsteuer (7%)

- **GIVEN** approved tax events with `ust_satz=7%` fall within the selected supported period
- **WHEN** UStVA is computed
- **THEN** the key assigned to those events by the accepted year-specific field map shows their tax amount

#### Scenario: KZ 18 — Differenzsteuer §25a

- **GIVEN** approved §25a events fall within the selected supported period and the accepted form-year map assigns the margin base/tax to KZ 18
- **WHEN** UStVA is computed
- **THEN** KZ 18 shows the amount calculated by that accepted mapping
- **AND** the same value is not duplicated in another key unless that map explicitly requires it

#### Scenario: KZ 61 — Vorsteuerabzug ig Erwerb

- **GIVEN** accepted tax events with `ust_sonderfall='ig_erwerb'` fall within the selected supported period
- **WHEN** UStVA is computed
- **THEN** the accepted year mapping reports the eligible input tax in KZ 61
- **AND** it is excluded from KZ 66

#### Scenario: KZ 66 — Allgemeiner Vorsteuerabzug

- **GIVEN** eligible domestic input-tax claims in `vorsteuer_ansprueche` fall within the selected supported period
- **WHEN** UStVA is computed
- **THEN** the accepted year mapping reports them in KZ 66
- **AND** it excludes claims assigned to the ig Erwerb KZ 61 scenario

#### Scenario: KZ 89/93 — Reverse Charge

- **GIVEN** accepted §13b/reverse-charge tax events fall within the selected supported period
- **WHEN** UStVA is computed
- **THEN** their base and tax use the configured KZ 89/93 mapping
- **AND** the same events are not reported as ordinary domestic turnover

#### Scenario: KZ 81/83 — Differenzbetrag §25a

- **GIVEN** approved §25a events fall within the selected supported period and the accepted form-year map assigns the margin base/tax to KZ 81/83
- **WHEN** UStVA is computed
- **THEN** KZ 81 and KZ 83 show the base and tax according to that accepted map
- **AND** values are not duplicated in KZ 18 unless the map explicitly requires it

#### Scenario: Quarterly filing

- **GIVEN** the company's configured rhythm is `quartal` and quarter 1, 2, 3, or 4 is selected
- **WHEN** UStVA is computed
- **THEN** the preview covers exactly the three calendar months of that quarter
- **AND** it does not create an official filing artifact or submission status

#### Scenario: No transactions in period

- **GIVEN** source coverage is complete for a supported filing period and there are no eligible tax events
- **WHEN** UStVA is computed
- **THEN** every required key displays the accepted field map's zero/blank representation
- **AND** the preview identifies that the complete period contains no eligible events

#### Scenario: UStVA year map or source is unavailable

- **GIVEN** there is no accepted year-specific field map, configured filing rhythm, or approved canonical accounting source
- **WHEN** UStVA is requested
- **THEN** the result is unavailable and identifies the missing version, setting, or dependency
- **AND** it does not emit zeroes or partial values as a completed preview

### Requirement: GuV (Gewinn- und Verlustrechnung)

The application MAY provide a management GuV for one supported calendar year, using only approved balanced postings and a versioned account-to-GuV-line mapping. A product-level optional-module rule MAY make that management view available after its own defined activation condition; it SHALL NOT present that activation or a threshold crossing as proof of statutory bookkeeping duty. The current account-range shorthand SHALL NOT substitute for an accepted account mapping. The GuV calculation SHALL be unavailable while the balanced-posting/settlement or invoice-money prerequisite remains unapproved.

A §141 AO bookkeeping-duty warning SHALL be separate from the optional management GuV. A threshold crossing by itself SHALL NOT establish duty or auto-enable a statutory-duty state. A warning requires verified evidence for the individual business: qualifying type (`Gewerbebetrieb` or `Land- und Forstwirtschaft`), the corresponding threshold basis and measured period/value, a Finanzamt finding and notice date, and the effective date. Under §141(1) AO, the thresholds are total turnover within the meaning of §19(2) UStG over €800,000 in a calendar year, trade profit over €80,000 in a fiscal year, or agricultural/forestry profit over €80,000 in a calendar year. Under §141(2), the duty starts at the beginning of the Wirtschaftsjahr following the Finanzamt notice. The effective date SHALL be derived from verified notice evidence and the profile's supported Wirtschaftsjahr boundary; it SHALL NOT assume January 1 or infer a non-calendar Wirtschaftsjahr from transaction dates. Source: [§141 AO](https://www.gesetze-im-internet.de/ao_1977/__141.html).

#### Scenario: Threshold exceeded

- **GIVEN** §19(2) total turnover exceeds €800,000 or applicable business profit exceeds €80,000 but no verified Finanzamt notice/effective-date evidence exists
- **WHEN** the Dashboard is loaded
- **THEN** the application does not claim that §141 bookkeeping duty applies without the notice/effective-date evidence
- **AND** any management-GuV activation follows only its separate product-level preference/activation rule

#### Scenario: GuV computation

- **GIVEN** the management GuV is enabled, the requested calendar year is supported, and approved balanced postings plus a versioned account mapping exist
- **WHEN** the GuV is generated
- **THEN** it groups amounts by the accepted account-to-GuV-line mapping for the declared chart version
- **AND** it records the source/mapping version and period

#### Scenario: Threshold not exceeded

- **GIVEN** none of the applicable §141 thresholds is exceeded or the business type/evidence is unknown
- **WHEN** the dashboard is loaded while the optional management GuV is disabled
- **THEN** no §141 duty warning is displayed
- **AND** the optional GuV section remains hidden according to the user's preference

#### Scenario: §141 warning follows notice effective date

- **GIVEN** the business type and applicable threshold facts are verified and a Finanzamt notice states a start date
- **WHEN** the dashboard displays a period before that effective date
- **THEN** it does not claim the duty has started
- **WHEN** the dashboard displays a period on or after the effective date
- **THEN** it displays the duty warning with its source notice and effective date

#### Scenario: §141 warning follows a non-calendar Wirtschaftsjahr

- **GIVEN** the verified profile Wirtschaftsjahr runs from 1 April through 31 March and a Finanzamt notice received on 15 December 2025 states that §141 applies
- **WHEN** the dashboard displays dates before 1 April 2026 and then dates from 1 April 2026 onward
- **THEN** it SHALL not claim the duty started before 1 April 2026
- **AND** from 1 April 2026 it SHALL show the warning with the notice and evidenced Wirtschaftsjahr boundary

#### Scenario: GuV is unavailable without approved postings

- **GIVEN** the balanced-posting/settlement or invoice-money prerequisite is not independently approved
- **WHEN** the management GuV is requested
- **THEN** the result is unavailable and no raw journal-range estimate is shown

### Requirement: ZM (Zusammenfassende Meldung)

The ZM preview in this change SHALL support only outgoing qualifying intra-community supplies under §6a(1) UStG to a recipient in another EU Member State with a valid recipient USt-IdNr, excluding a new vehicle supplied to a recipient without a USt-IdNr. Required source fields are transaction direction/type, supply date, invoice issue date, destination Member State, recipient USt-IdNr, and taxable base in integer cents. The preview SHALL group taxable bases by recipient USt-IdNr for one calendar month. For a supported supply, the reporting month is the invoice-issue month, but SHALL not be later than the statutory latest period, the calendar month following the supply; an invoice issued after that limit requires correction/review and makes the preview unavailable.

This phase does not support §3a(2) services, §25b triangular transactions, §6b movements, own-goods transfers, other transaction directions, quarterly-election logic, or electronic submission. An ordinary intra-community acquisition is an explicit nonreportable exclusion. If profile data indicates §19(1) UStG applies, ZM is not applicable; if that status is required but unknown, the preview is unavailable. If source data indicates any other potentially reportable unsupported transaction, the selected period SHALL be unavailable and SHALL identify that transaction; the system SHALL NOT return an empty report. The preview is not an official submission dataset. Source: [§18a UStG](https://www.gesetze-im-internet.de/ustg_1980/__18a.html), especially paragraphs 1, 4, and 6–8.

#### Scenario: ZM with ig Lieferungen

- **GIVEN** finalized outgoing invoice events in a selected calendar month meet the supported §6a(1) supply criteria and contain valid recipient Member State, USt-IdNr, supply date, invoice date, and taxable base
- **WHEN** the ZM preview is generated
- **THEN** the amounts are grouped by recipient USt-IdNr in the invoice-issue month subject to the latest statutory period
- **AND** each total links to its source invoices and records the §18a contract version

#### Scenario: ZM with ig Erwerb

- **GIVEN** an incoming invoice records an ordinary innergemeinschaftlicher Erwerb (`ust_sonderfall='ig_erwerb'`) and source coverage for the selected month is complete
- **WHEN** the ZM preview is generated with any eligible outgoing supplies in that month
- **THEN** the acquisition is not included as the recipient's reportable supply
- **AND** it does not prevent an otherwise complete preview for supported outgoing supplies

#### Scenario: No EU transactions in period

- **GIVEN** source coverage for the selected calendar month is complete and no supported or unsupported potentially reportable EU transaction exists
- **WHEN** the ZM preview is generated
- **THEN** it indicates that there are no supported reportable transactions
- **AND** it does not create an official filing artifact or submission status

#### Scenario: Missing ZM source field blocks preview

- **GIVEN** a potentially qualifying outgoing supply lacks invoice date, supply date, destination Member State, recipient USt-IdNr, or taxable base
- **WHEN** the ZM preview is requested
- **THEN** the period is unavailable with the source invoice and missing field identified

#### Scenario: Unsupported reportable service blocks ZM preview

- **GIVEN** a selected month contains a potentially reportable §3a(2) intra-community service
- **WHEN** the ZM preview is requested
- **THEN** the period is unavailable and links the service source
- **AND** the service is not misreported as a goods supply or omitted from an apparently complete report

### Requirement: DATEV EXTF Export

DATEV export SHALL produce only a structured CSV `Buchungsstapel` using header version 700, format category 21, and format version 13, matching the official DATEV header and field specifications. This meets or exceeds DATEV's published interface minimum of header version 700 and Buchungsstapel format version 12. The export SHALL contain one calendar-month period per file, with inclusive `Datum von`/`Datum bis`, and SHALL support only a calendar business-year start on 1 January. It SHALL contain exactly the official v13 header positions and 125 booking-row positions; fields unused by the supported source event remain blank. This change does not export standalone Debitoren/Kreditoren master data.

The DATEV header SHALL use the official 31-position v13 layout: fields 1–5 are `EXTF`, `700`, `21`, `Buchungsstapel`, `13`; field 6 is a valid `YYYYMMDDHHMMSSFFF` timestamp; field 7 is blank; field 8 is `RE`; fields 9–10 are blank; fields 11–12 are configured Beraternummer and Mandantennummer; field 13 is `YYYY0101`; field 14 is the configured Sachkontenlänge; fields 15–16 are the selected month's `YYYYMMDD` start and end; field 17 is a valid stack label; field 18 is blank; fields 19–21 are `1`, `0`, `0`; field 22 is `EUR`; fields 23–26 are blank; field 27 is the configured supported chart code (`03` or `04`); and fields 28–31 follow the official v13 definitions, blank unless their documented source value is present. Missing required header configuration SHALL fail export.

Booking rows SHALL be derived only from approved balanced-posting records and explicit mappings. Supported fields are:

| DATEV field | Value/source rule |
| --- | --- |
| 001 Umsatz | Positive, non-zero amount from the accepted posting leg; decimal comma and exactly two cents |
| 002 Soll-/Haben-Kennzeichen | `S` or `H` from the side of the account in field 007; never inferred from a negative amount |
| 003–006 Currency/rate/base | Blank for supported EUR rows; non-EUR rows are unavailable until explicit currency/rate rules are accepted |
| 007 Konto / 008 Gegenkonto | Explicit source account and counter-account mapping from the accepted posting event; partner ledger accounts are allowed only when explicitly mapped |
| 009 BU-Schlüssel | Exact configured tax key for the source tax treatment; missing required mapping blocks export |
| 010 Belegdatum | Source document date as `TTMM`; year is the header's field 13 business year |
| 011 Belegfeld 1 | Source document number, limited to DATEV's allowed characters and 36 characters; invalid/missing required identity blocks export |
| 012 Belegfeld 2 | Explicit due date/OPOS value only when present and supported; otherwise blank |
| 014 Buchungstext | Source posting/document description within the DATEV v13 length and character rules |
| 020 Beleglink | DATEV-supported persisted document link only; a local file path is not a DATEV link. If an event requiring a document link has no valid supported representation, export fails; blank is allowed only for event types without a document |
| 040–041, 115–116, 118–120 | Populate only when the accepted source event explicitly requires and supplies the corresponding EU/OSS, service-date, correction, tax-rate, and country facts; otherwise unsupported events block export |

No fallback account number (`1200`, `8400`, or another invented value), global-bank-account substitution, guessed tax key, or fabricated partner/document value is permitted. Missing required source mapping fails closed with the source ID and field. The versioned fixture SHALL assert all header values, all 125 row positions, the above source mappings, period boundaries, decimals, dates, escaping/character-set behavior, and pass the DATEV format validator. The DATEV interface notes that header acceptance alone is insufficient and requires the specified CSV/field rules; the fixture's validation evidence SHALL be recorded with the supported version. Sources: [DATEV header](https://developer.datev.de/de/file-format/details/datev-format/format-description/header), [DATEV Buchungsstapel fields](https://developer.datev.de/de/file-format/details/datev-format/format-description/booking-batch), and [DATEV EXTF interface requirements](https://developer.datev.de/de/product-detail/accounting-extf-files/2.0/documentation/interface-requirements-file).

#### Scenario: DATEV export generation

- **GIVEN** accepted balanced posting events, complete required account/tax/document mappings, and configured DATEV header values exist for a supported calendar month
- **WHEN** a DATEV export is requested
- **THEN** the file is a v13 structured CSV with header version 700/category 21 and 125 booking-row positions
- **AND** each supported event maps amount, side, account, counter-account, document date, document number, and description to the specified fields

#### Scenario: DATEV account mapping

- **GIVEN** a posting references an explicit account with a DATEV account mapping and an explicit counter-account mapping
- **WHEN** the DATEV export is generated
- **THEN** fields 007 and 008 use those mappings
- **AND** neither field falls back to a global bank account or fabricated account number

#### Scenario: DATEV metadata

- **GIVEN** a DATEV export is requested for a calendar-month period
- **WHEN** the header is generated
- **THEN** fields 011–016 contain configured Beraternummer, Mandantennummer, 1 January business-year start, configured Sachkontenlänge, and the exact inclusive month boundaries
- **AND** field 022 identifies EUR

#### Scenario: DATEV export with missing company config

- **GIVEN** the company lacks a required Beraternummer, Mandantennummer, or supported header account-length value
- **WHEN** the DATEV export is generated
- **THEN** generation fails with the missing configuration field identified
- **AND** no successful export-history entry is recorded

#### Scenario: DATEV export with missing source mapping

- **GIVEN** a source posting lacks a required account, counter-account, tax key, partner account, document date, or document identity
- **WHEN** the DATEV export is generated
- **THEN** export fails with the source record and field identified
- **AND** no successful export-history entry is recorded

#### Scenario: DATEV fixture matches the pinned interface

- **GIVEN** the versioned fixture contains the supported invoice, payment, correction, tax, and document-link cases
- **WHEN** it is checked against DATEV EXTF v13
- **THEN** the header and 125-position rows match the pinned field map and period rules
- **AND** the DATEV format validator accepts the fixture
