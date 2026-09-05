## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/runtime-composition-and-database-lifecycle/spec.md → One opened application graph owns feature lifecycles | Normal startup shares one ready database | test/integration/audit/runtime-composition-and-database-lifecycle_test.dart | test_runtime_composition_and_database_lifecycle_1_1_normal_startup_shares_one_ready_database | 🔴 red |
| specs/runtime-composition-and-database-lifecycle/spec.md → One opened application graph owns feature lifecycles | Dependency resolution cannot use an unopened default | test/integration/audit/runtime-composition-and-database-lifecycle_test.dart | test_runtime_composition_and_database_lifecycle_1_2_dependency_resolution_cannot_use_an_unopened_default | 🔴 red |
| specs/runtime-composition-and-database-lifecycle/spec.md → Feature UI respects the clean dependency direction | A page calls its use case | test/integration/audit/runtime-composition-and-database-lifecycle_test.dart | test_runtime_composition_and_database_lifecycle_2_1_a_page_calls_its_use_case | 🔴 red |
| specs/runtime-composition-and-database-lifecycle/spec.md → Feature UI respects the clean dependency direction | A missing service is diagnosed at composition time | test/integration/audit/runtime-composition-and-database-lifecycle_test.dart | test_runtime_composition_and_database_lifecycle_2_2_a_missing_service_is_diagnosed_at_composition_time | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
