# OpenAccounting — Accounting Specification

## Purpose
Double-entry journal accounting with GoBD-compliant audit trail, account plan management, and fiscal period controls.

## Requirements

### Requirement: Journal Entries

New invoice-issue and settlement events SHALL NOT use the single gross `betrag` row path; they SHALL post only through the balanced, source-linked posting-group boundary defined above, with explicit debit/credit legs, `(source_kind, source_id)` uniqueness, and transaction-level balance validation. For these in-scope events the boundary overrides the legacy first-active-category/fallback-account-`1` behavior: unresolvable accounts or tax mappings SHALL fail before commit. The following existing writers are explicitly out of scope and keep their maintained single-row behavior until a separate contract routes them: recurring-template postings, setup opening-balance rows, and other direct `JournalRepository.create` rows. Pre-existing rows without balanced legs SHALL carry a durable `legacy_unverified` marker and remain readable history; they SHALL NOT be auto-balanced or relabeled as balanced.

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

#### Scenario: In-scope invoice does not use the single-row path
- **GIVEN** an invoice finalization event is in scope for balanced posting
- **WHEN** its accounting event is posted
- **THEN** no single gross `betrag` row SHALL be created for it
- **AND** its lines SHALL satisfy the balanced-group invariants above

#### Scenario: Out-of-scope writer keeps its maintained behavior
- **GIVEN** a recurring-template or setup opening-balance posting
- **WHEN** it is created
- **THEN** its maintained single-row behavior SHALL remain unchanged
- **AND** no invoice/settlement group SHALL be required for it by this change

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

#### Scenario: EÜR reads settlements, not invoice dates

- **GIVEN** a committed settlement allocation dated in 2025 and an invoice dated earlier in 2025
- **WHEN** the supported 2025 annual EÜR is generated
- **THEN** the settled portion SHALL be included under its mapped `euer_zeile`
- **AND** the unpaid invoice-date amount SHALL remain excluded

#### Scenario: EÜR rejects mixed legacy and settlement data

- **GIVEN** the supported 2025 annual EÜR source contains both settlement allocations and `legacy_unverified` rows
- **WHEN** the 2025 EÜR is generated
- **THEN** generation SHALL fail closed identifying the unverified rows
- **AND** no partial settlement-only total SHALL be presented as complete

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

#### Scenario: GuV preference is independent of a missing provider

- **GIVEN** the catalog preference for `guv` is enabled but the GuV calculator provider is unavailable
- **WHEN** the optional-module guard resolves `guv`
- **THEN** the saved preference remains enabled while the guard displays its unavailable state
- **AND** the calculator child is not built

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

### Requirement: GoBD Export

The system SHALL generate a GoBD audit export as a ZIP file for an explicitly selected period. Period membership SHALL use the owning accounting source's effective date: journal entries use their journal date, tax reports use their returned reporting period, and finalized business documents and corrections use their immutable document date. A correction SHALL be included in the period containing its own document date; its source document SHALL remain linked evidence even when the source predates the selected period. A record with no valid effective date or an unavailable required report source SHALL make the inventory incomplete and block a complete result; the exporter SHALL NOT guess a date or silently omit the record. The package SHALL include the period's journal ledger and applicable EÜR/UStVA reports produced through `accounting-reporting-workspaces`, finalized business-document artifacts, linked source evidence, and metadata sufficient to trace numbering, finalization state, source/correction/conversion relationships, and accounting chronology. Report generation and its data sources are a prerequisite; this change SHALL NOT independently recalculate reports. The export SHALL include a manifest with SHA-256 hashes for every included file and a human-readable inventory and verification result. ZIP verification SHALL be streaming and MUST NOT extract untrusted paths; it SHALL reject absolute paths, parent traversal, duplicate normalized paths, symlink entries, more than 20,000 entries, archives above 2 GiB, total declared uncompressed content above 5 GiB, and actual streamed content above 5 GiB. It SHALL count actual bytes emitted by each entry while streaming, abort and return invalid as soon as the 5 GiB content bound would be exceeded, and require the normalized archive file-entry set to exactly match the manifest (no missing and no unmanifested entries). The application SHALL expose period selection, export, and verification through a localized accounting/report workflow and SHALL allow the user to save the generated package. This evidence package SHALL NOT be described as certified statutory compliance unless its legal criteria have been separately established.

