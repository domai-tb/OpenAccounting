# Implementation Tasks

Complete all prerequisites before starting the scenario work. They are explicit design gates, not assumptions already satisfied by the current code.

Tax-contract revision note: the delivered base ledger was 96/128 complete. Tasks 7.1–7.6 are reopened because their checked implementation/tests did not cover the revised explicit subtype and eligibility-evidence mappings. All unrelated checked work remains checked.

## 1. Resolve implementation prerequisites

- [x] 1.1 Establish an accepted invoice-money contract and record it as a dependency; do not recalculate or round money during serialization.
- [x] 1.2 Independently review and accept the closed tax mapping before further persistence or input-wiring work. Scope K to §6a(1)(2)(a) VAT-registered business buyers acquiring for their businesses; reject §6a(1)(2)(b) and new vehicles under §6a(1)(2)(c). Require line-bound §6a(1)(3) destination-tax applicability and §6a(3) movement proof. For G, retain ordinary supplier-carried and qualified foreign-buyer routes only; reject §6(1)(3), §6(3) buyer-carried transport-equipment/supply cases, and §6(3a) personal luggage, and require §6(4) export proof. The existing v29 fields persist nullable claims and references; the reviewed schema ledger is v30, and these fields are not resolved proof. For §25a, resolve immutable line-bound §25a(1)(2) acquisition eligibility or the applicable §25a(2) acquisition route and election; verify the §25a(2) declaration remains in force (binding for at least two calendar years), exclude §25a(1)(3) goods, and reject barred §25a(7) routes and §25a(4) aggregate calculation. The invoice-money result already has position-keyed payable amounts and price/allowance basis, but must separately supply position-keyed accounting margin tax and disclosure totals. The independent escalated review approved this exact contract revision (see `review.md`). This closes only the contract-review prerequisite; implementation, immutable evidence resolution, input capture, and positive output remain gated by their open tasks.
- [ ] 1.3 Package and demonstrate the pinned offline validator and PDF/A-3b validation on Linux, Windows, and macOS; package private Java runtimes for each supported OS without runtime validator downloads.
- [x] 1.4 Provide a user-facing master-data editor for the customer ZUGFeRD default, or establish the accepted dependency that supplies it.
- [x] 1.5 Establish and migrate persistent finalized customer snapshot storage so standalone exports cannot read changed live customer data.

## 2. Document Lifecycle — Finalization

- [x] 2.1 Write failing test for "Finalization locks document": finalization_assigns_number_locks_fields_persists_format_and_stores_pdf in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 2.2 Implement the required application behavior for "Finalization locks document" from specs/documents/spec.md to pass the named test.
- [x] 2.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 2.4 Write failing test for "Finalization captures company snapshot": finalized_pdf_uses_captured_company_snapshot in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 2.5 Implement the required application behavior for "Finalization captures company snapshot" from specs/documents/spec.md to pass the named test.
- [x] 2.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 2.7 Write failing test for "Re-finalization blocked": rejects_finalization_of_already_finalized_invoice in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 2.8 Implement the required application behavior for "Re-finalization blocked" from specs/documents/spec.md to pass the named test.
- [x] 2.9 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 2.10 Write failing test for "Legacy finalized invoice defaults to PDF": legacy_finalized_invoice_resolves_missing_format_to_pdf in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 2.11 Implement the required application behavior for "Legacy finalized invoice defaults to PDF" from specs/documents/spec.md to pass the named test.
- [x] 2.12 Refactor the related implementation; targeted tests and the full suite stay green.

## 3. Kunden — Zugferd aktiv

