## 1. accounting: Balanced, source-linked posting groups

- [x] 1.1 Write failing test `test_post_a_finalized_invoice` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Post a finalized invoice"; assert it fails for the right reason.
- [x] 1.2 Implement the specified behavior for "Post a finalized invoice" to pass 1.1.
- [x] 1.3 Refactor the affected code; keep the focused and full suites green.
- [x] 1.4 Write failing test `test_required_posting_mapping_is_missing` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Required posting mapping is missing"; assert it fails for the right reason.
- [x] 1.5 Implement the specified behavior for "Required posting mapping is missing" to pass 1.4.
- [x] 1.6 Refactor the affected code; keep the focused and full suites green.
- [x] 1.7 Write failing test `test_retry_a_source_event` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Retry a source event"; assert it fails for the right reason.
- [x] 1.8 Implement the specified behavior for "Retry a source event" to pass 1.7.
- [x] 1.9 Refactor the affected code; keep the focused and full suites green.
- [x] 1.10 Write failing test `test_reverse_a_posted_group` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Reverse a posted group"; assert it fails for the right reason, including VAT-claim linkage and duplicate-reversal rejection (see §5 reversal lifecycle).
- [x] 1.11 Implement the specified behavior for "Reverse a posted group" to pass 1.10, including VAT-claim linkage and duplicate-reversal rejection.
- [x] 1.12 Refactor the affected code; keep the focused and full suites green.

## 2. accounting: Payment and invoice posting linkage

- [x] 2.1 Write failing test `test_post_a_partial_receipt` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Post a partial receipt"; assert it fails for the right reason (see also 6.10-6.12 repeated-confirmation idempotency).
- [x] 2.2 Implement the specified behavior for "Post a partial receipt" to pass 2.1 (see also 6.10-6.12).
- [x] 2.3 Refactor the affected code; keep the focused and full suites green (see also 6.10-6.12).
- [x] 2.4 Write failing test `test_do_not_post_an_unconfirmed_bank_row` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Do not post an unconfirmed bank row"; assert it fails for the right reason.
- [x] 2.5 Implement the specified behavior for "Do not post an unconfirmed bank row" to pass 2.4.
- [x] 2.6 Refactor the affected code; keep the focused and full suites green.

## 3. einkommen: Cash-basis EÜR settlement timing

- [x] 3.1 Write failing test `test_include_an_ordinary_receipt_in_its_settlement_period` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Include an ordinary receipt in its settlement period"; assert it fails for the right reason. Assert the authoritative settlement date (bank booking/value date; manual payment date for cash) — confirmation date excluded.
- [x] 3.2 Implement the specified behavior for "Include an ordinary receipt in its settlement period" to pass 3.1.
- [x] 3.3 Refactor the affected code; keep the focused and full suites green.
- [x] 3.4 Write failing test `test_exclude_an_unpaid_invoice` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Exclude an unpaid invoice"; assert it fails for the right reason.
- [x] 3.5 Implement the specified behavior for "Exclude an unpaid invoice" to pass 3.4.
- [x] 3.6 Refactor the affected code; keep the focused and full suites green.
- [x] 3.7 Write failing test `test_split_a_settlement_across_reporting_periods` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Split a settlement across reporting periods"; assert it fails for the right reason. Assert the authoritative settlement date (bank booking/value date; manual payment date for cash) — confirmation date excluded.
- [x] 3.8 Implement the specified behavior for "Split a settlement across reporting periods" to pass 3.7.
- [x] 3.9 Refactor the affected code; keep the focused and full suites green.
- [x] 3.10 Write failing test `test_keep_input_tax_claim_timing_independent` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Keep input-tax claim timing independent"; assert it fails for the right reason.
- [x] 3.11 Implement the specified behavior for "Keep input-tax claim timing independent" to pass 3.10.
- [x] 3.12 Refactor the affected code; keep the focused and full suites green.
- [x] 3.13 Write failing test `test_apply_an_approved_statutory_timing_exception` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Apply an approved statutory timing exception"; assert it fails for the right reason.
- [x] 3.14 Implement the specified behavior for "Apply an approved statutory timing exception" to pass 3.13.
- [x] 3.15 Refactor the affected code; keep the focused and full suites green.
- [x] 3.16 Write failing test `test_do_not_infer_an_exception` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Do not infer an exception"; assert it fails for the right reason.
- [x] 3.17 Implement the specified behavior for "Do not infer an exception" to pass 3.16.
- [x] 3.18 Refactor the affected code; keep the focused and full suites green.

## 4. receipts-and-payment-reconciliation: Confirmed payment application posts settlement atomically