#### Scenario: GoBD ZIP generation
- **GIVEN** a valid period is selected and all referenced artifacts are readable
- **WHEN** the user requests and saves the GoBD export
- **THEN** the ZIP contains the period ledger and applicable reports, finalized document PDFs, linked source evidence, traceable record metadata, a SHA-256 manifest, and a human-readable inventory marked complete

#### Scenario: GoBD integrity verification
- **GIVEN** a previously generated GoBD export has an intact manifest
- **WHEN** the user verifies it
- **THEN** the verifier recomputes each included file's SHA-256 digest and reports a valid result only if every digest matches

#### Scenario: GoBD export with missing documents
- **GIVEN** a selected period contains a finalized record or linked evidence whose artifact is missing or unreadable
- **WHEN** the export is generated
- **THEN** the inventory identifies each missing artifact and affected record, marks the package incomplete, and does not report verification as valid

#### Scenario: GoBD verification detects a changed file
- **GIVEN** a file in a previously generated export differs from its manifest digest
- **WHEN** the user verifies the export
- **THEN** verification reports the affected file and digest mismatch and returns an invalid result

#### Scenario: GoBD verification rejects unsafe or oversized ZIP content
- **GIVEN** a selected ZIP contains an absolute or parent-traversal path, a symlink, duplicate normalized path, too many entries, or exceeds a configured archive/content bound
- **WHEN** the user verifies the ZIP
- **THEN** verification stops without extracting any entry, reports the unsafe or oversized input, and returns an invalid result

#### Scenario: GoBD verification rejects manifest mismatch and streamed-size overflow
- **GIVEN** a selected ZIP contains an unmanifested entry, omits a manifest entry, or emits more than the allowed uncompressed bytes despite smaller declared sizes
- **WHEN** the user verifies the ZIP
- **THEN** verification reports the exact manifest or content-bound failure and returns invalid without extracting files

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

The system SHALL support recurring booking templates for fixed costs and regular income. Saving a template SHALL store its configured type, category, amount, interval, and position data without creating a financial event. When a template is due, execution SHALL first create or reuse one durable review instance identified by the template and stored due date. Schedule detection MUST NOT write a journal entry, input-tax claim, or finalized incoming invoice. After explicit user confirmation, a direct booking SHALL use the accepted shared accounting posting contract; Beleg mode SHALL hand off to the existing incoming-invoice draft use case. If the posting contract, a mapping required by that contract, or a required tax interpretation is unavailable, the instance MUST remain pending with no financial side effect. A template referencing an article SHALL use the article's current price when preparing a confirmed booking, as defined by this maintained requirement. A paused template SHALL create no new actionable instances. A deactivated category with `catalog_verified` or `user_confirmed` status SHALL retain the existing warning behavior when the accepted shared posting contract permits the booking, without changing its provenance status. A deactivated category with `legacy_unverified` or `review_required` status whose mapping is required SHALL remain blocked even with the warning, until explicitly reviewed. A deactivated `unmapped` category SHALL proceed only with a warning when the posting supplies all required account and tax data independently, inferring no mapping.

#### Scenario: Template creation
- **GIVEN** a template is created with `art`, category, amount, interval, and optional position data
- **WHEN** the template is saved
- **THEN** those values are stored and no journal entry or input-tax claim is created

#### Scenario: Due template is staged for review
- **GIVEN** a Buchungsvorlage is due under its stored schedule
- **WHEN** the due-instance workflow runs
- **THEN** one durable review instance is available and no financial event is created