- [x] 3.1 Write failing test for "Customer preference preselects ZUGFeRD": zugferd_customer_preference_preselects_zugferd in test/features/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [x] 3.2 Implement the required application behavior for "Customer preference preselects ZUGFeRD" from specs/stammdaten/spec.md to pass the named test.
- [x] 3.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 3.4 Write failing test for "Customer preference preselects PDF": disabled_zugferd_preference_preselects_pdf in test/features/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [x] 3.5 Implement the required application behavior for "Customer preference preselects PDF" from specs/stammdaten/spec.md to pass the named test.
- [x] 3.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 3.7 Write failing test for "Per-invoice selection overrides the default": per_invoice_choice_overrides_default_without_changing_customer in test/features/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [x] 3.8 Implement the required application behavior for "Per-invoice selection overrides the default" from specs/stammdaten/spec.md to pass the named test.
- [x] 3.9 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 3.10 Write failing test for "ZUGFeRD invoice generation": zugferd_finalization_stores_validated_hybrid_and_readiness in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 3.11 Implement the required application behavior for "ZUGFeRD invoice generation" from specs/stammdaten/spec.md to pass the named test.
- [ ] 3.12 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 3.13 Write failing test for "ZUGFeRD not generated when disabled": pdf_selection_does_not_embed_zugferd_xml in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 3.14 Implement the required application behavior for "ZUGFeRD not generated when disabled" from specs/stammdaten/spec.md to pass the named test.
- [x] 3.15 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 3.16 Write failing test for "Invalid selected ZUGFeRD data blocks finalization": invalid_zugferd_data_blocks_finalization_without_side_effects in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 3.17 Implement the required application behavior for "Invalid selected ZUGFeRD data blocks finalization" from specs/stammdaten/spec.md to pass the named test.
- [x] 3.18 Refactor the related implementation; targeted tests and the full suite stay green.

## 4. ZUGFeRD and XRechnung E-Invoicing

- [x] 4.1 Write failing test for "ZUGFeRD PDF generation": zugferd_pdf_generator_embeds_cii_as_facturx_attachment_with_pdfa_metadata in test/features/rechnungen/e_invoice_finalization_test.dart; the Unicode regression proved `/Params/Size` was 259 while the UTF-8 payload was 261 bytes.
- [x] 4.2 Implement Factur-X PDF construction in PdfGenerator and declare the embedded CII attachment size from its UTF-8 bytes; exact payload and size assertions pass. Formal PDF/A-3b validation remains open under task 1.3.
- [ ] 4.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 4.4 Write failing test for "XRechnung generation": generates_standalone_xrechnung_ubl_without_mutating_invoice in test/features/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [ ] 4.5 Implement the required application behavior for "XRechnung generation" from specs/pdf/spec.md to pass the named test.
- [ ] 4.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 4.7 Write failing test for "Invalid invoice data for e-invoicing": rejects_invalid_invoice_with_localized_rule_diagnostic_and_no_output in test/features/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [ ] 4.8 Implement the required application behavior for "Invalid invoice data for e-invoicing" from specs/pdf/spec.md to pass the named test.
- [ ] 4.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 5. Version-pinned e-invoice formats

- [ ] 5.1 Complete the positive supported-format regression. The attempted real KoSIT run remains blocked by missing persisted seller contact point and telephone fields; see verify.md.
- [ ] 5.2 Complete supported XRechnung generation only after seller contact data has an accepted persisted source. Keep output fail-closed until then.
- [ ] 5.3 Refactor and run targeted plus full-suite validation after the seller contact prerequisite is implemented.
- [x] 5.4 Write failing test for "Unsupported or unavailable validation bundle": unavailable_or_corrupt_bundle_rejects_output_without_compliance_claim in test/features/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [x] 5.5 Implement the required application behavior for "Unsupported or unavailable validation bundle" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 5.6 Refactor the related implementation; targeted tests and the full suite stay green.

## 6. Generate from one canonical invoice snapshot