- [x] 4.1 Write failing test `test_confirm_a_matched_receipt` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Confirm a matched receipt"; assert it fails for the right reason. Assert sign direction (positive bank row → customer receivable, negative → supplier payable), status transitions (`offen` → `teilbezahlt` → `bezahlt`), and applied-plus-unapplied reconciliation to the signed bank amount.
- [x] 4.2 Implement the specified behavior for "Confirm a matched receipt" to pass 4.1. Cover sign direction, status transitions, and amount reconciliation.
- [x] 4.3 Refactor the affected code; keep the focused and full suites green.
- [x] 4.4 Write failing test `test_leave_an_ambiguous_suggestion_unapplied` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Leave an ambiguous suggestion unapplied"; assert it fails for the right reason.
- [x] 4.5 Implement the specified behavior for "Leave an ambiguous suggestion unapplied" to pass 4.4.
- [x] 4.6 Refactor the affected code; keep the focused and full suites green.
- [x] 4.7 Write failing test `test_roll_back_a_failed_settlement` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Roll back a failed settlement"; assert it fails for the right reason.
- [x] 4.8 Implement the specified behavior for "Roll back a failed settlement" to pass 4.7.
- [x] 4.9 Refactor the affected code; keep the focused and full suites green.

## 5. accounting: Reversal lifecycle (Balanced, source-linked posting groups)

- [x] 5.1 Write failing test `test_reverse_a_settlement_restores_the_open_item` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Reverse a settlement restores the open item"; assert it fails for the right reason.
- [x] 5.2 Implement the specified behavior for "Reverse a settlement restores the open item" to pass 5.1.
- [x] 5.3 Refactor the affected code; keep the focused and full suites green.
- [x] 5.4 Write failing test `test_reject_invoice_reversal_with_applied_settlements` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Reject invoice reversal with applied settlements"; assert it fails for the right reason.
- [x] 5.5 Implement the specified behavior for "Reject invoice reversal with applied settlements" to pass 5.4.
- [x] 5.6 Refactor the affected code; keep the focused and full suites green.

## 6. accounting: Supplier, split, overpayment, repeat (Payment and invoice posting linkage)

- [x] 6.1 Write failing test `test_post_a_supplier_payment` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Post a supplier payment"; assert it fails for the right reason.
- [x] 6.2 Implement the specified behavior for "Post a supplier payment" to pass 6.1.
- [x] 6.3 Refactor the affected code; keep the focused and full suites green.
- [x] 6.4 Write failing test `test_split_one_transaction_across_invoices` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Split one transaction across invoices"; assert it fails for the right reason.
- [x] 6.5 Implement the specified behavior for "Split one transaction across invoices" to pass 6.4.
- [x] 6.6 Refactor the affected code; keep the focused and full suites green.
- [x] 6.7 Write failing test `test_retain_an_overpayment_as_credit` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Retain an overpayment as credit"; assert it fails for the right reason.
- [x] 6.8 Implement the specified behavior for "Retain an overpayment as credit" to pass 6.7.
- [x] 6.9 Refactor the affected code; keep the focused and full suites green.
- [x] 6.10 Write failing test `test_repeated_confirmation_does_not_re_apply` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Repeated confirmation does not re-apply"; assert it fails for the right reason.
- [x] 6.11 Implement the specified behavior for "Repeated confirmation does not re-apply" to pass 6.10.
- [x] 6.12 Refactor the affected code; keep the focused and full suites green.

## 7. accounting: Posting writers (Journal Entries)

- [x] 7.1 Write failing test `test_in_scope_invoice_does_not_use_the_single_row_path` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "In-scope invoice does not use the single-row path"; assert it fails for the right reason.
- [x] 7.2 Implement the specified behavior for "In-scope invoice does not use the single-row path" to pass 7.1.
- [x] 7.3 Refactor the affected code; keep the focused and full suites green.
- [x] 7.4 Write failing test `test_out_of_scope_writer_keeps_its_maintained_behavior` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Out-of-scope writer keeps its maintained behavior"; assert it fails for the right reason.
- [x] 7.5 Implement the specified behavior for "Out-of-scope writer keeps its maintained behavior" to pass 7.4.
- [x] 7.6 Refactor the affected code; keep the focused and full suites green.

## 8. accounting: EÜR settlement reads (EÜR (Einnahmen-Überschuss-Rechnung))

- [x] 8.1 Write failing test `test_eur_reads_settlements_not_invoice_dates` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "EÜR reads settlements, not invoice dates"; assert it fails for the right reason.
- [x] 8.2 Implement the specified behavior for "EÜR reads settlements, not invoice dates" to pass 8.1.
- [x] 8.3 Refactor the affected code; keep the focused and full suites green.
- [x] 8.4 Write failing test `test_eur_rejects_mixed_legacy_and_settlement_data` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "EÜR rejects mixed legacy and settlement data"; assert it fails for the right reason.
- [x] 8.5 Implement the specified behavior for "EÜR rejects mixed legacy and settlement data" to pass 8.4.
- [x] 8.6 Refactor the affected code; keep the focused and full suites green.