#### Scenario: Template execution
- **GIVEN** a reviewed direct-mode instance has complete mappings and the accepted shared posting contract is available
- **WHEN** the user confirms execution
- **THEN** the resulting financial event is created through that contract and linked to the due occurrence

#### Scenario: Template with article
- **GIVEN** a template references an article whose current price differs from the stored template price
- **WHEN** a booking is prepared for user confirmation
- **THEN** the current article price is used in the review data, and no event is posted before confirmation

#### Scenario: Template lifecycle
- **GIVEN** a template is paused (`aktiv=false`, `beendet=false`) or ended (`beendet=true`)
- **WHEN** its scheduled date arrives
- **THEN** the paused template produces no new booking until reactivated, while the ended template remains archived

#### Scenario: Unavailable mapping or shared contract fails closed
- **GIVEN** a due template has a deactivated/unresolved category or the shared posting contract or tax interpretation is unavailable
- **WHEN** execution is requested
- **THEN** the occurrence remains pending, identifies the missing mapping or contract, and no journal entry or input-tax claim is created

#### Scenario: Template with deleted category
- **GIVEN** a Buchungsvorlage references a deactivated (`aktiv=0`) category with `catalog_verified` or `user_confirmed` status
- **WHEN** the user confirms the reviewed occurrence and the accepted shared posting contract permits the configured category
- **THEN** the booking uses the deactivated category, the workspace records or displays the warning required by this maintained category policy, and deactivation does not change its provenance status

#### Scenario: Deactivated category with unresolved provenance stays blocked
- **GIVEN** a Buchungsvorlage references a deactivated category with `legacy_unverified` or `review_required` status whose mapping is required by the posting
- **WHEN** the user confirms the reviewed occurrence
- **THEN** execution remains blocked with the mapping-review reason, the inactive-category warning does not bypass the block, and no journal entry or input-tax claim is created

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

The system SHALL maintain an Anlagenverzeichnis for AVEÜR with linear AfA, supporting KFZ, EDV, and sonstig asset types. The annual amount SHALL follow the maintained accounting contract's full-year formula from net purchase price and useful life. Each full-year amount SHALL be `kaufpreis_netto / nutzungsdauer_jahre` rounded half-up to the cent for `NUMERIC(12,2)` storage, computed independently per year with no final-year remainder adjustment; the schedule SHALL contain at most `nutzungsdauer_jahre` full-year rows. Apply private-use reduction only to KFZ as specified in the maintained contract; a non-zero private-use value for EDV or sonstig SHALL make the schedule unavailable until that rule is accepted. An annual schedule SHALL identify its asset, period, source inputs, formula, and result. The owning EÜR workflow, under its independently accepted reporting contract, may consume only complete schedule amounts whose inputs map to this contract; this change defines no EÜR report output on its own and waits on no other change for its asset and schedule scope; unresolved assets or unsupported period calculations SHALL make the result incomplete instead of contributing an invented zero or amount. Disposal-year cutoff, opening/remaining book value, and asset account mapping SHALL remain unavailable until their rules are accepted. The asset register SHALL NOT write journal entries.

#### Scenario: Asset registration

- **GIVEN** an EDV asset is registered with `kaufpreis_netto=1000`, `nutzungsdauer_jahre=3`, `afa_methode='linear'`, and no private-use share
- **WHEN** the asset is saved and its full-year schedule is generated
- **THEN** the schedule shows annual AfA `333.33` and identifies the asset, inputs, and formula without creating a journal entry

#### Scenario: KFZ with private share

- **GIVEN** a KFZ asset has net purchase price `1000`, useful life `3` years, and `privat_anteil_prozent=30`
- **WHEN** the full-year AfA schedule is computed
- **THEN** the annual amount is reduced by 30% and shows the business portion `233.33`

#### Scenario: Non-KFZ private-use amount remains unavailable