- [x] 6.1 Write failing test for "Finalization outputs share one canonical snapshot": pdf_and_cii_match_the_snapshot_and_committed_invoice in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 6.2 Implement the required application behavior for "Finalization outputs share one canonical snapshot" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 6.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 6.4 Write failing test for "Standalone export reads the committed snapshot": standalone_export_uses_committed_snapshot_without_mutation in test/features/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [x] 6.5 Implement the required application behavior for "Standalone export reads the committed snapshot" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 6.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 6.7 Write failing test for "Snapshot output failure rolls back finalization": output_failure_rolls_back_number_status_stock_and_artifacts in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 6.8 Implement the required application behavior for "Snapshot output failure rolls back finalization" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 6.9 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 6.10 Write failing test for "Draft invoice cannot be exported": draft_invoice_rejects_export_without_changes in test/features/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [x] 6.11 Implement the required application behavior for "Draft invoice cannot be exported" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 6.12 Refactor the related implementation; targeted tests and the full suite stay green.

## 7. Tax categories are explicitly classified

- [ ] 7.1 Complete the focused tax matrix, including resolver-backed positive §13b(1)/(2), both positive §6/G movement routes, §6a/K, and every supported §25a subtype. Retain only supported positive K/G routes, but block output until immutable line-bound evidence resolves; v29 already persists typed claims and references, not proof. K evidence supports only a VAT-registered business buyer acquiring for its business under §6a(1)(2)(a), and resolves the buyer-used valid foreign VAT ID, goods, date, destination, movement, §6a(1)(3) tax-rule applicability, and §6a(3) movement proof to this line. Reject §6a(1)(2)(b), new vehicles under §6a(1)(2)(c), and unknown buyer/vehicle status. The typed status means applicability of those rules, not actual tax charged or paid; missing, unknown, not-subject, or unverified status must fail closed. G must resolve a line-bound ordinary §3(1) supply, actor/route, actual third-country destination outside §1(3), goods, buyer, date, and seller-held §6(4) export proof under §§8–11 UStDV. Explicitly reject §3(1b) deemed supplies under §6(5). Support ordinary supplier/supplier-agent movement under §6(1)(1) and qualified foreign-buyer movement under §6(1)(2)/§6(2). Reject §6(1)(3), buyer-carried transport-equipment/supply under §6(3), and personal luggage under §6(3a). `kunden.land` cannot substitute for destination or buyer qualification. Add `section_6_deemed_supply_under_section_3_1b_fails_closed` to prove that absent or contrary line-bound §3(1) evidence blocks G. Current K negatives cover missing/unknown, DE, non-EU destination, and unresolved evidence; add `section_6a_destination_state_acquisition_tax_treatment_missing_or_unverified_fails_closed` for missing/unknown/not-subject/unverified §6a(1)(3) treatment. The G snapshot boundary now rejects missing/unknown, DE/EU, and customer-country-only destinations, and keeps every line blocked until a line-bound movement actor/evidence resolver exists; focused FVM verification is pending the shared slot. Add missing/unknown-actor, unqualified-buyer, actor/route-mismatch, unsupported-route, and absent/mismatched §6(4)-proof tests against the real immutable resolver; v29 already persists typed actor fields, so do not block these on another migration or create fixture-only proof. Preserve the existing standard/reduced, taxable-zero, §19 BT-33/BT-120, §13b rejection, §25a subtype/code/note, tuple-mismatch, and unresolved-mapping matrix. Keep the three §25a payable-disclosure regressions, but add immutable evidence for the alternative §25a(1)(2)/§25a(2) acquisition routes, timely/in-force §25a(2) election coverage (including a withdrawal after its minimum binding period), barred §25a(7) cases, and a separate keyed accounting margin-tax input assertion. Existing amount tests prove BT-131 disclosure only, not eligibility or separate accounting capture. Assert E BT-117 is 0.00 and BT-110 is 0.00 only when no other category contributes. Add `section_25a_mixed_with_standard_tax_preserves_standard_bt110` in `test/features/rechnungen/e_invoice_generation_test.dart`: combine a §25a payable line of 107.60 with a standard `S` line of 50.00 at 19%, assert E BT-117 = 0.00, S BT-117 = 9.50, BT-109 = 157.60, BT-110 = 9.50, and BT-112/BT-115 = 167.10 with no payment, rounding, allowance, or charge. Also cover repeated identical subtypes aggregating into one E breakdown, mixed F/I/J reasons failing closed, and `section_19_mixed_with_25a_fails_closed_for_e_breakdown_reason_conflict`. The §19 + §25a case must assert conflicting BT-120/BT-121 requirements are diagnosed by position and no XML is returned. The three §25a-only amount cases and the mixed-S/19% case have source and test implementations. Repeated same-subtype aggregation now produces one E breakdown; mixed F/I/J and §19/§25a lines fail closed with position-keyed BT-121/BT-120 diagnostics and no UBL/CII XML. Positive §13b, K, and G output remains blocked until real source records resolve; do not synthesize evidence from nonempty IDs or references.
- [x] 7.2 Implement additive e-invoice tax-claim fields and snapshot projection in migration v29 after mileage v28. This work is complete: nullable typed position fields and snapshot projection are covered by fresh-install/v28-upgrade, draft round-trip, committed-reader, and disclosure-inventory tests; legacy rows remain null without inference. These fields store claims and references only; they do not create or resolve immutable assessment/proof records. The reviewed schema ledger is v30.
- [ ] 7.3 Refactor the typed evidence and mapping implementation; focused tests stay green.
- [x] 7.4 Write rejection tests for incomplete §13b facts and unresolved source references: `eu_service_13b1_missing_eligibility_evidence_fails_with_position_diagnostic`, `eu_service_13b1_complete_facts_without_resolved_assessment_fail_closed`, `construction_13b2_unresolved_references_fail_closed_without_seller_country_assumption`, `construction_13b2_missing_or_invalid_ust1tg_fails_with_position_diagnostic`, `tax_evidence_tuple_mismatch_fails_with_position_field_diagnostic`, and `section_25a_without_supported_reason_code_fails_with_position_diagnostic` in test/features/rechnungen/e_invoice_generation_test.dart.
- [x] 7.5 Implement field-level diagnostics and fail-closed behavior for unsupported/incomplete evidence. Earlier §25a tuple tests prove code/note mapping only. Position-keyed payable amounts and price/allowance basis plus four disclosure-parity regressions are implemented; immutable §25a eligibility resolution and separate position-keyed accounting margin-tax capture remain open; repeated-subtype aggregation and cross-treatment reason regressions now have focused source and test evidence.
- [ ] 7.6 Refactor the fail-closed diagnostic behavior; focused tests stay green.

