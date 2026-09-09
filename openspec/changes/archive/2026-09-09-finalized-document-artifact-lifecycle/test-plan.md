## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/finalized-document-artifact-lifecycle/spec.md → Finalized documents have real profile-local artifacts | Invoice finalization creates a readable PDF | test/integration/audit/finalized-document-artifact-lifecycle_test.dart | test_finalized_document_artifact_lifecycle_1_1_invoice_finalization_creates_a_readable_pdf | 🔴 red |
| specs/finalized-document-artifact-lifecycle/spec.md → Finalized documents have real profile-local artifacts | Artifact failure prevents a false path | test/integration/audit/finalized-document-artifact-lifecycle_test.dart | test_finalized_document_artifact_lifecycle_1_2_artifact_failure_prevents_a_false_path | 🔴 red |
| specs/finalized-document-artifact-lifecycle/spec.md → Desktop artifact actions operate on stored documents | A user can reopen and save a finalized PDF | test/integration/audit/finalized-document-artifact-lifecycle_test.dart | test_finalized_document_artifact_lifecycle_2_1_a_user_can_reopen_and_save_a_finalized_pdf | 🔴 red |
| specs/finalized-document-artifact-lifecycle/spec.md → Desktop artifact actions operate on stored documents | Missing or unsupported actions are actionable | test/integration/audit/finalized-document-artifact-lifecycle_test.dart | test_finalized_document_artifact_lifecycle_2_2_missing_or_unsupported_actions_are_actionable | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
