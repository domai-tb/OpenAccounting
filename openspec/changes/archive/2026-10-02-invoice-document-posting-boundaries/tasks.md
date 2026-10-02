## 1. Invoice classification and accounting direction

- [x] 1.1 Write failing tests `test_outgoing_invoice_posts_receivable_without_input_tax`, `test_incoming_aliases_use_purchase_range_and_accounting`, `test_incoming_type_is_canonicalized`, `test_supplier_linked_legacy_rechnung_is_incoming`, `test_incoming_customer_without_supplier_has_no_receivable`, `test_supplier_linked_offer_has_no_invoice_effects`, `test_unsupported_raw_types_are_rejected`, and `test_incoming_range_failures_do_not_fallback` from the test plan; confirm the type, range, and posting assertions fail for the expected reason.
- [x] 1.2 Implement one resolved invoice direction for canonical type, partner, number range, supported document types, and generic posting eligibility; reject unsupported and correction types before side effects.
- [x] 1.3 Refactor the classification path; rerun group 1 tests.

## 2. Invoice-derived receivables and input-tax claims

- [x] 2.1 Confirm the regression tests `test_create_for_rechnung_rejects_finalized_offer`, `test_create_for_rechnung_accepts_incoming_alias`, `test_incoming_invoice_creates_input_tax_claim`, `test_outgoing_vat_does_not_create_input_tax_claim`, and `test_supplier_linked_offer_has_no_invoice_effects`; the offer guard and incoming alias pass, while outgoing VAT creates a false input-tax claim before the tax fix.
- [x] 2.2 Apply the same supported-invoice classification to `ForderungenRepository.createForRechnung` and limit generic input-tax claims to incoming invoices.
- [x] 2.3 Refactor posting eligibility and run group 2 tests.

## 3. PDF identity, counterparty, and finalization rollback

- [x] 3.1 Add and run `test_incoming_pdf_uses_supplier_as_counterparty`, `test_outgoing_late_failure_rolls_back_stock_and_pdf`, `test_incoming_input_tax_failure_rolls_back`, `test_document_only_failure_rolls_back_pdf_and_number`, `test_same_display_number_keeps_distinct_pdf_artifacts`, and `test_preexisting_pdf_target_is_not_overwritten_or_deleted` with real temporary profile directories and byte-preservation assertions.
- [x] 3.2 Store new artifacts under document-row identity, refuse occupied targets, track cleanup ownership only after rename, choose the supplier PDF counterparty for incoming documents, and add the document-stage failure point.
- [x] 3.3 Refactor artifact creation/cleanup; rerun group 3 tests.

## 4. Outgoing stock deduction and legacy compatibility

- [x] 4.1 Add repeated-quantity and legacy-stock regressions; reuse existing tests for multi-position updates, movement references, disabled/enabled stock, incoming invoices, document-only records, and atomic insufficient-stock rejection.
- [x] 4.2 Run stock validation and deduction only for outgoing invoices, aggregate by article before checking stock, and update legacy and active stock once per article.
- [x] 4.3 Refactor stock aggregation; rerun group 4 tests.

## 5. Storno restoration and movement ledger

- [x] 5.1 Add and run regressions for source-movement filtering and aggregation, no-movement documents, manual stock changes, non-inventory and legacy articles, transaction rollback/retry, and repeated legacy line items.
- [x] 5.2 Restore only aggregated negative movements for the source invoice, apply the explicit legacy predicate, and keep stock, movement, correction, counter, and source-state writes in the Storno transaction.
- [x] 5.3 Refactor the movement restoration path; rerun group 5 tests and the existing correction-document lifecycle tests.

## 6. Synchronize and verify

- [x] 6.1 Run focused invoice, receivable, PDF artifact, and inventory tests; flip every passing test-plan row to green and investigate any mismatch.
- [x] 6.2 Run `fvm flutter analyze`, the full VM test suite, strict OpenSpec change/spec validation, and `git diff --check`; record exact results in `verify.md`.
- [x] 6.3 Synchronize the three accepted delta specs into the main documents, accounting, and inventory specs, archive the completed change, and validate the archived result.