The following §13b source-record work is the accepted contract amendment committed in `03c9d8c01b07b0892f2fd8e771f8011f36b93663`. It applies to task 7.1's resolver-backed positive cases and keeps them in scope.

- [ ] 7.7 Write failing tests for `eu_service_13b1_resolved_assessment_emits_ae_in_ubl_and_cii`, `eu_service_13b1_mismatched_assessment_fails_closed_before_finalization_side_effects`, and `committed_export_uses_frozen_13b1_assessment_without_live_lookup`. Cover reference resolution for the exact invoice, persisted position, buyer, treatment, and all existing typed facts; include both finalization and committed export paths. Keep the already accepted `leistungsdatum` check on §13b(2) certificate validity; do not add a new §13b(1) date predicate.
- [ ] 7.8 Implement an append-only §13b assessment record and resolver in the next sequential migration slot after mileage v30 if v30 lands first; recheck the live migration ledger and use its then-available next slot if v30 has not landed. Key each record by the existing `e_invoice_reverse_charge_evidence_source_ref` and bind it to one invoice, persisted position, and buyer. Store only the already accepted §13b treatment/facts. For construction, resolve the existing USt 1 TG certificate reference and its accepted buyer, construction scope, issue date, and validity-through facts against the already required `leistungsdatum`. The owning tax-assessment/invoice-entry workflow must create records from its upstream evidence; line fields, customer status, VAT IDs, and non-empty references alone are insufficient. Resolve within finalization before side effects, freeze the verified facts/reference into the snapshot, use the frozen evidence for committed exports, reject stale/mismatched records, and do not backfill legacy positions.
- [ ] 7.9 Refactor the §13b assessment resolver and snapshot path; focused generation, finalization, and export tests stay green.

