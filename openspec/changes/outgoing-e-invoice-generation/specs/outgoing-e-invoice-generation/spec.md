## ADDED Requirements

### Requirement: Version-pinned e-invoice formats

The initial supported formats SHALL be ZUGFeRD 2.5.2 using the `EN16931` profile and UN/CEFACT CII D22B, and XRechnung 3.0 using UBL 2.1. XRechnung validation SHALL use the official XRechnung Bundle 3.0.2 Summer 2026 technical artifacts dated 2026-08-31; the bundle version MUST NOT be presented as the normative XRechnung version. The application SHALL package the official schema and business-rule artifacts locally, identify format and validator-bundle versions in application/release metadata, and validate without network access. Runtime SHALL NOT download, update, or silently select a different release. A later format or bundle release SHALL require an explicit compatibility change and updated fixtures.

#### Scenario: Generate supported pinned format

- **GIVEN** a finalized outgoing invoice has all source data required by the selected profile and its pinned local validator is available
- **WHEN** the user requests the supported output
- **THEN** the generated XML validates against the exact packaged XSD and Schematron/configuration artifacts, with XRechnung identified as version 3.0 and its validator bundle as 3.0.2 Summer 2026

#### Scenario: Unsupported or unavailable validation bundle

- **GIVEN** the required pinned validator artifacts are missing, corrupt, or cannot run on the active desktop platform
- **WHEN** generation is requested
- **THEN** the system reports validation unavailable, creates no output, and does not claim the file is compliant

### Requirement: Generate from one canonical invoice snapshot

Finalization SHALL materialize one typed immutable snapshot inside the finalization transaction after number allocation and canonical invoice calculation and before PDF/e-invoice generation. The snapshot SHALL contain the allocated number, selected `ausgabeformat` enum (`zugferd`, `xrechnung`, or `pdf`), dates, sender and customer data, invoice lines, persisted tax-treatment/legal-basis/category/reason evidence, currency, canonical disclosed invoice totals, and any separate accounting-only tax values. If finalization commits, the same snapshot values MUST be persisted on the finalized invoice row. The visual PDF and embedded ZUGFeRD XML SHALL consume that same snapshot. A standalone XRechnung export SHALL consume a typed immutable snapshot read from the committed finalized outgoing invoice. Serialization SHALL preserve applicable snapshot values and MUST NOT calculate or round invoice money, infer tax treatment, fabricate identifiers or terms, calculate VAT-category breakdowns, expose internal margin tax, create accounting entries, or mutate the invoice. This initial capability covers ordinary outgoing invoices only.

#### Scenario: Finalization outputs share one canonical snapshot

- **GIVEN** an outgoing invoice draft has all canonical values required by the selected output and its finalization transaction allocates its invoice number
- **WHEN** the immutable snapshot is materialized and the selected PDF/e-invoice output is generated
- **THEN** the PDF and embedded CII fields and totals match that snapshot, and the values persisted on commit equal the snapshot

#### Scenario: Standalone export reads the committed snapshot

- **GIVEN** an ordinary outgoing invoice is finalized with persisted canonical values
- **WHEN** standalone XML is generated
- **THEN** its fields and totals represent the committed snapshot exactly and no invoice or accounting record changes

#### Scenario: Snapshot output failure rolls back finalization

- **GIVEN** finalization has materialized a snapshot but its selected output fails generation or validation
- **WHEN** the finalization transaction handles the failure
- **THEN** no invoice number, finalized row, stock effect, final artifact, or temporary artifact remains

#### Scenario: Draft invoice cannot be exported

- **GIVEN** an outgoing invoice is still a draft
- **WHEN** XRechnung export is requested
- **THEN** export is unavailable and no invoice data or artifact is changed

### Requirement: Tax categories are explicitly classified

