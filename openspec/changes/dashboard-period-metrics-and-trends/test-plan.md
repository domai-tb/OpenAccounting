## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Default quick links | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_default_quick_links | 🔴 red |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Custom quick link | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_custom_quick_link | 🔴 red |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Add, edit, and reorder a quick link | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_add_edit_and_reorder_a_quick_link | 🔴 red |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Remove a quick link | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_remove_a_quick_link | 🔴 red |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Quick link with invalid route | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_quick_link_with_invalid_route | 🔴 red |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Select a reporting period | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_select_a_reporting_period | 🔴 red |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Invalid or unavailable period | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_invalid_or_unavailable_period | 🔴 red |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Historical open balance snapshot | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_historical_open_balance_snapshot | 🔴 red |
| specs/specs/dashboard/spec.md → Comparable KPI trends | Show a comparable year-over-year trend | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_show_a_comparable_year_over_year_trend | 🔴 red |
| specs/specs/dashboard/spec.md → Comparable KPI trends | Handle a zero comparison baseline | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_handle_a_zero_comparison_baseline | 🔴 red |
| specs/specs/dashboard/spec.md → Comparable KPI trends | Compare a negative prior profit | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_compare_a_negative_prior_profit | 🔴 red |
| specs/specs/dashboard/spec.md → Period trend visualizations | Render supported trend data | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_render_supported_trend_data | 🔴 red |
| specs/specs/dashboard/spec.md → Period trend visualizations | Trend data is missing or invalid | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_trend_data_is_missing_or_invalid | 🔴 red |
| specs/specs/dashboard/spec.md → Accounting-backed operational metrics | Render open invoices and receipts | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_render_open_invoices_and_receipts | 🔴 red |
| specs/specs/dashboard/spec.md → Accounting-backed operational metrics | Accounting source is incomplete | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_accounting_source_is_incomplete | 🔴 red |
| specs/specs/dashboard/spec.md → Actionable dashboard attention items | Open an attention item | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_open_an_attention_item | 🔴 red |
| specs/specs/dashboard/spec.md → Actionable dashboard attention items | Tax calendar is unavailable | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_tax_calendar_is_unavailable | 🔴 red |
| specs/specs/dashboard/spec.md → Actionable dashboard attention items | Open a configured tax deadline | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_open_a_configured_tax_deadline | 🔴 red |
| specs/specs/dashboard/spec.md → Localized dashboard interactions | Render metrics in the selected locale | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_render_metrics_in_the_selected_locale | 🔴 red |
| specs/specs/dashboard/spec.md → Localized dashboard interactions | No data for a selected period | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_no_data_for_a_selected_period | 🔴 red |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
