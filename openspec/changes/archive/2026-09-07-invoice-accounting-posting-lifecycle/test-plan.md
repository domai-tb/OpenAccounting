## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/invoice-accounting-posting-lifecycle/spec.md → Finalization creates the complete accounting posting set | Outgoing invoice creates a receivable | test/integration/audit/invoice-accounting-posting-lifecycle_test.dart | test_invoice_accounting_posting_lifecycle_1_1_outgoing_invoice_creates_a_receivable | 🟢 green |
| specs/invoice-accounting-posting-lifecycle/spec.md → Finalization creates the complete accounting posting set | Incoming invoice creates input-tax state | test/integration/audit/invoice-accounting-posting-lifecycle_test.dart | test_invoice_accounting_posting_lifecycle_1_2_incoming_invoice_creates_input_tax_state | 🟢 green |
| specs/invoice-accounting-posting-lifecycle/spec.md → Finalization creates the complete accounting posting set | Failure leaves no partial posting | test/integration/audit/invoice-accounting-posting-lifecycle_test.dart | test_invoice_accounting_posting_lifecycle_1_3_failure_leaves_no_partial_posting | 🟢 green |
| specs/invoice-accounting-posting-lifecycle/spec.md → Finalization is idempotent and audit-linked | Retry does not duplicate accounting | test/integration/audit/invoice-accounting-posting-lifecycle_test.dart | test_invoice_accounting_posting_lifecycle_2_1_retry_does_not_duplicate_accounting | 🟢 green |
| specs/invoice-accounting-posting-lifecycle/spec.md → Finalization is idempotent and audit-linked | Correction can find its source | test/integration/audit/invoice-accounting-posting-lifecycle_test.dart | test_invoice_accounting_posting_lifecycle_2_2_correction_can_find_its_source | 🟢 green |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests.