Each invoice line SHALL persist explicit typed tax evidence before it can be included in an e-invoice snapshot. Additive migration v26 SHALL add nullable legacy-compatible fields `tax_treatment`, `tax_legal_basis`, `e_invoice_tax_category_code`, `e_invoice_exemption_reason_code`, and `e_invoice_exemption_reason_text` to invoice positions. The closed `tax_treatment` values are `standard_19`, `reduced_7`, `taxable_zero_12_3`, `kleinunternehmer_19`, `reverse_charge_eu_service_13b_1`, `reverse_charge_domestic_construction_13b_2_4_5`, `intra_community_supply_6a`, `export_supply_6`, and `margin_scheme_25a_unmapped`. The matching legal-basis values are respectively `ustg_12_1`, `ustg_12_2`, `ustg_12_3`, `ustg_19`, `ustg_3a_2_13b_1`, `ustg_13b_2_4_5`, `ustg_4_1b_6a`, `ustg_4_1a_6`, and `ustg_25a`. New eligible lines SHALL persist a complete, accepted tuple; historical rows with absent fields SHALL remain unresolved and MUST NOT be backfilled from `ust_satz`. An owning accounting/tax source or explicit invoice-entry workflow SHALL write the typed treatment separately from `ust_satz`; copying an explicitly stored treatment is allowed, but inferring it from rate, product name, country, VAT-ID prefix, customer type, or margin amount is forbidden.

For the two supported §13b cases, v26 SHALL also persist the following nullable, typed eligibility evidence on the invoice position and capture it verbatim in the immutable snapshot: `e_invoice_reverse_charge_supplier_establishment_country_iso`; `e_invoice_reverse_charge_supplier_establishment_basis` (`seat_or_management`, `fixed_establishment`); `e_invoice_reverse_charge_supplier_german_fixed_establishment_status` (`none`, `exists_not_involved`, `exists_participating`, `unknown`); `e_invoice_reverse_charge_recipient_status` (`entrepreneur_for_business`, `entrepreneur`, `other`, `unknown`); `e_invoice_reverse_charge_recipient_establishment_country_iso`; `e_invoice_reverse_charge_service_kind` (`general_b2b_service_3a_2_no_exception`, `construction_service_13b_2_4`, `other`, `unknown`); `e_invoice_reverse_charge_place_of_supply_basis` (`recipient_business_establishment_3a_2`, `recipient_fixed_establishment_3a_2`, `german_immovable_property_13b_2_4`, `other`, `unknown`); `e_invoice_reverse_charge_place_of_supply_country_iso`; `e_invoice_reverse_charge_taxability` (`taxable_in_germany_under_3a_2`, `taxable_in_germany_under_13b_2_4`, `not_taxable`, `unknown`); and `e_invoice_reverse_charge_evidence_source_ref`. For the construction case, also persist `e_invoice_reverse_charge_recipient_13b5_basis` (`valid_ust1tg_certificate`, `unverified`, `other`, `unknown`), `e_invoice_reverse_charge_ust1tg_certificate_ref`, `e_invoice_reverse_charge_ust1tg_scope` (`construction_13b_2_4`, `building_cleaning_13b_2_8`, `other`, `unknown`), `e_invoice_reverse_charge_ust1tg_recipient_vat_id`, `e_invoice_reverse_charge_ust1tg_issued_on`, and `e_invoice_reverse_charge_ust1tg_valid_through`. For §13b(1), supplier-establishment, recipient, service, place-of-supply, and taxability fields are required and must prove the enumerated §3a(2)/§13b(1) conditions. For §13b(2) no. 4, the service, German place-of-supply, taxability, recipient, and certificate fields are required; supplier-establishment fields are captured from the source record but their country or German fixed-establishment status is not a §13b(5) recipient-qualification test. A certificate reference SHALL resolve to the captured authority-issued certificate; the certificate recipient VAT ID SHALL match the immutable buyer VAT ID. These facts are explicit upstream tax-source inputs, not serializer inferences; a null required field, unknown/invalid enum, unresolved reference, or contradictory evidence SHALL fail closed with a localized position/field diagnostic.

For §13b, `e_invoice_reverse_charge_evidence_source_ref` SHALL resolve to the immutable upstream tax assessment/evidence record from which the persisted recipient, supplier, service, place-of-supply, and taxability facts were established; a customer type or VAT-ID validation record alone is insufficient. The construction certificate reference SHALL resolve to the captured authority-issued certificate and its persisted recipient identifier, service scope, issue date, and validity-through date. If either reference cannot be resolved or contradicts the captured invoice facts, generation SHALL fail closed.

The application SHALL validate stored tuples against the following closed mapping for both XRechnung 3.0 UBL 2.1 and ZUGFeRD 2.5.2 EN16931 CII:

| Explicit treatment | Required legal basis | EN 16931 category | Exemption reason | Required evidence |
|---|---|---|---|---|
| Standard taxable supply at 19% | `UStG §12(1)` | `S`, 19% | None | Persist treatment and legal basis; the rate MUST be exactly 19%. |
| Reduced taxable supply at 7% | `UStG §12(2)` | `S`, 7% | None | Persist treatment and legal basis; the rate MUST be exactly 7%. |
| Taxable zero-rate supply | `UStG §12(3)` | `Z`, 0% | None | Persist explicit taxable-zero treatment and legal basis. A 0% rate without this basis is unresolved. Require the seller VAT ID, seller tax registration ID, or seller tax-representative VAT ID required by BR-Z-2. |
| Kleinunternehmer | `UStG §19` | `E`, 0% | No VATEX code. XRechnung BT-33 and BT-120, and the corresponding CII reason text, SHALL carry exactly `Kein Ausweis von Umsatzsteuer, da Kleinunternehmer gemäß § 19 UStG`. | Persist explicit §19 status/treatment, legal basis, category, and required text. Do not infer it from 0%. |
| EU B2B service reverse charge | `UStG §3a(2) / §13b(1)` | `AE`, 0%, `VATEX-EU-AE` | BT-120 SHALL say `Steuerschuldnerschaft des Leistungsempfängers`. | Persist seller establishment country/basis; German fixed-establishment status (`none` or `exists_not_involved`); recipient status `entrepreneur_for_business`; recipient establishment country `DE`; service kind `general_b2b_service_3a_2_no_exception`; place-of-supply basis under §3a(2), country `DE`; taxability `taxable_in_germany_under_3a_2`; and an evidence-source reference. The supplier establishment country SHALL be another EU Member State. Require seller and buyer VAT IDs as profile identifiers, but never treat them as proof of eligibility. All lines, allowances, and charges in an AE invoice SHALL be AE, or none SHALL be AE. |
| Domestic construction service reverse charge | `UStG §13b(2) no. 4 / §13b(5)` | `AE`, 0%, `VATEX-EU-AE` | BT-120 SHALL say `Steuerschuldnerschaft des Leistungsempfängers`. | This change supports only a construction service under §13b(2) no. 4 on German immovable property and taxable in Germany. Persist service kind `construction_service_13b_2_4`, place-of-supply basis/country and taxability, recipient status `entrepreneur`, and recipient qualification `valid_ust1tg_certificate`. Capture supplier-establishment country/basis and German fixed-establishment status as source context, but do not use supplier nationality or establishment as proof of the recipient condition under §13b(5). The certificate SHALL identify construction services, match the immutable buyer VAT ID, and be valid on `leistungsdatum`; persist its source reference and issue/expiry dates. Seller and buyer VAT IDs remain profile identifiers, not proof of §13b(5) eligibility. A customer type, construction-service description, or VAT ID alone is insufficient. Missing, expired, unmatched, or other-scope evidence fails closed. A sustainable-services route without a valid USt 1 TG certificate and all other §13b cases remain unsupported in this change. |
| Intra-Community supply | `UStG §4 Nr. 1(b) in conjunction with §6a` | `K`, 0%, `VATEX-EU-IC` | Preserve one statutory source phrase: `Steuerfreie innergemeinschaftliche Lieferung` or `Steuerfrei nach § 4 Nr. 1 Buchst. b i. V. m. § 6a UStG`. | Require seller and buyer VAT IDs, delivery date, and destination country. All lines, allowances, and charges in a K invoice SHALL be K, or none SHALL be K. |
| Export supply | `UStG §4 Nr. 1(a) in conjunction with §6` | `G`, 0%, `VATEX-EU-G` | No generic exemption reason. | Require seller or tax-representative registration ID and an explicit destination country outside the EU. A buyer VAT ID is not required by this mapping. All lines, allowances, and charges in a G invoice SHALL be G, or none SHALL be G. |
| Margin-scheme resale | `UStG §25a` | **Unresolved; no category is approved.** | **Unresolved; no VATEX code or text mapping is approved.** | Keep disclosed invoice amounts separate from internal §25a margin tax. Until the owner accepts the category/reason pair and its relationship to VAT-breakdown/payable totals, any invoice containing a §25a line SHALL fail closed with `taxClassificationUnresolved`. |

