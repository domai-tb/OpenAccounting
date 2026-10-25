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

Finalization SHALL materialize one typed immutable snapshot inside the finalization transaction after number allocation and canonical invoice calculation and before PDF/e-invoice generation. The snapshot SHALL contain the allocated number, selected `ausgabeformat` enum (`zugferd`, `xrechnung`, or `pdf`), dates, sender and customer data, invoice lines, persisted tax-treatment/legal-basis/category/reason evidence, currency, canonical disclosed invoice totals, canonical final per-position amounts, and any separate accounting-only tax values. The accepted invoice-money result SHALL expose both its accounting view and its EN 16931 disclosure view before snapshot creation. Its immutable per-position disclosure record SHALL be keyed by the persisted position and provide the quantity, disclosed unit price and price-base quantity, supported line-level allowances/charges, and final BT-131 line net amount; it SHALL also keep any internal §25a margin-tax amount in a distinct accounting-only field. It SHALL ensure BT-131 equals `(BT-146 / BT-149 × BT-129) + BT-141 - BT-136` using the returned price/quantity/adjustment basis. The disclosure view SHALL provide canonical BT-106 through BT-117 breakdown values and BT-112 through BT-115 totals, satisfying `BT-109 = BT-106 - BT-107 + BT-108`, `BT-110 = sum(BT-117)`, `BT-112 = BT-109 + BT-110`, and `BT-115 = BT-112 - BT-113 + BT-114`. The snapshot SHALL copy these values without reconstructing them from unit price or tax rate. The accounting and disclosure views MAY share a value only when they are semantically and numerically equal. An aggregate result containing only accounting net, tax, and gross totals is insufficient. For §25a, BT-131 SHALL use the final customer-payable line amount; for category `E` at 0%, this amount is also the E/0% BT-116 taxable amount, while BT-117 remains zero. If the source does not provide the keyed position values and disclosure totals, or they do not reconcile with the accepted canonical source result and EN 16931 formulas, e-invoice generation SHALL fail closed before output. If finalization commits, the same snapshot values MUST be persisted on the finalized invoice row. The visual PDF and embedded ZUGFeRD XML SHALL consume that same snapshot. A standalone XRechnung export SHALL consume a typed immutable snapshot read from the committed finalized outgoing invoice. Serialization SHALL preserve applicable snapshot values and MUST NOT calculate or round invoice money, infer tax treatment, fabricate identifiers or terms, calculate VAT-category breakdowns, expose internal margin tax, create accounting entries, or mutate the invoice. This initial capability covers ordinary outgoing invoices only.

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

Each invoice line SHALL persist explicit typed tax evidence before it can be included in an e-invoice snapshot. The additive e-invoice tax-evidence migration is coordinated as v29, following mileage v28 after it lands. Migration v29 SHALL add nullable legacy-compatible fields `tax_treatment`, `tax_legal_basis`, `e_invoice_tax_category_code`, `e_invoice_exemption_reason_code`, `e_invoice_exemption_reason_text`, `e_invoice_intra_community_destination_country_iso`, `e_invoice_intra_community_acquisition_tax_treatment` (`subject_to_destination_member_state_acquisition_vat_rules`, `not_subject_to_destination_member_state_acquisition_vat_rules`, `unknown`), `e_invoice_intra_community_supply_evidence_source_ref`, `e_invoice_export_destination_country_iso`, `e_invoice_export_movement_actor`, and `e_invoice_export_evidence_source_ref` to invoice positions. The §6a destination field SHALL record the actual EU supply/delivery destination separately for each position, while the §6 export destination field SHALL record the actual third-country export destination; the invoice workflow SHALL capture both explicitly and the immutable finalization snapshot SHALL preserve each with its resolved source evidence. `kunden.land` is the billing-party address and MUST NOT populate or substitute for either per-position destination. The §6a source reference SHALL resolve to immutable upstream movement/tax evidence that verifies a qualifying buyer and the valid foreign EU VAT ID actually used by that buyer, and binds buyer/VAT ID, goods, delivery date, destination, destination-state acquisition-tax treatment, and movement to this exact invoice line and supply. For UStG §6a(1)(3), `e_invoice_intra_community_acquisition_tax_treatment` SHALL be `subject_to_destination_member_state_acquisition_vat_rules` only when the resolver verifies that this buyer's acquisition of these goods is subject to the VAT rules in the actual destination Member State; missing, `not_subject_to_destination_member_state_acquisition_vat_rules`, `unknown`, or unverified treatment SHALL fail closed. This field describes applicability of destination-state VAT rules, not actual tax charged or paid: UStAE Abschnitt 6a.1(18) recognizes use of a valid foreign VAT ID by the buyer as evidence of this condition and does not require actual taxation. An arbitrary, unresolved, or mismatched source reference fails closed. The §6 export movement actor SHALL be explicitly captured per position as `supplier_or_supplier_agent` or `buyer_or_buyer_agent`. The source reference SHALL resolve to immutable export/movement evidence proving the matching party's route and movement to the per-position third-country destination and matching this invoice line's goods, buyer identity, delivery date, and destination. For `buyer_or_buyer_agent`, the resolved source SHALL also verify that the buyer is a foreign buyer under §6(2); supplier-carried movement under §6(1)(1) does not require that buyer qualification. An arbitrary, unresolved, or mismatched reference, missing/unknown actor, or unqualified buyer-carried route fails closed. The closed `tax_treatment` values are `standard_19`, `reduced_7`, `taxable_zero_12_3`, `kleinunternehmer_19`, `reverse_charge_eu_service_13b_1`, `reverse_charge_domestic_construction_13b_2_4_5`, `intra_community_supply_6a`, `export_supply_6`, `margin_scheme_25a_second_hand`, `margin_scheme_25a_art`, and `margin_scheme_25a_collectors_antiquities`. The matching legal-basis values are respectively `ustg_12_1`, `ustg_12_2`, `ustg_12_3`, `ustg_19`, `ustg_3a_2_13b_1`, `ustg_13b_2_4_5`, `ustg_4_1b_6a`, `ustg_4_1a_6`, `ustg_25a`, `ustg_25a`, and `ustg_25a`. New eligible lines SHALL persist a complete, accepted tuple; historical rows with absent fields SHALL remain unresolved and MUST NOT be backfilled from `ust_satz`. An owning accounting/tax source or explicit invoice-entry workflow SHALL write the typed treatment separately from `ust_satz`; copying an explicitly stored treatment is allowed, but inferring it from rate, product name, country, VAT-ID prefix, customer type, or margin amount is forbidden.

