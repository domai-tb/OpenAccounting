## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/dashboard-metrics-and-actions/spec.md → Dashboard metrics use explicit financial scopes | Draft and out-of-period rows are excluded | test/integration/audit/dashboard-metrics-and-actions_test.dart | test_dashboard_metrics_and_actions_1_1_draft_and_out_of_period_rows_are_excluded | 🔴 red |
| specs/dashboard-metrics-and-actions/spec.md → Dashboard metrics use explicit financial scopes | Income and expense direction is correct | test/integration/audit/dashboard-metrics-and-actions_test.dart | test_dashboard_metrics_and_actions_1_2_income_and_expense_direction_is_correct | 🔴 red |
| specs/dashboard-metrics-and-actions/spec.md → Dashboard metrics use explicit financial scopes | Filing deadline follows configuration | test/integration/audit/dashboard-metrics-and-actions_test.dart | test_dashboard_metrics_and_actions_1_3_filing_deadline_follows_configuration | 🔴 red |
| specs/dashboard-metrics-and-actions/spec.md → Dashboard actions open the corresponding workflow | Quick links reach their intended action | test/integration/audit/dashboard-metrics-and-actions_test.dart | test_dashboard_metrics_and_actions_2_1_quick_links_reach_their_intended_action | 🔴 red |
| specs/dashboard-metrics-and-actions/spec.md → Dashboard actions open the corresponding workflow | Missing target remains safe | test/integration/audit/dashboard-metrics-and-actions_test.dart | test_dashboard_metrics_and_actions_2_2_missing_target_remains_safe | 🔴 red |
| specs/dashboard-metrics-and-actions/spec.md → Dashboard configuration reports persistence outcomes | Successful customization persists | test/integration/audit/dashboard-metrics-and-actions_test.dart | test_dashboard_metrics_and_actions_3_1_successful_customization_persists | 🔴 red |
| specs/dashboard-metrics-and-actions/spec.md → Dashboard configuration reports persistence outcomes | Failed customization rolls back | test/integration/audit/dashboard-metrics-and-actions_test.dart | test_dashboard_metrics_and_actions_3_2_failed_customization_rolls_back | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