The table applies to the EN 16931 semantic model: UBL SHALL place the persisted category/reason in the applicable line and tax-breakdown fields; CII SHALL place the same evidence in the matching `ApplicableTradeTax` structures. The serializer SHALL NOT select or complete a mapping. It SHALL consume only the persisted tax tuple, the captured seller/buyer party IDs and country codes, the §13b eligibility fields, and accepted canonical amounts. It SHALL NOT calculate tax, round amounts, aggregate VAT breakdowns, apply tax rates, decide legal eligibility, or access accounting-only margin tax. Missing or mismatched values SHALL produce a localized field-level diagnostic naming the invoice position and source field, including the tax tuple fields or any required `e_invoice_reverse_charge_*` field.

Other §4 exemptions, generic reverse-charge cases, outside-scope turnover, custom tax rates, and any legacy or new treatment not named in the table SHALL have no mapping and SHALL fail closed. `K` and `G` are limited to the named §6a and §6 supplies above and MUST NOT be used as generic exemptions. A category or VATEX code is serialization evidence, not a decision that the underlying statutory conditions are met.

#### Scenario: Explicit tax classification is serialized

- **GIVEN** every invoice line has an approved typed category and any required exemption reason
- **WHEN** an e-invoice is generated
- **THEN** each line and tax breakdown uses the persisted category and reason from the matching treatment/legal-basis tuple without inferring them from the tax percentage

#### Scenario: Standard and reduced rates use explicit S evidence

- **GIVEN** a line persists `standard_19` with `UStG §12(1)` and 19%, or `reduced_7` with `UStG §12(2)` and 7%
- **WHEN** either e-invoice format is generated
- **THEN** both the line and matching tax breakdown use category `S` and the stored 19% or 7% rate, with no exemption reason

#### Scenario: Zero rate requires explicit taxable basis

- **GIVEN** a line has a 0% rate and an explicit persisted taxable-zero treatment with `UStG §12(3)` basis
- **WHEN** either e-invoice format is generated
- **THEN** the line uses category `Z` without an exemption reason
- **AND** a 0% line without the typed basis fails closed instead of being classified as `Z`, `E`, `K`, or `G`

#### Scenario: Kleinunternehmer uses the pinned exemption evidence

- **GIVEN** a line persists the §19 treatment, legal basis, category `E`, and exact reason text
- **WHEN** either e-invoice format is generated
- **THEN** the output uses category `E`, contains the exact required text, and contains no VATEX code

#### Scenario: Named reverse-charge cases use AE evidence

- **GIVEN** a line persists either named reverse-charge treatment with its complete case-specific eligibility evidence and seller and buyer VAT IDs
- **WHEN** either e-invoice format is generated
- **THEN** the line and matching tax breakdown use `AE`, 0%, and `VATEX-EU-AE`, with the statutory reason text
- **AND** any unsupported §13b treatment or invoice with a mixed AE/non-AE line, allowance, or charge fails closed

#### Scenario: §13b(1) EU service uses AE only with persisted eligibility evidence

- **GIVEN** a line persists an ordinary §3a(2) B2B service with no place-of-supply exception, explicit German taxability, a German recipient business establishment, and a supplier establishment in another EU Member State
- **AND** the persisted supplier-establishment basis and German fixed-establishment participation status establish that the supplier is EU-established for this transaction
- **AND** the persisted recipient status is `entrepreneur_for_business`, and the place-of-supply basis, country, service kind, taxability, evidence-source reference, and seller/buyer VAT IDs are complete
- **WHEN** either e-invoice format is generated
- **THEN** the line and matching tax breakdown use `AE`, 0%, and `VATEX-EU-AE`
- **AND** VAT IDs alone do not establish supplier establishment, recipient business status, place of supply, or taxability

#### Scenario: §13b(1) missing eligibility evidence fails closed

- **GIVEN** a line is marked for §13b(1) but any required supplier-establishment, German-fixed-establishment, recipient-status, service-kind, place-of-supply, taxability, or evidence-source field is absent, unknown, or contradictory
- **WHEN** either e-invoice format is generated
- **THEN** generation fails with a localized diagnostic naming the invoice position and missing or inconsistent `e_invoice_reverse_charge_*` field
- **AND** no artifact is written and no AE classification is inferred from VAT IDs

#### Scenario: §13b(2) no. 4 construction uses AE with valid recipient certificate evidence

- **GIVEN** a line persists a construction service under §13b(2) no. 4 on German immovable property and explicit German taxability
- **AND** the recipient is explicitly an entrepreneur and its referenced authority-issued USt 1 TG certificate covers construction services, matches the immutable buyer VAT ID, and is valid on `leistungsdatum`
- **WHEN** either e-invoice format is generated
- **THEN** the line and matching tax breakdown use `AE`, 0%, and `VATEX-EU-AE`
- **AND** a VAT ID, customer type, or construction-service description alone does not establish §13b(5) recipient qualification