§13b implementation checkpoint (2026-10-25): migration ledger is v30 after mileage commit `174668cbd372b6d39c1ed2b392fea36444a33faf`. The only current source is mutable per-position claim columns; no owning assessment/certificate record store, resolver, creator, or invoice-entry capture flow exists. PDF finalization now runs the existing fail-closed reverse-charge validator before transactional side effects, with a regression proving the invoice row, sequence, artifacts, and accounting postings remain unchanged for unresolved §13b(1) evidence. No v31 migration or fabricated positive evidence was added. Tasks 7.7–7.9 remain open because the real upstream source integration is required for positive assessment resolution, immutable snapshot freezing, mismatch coverage, and frozen-evidence export.

Tax serializer checkpoint (2026-10-18; historical, with K/G eligibility scope subsequently tightened): focused tests then covered explicit S/Z/E tuples, §19 BT-33/BT-120, unresolved §13b references, K/G category serialization, and §25a tuples. Those K/G fixtures relied on customer-country data and did not prove per-line destination or resolved movement/eligibility evidence. The v29 nullable claim migration has since completed after mileage v28, but does not resolve legal eligibility. Tasks 1.2, 7.1, 7.3, and 7.6 remain open; the current article field is only a boolean and does not supply a §25a subtype.

Implementation progress (2026-10-25): the independent approval of the seven-artifact contract is recorded in `review.md`. The position-keyed amount source and four scoped parity regressions implement only a subset of task 7.1. A fresh implementation review found the committed reader omitted available typed tax columns; finalization and committed export now share the optional evidence projection. The red committed-reader regression failed with `unresolvedTaxClassification`; after the repair, both committed-reader tests and all 9 export tests passed, the generation suite passed 45/45, the invoice-money suite passed 19/19, scoped analysis found no issues, and formatting is clean. The migration, subtype/margin-tax capture, explicit price/adjustment basis, and remaining reason/matrix tests are still open. Tasks 1.2 and 7.1 remain unchecked.

- [ ] 7.10 Implement immutable §6a and §6 evidence resolution from owning source workflows. Resolve each source reference to one persisted invoice position and buyer; verify supported buyer/actor route, actual destination, goods, date, destination-state treatment where applicable, and the statutory movement/export proof. Keep unsupported §6 routes and §6a buyer/new-vehicle cases fail-closed. Use the next sequential migration slot only if the reviewed source requires new persisted evidence, after checking the live ledger.
- [ ] 7.11 Implement immutable §25a assessment and accounting output. Resolve §25a(1)(2) acquisition eligibility or the applicable §25a(2) route and election, including the goods group, filing deadline, effective year, minimum binding period, and any later withdrawal; verify reseller/goods eligibility and reject §25a(1)(3), §25a(7)(1)(a)–(c), §25a(7)(3), and unsupported §25a(4) cases. Supply position-keyed accounting margin tax separately from BT-131 and disclosure totals, freeze the result for committed export, and fail closed on missing or mismatched evidence. Recheck the live migration ledger before adding persistence.

## 8. Required-field and business-rule validation

- [x] 8.1 Write failing test for "Valid data passes pinned validation": valid_snapshot_is_accepted_and_reported_ready in test/features/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [x] 8.2 Implement the required application behavior for "Valid data passes pinned validation" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 8.3 Refactor the related implementation; targeted tests and the full suite stay green. The scoped validator files pass; full-suite verification remains pending.
- [x] 8.4 Write failing test for "Missing required source field": missing_source_field_reports_localized_diagnostic_without_output in test/features/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [x] 8.5 Implement the required application behavior for "Missing required source field" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 8.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 8.7 Write failing test for "Pinned business rule rejects invoice": pinned_business_rule_rejects_output_without_mutating_invoice in test/features/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [ ] 8.8 Implement the required application behavior for "Pinned business rule rejects invoice" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 8.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 9. Selected ZUGFeRD hybrid finalization