- **GIVEN** an EDV or sonstig asset has `privat_anteil_prozent` greater than zero and no accepted type-specific rule
- **WHEN** a full-year AfA amount is computed
- **THEN** the schedule row is unavailable and does not apply the KFZ reduction rule by analogy

#### Scenario: Asset disposal

- **GIVEN** an asset has `verkauft_am` recorded but no accepted cutoff or remaining-book-value contract exists
- **WHEN** the schedule is generated for the disposal year
- **THEN** the row is unavailable and the EÜR does not invent a disposal-year amount or remaining book value

#### Scenario: AVEÜR integration

- **GIVEN** active assets have complete inputs and contract-backed full-year schedule values
- **WHEN** the owning EÜR workflow consumes schedule values under its independently accepted reporting contract
- **THEN** it may consume only complete annual AfA values in the Abschreibungen section (EÜR Zeile 33) with asset-level source references retained, and this change defines no report output on its own

#### Scenario: Unresolved AfA or disposal inputs

- **GIVEN** an asset uses ambiguous legacy fields, a partial acquisition/disposal year, or an unresolved disposal/book-value rule
- **WHEN** the EÜR or AVEÜR result is generated
- **THEN** the affected schedule and report are marked incomplete with the asset and missing policy identified, and no guessed amount or zero is substituted

#### Scenario: Legacy-only asset values do not feed EÜR

- **GIVEN** an active asset has legacy cost, useful-life, or private-use values without an accepted mapping to canonical inputs
- **WHEN** EÜR line 33 is generated
- **THEN** generation fails closed with the asset ID and does not calculate depreciation from the legacy values

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

### Requirement: Balanced, source-linked posting groups

Every posted financial event SHALL be stored as a source-linked posting group with at least two account-backed journal lines. Each line SHALL carry exactly one non-zero side in integer cents (debit > 0 XOR credit > 0, the other zero) from the accepted invoice-money contract. Proportional splits SHALL use non-negative integer-cent amounts and integer weights, floor each initial share, and assign remaining cents by descending fractional remainder and then by a stable ascending key; mixed-category settlement allocations SHALL use the source journal ID as that key. The sum of debit values SHALL equal the sum of credit values for the group, and all lines SHALL be created atomically. The group root SHALL store `(source_kind, source_id)` under a unique constraint (`invoice_event` for issue, `bank_transaction`/`cash_payment` for settlement); all lines SHALL share the root's group id. Repeating the same source event SHALL return the committed group and SHALL NOT create duplicate groups. A posted group SHALL be reversed by a new linked immutable group; posted lines SHALL NOT be edited or deleted. A reversal SHALL link any required input-tax-claim reversal and document-correction record under their maintained contracts instead of adjusting the original claim or document in place. In-scope invoice and settlement events SHALL route through this posting boundary and SHALL NOT use the legacy single gross row or the first-active-category/fallback-account-`1` path; recurring templates, setup opening balances, and other direct `JournalRepository.create` rows are explicitly out of scope and keep their maintained behavior. Pre-existing rows without balanced legs SHALL carry a durable `legacy_unverified` marker and SHALL be excluded from balanced-group assertions.

#### Scenario: Post a finalized invoice
- **GIVEN** an issued invoice has valid configured accounts and tax mapping
- **WHEN** its accounting event is posted
- **THEN** a source-linked journal group with at least two account-backed lines SHALL be committed
- **AND** total debit SHALL equal total credit
- **AND** the invoice SHALL reference that group

#### Scenario: Required posting mapping is missing
- **GIVEN** an invoice cannot resolve a required account or tax mapping
- **WHEN** finalization attempts to post its accounting event
- **THEN** the transaction SHALL roll back the invoice finalization and all journal lines
- **AND** the user SHALL receive a field/actionable mapping error

#### Scenario: Retry a source event
- **GIVEN** a source event already has a committed posting group
- **WHEN** the same event is submitted again
- **THEN** the original group SHALL be returned or recognized
- **AND** no additional journal lines SHALL be created
- **AND** no additional allocation or balance change SHALL occur

