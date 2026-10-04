## 1. accounting: Balanced, source-linked posting groups

- [ ] 1.1 Write failing test `test_post_a_finalized_invoice` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Post a finalized invoice"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Post a finalized invoice" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_required_posting_mapping_is_missing` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Required posting mapping is missing"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "Required posting mapping is missing" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_retry_a_source_event` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Retry a source event"; assert it fails for the right reason.
- [ ] 1.8 Implement the specified behavior for "Retry a source event" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.10 Write failing test `test_reverse_a_posted_group` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Reverse a posted group"; assert it fails for the right reason.
- [ ] 1.11 Implement the specified behavior for "Reverse a posted group" to pass 1.10.
- [ ] 1.12 Refactor the affected code; keep the focused and full suites green.

## 2. accounting: Payment and invoice posting linkage

- [ ] 2.1 Write failing test `test_post_a_partial_receipt` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Post a partial receipt"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Post a partial receipt" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_do_not_post_an_unconfirmed_bank_row` in `test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Do not post an unconfirmed bank row"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Do not post an unconfirmed bank row" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.

## 3. einkommen: Cash-basis EÜR settlement timing

- [ ] 3.1 Write failing test `test_include_an_ordinary_receipt_in_its_settlement_period` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Include an ordinary receipt in its settlement period"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Include an ordinary receipt in its settlement period" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_exclude_an_unpaid_invoice` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Exclude an unpaid invoice"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Exclude an unpaid invoice" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.7 Write failing test `test_split_a_settlement_across_reporting_periods` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Split a settlement across reporting periods"; assert it fails for the right reason.
- [ ] 3.8 Implement the specified behavior for "Split a settlement across reporting periods" to pass 3.7.
- [ ] 3.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.10 Write failing test `test_keep_input_tax_claim_timing_independent` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Keep input-tax claim timing independent"; assert it fails for the right reason.
- [ ] 3.11 Implement the specified behavior for "Keep input-tax claim timing independent" to pass 3.10.
- [ ] 3.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.13 Write failing test `test_apply_an_approved_statutory_timing_exception` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Apply an approved statutory timing exception"; assert it fails for the right reason.
- [ ] 3.14 Implement the specified behavior for "Apply an approved statutory timing exception" to pass 3.13.
- [ ] 3.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.16 Write failing test `test_do_not_infer_an_exception` in `test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Do not infer an exception"; assert it fails for the right reason.
- [ ] 3.17 Implement the specified behavior for "Do not infer an exception" to pass 3.16.
- [ ] 3.18 Refactor the affected code; keep the focused and full suites green.

## 4. receipts-and-payment-reconciliation: Confirmed payment application posts settlement atomically

- [ ] 4.1 Write failing test `test_confirm_a_matched_receipt` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Confirm a matched receipt"; assert it fails for the right reason.
- [ ] 4.2 Implement the specified behavior for "Confirm a matched receipt" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_leave_an_ambiguous_suggestion_unapplied` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Leave an ambiguous suggestion unapplied"; assert it fails for the right reason.
- [ ] 4.5 Implement the specified behavior for "Leave an ambiguous suggestion unapplied" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.7 Write failing test `test_roll_back_a_failed_settlement` in `test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart` for scenario "Roll back a failed settlement"; assert it fails for the right reason.
- [ ] 4.8 Implement the specified behavior for "Roll back a failed settlement" to pass 4.7.
- [ ] 4.9 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