- [x] 9.1 Write failing test for "Selected ZUGFeRD finalization": stores_validated_hybrid_pdf_and_references_artifact in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 9.2 Implement the required application behavior for "Selected ZUGFeRD finalization" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 9.3 Refactor the related implementation; the focused regression and scoped analysis pass, with full-suite confirmation pending.
- [x] 9.4 Write failing test for "Customer default is overridden per invoice": explicit_non_zugferd_choice_generates_non_hybrid_pdf in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 9.5 Implement the required application behavior for "Customer default is overridden per invoice" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 9.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 9.7 Write failing test for "ZUGFeRD validation failure rolls back finalization": zugferd_validation_failure_rolls_back_finalization_and_temp_files in test/features/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [x] 9.8 Implement the required application behavior for "ZUGFeRD validation failure rolls back finalization" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 9.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 10. Standalone XRechnung export

- [ ] 10.1 Write failing test for "Export standalone XRechnung": saves_validated_xrechnung_atomically_without_invoice_mutation in test/features/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [ ] 10.2 Implement the required application behavior for "Export standalone XRechnung" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 10.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 10.4 Write failing test for "Cancel standalone XRechnung export": canceling_save_dialog_writes_no_file_and_changes_nothing in test/features/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [x] 10.5 Implement the required application behavior for "Cancel standalone XRechnung export" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 10.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 10.7 Write failing test for "Export cannot validate": validation_failure_prevents_save_dialog_and_file_write in test/features/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [x] 10.8 Implement the required application behavior for "Export cannot validate" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 10.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 11. E-invoice output follows application boundaries and design

- [x] 11.1 Write failing test for "Output choices and state are visible": shows_all_formats_selection_and_readiness_with_text in test/features/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [x] 11.2 Implement the required application behavior for "Output choices and state are visible" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 11.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 11.4 Write failing test for "Selected format survives reopening a finalized invoice": restores_persisted_xrechnung_selection_after_reopen in test/features/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [x] 11.5 Implement the required application behavior for "Selected format survives reopening a finalized invoice" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 11.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 11.7 Write failing test for "Invoice detail exposes a reachable export": exposes_keyboard_reachable_localized_export_and_error_details in test/features/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [x] 11.8 Implement the required application behavior for "Invoice detail exposes a reachable export" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 11.9 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 11.10 Write failing test for "Draft has no standalone export action": hides_or_disables_export_for_draft_invoice in test/features/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [x] 11.11 Implement the required application behavior for "Draft has no standalone export action" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 11.12 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 11.13 Write failing test for "Legacy finalized invoice defaults to PDF": reopened_legacy_invoice_shows_pdf_without_customer_inference in test/features/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [x] 11.14 Implement the required application behavior for "Legacy finalized invoice defaults to PDF" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 11.15 Refactor the related implementation; targeted tests and the full suite stay green.

## 12. XRechnung party endpoints and payment instructions

- [x] 12.1 Write failing test for "Seller endpoint uses the company VAT identifier": seller_endpoint_uses_vat_id_with_9930 in test/features/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [x] 12.2 Implement the required application behavior for "Seller endpoint uses the company VAT identifier" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 12.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 12.4 Write failing test for "Endpoints fall back without invention": endpoint_fallback_without_invention in test/features/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [x] 12.5 Implement the required application behavior for "Endpoints fall back without invention" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 12.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 12.7 Write failing test for "Missing payment data fails closed": missing_payment_data_fails_closed in test/features/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [x] 12.8 Implement the required application behavior for "Missing payment data fails closed" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 12.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 13. XRechnung delivery date