#### Scenario: Reverse a posted group
- **GIVEN** an immutable balanced posting group exists
- **WHEN** an authorized reversal is posted
- **THEN** a new immutable group SHALL link to the original and contain the exact opposite account balances
- **AND** the original group SHALL remain unchanged
- **AND** a duplicate reversal of the same group SHALL be rejected

#### Scenario: Reverse a settlement restores the open item
- **GIVEN** a settlement group has an applied allocation reducing a receivable
- **WHEN** its authorized reversal commits
- **THEN** the open-item balance SHALL be restored by the reversed amount in the same transaction
- **AND** the settled portion SHALL no longer be recognized in EÜR
- **AND** the reversal SHALL be recorded in the reversal period, not the original settlement period

#### Scenario: Reject invoice reversal with applied settlements
- **GIVEN** an invoice group has one or more applied settlement allocations
- **WHEN** an invoice-group reversal is requested before those settlements are reversed
- **THEN** the reversal SHALL be rejected with the blocking settlement identified
- **AND** no journal, allocation, or balance change SHALL occur

### Requirement: Payment and invoice posting linkage

Invoice issue events and payment events SHALL have distinct source identifiers and posting groups. A payment posting SHALL identify its bank/cash account, counterparty, applied receivable or payable, settlement date, and applied amount. One confirmed bank transaction SHALL map to exactly one settlement group holding one or more allocation rows; applied amounts plus the unapplied remainder SHALL reconcile to the signed bank amount. A positive bank row SHALL apply only to a customer receivable and a negative bank row only to a supplier payable. A confirmed customer overpayment SHALL close the receivable and retain the excess as a separately classified credit; a supplier overpayment SHALL retain the excess as supplier credit per the maintained receivables contract. Partial payment SHALL reduce only the applied open balance; any unapplied remainder SHALL remain separately identifiable.

#### Scenario: Post a partial receipt
- **GIVEN** a customer receivable has an open balance of 100.00
- **WHEN** a confirmed receipt of 40.00 is applied to it
- **THEN** one balanced payment group SHALL reference the receipt and receivable
- **AND** the receivable balance SHALL become 60.00
- **AND** the payment date SHALL be retained

#### Scenario: Do not post an unconfirmed bank row
- **GIVEN** an imported bank transaction has no confirmed invoice/payment application
- **WHEN** accounting postings are requested
- **THEN** no receipt settlement group SHALL be created
- **AND** the transaction SHALL remain available as unreconciled work

#### Scenario: Post a supplier payment
- **GIVEN** a supplier payable has an open balance of 200.00 and a negative bank row of 200.00 is confirmed against it
- **WHEN** the settlement is saved
- **THEN** one balanced payment group SHALL reference the bank row and payable
- **AND** the payable balance SHALL become 0.00 with status `bezahlt`

#### Scenario: Split one transaction across invoices
- **GIVEN** one confirmed bank receipt of 100.00 is applied 40.00 and 60.00 to two customer receivables
- **WHEN** the settlement is saved
- **THEN** exactly one settlement group SHALL hold two allocation rows for the two receivables
- **AND** applied plus unapplied amounts SHALL reconcile to 100.00

#### Scenario: Retain an overpayment as credit
- **GIVEN** a customer receivable has an open balance of 100.00 and a confirmed receipt of 120.00 is applied
- **WHEN** the settlement is saved
- **THEN** 100.00 SHALL close the receivable and 20.00 SHALL remain as a separately classified credit per the maintained receivables contract

#### Scenario: Repeated confirmation does not re-apply
- **GIVEN** a confirmed bank transaction already has a committed settlement group
- **WHEN** the same confirmation is submitted again
- **THEN** the original settlement group SHALL be returned
- **AND** no additional allocation or balance change SHALL occur