For the two supported §13b cases, v29 SHALL also persist the following nullable, typed eligibility evidence on the invoice position and capture it verbatim in the immutable snapshot: `e_invoice_reverse_charge_supplier_establishment_country_iso`; `e_invoice_reverse_charge_supplier_establishment_basis` (`seat_or_management`, `fixed_establishment`); `e_invoice_reverse_charge_supplier_german_fixed_establishment_status` (`none`, `exists_not_involved`, `exists_participating`, `unknown`); `e_invoice_reverse_charge_recipient_status` (`entrepreneur_for_business`, `entrepreneur`, `other`, `unknown`); `e_invoice_reverse_charge_recipient_establishment_country_iso`; `e_invoice_reverse_charge_service_kind` (`general_b2b_service_3a_2_no_exception`, `construction_service_13b_2_4`, `other`, `unknown`); `e_invoice_reverse_charge_place_of_supply_basis` (`recipient_business_establishment_3a_2`, `recipient_fixed_establishment_3a_2`, `german_immovable_property_13b_2_4`, `other`, `unknown`); `e_invoice_reverse_charge_place_of_supply_country_iso`; `e_invoice_reverse_charge_taxability` (`taxable_in_germany_under_3a_2`, `taxable_in_germany_under_13b_2_4`, `not_taxable`, `unknown`); and `e_invoice_reverse_charge_evidence_source_ref`. For the construction case, also persist `e_invoice_reverse_charge_recipient_13b5_basis` (`valid_ust1tg_certificate`, `unverified`, `other`, `unknown`), `e_invoice_reverse_charge_ust1tg_certificate_ref`, `e_invoice_reverse_charge_ust1tg_scope` (`construction_13b_2_4`, `building_cleaning_13b_2_8`, `other`, `unknown`), `e_invoice_reverse_charge_ust1tg_recipient_vat_id`, `e_invoice_reverse_charge_ust1tg_issued_on`, and `e_invoice_reverse_charge_ust1tg_valid_through`. For §13b(1), supplier-establishment, recipient, service, place-of-supply, and taxability fields are required and must prove the enumerated §3a(2)/§13b(1) conditions. For §13b(2) no. 4, the service, German place-of-supply, taxability, recipient, and certificate fields are required; supplier-establishment fields are captured from the source record but their country or German fixed-establishment status is not a §13b(5) recipient-qualification test. A certificate reference SHALL resolve to the captured authority-issued certificate; the certificate recipient VAT ID SHALL match the immutable buyer VAT ID. These facts are explicit upstream tax-source inputs, not serializer inferences; a null required field, unknown/invalid enum, unresolved reference, or contradictory evidence SHALL fail closed with a localized position/field diagnostic.

For §13b, `e_invoice_reverse_charge_evidence_source_ref` SHALL resolve to the immutable upstream tax assessment/evidence record from which the persisted recipient, supplier, service, place-of-supply, and taxability facts were established; a customer type or VAT-ID validation record alone is insufficient. The construction certificate reference SHALL resolve to the captured authority-issued certificate and its persisted recipient identifier, service scope, issue date, and validity-through date. If either reference cannot be resolved or contradicts the captured invoice facts, generation SHALL fail closed.