- [x] 13.1 Write failing test for "Delivery date is emitted verbatim": delivery_date_emitted_verbatim in test/features/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [x] 13.2 Implement the required application behavior for "Delivery date is emitted verbatim" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 13.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 13.4 Write failing test for "Missing delivery date fails closed": missing_delivery_date_fails_closed in test/features/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [x] 13.5 Implement the required application behavior for "Missing delivery date fails closed" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [x] 13.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [x] 13.7 Write failing test for invoice `leistungsdatum` persistence and workspace capture: persists_optional_leistungsdatum_through_workspace in test/features/rechnungen/workspace_lifecycle_actions_test.dart (assert it fails for the right reason).
- [x] 13.8 Implement the invoice `leistungsdatum` column, snapshot capture, and workspace field to pass 13.7.
- [ ] 13.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 14. Offline XML validation service wiring

- [x] 14.1 Write failing service-boundary tests proving schema-invalid serialized UBL and CII are rejected and accepted validation results allow output: `offline_validator_rejects_schema_invalid_xrechnung_xml`, `offline_validator_rejects_schema_invalid_cii_before_hybrid_return`, and `offline_validator_accepts_serialized_ubl_and_cii_before_return` in `test/features/rechnungen/e_invoice_generation_test.dart`.
- [x] 14.2 Invoke the packaged offline XML validator after serialization and structural checks, before UBL return/save-dialog/write and before CII artifact return; adapt callers to await the async boundary.
- [x] 14.3 Preserve offline-validator diagnostics on `EInvoiceExportValidationException` and prove invalid UBL does not open the save dialog or write a file with `offline_schema_failure_prevents_save_dialog_and_file_write`; focused tests and analyzer pass.
- [x] 14.4 Distinguish unavailable validation from invalid XML in typed results and localized diagnostics; prove unavailable UBL/CII output and export are blocked without opening the save dialog or writing a file.
- [x] 14.5 Validate generated ZUGFeRD CII during production finalization before number reservation, stock, invoice/accounting mutations, or PDF/CII/temp artifact writes; prove unavailable validation preserves all state with `zugferd_validator_unavailable_prevents_any_finalization_side_effects` in `test/features/rechnungen/e_invoice_finalization_test.dart`.

## 15. Hybrid attachment integrity and crash recovery

- [x] 15.1 Write a failing regression proving non-ASCII embedded CII bytes match the payload and declared `/Params/Size`.
- [x] 15.2 Set the embedded-file size to the actual UTF-8 byte count and verify the German `Straße ß` payload.
- [x] 15.3 Write a failing recovery regression with a real draft row, an absent invoice ID, a finalized row, and exact final/temp sidecars; verify retry succeeds.
- [x] 15.4 Recover only strict numeric ZUGFeRD sidecar names for draft or absent invoice rows; preserve finalized-row sidecars, finalized PDF, and unrelated files.
- [x] 15.5 Run both focused regressions and scoped analysis; formal PDF/A-3b conformance and immutable tax-evidence resolution remain separate open gates.

Implementation progress update (2026-10-25): the snapshot emits an explicit one-piece H87 price base and checks canonical BT-131 against source unit price and quantity. For per-line percentage discounts, the source carries canonical position-keyed pre-discount price basis and allowance; the builder reconciles them to persisted price, quantity, percentage, and payable line amount, then UBL/CII serialize the validated allowance. Focused regressions cover net and gross standard-tax lines, §25a E lines, and committed-reader export parity. Document-level discounts remain fail-closed. This slice does not add schema columns or complete the tax matrix, and the separate §25a accounting margin-tax amount is still unavailable from the preview source. The v29 nullable tax-claim migration and projection are now implemented and covered; they do not resolve legal eligibility. The current ledger is v30. Tasks 1.2 and 7.1 remain unchecked pending immutable source evidence, the separate §25a accounting margin-tax amount, the remaining tax matrix, and fresh exact-diff independent review.
