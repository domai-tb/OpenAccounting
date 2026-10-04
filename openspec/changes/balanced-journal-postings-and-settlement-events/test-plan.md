## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/accounting/spec.md → Balanced, source-linked posting groups | Post a finalized invoice | test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart | test_post_a_finalized_invoice | 🔴 red |
| specs/specs/accounting/spec.md → Balanced, source-linked posting groups | Required posting mapping is missing | test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart | test_required_posting_mapping_is_missing | 🔴 red |
| specs/specs/accounting/spec.md → Balanced, source-linked posting groups | Retry a source event | test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart | test_retry_a_source_event | 🔴 red |
| specs/specs/accounting/spec.md → Balanced, source-linked posting groups | Reverse a posted group | test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart | test_reverse_a_posted_group | 🔴 red |
| specs/specs/accounting/spec.md → Payment and invoice posting linkage | Post a partial receipt | test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart | test_post_a_partial_receipt | 🔴 red |
| specs/specs/accounting/spec.md → Payment and invoice posting linkage | Do not post an unconfirmed bank row | test/features/accounting/balanced_journal_postings_and_settlement_events_test.dart | test_do_not_post_an_unconfirmed_bank_row | 🔴 red |
| specs/specs/einkommen/spec.md → Cash-basis EÜR settlement timing | Include an ordinary receipt in its settlement period | test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart | test_include_an_ordinary_receipt_in_its_settlement_period | 🔴 red |
| specs/specs/einkommen/spec.md → Cash-basis EÜR settlement timing | Exclude an unpaid invoice | test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart | test_exclude_an_unpaid_invoice | 🔴 red |
| specs/specs/einkommen/spec.md → Cash-basis EÜR settlement timing | Split a settlement across reporting periods | test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart | test_split_a_settlement_across_reporting_periods | 🔴 red |
| specs/specs/einkommen/spec.md → Cash-basis EÜR settlement timing | Keep input-tax claim timing independent | test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart | test_keep_input_tax_claim_timing_independent | 🔴 red |
| specs/specs/einkommen/spec.md → Cash-basis EÜR settlement timing | Apply an approved statutory timing exception | test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart | test_apply_an_approved_statutory_timing_exception | 🔴 red |
| specs/specs/einkommen/spec.md → Cash-basis EÜR settlement timing | Do not infer an exception | test/features/einkommen/balanced_journal_postings_and_settlement_events_test.dart | test_do_not_infer_an_exception | 🔴 red |
| specs/specs/receipts-and-payment-reconciliation/spec.md → Confirmed payment application posts settlement atomically | Confirm a matched receipt | test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart | test_confirm_a_matched_receipt | 🔴 red |
| specs/specs/receipts-and-payment-reconciliation/spec.md → Confirmed payment application posts settlement atomically | Leave an ambiguous suggestion unapplied | test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart | test_leave_an_ambiguous_suggestion_unapplied | 🔴 red |
| specs/specs/receipts-and-payment-reconciliation/spec.md → Confirmed payment application posts settlement atomically | Roll back a failed settlement | test/features/receipts_and_payment_reconciliation/balanced_journal_postings_and_settlement_events_test.dart | test_roll_back_a_failed_settlement | 🔴 red |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
