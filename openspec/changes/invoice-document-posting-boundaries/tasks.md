## 1. Invoice classification and accounting direction

- [ ] 1.1 Write failing tests `test_outgoing_invoice_posts_receivable_without_input_tax`, `test_incoming_aliases_use_purchase_range_and_accounting`, `test_incoming_type_is_canonicalized`, `test_supplier_linked_legacy_rechnung_is_incoming`, `test_incoming_customer_without_supplier_has_no_receivable`, `test_supplier_linked_offer_has_no_invoice_effects`, `test_unsupported_raw_types_are_rejected`, and `test_incoming_range_failures_do_not_fallback` from the test plan; confirm the type, range, and posting assertions fail for the expected reason.
- [ ] 1.2 Implement one resolved invoice direction for canonical type, partner, number range, supported document types, and generic posting eligibility; reject unsupported and correction types before side effects.
- [ ] 1.3 Refactor the classification path; rerun group 1 tests.

## 2. Invoice-derived receivables and input-tax claims

- [ ] 2.1 Write failing tests `test_create_for_rechnung_rejects_finalized_offer`, `test_create_for_rechnung_accepts_incoming_alias`, `test_incoming_invoice_creates_input_tax_claim`, `test_outgoing_vat_does_not_create_input_tax_claim`, and `test_supplier_linked_offer_does_not_create_input_tax_claim` from the test plan; confirm each failure demonstrates the missing type guard or VAT direction.
- [ ] 2.2 Apply the same supported-invoice classification to `ForderungenRepository.createForRechnung` and limit generic input-tax claims to incoming invoices.
- [ ] 2.3 Refactor posting eligibility and run group 2 tests.

## 3. PDF identity, counterparty, and finalization rollback

- [ ] 3.1 Write failing tests `test_incoming_pdf_uses_supplier_as_counterparty`, `test_outgoing_late_failure_rolls_back_stock_and_pdf`, `test_incoming_posting_failure_rolls_back_pdf_and_rows`, `test_document_only_failure_rolls_back_pdf_and_number`, `test_same_display_number_keeps_distinct_pdf_artifacts`, and `test_preexisting_pdf_target_is_not_overwritten_or_deleted` from the test plan; use a real temporary profile directory and compare existing PDF bytes.
- [ ] 3.2 Store new artifacts under document-row identity, refuse occupied targets, track cleanup ownership only after rename, choose the supplier PDF counterparty for incoming legacy rows, and add the document-stage failure point.
- [ ] 3.3 Refactor artifact creation/cleanup; rerun group 3 tests.

## 4. Outgoing stock deduction and legacy compatibility

- [ ] 4.1 Write failing tests `test_multi_position_stock_update`, `test_stock_change_logged_with_reference`, `test_incoming_invoice_does_not_reduce_stock`, `test_document_only_ignores_insufficient_stock`, `test_disabled_nonlegacy_article_is_unchanged`, `test_enabled_article_stock_decreases_on_outgoing_invoice`, `test_multiple_line_items_update_only_tracked_articles`, `test_non_inventory_stock_fields_are_ignored`, `test_insufficient_article_prevents_any_stock_update`, `test_incoming_invoice_has_no_stock_movement`, `test_repeated_article_quantities_are_combined`, `test_repeated_quantities_fail_atomically`, `test_legacy_stock_is_migrated_on_first_outgoing_movement`, `test_repeated_legacy_quantity_roundtrip_matches_movements`, and `test_disabled_stock_is_not_misclassified_as_legacy` from the test plan; confirm red failures match the combined-quantity or document-direction defect.
- [ ] 4.2 Run stock validation and deduction only for outgoing invoices, aggregate by article before checking stock, and update legacy and active stock once per article.
- [ ] 4.3 Refactor stock aggregation; rerun group 4 tests.

## 5. Storno restoration and movement ledger

- [ ] 5.1 Write failing tests `test_storno_restores_recorded_stock_movement`, `test_storno_restores_recorded_quantity_after_manual_change`, `test_storno_without_source_movement_does_not_add_stock`, `test_storno_skips_noninventory_article`, `test_storno_filters_and_aggregates_source_movements`, `test_storno_promotes_legacy_and_skips_disabled_stock`, `test_storno_failure_rolls_back_and_retry_restores_once`, `test_automatic_movement_is_atomic_and_referenced`, `test_storno_movement_is_atomic_and_referenced`, and `test_incoming_and_document_only_have_no_movement` from the test plan; confirm new source-movement and rollback expectations fail for the expected reason.
- [ ] 5.2 Restore only aggregated negative movements for the source invoice, apply the explicit legacy predicate, and keep stock, movement, correction, counter, and source-state writes in the Storno transaction.
- [ ] 5.3 Refactor the movement restoration path; rerun group 5 tests and the existing correction-document lifecycle tests.

## 6. Synchronize and verify

- [ ] 6.1 Run focused invoice, receivable, PDF artifact, and inventory tests; flip every passing test-plan row from red to green and investigate any mismatch.
- [ ] 6.2 Run `fvm flutter analyze`, the full VM test suite, strict OpenSpec change/spec validation, and `git diff --check`; record exact results in `verify.md`.
- [ ] 6.3 Synchronize the three accepted delta specs into the main documents, accounting, and inventory specs, archive the completed change, and validate the archived result.
