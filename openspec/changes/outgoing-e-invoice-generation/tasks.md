# Implementation Tasks

Complete all prerequisites before starting the scenario work. They are explicit design gates, not assumptions already satisfied by the current code.

## 1. Resolve implementation prerequisites

- [ ] 1.1 Establish an accepted invoice-money contract and record it as a dependency; do not recalculate or round money during serialization.
- [ ] 1.2 Approve a typed tax-category and exemption-reason mapping for every tax treatment in the initial supported scope.
- [ ] 1.3 Package and demonstrate the pinned offline validator and PDF/A-3b validation on Linux, Windows, and macOS.
- [ ] 1.4 Provide a user-facing master-data editor for the customer ZUGFeRD default, or establish the accepted dependency that supplies it.
- [ ] 1.5 Establish and migrate persistent finalized customer snapshot storage so standalone exports cannot read changed live customer data.

## 2. Document Lifecycle — Finalization

- [ ] 2.1 Write failing test for "Finalization locks document": finalization_assigns_number_locks_fields_persists_format_and_stores_pdf in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 2.2 Implement the required application behavior for "Finalization locks document" from specs/documents/spec.md to pass the named test.
- [ ] 2.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 2.4 Write failing test for "Finalization captures company snapshot": finalized_pdf_uses_captured_company_snapshot in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 2.5 Implement the required application behavior for "Finalization captures company snapshot" from specs/documents/spec.md to pass the named test.
- [ ] 2.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 2.7 Write failing test for "Re-finalization blocked": rejects_finalization_of_already_finalized_invoice in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 2.8 Implement the required application behavior for "Re-finalization blocked" from specs/documents/spec.md to pass the named test.
- [ ] 2.9 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 2.10 Write failing test for "Legacy finalized invoice defaults to PDF": legacy_finalized_invoice_resolves_missing_format_to_pdf in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 2.11 Implement the required application behavior for "Legacy finalized invoice defaults to PDF" from specs/documents/spec.md to pass the named test.
- [ ] 2.12 Refactor the related implementation; targeted tests and the full suite stay green.

## 3. Kunden — Zugferd aktiv

- [ ] 3.1 Write failing test for "Customer preference preselects ZUGFeRD": zugferd_customer_preference_preselects_zugferd in test/pages/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [ ] 3.2 Implement the required application behavior for "Customer preference preselects ZUGFeRD" from specs/stammdaten/spec.md to pass the named test.
- [ ] 3.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 3.4 Write failing test for "Customer preference preselects PDF": disabled_zugferd_preference_preselects_pdf in test/pages/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [ ] 3.5 Implement the required application behavior for "Customer preference preselects PDF" from specs/stammdaten/spec.md to pass the named test.
- [ ] 3.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 3.7 Write failing test for "Per-invoice selection overrides the default": per_invoice_choice_overrides_default_without_changing_customer in test/pages/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [ ] 3.8 Implement the required application behavior for "Per-invoice selection overrides the default" from specs/stammdaten/spec.md to pass the named test.
- [ ] 3.9 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 3.10 Write failing test for "ZUGFeRD invoice generation": zugferd_finalization_stores_validated_hybrid_and_readiness in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 3.11 Implement the required application behavior for "ZUGFeRD invoice generation" from specs/stammdaten/spec.md to pass the named test.
- [ ] 3.12 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 3.13 Write failing test for "ZUGFeRD not generated when disabled": pdf_selection_does_not_embed_zugferd_xml in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 3.14 Implement the required application behavior for "ZUGFeRD not generated when disabled" from specs/stammdaten/spec.md to pass the named test.
- [ ] 3.15 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 3.16 Write failing test for "Invalid selected ZUGFeRD data blocks finalization": invalid_zugferd_data_blocks_finalization_without_side_effects in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 3.17 Implement the required application behavior for "Invalid selected ZUGFeRD data blocks finalization" from specs/stammdaten/spec.md to pass the named test.
- [ ] 3.18 Refactor the related implementation; targeted tests and the full suite stay green.

## 4. ZUGFeRD and XRechnung E-Invoicing

- [ ] 4.1 Write failing test for "ZUGFeRD PDF generation": generates_hybrid_pdf_with_validated_zugferd_metadata in test/pages/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [ ] 4.2 Implement the required application behavior for "ZUGFeRD PDF generation" from specs/pdf/spec.md to pass the named test.
- [ ] 4.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 4.4 Write failing test for "XRechnung generation": generates_standalone_xrechnung_ubl_without_mutating_invoice in test/pages/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [ ] 4.5 Implement the required application behavior for "XRechnung generation" from specs/pdf/spec.md to pass the named test.
- [ ] 4.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 4.7 Write failing test for "Invalid invoice data for e-invoicing": rejects_invalid_invoice_with_localized_rule_diagnostic_and_no_output in test/pages/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [ ] 4.8 Implement the required application behavior for "Invalid invoice data for e-invoicing" from specs/pdf/spec.md to pass the named test.
- [ ] 4.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 5. Version-pinned e-invoice formats

- [ ] 5.1 Write failing test for "Generate supported pinned format": validates_supported_xml_against_exact_local_pinned_artifacts in test/pages/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [ ] 5.2 Implement the required application behavior for "Generate supported pinned format" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 5.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 5.4 Write failing test for "Unsupported or unavailable validation bundle": unavailable_or_corrupt_bundle_rejects_output_without_compliance_claim in test/pages/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [ ] 5.5 Implement the required application behavior for "Unsupported or unavailable validation bundle" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 5.6 Refactor the related implementation; targeted tests and the full suite stay green.

## 6. Generate from one canonical invoice snapshot

