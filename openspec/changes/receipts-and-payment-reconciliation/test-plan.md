## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/receipts-and-payment-reconciliation/spec.md → Receipts follow an actionable inbox lifecycle | Receipt is reviewed and linked | test/integration/audit/receipts-and-payment-reconciliation_test.dart | test_receipts_and_payment_reconciliation_1_1_receipt_is_reviewed_and_linked | 🔴 red |
| specs/receipts-and-payment-reconciliation/spec.md → Receipts follow an actionable inbox lifecycle | Unreadable receipt remains reviewable | test/integration/audit/receipts-and-payment-reconciliation_test.dart | test_receipts_and_payment_reconciliation_1_2_unreadable_receipt_remains_reviewable | 🔴 red |
| specs/receipts-and-payment-reconciliation/spec.md → Bank transactions apply payments to receivables | Partial payment is applied once | test/integration/audit/receipts-and-payment-reconciliation_test.dart | test_receipts_and_payment_reconciliation_2_1_partial_payment_is_applied_once | 🔴 red |
| specs/receipts-and-payment-reconciliation/spec.md → Bank transactions apply payments to receivables | Ambiguous match requires review | test/integration/audit/receipts-and-payment-reconciliation_test.dart | test_receipts_and_payment_reconciliation_2_2_ambiguous_match_requires_review | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