#### Scenario: §13b(2) no. 4 missing or invalid recipient certificate fails closed

- **GIVEN** a line is marked for the supported §13b(2) no. 4 construction case but the recipient's certificate is absent, expired on `leistungsdatum`, for another service scope, does not match the immutable buyer VAT ID, or its evidence fields are unknown or inconsistent
- **WHEN** either e-invoice format is generated
- **THEN** generation fails with a localized diagnostic naming the invoice position and missing or inconsistent `e_invoice_reverse_charge_*` field
- **AND** no artifact is written and no §13b(5) recipient qualification is inferred from a VAT ID, customer type, or service description

#### Scenario: Intra-Community supply uses K evidence

- **GIVEN** a line persists the §6a treatment, category `K`, reason code `VATEX-EU-IC`, seller and buyer VAT IDs, delivery date, destination country, and a statutory exemption statement
- **WHEN** either e-invoice format is generated
- **THEN** the output uses the persisted K evidence
- **AND** a K invoice containing a non-K line, allowance, or charge fails closed

#### Scenario: Export supply uses G evidence

- **GIVEN** a line persists the §6 export treatment, category `G`, reason code `VATEX-EU-G`, a seller or tax-representative registration ID, and an explicit non-EU destination country
- **WHEN** either e-invoice format is generated
- **THEN** the output uses the persisted G evidence without requiring a buyer VAT ID
- **AND** an unspecified zero-rate line cannot use category `G`
- **AND** a G invoice containing a non-G line, allowance, or charge fails closed

#### Scenario: Unsupported exemptions and legacy tax rows fail closed

- **GIVEN** a line has a generic or unsupported §4 exemption, an unsupported reverse-charge case, or no typed evidence because it is legacy data
- **WHEN** e-invoice generation is requested
- **THEN** it fails with a localized position/field diagnostic and writes no output

#### Scenario: Persisted tax tuple mismatch fails closed

- **GIVEN** a line's stored category, exemption code, reason text, tax treatment, legal basis, and rate do not match the accepted tuple
- **WHEN** either e-invoice format is requested
- **THEN** generation fails with a localized diagnostic naming the invoice position and mismatched source field
- **AND** no artifact is written

#### Scenario: §25a remains separate and unavailable for e-invoice output

- **GIVEN** an invoice contains a §25a margin-scheme line with internal margin-tax amounts
- **WHEN** either e-invoice format is requested before the category/reason and amount relationship are accepted
- **THEN** generation fails with `taxClassificationUnresolved`
- **AND** internal margin tax is not included in the e-invoice tax breakdown or passed to the serializer
- **AND** the canonical disclosed invoice amounts remain separate from accounting-only margin tax
- **AND** the unresolved owner question is which EN 16931 category/reason code or text represents §25a in each pinned profile, what taxable and tax amounts belong in its VAT breakdown, and how those amounts relate to disclosed line amounts and payable totals for both pure and mixed invoices

#### Scenario: Tax evidence persists and is captured without inference

- **GIVEN** a finalized invoice position has the complete v26 tax-evidence tuple
- **WHEN** its immutable snapshot is built and later exported
- **THEN** the snapshot and export retain the persisted treatment, legal basis, category, and reason exactly
- **AND** changing the numeric rate alone cannot change the selected category or reason

#### Scenario: Tax category mapping is unavailable

- **GIVEN** a finalized invoice contains a line whose stored tax data has no approved mapping to the selected profile
- **WHEN** e-invoice generation is requested
- **THEN** generation fails with the affected line and unresolved classification identified, without choosing a code or writing an artifact

### Requirement: Required-field and business-rule validation

Before output is exposed or written, the selected format's pinned validator SHALL validate required fields and business rules. The system SHALL map validation findings to typed field/business-term or rule identifiers and localized corrective messages. If the source snapshot is missing a required value or violates a pinned rule, generation SHALL fail without a partial file. Diagnostics MUST NOT silently default or infer missing financial, identity, tax, buyer-reference, or payment-term values.

#### Scenario: Valid data passes pinned validation