## 9. einkommen: Settlement timing extensions (Cash-basis EÜR settlement timing)

- [x] 9.1 Write failing test `test_allocate_a_mixed_category_partial_settlement` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Allocate a mixed-category partial settlement"; assert it fails for the right reason.
- [x] 9.2 Implement the specified behavior for "Allocate a mixed-category partial settlement" to pass 9.1.
- [x] 9.3 Refactor the affected code; keep the focused and full suites green.
- [x] 9.4 Write failing test `test_recognize_a_direct_cash_receipt_without_an_invoice` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Recognize a direct cash receipt without an invoice"; assert it fails for the right reason.
- [x] 9.5 Implement the specified behavior for "Recognize a direct cash receipt without an invoice" to pass 9.4.
- [x] 9.6 Refactor the affected code; keep the focused and full suites green.
- [x] 9.7 Write failing test `test_exclude_a_write_off_from_operating_receipts` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Exclude a write-off from operating receipts"; assert it fails for the right reason.
- [x] 9.8 Implement the specified behavior for "Exclude a write-off from operating receipts" to pass 9.7.
- [x] 9.9 Refactor the affected code; keep the focused and full suites green.
- [x] 9.10 Write failing test `test_classify_an_overpayment_credit_separately` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Classify an overpayment credit separately"; assert it fails for the right reason.
- [x] 9.11 Implement the specified behavior for "Classify an overpayment credit separately" to pass 9.10.
- [x] 9.12 Refactor the affected code; keep the focused and full suites green.
- [x] 9.13 Write failing test `test_reclassify_a_reversed_settlement_in_the_reversal_period` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Reclassify a reversed settlement in the reversal period"; assert it fails for the right reason.
- [x] 9.14 Implement the specified behavior for "Reclassify a reversed settlement in the reversal period" to pass 9.13.
- [x] 9.15 Refactor the affected code; keep the focused and full suites green.
- [x] 9.16 Write failing test `test_exclude_legacy_unverified_rows_from_settlement_totals` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Exclude legacy unverified rows from settlement totals"; assert it fails for the right reason.
- [x] 9.17 Implement the specified behavior for "Exclude legacy unverified rows from settlement totals" to pass 9.16.
- [x] 9.18 Refactor the affected code; keep the focused and full suites green.

## 10. receipts-and-payment-reconciliation: Settlement confirmation extensions (Confirmed payment application posts settlement atomically)

- [x] 10.1 Write failing test `test_confirm_a_supplier_payment` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Confirm a supplier payment"; assert it fails for the right reason.
- [x] 10.2 Implement the specified behavior for "Confirm a supplier payment" to pass 10.1.
- [x] 10.3 Refactor the affected code; keep the focused and full suites green.
- [x] 10.4 Write failing test `test_split_one_transaction_across_invoices` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Split one transaction across invoices"; assert it fails for the right reason.
- [x] 10.5 Implement the specified behavior for "Split one transaction across invoices" to pass 10.4.
- [x] 10.6 Refactor the affected code; keep the focused and full suites green.
- [x] 10.7 Write failing test `test_retain_a_confirmed_overpayment_as_credit` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Retain a confirmed overpayment as credit"; assert it fails for the right reason.
- [x] 10.8 Implement the specified behavior for "Retain a confirmed overpayment as credit" to pass 10.7.
- [x] 10.9 Refactor the affected code; keep the focused and full suites green.
- [x] 10.10 Write failing test `test_repeated_confirmation_does_not_duplicate` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Repeated confirmation does not duplicate"; assert it fails for the right reason.
- [x] 10.11 Implement the specified behavior for "Repeated confirmation does not duplicate" to pass 10.10.
- [x] 10.12 Refactor the affected code; keep the focused and full suites green.
- [x] 10.13 Write failing test `test_full_payment_clears_the_dunning_trigger` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Full payment clears the dunning trigger"; assert it fails for the right reason.
- [x] 10.14 Implement the specified behavior for "Full payment clears the dunning trigger" to pass 10.13.
- [x] 10.15 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
- Reversals are atomic: the reversal group, allocation restore, and EÜR reclassification commit in one transaction; an invoice-group reversal with applied settlements is rejected until its settlements are reversed (§5).
- §11 EStG timing exceptions apply only via an explicit versioned rule result (rule id/version, legal basis, affected year, approver, source trace); never infer an exception from free text.
- Legacy-mixed periods fail closed: `legacy_unverified` rows are excluded from settlement-based totals and EÜR generation fails closed when mixed with settlement data in an in-scope period.