The v29 position fields are typed claims and SHALL NOT count as a resolved assessment. Before positive §13b output, the owning tax-assessment/invoice-entry workflow SHALL persist an immutable reverse-charge assessment record in the next sequential migration slot after the mileage-owned v30 migration if v30 lands first; implementation SHALL recheck the live migration ledger and use its then-available next slot rather than hard-code v31 if v30 has not landed. The existing `e_invoice_reverse_charge_evidence_source_ref` SHALL identify exactly one record scoped to one invoice ID, persisted position ID, and buyer ID; the record SHALL carry the already specified treatment and case-specific `e_invoice_reverse_charge_*` values without adding statutory eligibility predicates. For §13b(2) no. 4, its existing certificate reference SHALL resolve to the captured authority-issued certificate with the already specified recipient VAT ID, construction scope, issue date, and validity-through date, and validity SHALL be checked against the already required `leistungsdatum`. Records are append-only: corrections create a new reference and cannot retarget or modify an existing record. The finalization transaction SHALL resolve the reference and compare its invoice, position, buyer, treatment, and every captured typed value before any finalization side effect. For §13b(2) no. 4, the existing certificate validity check also applies. A mismatch, missing record, or unresolved certificate SHALL fail closed with position/field diagnostics. Finalization SHALL freeze the resolved reference and accepted values in the immutable snapshot; committed UBL/CII generation SHALL use that frozen evidence and SHALL NOT re-resolve live records. Editing the buyer, position, or accepted facts requires a new matching assessment. Historical positions SHALL NOT be backfilled.

The application SHALL validate stored tuples against the following closed mapping for both XRechnung 3.0 UBL 2.1 and ZUGFeRD 2.5.2 EN16931 CII:

| Explicit treatment | Required legal basis | EN 16931 category | Exemption reason | Required evidence |
|---|---|---|---|---|
| Standard taxable supply at 19% | `UStG §12(1)` | `S`, 19% | None | Persist treatment and legal basis; the rate MUST be exactly 19%. |
| Reduced taxable supply at 7% | `UStG §12(2)` | `S`, 7% | None | Persist treatment and legal basis; the rate MUST be exactly 7%. |
| Taxable zero-rate supply | `UStG §12(3)` | `Z`, 0% | None | Persist explicit taxable-zero treatment and legal basis. A 0% rate without this basis is unresolved. Require the seller VAT ID, seller tax registration ID, or seller tax-representative VAT ID required by BR-Z-2. |
| Kleinunternehmer | `UStG §19` | `E`, 0% | No VATEX code. XRechnung BT-33 (`cac:PartyLegalEntity/cbc:CompanyLegalForm`) and BT-120, and the corresponding CII reason text, SHALL carry exactly `Kein Ausweis von Umsatzsteuer, da Kleinunternehmer gemäß § 19 UStG`. | Persist explicit §19 status/treatment, legal basis, category, and required text. Do not infer it from 0%. |
| EU B2B service reverse charge | `UStG §3a(2) / §13b(1)` | `AE`, 0%, `VATEX-EU-AE` | BT-120 SHALL say `Steuerschuldnerschaft des Leistungsempfängers`. | Persist seller establishment country/basis; German fixed-establishment status (`none` or `exists_not_involved`); recipient status `entrepreneur_for_business`; recipient establishment country `DE`; service kind `general_b2b_service_3a_2_no_exception`; place-of-supply basis under §3a(2), country `DE`; taxability `taxable_in_germany_under_3a_2`; and an evidence-source reference. The supplier establishment country SHALL be another EU Member State. Require seller and buyer VAT IDs as profile identifiers, but never treat them as proof of eligibility. All lines, allowances, and charges in an AE invoice SHALL be AE, or none SHALL be AE. |
| Domestic construction service reverse charge | `UStG §13b(2) no. 4 / §13b(5)` | `AE`, 0%, `VATEX-EU-AE` | BT-120 SHALL say `Steuerschuldnerschaft des Leistungsempfängers`. | This change supports only a construction service under §13b(2) no. 4 on German immovable property and taxable in Germany. Persist service kind `construction_service_13b_2_4`, place-of-supply basis/country and taxability, recipient status `entrepreneur`, and recipient qualification `valid_ust1tg_certificate`. Capture supplier-establishment country/basis and German fixed-establishment status as source context, but do not use supplier nationality or establishment as proof of the recipient condition under §13b(5). The certificate SHALL identify construction services, match the immutable buyer VAT ID, and be valid on `leistungsdatum`; persist its source reference and issue/expiry dates. Seller and buyer VAT IDs remain profile identifiers, not proof of §13b(5) eligibility. A customer type, construction-service description, or VAT ID alone is insufficient. Missing, expired, unmatched, or other-scope evidence fails closed. A sustainable-services route without a valid USt 1 TG certificate and all other §13b cases remain unsupported in this change. |
| Intra-Community supply | `UStG §4 Nr. 1(b) in conjunction with §6a(1)(1)–(4)` | `K`, 0%, `VATEX-EU-IC` | Preserve one statutory source phrase: `Steuerfreie innergemeinschaftliche Lieferung` or `Steuerfrei nach § 4 Nr. 1 Buchst. b i. V. m. § 6a UStG`. | For this German-origin mapping, require seller and buyer VAT IDs, delivery date, actual per-position `e_invoice_intra_community_destination_country_iso`, `e_invoice_intra_community_acquisition_tax_treatment=subject_to_destination_member_state_acquisition_vat_rules`, and resolved `e_invoice_intra_community_supply_evidence_source_ref`. The destination SHALL be an EU Member State other than DE; `kunden.land` SHALL NOT populate or substitute for it. The immutable resolver SHALL verify a qualifying buyer, the valid foreign EU VAT ID actually used by the buyer, and that this buyer’s acquisition of the line goods is subject to VAT rules in that actual destination Member State under §6a(1)(2)–(4). It SHALL bind buyer/VAT ID, goods, delivery date, destination, destination-state acquisition-tax treatment, and movement to this exact invoice line and supply. Missing/unknown/DE/non-EU destination, missing/unknown/not-subject/unverified acquisition-tax treatment, or unresolved/mismatched evidence fails closed with a position/field diagnostic. This treatment means applicability of destination-state VAT rules, not that tax was actually charged or paid: UStAE Abschnitt 6a.1(18) recognizes the buyer’s valid foreign VAT ID used for the supply as evidence of this condition and does not require actual taxation. All lines, allowances, and charges in a K invoice SHALL be K, or none SHALL be K. Sources: [UStG §4](https://www.gesetze-im-internet.de/ustg_1980/__4.html), [UStG §6a(1)](https://www.gesetze-im-internet.de/ustg_1980/__6a.html), [UStAE Abschnitt 6a.1(17)–(18)](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Umsatzsteuer/Umsatzsteuer-Anwendungserlass/Umsatzsteuer-Anwendungserlass-31-12-2025.pdf?__blob=publicationFile&v=2), [XStandards UStG mapping](https://xeinkauf.de/xrechnung/ustg/), [EC guidance, case 2](https://ec.europa.eu/digital-building-blocks/sites/download/attachments/467108974/eInvoicing%20technical%20guidance%20document_v1.pdf?api=v2&modificationDate=1721117125403&version=2), [UStDV §17d](https://www.gesetze-im-internet.de/ustdv_1980/__17d.html). |
| Export supply | `UStG §4 Nr. 1(a) in conjunction with §6(1)(1) or §6(1)(2), and §6(2) when the buyer carries the goods` | `G`, 0%, `VATEX-EU-G` | No generic exemption reason. | Require seller or tax-representative registration ID, actual per-position `e_invoice_export_destination_country_iso` in a third-country territory under §6, explicit `e_invoice_export_movement_actor`, and a resolved `e_invoice_export_evidence_source_ref`. Support supplier/supplier-agent movement under §6(1)(1), or buyer/buyer-agent movement under §6(1)(2) only when the immutable resolver also verifies the buyer is foreign under §6(2). Resolve evidence that binds this line’s goods, buyer identity, delivery date, actual destination, and movement actor/route to this exact invoice line and supply. `kunden.land` is only the billing-party address and SHALL NOT populate the export destination or independently prove foreign-buyer status. Missing/unknown/DE/EU destination, missing/unknown actor, absent/unresolved/mismatched line-bound evidence, or buyer-carried movement without verified foreign-buyer qualification fails closed. A buyer VAT ID is not required by this mapping. All lines, allowances, and charges in a G invoice SHALL be G, or none SHALL be G. Sources: [UStG §4](https://www.gesetze-im-internet.de/ustg_1980/__4.html), [UStG §6(1)(1),(2) and §6(2)](https://www.gesetze-im-internet.de/ustg_1980/__6.html), [EC guidance, case 4](https://ec.europa.eu/digital-building-blocks/sites/download/attachments/467108974/eInvoicing%20technical%20guidance%20document_v1.pdf?api=v2&modificationDate=1721117125403&version=2), [UStDV §8](https://www.gesetze-im-internet.de/ustdv_1980/__8.html). |
| §25a second-hand goods | `UStG §25a` | `E`, 0%, `VATEX-EU-F` | Exact reason and BT-22 text: `Gebrauchtgegenstände/Sonderregelung`. | Require treatment `margin_scheme_25a_second_hand`, exact code and text. |
| §25a works of art | `UStG §25a` | `E`, 0%, `VATEX-EU-I` | Exact reason and BT-22 text: `Kunstgegenstände/Sonderregelung`. | Require treatment `margin_scheme_25a_art`, exact code and text. |
| §25a collectors' items and antiques | `UStG §25a` | `E`, 0%, `VATEX-EU-J` | Exact reason and BT-22 text: `Sammlungsstücke und Antiquitäten/Sonderregelung`. | Require treatment `margin_scheme_25a_collectors_antiquities`, exact code and text. For all three subtypes, UBL SHALL emit BT-22 as `cbc:Note`; CII SHALL emit it as `ram:IncludedNote`. The accounting margin-tax amount SHALL remain internal and SHALL be embedded exactly once in the accepted customer-payable BT-131 amount; it SHALL NOT be emitted as tax in the E breakdown's BT-117 or counted a second time in invoice-wide BT-110. BT-110 SHALL continue to equal the sum of BT-117 across all VAT breakdowns, including other categories such as standard-tax `S`; BT-110 is zero only when no other breakdown contributes tax. Never infer subtype from an article flag, product name, or margin amount. This mapping follows the [Peppol VATEX list](https://docs.peppol.eu/poacc/billing/3.0/codelist/vatex/), [Peppol E-category rules BR-E-01/08/09/10](https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-E-01/), and [Peppol invoice total formulas](https://docs.peppol.eu/poacc/billing/3.0/bis/#calculation-of-totals), and the German invoice-note requirement in [UStG §14a(6)](https://www.gesetze-im-internet.de/ustg_1980/__14a.html), as listed in [XStandards UStG mapping](https://xeinkauf.de/xrechnung/ustg/), with legal basis [UStG §25a](https://www.gesetze-im-internet.de/ustg_1980/__25a.html) and the [BMF UStH 25a.1(16)](https://usth.bundesfinanzministerium.de/usth/2024/A-Umsatzsteuergesetz/VI-Sonderregelungen/Paragraf-25a/ae-25a-1.html). |

The table applies to the EN 16931 semantic model: UBL SHALL place the persisted category/reason in the applicable line and tax-breakdown fields; CII SHALL place the same evidence in the matching `ApplicableTradeTax` structures. The serializer SHALL NOT select or complete a mapping. It SHALL consume only the persisted tax tuple, the captured seller/buyer party IDs and country codes, the §13b eligibility fields, and accepted canonical amounts. It SHALL NOT calculate tax, round amounts, aggregate VAT breakdowns, apply tax rates, decide legal eligibility, or access accounting-only margin tax. Missing or mismatched values SHALL produce a localized field-level diagnostic naming the invoice position and source field, including the tax tuple fields or any required `e_invoice_reverse_charge_*` field.

For each §25a line, the accepted invoice-money source SHALL provide the post-discount customer-payable amount as BT-131 together with its disclosed unit-price and any supported line-adjustment basis; BT-131 SHALL reconcile with that basis under the selected profile formula. The serializer MUST NOT replace BT-131 with the internal net tax base or manufacture a balancing allowance. The source's accounting margin-tax value SHALL be retained only in the accounting view. Under `E`, 0%, BT-116 SHALL equal the E-line amount after any category-E document allowances/charges, and BT-117 for the E breakdown SHALL be zero. Invoice-wide BT-110 SHALL equal the sum of BT-117 across all VAT breakdowns; it is zero only when no other taxable category contributes tax, so standard VAT remains included in BT-110 on a mixed standard-tax/§25a invoice. BT-109 SHALL follow the BT-131/document-adjustment formula, BT-112 SHALL equal BT-109 plus BT-110, and BT-115 SHALL equal BT-112 minus paid amount plus rounding amount. For the maintained accounting result net `100.00` plus internal margin tax `7.60`, customer payable remains `107.60`: the accepted disclosure source SHALL return BT-131 `107.60`; for a §25a-only invoice with no payment, rounding, allowance, or charge, BT-116, BT-109, BT-112, and BT-115 are `107.60`, while the E-breakdown BT-117 and invoice-wide BT-110 are `0.00` because no other taxable category contributes tax. Thus the margin-tax amount is embedded in the payable line amount exactly once and is never disclosed as E-category VAT or counted a second time in invoice-wide BT-110 or the invoice payable total. These accounting and EN 16931 relationships are grounded respectively in [UStG §25a(3)](https://www.gesetze-im-internet.de/ustg_1980/__25a.html), [BMF UStH 25a.1(16)](https://usth.bundesfinanzministerium.de/usth/2024/A-Umsatzsteuergesetz/VI-Sonderregelungen/Paragraf-25a/ae-25a-1.html), and [Peppol BR-E-08/09 and total formulas](https://docs.peppol.eu/poacc/billing/3.0/bis/#calculation-of-totals). The currently accepted preview result exposes only aggregate accounting totals, so it is insufficient for this purpose: an upstream canonical invoice-money result must first provide the position-keyed disclosure view and its payable total.

An EN 16931 invoice SHALL contain exactly one E VAT breakdown when it contains E-category lines, and that breakdown SHALL carry a VAT exemption reason code or text. Every E/0% line in the invoice SHALL be compatible with the same exact breakdown-reason pair (`BT-121`, when applicable, and `BT-120`). Lines with the same accepted reason pair MAY aggregate when their treatment mapping permits it. Any incompatible combination SHALL fail closed before output with diagnostics naming the affected positions and required reasons; this includes mixed `margin_scheme_25a_second_hand`/F, `margin_scheme_25a_art`/I, and `margin_scheme_25a_collectors_antiquities`/J lines, and a `kleinunternehmer_19` line combined with any §25a line. The §19 BT-33 legal text and BT-120 reason remain required, and each §25a line retains its BT-22 statutory note, but those fields do not merge or override the single E-breakdown reason pair. The system MUST NOT emit duplicate E breakdowns, invent a composite reason, or select one reason arbitrarily. This follows [Peppol BR-E-01 and BR-E-10](https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-E-01/) and the §19 mapping in [XRechnung 3.0.2 §13.3](https://xeinkauf.de/app/uploads/2024/07/302-XRechnung-2024-06-20.pdf).

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
- **THEN** the output uses category `E`, contains no VATEX code, and carries exactly `Kein Ausweis von Umsatzsteuer, da Kleinunternehmer gemäß § 19 UStG` as BT-120 and the corresponding CII reason
- **AND** XRechnung places the same exact text in BT-33 at `cac:PartyLegalEntity/cbc:CompanyLegalForm`

#### Scenario: Named reverse-charge cases use AE evidence after reference resolution

- **GIVEN** a line persists either named reverse-charge treatment with its complete case-specific eligibility evidence, seller and buyer VAT IDs, and a resolvable immutable assessment reference
- **AND** for §13b(2) no. 4, the immutable authority-issued USt 1 TG certificate reference resolves and matches the buyer and service facts
- **WHEN** either e-invoice format is generated
- **THEN** the line and matching tax breakdown use `AE`, 0%, and `VATEX-EU-AE`, with the statutory reason text
- **AND** any unsupported §13b treatment or invoice with a mixed AE/non-AE line, allowance, or charge fails closed

#### Scenario: §13b(1) EU service uses AE only with persisted eligibility evidence

- **GIVEN** a line persists an ordinary §3a(2) B2B service with no place-of-supply exception, explicit German taxability, a German recipient business establishment, and a supplier establishment in another EU Member State
- **AND** the persisted supplier-establishment basis and German fixed-establishment participation status establish that the supplier is EU-established for this transaction
- **AND** the persisted recipient status is `entrepreneur_for_business`, and the place-of-supply basis, country, service kind, taxability, evidence-source reference, and seller/buyer VAT IDs are complete
- **AND** the immutable assessment reference resolves to a record bound to this invoice, persisted position, buyer, treatment, and those exact persisted facts
- **WHEN** either e-invoice format is generated
- **THEN** the line and matching tax breakdown use `AE`, 0%, and `VATEX-EU-AE`
- **AND** VAT IDs alone do not establish supplier establishment, recipient business status, place of supply, or taxability

#### Scenario: §13b(1) assessment cannot be reused for another line

- **GIVEN** a supported §13b(1) line has a non-empty reference to an immutable assessment recorded for another invoice, position, buyer, treatment, or set of persisted eligibility facts
- **WHEN** finalization attempts to resolve the assessment
- **THEN** finalization fails closed with a position/field diagnostic before numbering, stock, accounting, or artifact side effects
- **AND** neither UBL nor CII output is produced from the mismatched assessment

#### Scenario: §13b missing or unresolved eligibility evidence fails closed

- **GIVEN** a line is marked for a supported §13b case but any required supplier-establishment, German-fixed-establishment, recipient-status, service-kind, place-of-supply, taxability, or evidence-source field is absent, unknown, or contradictory, or its source reference does not resolve to a matching immutable evidence record
- **WHEN** either e-invoice format is generated
- **THEN** generation fails with a localized diagnostic naming the invoice position and missing or inconsistent `e_invoice_reverse_charge_*` field
- **AND** no artifact is written and no AE classification is inferred from VAT IDs

#### Scenario: §13b(2) no. 4 construction uses AE with valid recipient certificate evidence

- **GIVEN** a line persists a construction service under §13b(2) no. 4 on German immovable property and explicit German taxability
- **AND** the recipient is explicitly an entrepreneur and its referenced authority-issued USt 1 TG certificate covers construction services, matches the immutable buyer VAT ID, and is valid on `leistungsdatum`
- **WHEN** either e-invoice format is generated
- **THEN** the line and matching tax breakdown use `AE`, 0%, and `VATEX-EU-AE`
- **AND** a VAT ID, customer type, or construction-service description alone does not establish §13b(5) recipient qualification

#### Scenario: §13b(2) no. 4 missing, unresolved, or invalid recipient certificate fails closed

- **GIVEN** a line is marked for the supported §13b(2) no. 4 construction case but the recipient's certificate reference does not resolve, the certificate is absent, expired on `leistungsdatum`, for another service scope, does not match the immutable buyer VAT ID, or its evidence fields are unknown or inconsistent
- **WHEN** either e-invoice format is generated
- **THEN** generation fails with a localized diagnostic naming the invoice position and missing or inconsistent `e_invoice_reverse_charge_*` field
- **AND** no artifact is written and no §13b(5) recipient qualification is inferred from a VAT ID, customer type, or service description

#### Scenario: Intra-Community supply uses K evidence

- **GIVEN** a line persists the §6a treatment, category `K`, reason code `VATEX-EU-IC`, seller and buyer VAT IDs, delivery date, actual per-position destination in another EU Member State, destination-state acquisition-tax treatment `subject_to_destination_member_state_acquisition_vat_rules`, and the statutory exemption statement
- **AND** its immutable resolver verifies the qualifying buyer, the valid foreign EU VAT ID actually used, and the buyer’s acquisition of these goods is subject to VAT rules in that destination Member State
- **AND** the resolved evidence binds buyer/VAT ID, goods, date, destination, acquisition-tax treatment, and movement to this exact invoice line and supply
- **WHEN** either e-invoice format is generated
- **THEN** the output uses the persisted K evidence
- **AND** a K invoice containing a non-K line, allowance, or charge fails closed
- **AND** a billing-party country or non-empty reference alone cannot establish §6a eligibility

#### Scenario: §6a destination-state acquisition-tax treatment fails closed when missing or unverified

- **GIVEN** a line is marked for the supported §6a treatment but `e_invoice_intra_community_acquisition_tax_treatment` is absent, `unknown`, `not_subject_to_destination_member_state_acquisition_vat_rules`, or is not verified by the immutable line-bound resolver
- **WHEN** either e-invoice format is generated
- **THEN** generation fails with a localized diagnostic naming the invoice position and `e_invoice_intra_community_acquisition_tax_treatment`
- **AND** no artifact is written
- **AND** the condition concerns applicability of destination-state VAT rules, not proof that VAT was actually charged or paid

#### Scenario: §6a missing or invalid destination or evidence fails closed

- **GIVEN** a line is marked for the supported §6a treatment but its actual per-position destination is missing or unknown, is DE, or is not an EU Member State, or its immutable evidence is absent, unresolved, mismatched to the buyer/VAT ID, goods, date, destination, movement, or invoice line, or does not verify the qualifying buyer and the valid foreign EU VAT ID actually used
- **WHEN** either e-invoice format is generated
- **THEN** generation fails with a localized diagnostic naming the invoice position and missing or inconsistent source field
- **AND** no artifact is written and `kunden.land` or a non-empty evidence reference is not accepted as proof

#### Scenario: Supplier-carried export supply uses G evidence

- **GIVEN** a line persists the §6 export treatment, category `G`, reason code `VATEX-EU-G`, a seller or tax-representative registration ID, its actual per-position third-country destination, and movement actor `supplier_or_supplier_agent`
- **AND** its immutable resolver verifies supplier/supplier-agent movement under §6(1)(1) and binds this line’s goods, buyer identity, delivery date, destination, and movement route to the exact invoice line and supply
- **WHEN** either e-invoice format is generated
- **THEN** the output uses the persisted G evidence without requiring a buyer VAT ID
- **AND** an unspecified zero-rate line cannot use category `G`
- **AND** a G invoice containing a non-G line, allowance, or charge fails closed

#### Scenario: Qualified buyer-carried export supply uses G evidence

- **GIVEN** a line persists the §6 export treatment, category `G`, reason code `VATEX-EU-G`, a seller or tax-representative registration ID, its actual per-position third-country destination, and movement actor `buyer_or_buyer_agent`
- **AND** its immutable resolver verifies buyer/buyer-agent movement under §6(1)(2), the buyer’s foreign status under §6(2), and binds this line’s goods, buyer identity, delivery date, destination, and movement route to the exact invoice line and supply
- **WHEN** either e-invoice format is generated
- **THEN** the output uses the persisted G evidence without requiring a buyer VAT ID
- **AND** no buyer-carried G route is accepted from the billing address or buyer identity alone

#### Scenario: Export destination, actor, or line-bound movement evidence fails closed

- **GIVEN** a line is marked for the supported §6 export treatment but the actual per-position destination is absent or unknown, is DE, or is not a third-country territory, or the movement actor is missing or unknown, or its evidence is absent, unresolved, or mismatched to the line’s goods, buyer, date, destination, or actor/route
- **WHEN** either e-invoice format is generated
- **THEN** generation fails with a localized diagnostic naming the invoice position and missing or inconsistent source field
- **AND** a third-country customer billing address alone does not establish the export destination or movement

#### Scenario: Buyer-carried export fails closed without verified foreign-buyer status

- **GIVEN** a line claims buyer/buyer-agent carriage under §6(1)(2) but the immutable source does not verify that buyer is foreign under §6(2) or does not bind that qualification to this buyer, supply, goods, date, and destination
- **WHEN** either e-invoice format is generated
- **THEN** generation fails with a localized diagnostic naming the invoice position and foreign-buyer evidence
- **AND** supplier-carried movement under §6(1)(1) remains supported without that buyer-qualification predicate

#### Scenario: Unsupported exemptions and legacy tax rows fail closed

- **GIVEN** a line has a generic or unsupported §4 exemption, an unsupported reverse-charge case, or no typed evidence because it is legacy data
- **WHEN** e-invoice generation is requested
- **THEN** it fails with a localized position/field diagnostic and writes no output

#### Scenario: Persisted tax tuple mismatch fails closed

- **GIVEN** a line's stored category, exemption code, reason text, tax treatment, legal basis, and rate do not match the accepted tuple
- **WHEN** either e-invoice format is requested
- **THEN** generation fails with a localized diagnostic naming the invoice position and mismatched source field
- **AND** no artifact is written

#### Scenario: Explicit §25a subtype uses its VATEX code and statutory note

- **GIVEN** a line persists exactly one supported §25a subtype with its matching `VATEX-EU-F`, `VATEX-EU-I`, or `VATEX-EU-J` code and statutory note
- **WHEN** either e-invoice format is generated
- **THEN** the line and VAT breakdown use category `E` at 0% with the exact subtype code and reason text
- **AND** UBL emits the statutory note as BT-22 `cbc:Note` and CII emits it as `ram:IncludedNote`
- **AND** the canonical customer-payable amount is preserved, including any margin tax embedded in that amount exactly once; the internal margin tax is not emitted as VAT
- **AND** a missing or mismatched subtype/code/text tuple fails closed with a position/field diagnostic

#### Scenario: §25a-only disclosed amount preserves the canonical payable total

- **GIVEN** a §25a-only invoice and the accepted invoice-money source returns a position-keyed post-discount customer-payable amount and a disclosed price basis for its §25a line
- **AND** the canonical accounting result is net `100.00`, internal margin tax `7.60`, and customer payable `107.60`
- **WHEN** either e-invoice format is generated
- **THEN** the E/0% line amount and taxable amount are `107.60`, and the tax amount is `0.00`
- **AND** the E-breakdown BT-117 and invoice BT-110 are `0.00`, and the document's BT-109, BT-112, and BT-115 remain `107.60`
- **AND** internal margin tax is neither exposed as VAT nor added a second time
- **AND** absent or mismatched per-position canonical disclosure values fail closed before output

#### Scenario: Mixed §25a and standard-tax invoice preserves standard VAT in BT-110

- **GIVEN** the accepted invoice-money source returns a §25a payable line of `107.60` and a standard `S`-category line of `50.00` at 19%
- **WHEN** either e-invoice format is generated without payments, rounding, allowances, or charges
- **THEN** the E breakdown has BT-116 `107.60` and BT-117 `0.00`, while the S breakdown has BT-116 `50.00` and BT-117 `9.50`
- **AND** invoice BT-109 is `157.60`, BT-110 is `9.50`, and BT-112 and BT-115 are `167.10`
- **AND** the §25a internal margin-tax value contributes no separate VAT amount to BT-117 or BT-110

#### Scenario: Repeated §25a lines with one subtype share one E/0% breakdown

- **GIVEN** multiple §25a lines use the same supported subtype and matching VATEX reason
- **WHEN** either e-invoice format is generated
- **THEN** their disclosed line amounts are summed into one E/0% VAT breakdown with that reason
- **AND** each line retains its own required statutory note

#### Scenario: Mixed §25a subtypes fail closed for the shared E/0% breakdown

- **GIVEN** §25a lines in one invoice use different supported subtypes and therefore different VATEX reasons
- **WHEN** either e-invoice format is generated
- **THEN** generation fails closed with diagnostics naming the conflicting positions and reasons
- **AND** it emits no duplicate E/0% breakdown and selects no arbitrary reason

#### Scenario: §19 and §25a lines with incompatible E reasons fail closed

- **GIVEN** one invoice contains a `kleinunternehmer_19` E/0% line with its required BT-33/BT-120 text and a §25a E/0% line with a VATEX-F/I/J reason
- **WHEN** either e-invoice format is generated
- **THEN** generation fails closed with diagnostics naming both positions and their incompatible E-breakdown reasons
- **AND** it returns no XML, emits no duplicate E breakdown, and combines neither reason into an invented value

#### Scenario: Tax evidence persists and is captured without inference

- **GIVEN** a finalized invoice position has the complete v29 tax-evidence tuple
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