- [ ] 6.1 Write failing test for "Finalization outputs share one canonical snapshot": pdf_and_cii_match_the_snapshot_and_committed_invoice in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 6.2 Implement the required application behavior for "Finalization outputs share one canonical snapshot" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 6.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 6.4 Write failing test for "Standalone export reads the committed snapshot": standalone_export_uses_committed_snapshot_without_mutation in test/pages/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [ ] 6.5 Implement the required application behavior for "Standalone export reads the committed snapshot" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 6.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 6.7 Write failing test for "Snapshot output failure rolls back finalization": output_failure_rolls_back_number_status_stock_and_artifacts in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 6.8 Implement the required application behavior for "Snapshot output failure rolls back finalization" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 6.9 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 6.10 Write failing test for "Draft invoice cannot be exported": draft_invoice_rejects_export_without_changes in test/pages/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [ ] 6.11 Implement the required application behavior for "Draft invoice cannot be exported" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 6.12 Refactor the related implementation; targeted tests and the full suite stay green.

## 7. Tax categories are explicitly classified

- [ ] 7.1 Write failing test for "Explicit tax classification is serialized": serializes_approved_typed_tax_category_and_exemption_reason in test/pages/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [ ] 7.2 Implement the required application behavior for "Explicit tax classification is serialized" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 7.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 7.4 Write failing test for "Tax category mapping is unavailable": unresolved_tax_mapping_fails_without_inference_or_output in test/pages/rechnungen/e_invoice_generation_test.dart (assert it fails for the right reason).
- [ ] 7.5 Implement the required application behavior for "Tax category mapping is unavailable" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 7.6 Refactor the related implementation; targeted tests and the full suite stay green.

## 8. Required-field and business-rule validation

- [ ] 8.1 Write failing test for "Valid data passes pinned validation": valid_snapshot_is_accepted_and_reported_ready in test/pages/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [ ] 8.2 Implement the required application behavior for "Valid data passes pinned validation" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 8.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 8.4 Write failing test for "Missing required source field": missing_source_field_reports_localized_diagnostic_without_output in test/pages/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [ ] 8.5 Implement the required application behavior for "Missing required source field" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 8.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 8.7 Write failing test for "Pinned business rule rejects invoice": pinned_business_rule_rejects_output_without_mutating_invoice in test/pages/rechnungen/e_invoice_validator_test.dart (assert it fails for the right reason).
- [ ] 8.8 Implement the required application behavior for "Pinned business rule rejects invoice" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 8.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 9. Selected ZUGFeRD hybrid finalization

- [ ] 9.1 Write failing test for "Selected ZUGFeRD finalization": stores_validated_hybrid_pdf_and_references_artifact in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 9.2 Implement the required application behavior for "Selected ZUGFeRD finalization" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 9.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 9.4 Write failing test for "Customer default is overridden per invoice": explicit_non_zugferd_choice_generates_non_hybrid_pdf in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 9.5 Implement the required application behavior for "Customer default is overridden per invoice" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 9.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 9.7 Write failing test for "ZUGFeRD validation failure rolls back finalization": zugferd_validation_failure_rolls_back_finalization_and_temp_files in test/pages/rechnungen/e_invoice_finalization_test.dart (assert it fails for the right reason).
- [ ] 9.8 Implement the required application behavior for "ZUGFeRD validation failure rolls back finalization" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 9.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 10. Standalone XRechnung export

- [ ] 10.1 Write failing test for "Export standalone XRechnung": saves_validated_xrechnung_atomically_without_invoice_mutation in test/pages/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [ ] 10.2 Implement the required application behavior for "Export standalone XRechnung" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 10.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 10.4 Write failing test for "Cancel standalone XRechnung export": canceling_save_dialog_writes_no_file_and_changes_nothing in test/pages/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [ ] 10.5 Implement the required application behavior for "Cancel standalone XRechnung export" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 10.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 10.7 Write failing test for "Export cannot validate": validation_failure_prevents_save_dialog_and_file_write in test/pages/rechnungen/e_invoice_export_test.dart (assert it fails for the right reason).
- [ ] 10.8 Implement the required application behavior for "Export cannot validate" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 10.9 Refactor the related implementation; targeted tests and the full suite stay green.

## 11. E-invoice output follows application boundaries and design

- [ ] 11.1 Write failing test for "Output choices and state are visible": shows_all_formats_selection_and_readiness_with_text in test/pages/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [ ] 11.2 Implement the required application behavior for "Output choices and state are visible" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 11.3 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 11.4 Write failing test for "Selected format survives reopening a finalized invoice": restores_persisted_xrechnung_selection_after_reopen in test/pages/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [ ] 11.5 Implement the required application behavior for "Selected format survives reopening a finalized invoice" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 11.6 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 11.7 Write failing test for "Invoice detail exposes a reachable export": exposes_keyboard_reachable_localized_export_and_error_details in test/pages/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [ ] 11.8 Implement the required application behavior for "Invoice detail exposes a reachable export" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 11.9 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 11.10 Write failing test for "Draft has no standalone export action": hides_or_disables_export_for_draft_invoice in test/pages/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [ ] 11.11 Implement the required application behavior for "Draft has no standalone export action" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 11.12 Refactor the related implementation; targeted tests and the full suite stay green.
- [ ] 11.13 Write failing test for "Legacy finalized invoice defaults to PDF": reopened_legacy_invoice_shows_pdf_without_customer_inference in test/pages/rechnungen/invoice_output_format_widget_test.dart (assert it fails for the right reason).
- [ ] 11.14 Implement the required application behavior for "Legacy finalized invoice defaults to PDF" from specs/outgoing-e-invoice-generation/spec.md to pass the named test.
- [ ] 11.15 Refactor the related implementation; targeted tests and the full suite stay green.