- **GIVEN** the selected output is generated from a snapshot with all required source values
- **WHEN** its pinned schema and business-rule validation runs
- **THEN** the validated artifact is made available and the UI reports the selected format as valid

#### Scenario: Missing required source field

- **GIVEN** the selected format requires a value absent from the invoice snapshot
- **WHEN** generation is requested
- **THEN** the system identifies the missing field/rule in a localized validation summary and writes no output

#### Scenario: Pinned business rule rejects invoice

- **GIVEN** generated XML violates a business rule from the selected pinned standard bundle
- **WHEN** validation runs
- **THEN** the output is rejected with the stable rule identifier, no partial artifact is exposed, and the source invoice is unchanged

### Requirement: Selected ZUGFeRD hybrid finalization

When ZUGFeRD is explicitly selected for an ordinary outgoing invoice, finalization SHALL generate a ZUGFeRD 2.5.2 `EN16931` CII invoice embedded in the human-readable PDF/A-3b visual document. The customer `zugferd_aktiv` value SHALL preselect this format but MUST NOT hide or force the per-invoice choice. The hybrid PDF SHALL validate its XML, PDF/A-3b conformance, embedded-file relationship, and required format metadata before the database finalization transaction commits. If generation or validation fails, invoice numbering, finalized status, inventory side effects, and other database changes SHALL roll back and temporary files SHALL be removed. If PDF or XRechnung is selected, finalization SHALL use the existing non-hybrid visual PDF path; standalone XRechnung generation remains a separate post-finalization export.

#### Scenario: Selected ZUGFeRD finalization

- **GIVEN** an outgoing invoice draft has ZUGFeRD selected and its snapshot meets the selected profile
- **WHEN** the invoice is finalized
- **THEN** the stored original PDF is the validated PDF/A-3b hybrid with embedded ZUGFeRD 2.5.2 XML, and the finalized invoice references that artifact

#### Scenario: Customer default is overridden per invoice

- **GIVEN** a customer's `zugferd_aktiv` value preselects ZUGFeRD for a draft invoice
- **WHEN** the user explicitly selects PDF or XRechnung before finalization
- **THEN** the chosen non-ZUGFeRD format is shown as selected and no ZUGFeRD XML is embedded in the finalized PDF

#### Scenario: ZUGFeRD validation failure rolls back finalization

- **GIVEN** ZUGFeRD is selected and the invoice snapshot fails a required field or pinned rule
- **WHEN** finalization is attempted
- **THEN** the invoice remains a draft without an allocated number or stock side effect, and no final or temporary artifact remains

### Requirement: Standalone XRechnung export

The detail workspace SHALL allow a finalized ordinary outgoing invoice to be exported as standalone XRechnung 3.0 UBL 2.1 XML validated with the pinned XRechnung Bundle 3.0.2 Summer 2026. The page SHALL obtain generation and validation through the registered invoice service/repository, validate before writing, and use a native save-file dialog. A successful export MUST NOT change invoice fields, finalization state, numbering, or accounting records.

#### Scenario: Export standalone XRechnung

- **GIVEN** a finalized ordinary outgoing invoice passes XRechnung 3.0 validation using Bundle 3.0.2 Summer 2026
- **WHEN** the user selects XRechnung export and saves the chosen file
- **THEN** a standalone UBL 2.1 XML file is written atomically and the invoice remains unchanged

#### Scenario: Cancel standalone XRechnung export

- **GIVEN** a finalized invoice passes validation and the native save dialog is open
- **WHEN** the user cancels the dialog
- **THEN** no XML file is written and the invoice remains unchanged

#### Scenario: Export cannot validate

- **GIVEN** the finalized snapshot is missing a required XRechnung value or its pinned validator is unavailable
- **WHEN** the user requests XRechnung export
- **THEN** localized validation or availability is shown, the save dialog is not opened, and no file or invoice field changes

### Requirement: XRechnung party endpoints and payment instructions

UBL party electronic addresses SHALL come from snapshot fields (persisted master-data captures plus the explicit export `buyerReference`): the seller address (BT-34) uses the company `ust_idnr` with scheme `9930` when present, else fails closed naming `ust_idnr`; the buyer address (BT-49) uses the customer `email` with scheme `EM` when present, else the snapshot `buyerReference` with scheme `0204` (the reference is documented as e.g. Leitweg-ID) when present, else fails closed. Values pass through verbatim after trimming; malformed values are left to pinned-rule diagnostics. No endpoint value SHALL ever be invented or defaulted. Payment instructions (BG-16) use the company `iban` as the SEPA credit-transfer account (BT-81 code 58 with BG-17 payee account); an absent IBAN SHALL fail closed with a localized diagnostic naming the company IBAN instead of emitting fabricated payment means. This payment gate is intentionally XRechnung-only (BR-DE-1 is XRechnung-specific).

