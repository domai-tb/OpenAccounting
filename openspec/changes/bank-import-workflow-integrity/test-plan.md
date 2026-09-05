## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/bank-import-workflow-integrity/spec.md → Banking exposes a reviewable import lifecycle | User reviews before import | test/integration/audit/bank-import-workflow-integrity_test.dart | test_bank_import_workflow_integrity_1_1_user_reviews_before_import | 🔴 red |
| specs/bank-import-workflow-integrity/spec.md → Banking exposes a reviewable import lifecycle | Unsupported input remains safe | test/integration/audit/bank-import-workflow-integrity_test.dart | test_bank_import_workflow_integrity_1_2_unsupported_input_remains_safe | 🔴 red |
| specs/bank-import-workflow-integrity/spec.md → Import outcomes are truthful and recoverable | Successful batch counts persisted rows | test/integration/audit/bank-import-workflow-integrity_test.dart | test_bank_import_workflow_integrity_2_1_successful_batch_counts_persisted_rows | 🔴 red |
| specs/bank-import-workflow-integrity/spec.md → Import outcomes are truthful and recoverable | A row failure is surfaced | test/integration/audit/bank-import-workflow-integrity_test.dart | test_bank_import_workflow_integrity_2_2_a_row_failure_is_surfaced | 🔴 red |
| specs/bank-import-workflow-integrity/spec.md → Import outcomes are truthful and recoverable | Retry does not duplicate rows | test/integration/audit/bank-import-workflow-integrity_test.dart | test_bank_import_workflow_integrity_2_3_retry_does_not_duplicate_rows | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
