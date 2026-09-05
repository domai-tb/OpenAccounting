## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/analyzer-and-integration-test-gates/spec.md → Pinned analysis is clean | Analyzer gate passes | test/integration/audit/analyzer-and-integration-test-gates_test.dart | test_analyzer_and_integration_test_gates_1_1_analyzer_gate_passes | 🟢 green |
| specs/analyzer-and-integration-test-gates/spec.md → Pinned analysis is clean | New diagnostics block acceptance | test/integration/audit/analyzer-and-integration-test-gates_test.dart | test_analyzer_and_integration_test_gates_1_2_new_diagnostics_block_acceptance | 🟢 green |
| specs/analyzer-and-integration-test-gates/spec.md → Integration tests exercise production composition | Route smoke tests prove reachability | test/integration/audit/analyzer-and-integration-test-gates_test.dart | test_analyzer_and_integration_test_gates_2_1_route_smoke_tests_prove_reachability | 🟢 green |
| specs/analyzer-and-integration-test-gates/spec.md → Integration tests exercise production composition | Runtime provider errors fail tests | test/integration/audit/analyzer-and-integration-test-gates_test.dart | test_analyzer_and_integration_test_gates_2_2_runtime_provider_errors_fail_tests | 🟢 green |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