#### Scenario: Seller endpoint uses the company VAT identifier

- **GIVEN** a finalized snapshot has a company `ust_idnr` and any email state
- **WHEN** XRechnung UBL is generated
- **THEN** the seller `EndpointID` carries the VAT identifier with `schemeID="9930"`

#### Scenario: Endpoints fall back without invention

- **GIVEN** the customer has no `email` but the snapshot has a `buyerReference`
- **WHEN** XRechnung UBL is generated
- **THEN** the buyer endpoint uses the buyer reference with `0204`
- **AND** a missing seller `ust_idnr` or a buyer with neither source SHALL fail closed with a localized diagnostic naming the absent field

### Requirement: XRechnung delivery date

The invoice SHALL carry an optional delivery date (`leistungsdatum`, ISO `YYYY-MM-DD`) captured in the draft/edit workspace, persisted on the invoice row, and snapshotted at finalization like other invoice facts. XRechnung UBL SHALL emit it as BT-72 Actual delivery date, verbatim after trimming; malformed values are left to pinned-rule diagnostics. An absent delivery date SHALL fail closed for XRechnung with a localized diagnostic naming `leistungsdatum`; no date SHALL ever be inferred from the issue date, due date, or creation timestamp. This gate is intentionally XRechnung-only.

#### Scenario: Delivery date is emitted verbatim

- **GIVEN** a finalized snapshot carries a `leistungsdatum` of `2026-03-10`
- **WHEN** XRechnung UBL is generated
- **THEN** the XML carries that exact date as BT-72 Actual delivery date

#### Scenario: Missing delivery date fails closed

- **GIVEN** the finalized snapshot carries no `leistungsdatum`
- **WHEN** XRechnung UBL is requested
- **THEN** generation SHALL fail closed with a localized diagnostic naming `leistungsdatum`
- **AND** no date SHALL be inferred from issue, due, or creation timestamps

### Requirement: E-invoice output follows application boundaries and design

The invoice finalization/detail surface SHALL expose a visible per-invoice choice of ZUGFeRD, XRechnung, and PDF, with the customer ZUGFeRD value used only as the default selection. It SHALL show the selected output and its validation/readiness state, plus available export actions; unavailable outputs SHALL explain why. The XRechnung action SHALL use the registered invoice application-scope service and typed repository; the widget MUST NOT issue SQL or construct a data source. New controls, status, errors, and validation SHALL use generated localization, keyboard-accessible interaction, visible focus, responsive layout, and non-color validation cues as defined by `DESIGN.md`.

#### Scenario: Output choices and state are visible

- **GIVEN** an outgoing invoice draft or finalized invoice is open in its detail surface
- **WHEN** the user reviews output formats
- **THEN** ZUGFeRD, XRechnung, and PDF are explicit choices, the customer ZUGFeRD value supplies only the draft default, and selected-format state and available actions are visible with text

#### Scenario: Selected format survives reopening a finalized invoice

- **GIVEN** a draft invoice is finalized with `ausgabeformat = xrechnung`
- **WHEN** the finalized invoice is closed and reopened from its detail route
- **THEN** the detail surface restores XRechnung as the selected output and shows its export as not yet validated until the user requests export

#### Scenario: Invoice detail exposes a reachable export

- **GIVEN** an eligible finalized invoice is open in the production detail route
- **WHEN** the user reviews its available actions
- **THEN** XRechnung export is reachable by keyboard with a localized accessible name, and validation errors identify the fields to correct

#### Scenario: Draft has no standalone export action

- **GIVEN** an outgoing invoice is still a draft
- **WHEN** the user reviews the detail actions
- **THEN** the XRechnung export action is unavailable and the UI does not imply that an e-invoice artifact exists

#### Scenario: Legacy finalized invoice defaults to PDF

- **GIVEN** a finalized invoice row has no saved `ausgabeformat` from before this change
- **WHEN** the invoice is reopened
- **THEN** the detail surface shows PDF as selected and does not infer a format from the customer's current ZUGFeRD preference
