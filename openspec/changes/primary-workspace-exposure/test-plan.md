## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/primary-workspace-exposure/spec.md → Primary destinations render data-backed workflows | A populated invoice and contact workspace is usable | test/integration/audit/primary-workspace-exposure_test.dart | test_primary_workspace_exposure_1_1_a_populated_invoice_and_contact_workspace_is_usable | 🔴 red |
| specs/primary-workspace-exposure/spec.md → Primary destinations render data-backed workflows | An empty or failed workspace is explicit | test/integration/audit/primary-workspace-exposure_test.dart | test_primary_workspace_exposure_1_2_an_empty_or_failed_workspace_is_explicit | 🔴 red |
| specs/primary-workspace-exposure/spec.md → Route contracts support creation, detail, and query state | Creation and detail paths select the correct mode | test/integration/audit/primary-workspace-exposure_test.dart | test_primary_workspace_exposure_2_1_creation_and_detail_paths_select_the_correct_mode | 🔴 red |
| specs/primary-workspace-exposure/spec.md → Route contracts support creation, detail, and query state | Invalid detail and filters are handled | test/integration/audit/primary-workspace-exposure_test.dart | test_primary_workspace_exposure_2_2_invalid_detail_and_filters_are_handled | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
