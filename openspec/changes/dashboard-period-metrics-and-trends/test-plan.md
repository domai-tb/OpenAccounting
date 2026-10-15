## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🟢 green to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Default quick links | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_default_quick_links | 🟢 green |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Custom quick link | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_custom_quick_link | 🟢 green |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Add, edit, and reorder a quick link | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_add_edit_and_reorder_a_quick_link | 🟢 green |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Remove a quick link | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_remove_a_quick_link | 🟢 green |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Quick link with invalid route | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_quick_link_with_invalid_route | 🟢 green |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Select a reporting period | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_select_a_reporting_period | 🟢 green |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Invalid or unavailable period | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_invalid_or_unavailable_period | 🟢 green |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Historical open balance snapshot | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_historical_open_balance_snapshot | 🟢 green |
| specs/specs/dashboard/spec.md → Comparable KPI trends | Show a comparable year-over-year trend | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_show_a_comparable_year_over_year_trend | 🟢 green |
| specs/specs/dashboard/spec.md → Comparable KPI trends | Handle a zero comparison baseline | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_handle_a_zero_comparison_baseline | 🟢 green |
| specs/specs/dashboard/spec.md → Comparable KPI trends | Compare a negative prior profit | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_compare_a_negative_prior_profit | 🟢 green |
| specs/specs/dashboard/spec.md → Period trend visualizations | Render supported trend data | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_render_supported_trend_data | 🟢 green |
| specs/specs/dashboard/spec.md → Period trend visualizations | Trend data is missing or invalid | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_trend_data_is_missing_or_invalid | 🟢 green |
| specs/specs/dashboard/spec.md → Accounting-backed operational metrics | Render open invoices and receipts | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_render_open_invoices_and_receipts | 🟢 green |
| specs/specs/dashboard/spec.md → Accounting-backed operational metrics | Accounting source is incomplete | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_accounting_source_is_incomplete | 🟢 green |
| specs/specs/dashboard/spec.md → Actionable dashboard attention items | Open an attention item | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_open_an_attention_item | 🟢 green |
| specs/specs/dashboard/spec.md → Actionable dashboard attention items | Tax calendar is unavailable | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_tax_calendar_is_unavailable | 🟢 green |
| specs/specs/dashboard/spec.md → Actionable dashboard attention items | Open a configured tax deadline | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_open_a_configured_tax_deadline | 🟢 green |
| specs/specs/dashboard/spec.md → Localized dashboard interactions | Render metrics in the selected locale | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_render_metrics_in_the_selected_locale | 🟢 green |
| specs/specs/dashboard/spec.md → Localized dashboard interactions | No data for a selected period | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_no_data_for_a_selected_period | 🟢 green |
| specs/specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Legacy persisted quick link is filtered on load | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_legacy_persisted_quick_link_is_filtered_on_load | 🟢 green |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Unsupported month, quarter, or year | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_unsupported_month_quarter_or_year | 🟢 green |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Historical payable snapshot uses supplier allocations | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_historical_payable_snapshot_uses_supplier_allocations | 🟢 green |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Settlement split and reversal follow allocation dates | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_settlement_split_and_reversal_follow_allocation_dates | 🟢 green |
| specs/specs/dashboard/spec.md → Period-scoped dashboard overview | Write-off or legacy history without an effective date is unavailable | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_write_off_or_legacy_history_without_an_effective_date_is_unavailable | 🟢 green |
| specs/specs/dashboard/spec.md → Actionable dashboard attention items | Unmatched filter is applied on the banking route | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_unmatched_filter_is_applied_on_the_banking_route | 🟢 green |
| specs/specs/dashboard/spec.md → Actionable dashboard attention items | Unmatched filter with missing, malformed, or unavailable ID shows typed not-found state | test/features/dashboard/dashboard_period_metrics_and_trends_test.dart | test_invalid_transaction_id_shows_typed_not_found_state | 🟢 green |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
