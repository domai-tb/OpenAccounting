## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Every canonical route has a useful surface | test/features/routed_surface/typed_route_test.dart | test_every_canonical_route_has_useful_surface | 🟢 green |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Database outage is not an empty route | test/features/routed_surface/typed_route_test.dart | test_database_outage_is_not_empty_route | 🟢 green |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Alias matrix preserves deep links | test/features/routed_surface/typed_route_test.dart | test_alias_matrix_preserves_deep_links | 🟢 green |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Route matrix exposes a truthful boundary | test/features/routed_surface/typed_route_test.dart | test_route_matrix_exposes_truthful_boundary | 🟢 green |
| specs/typed-route-workspaces/spec.md → Typed domain data and actions | Invoice detail exposes lifecycle actions | test/features/routed_surface/typed_route_test.dart | test_invoice_detail_exposes_lifecycle_actions | 🟢 green |
| specs/typed-route-workspaces/spec.md → Typed domain data and actions | Invalid record is safely reported | test/features/routed_surface/typed_route_test.dart | test_invalid_record_is_safely_reported | 🟢 green |
| specs/typed-route-workspaces/spec.md → Scalable domain lists | Contact search paginates | test/features/routed_surface/typed_route_test.dart | test_contact_search_paginates | 🟢 green |
| specs/typed-route-workspaces/spec.md → Scalable domain lists | List query failure is retryable | test/features/routed_surface/typed_route_test.dart | test_list_query_failure_is_retryable | 🟢 green |
| specs/dashboard-and-setup-workflows/spec.md → Dashboard cards lead to real capabilities | Open invoices card opens receivables | test/features/routed_surface/dashboard_setup_test.dart | test_open_invoices_card_opens_receivables | 🟢 green |
| specs/dashboard-and-setup-workflows/spec.md → Dashboard cards lead to real capabilities | Unavailable inventory card is truthful | test/features/routed_surface/dashboard_setup_test.dart | test_unavailable_inventory_card_is_truthful | 🟢 green |
| specs/dashboard-and-setup-workflows/spec.md → Dashboard cards lead to real capabilities | Dashboard configuration failure is recoverable | test/features/routed_surface/dashboard_setup_test.dart | test_dashboard_configuration_failure_is_recoverable | 🟢 green |
| specs/dashboard-and-setup-workflows/spec.md → Setup exposes persisted configuration | Setup summary shows real names | test/features/routed_surface/dashboard_setup_test.dart | test_setup_summary_shows_real_names | 🟢 green |
| specs/dashboard-and-setup-workflows/spec.md → Setup exposes persisted configuration | Setup write failure is recoverable | test/features/routed_surface/dashboard_setup_test.dart | test_setup_write_failure_is_recoverable | 🟢 green |
| specs/dashboard-and-setup-workflows/spec.md → Setup exposes persisted configuration | Successful profile switch rebinds services | test/features/routed_surface/dashboard_setup_test.dart | test_successful_profile_switch_rebinds_services | 🟢 green |
| specs/bank-import-recovery-surface/spec.md → Bank import retry and outcome fidelity | Manual review count is shown | test/features/routed_surface/bank_import_test.dart | test_manual_review_count_is_shown | 🟢 green |
| specs/bank-import-recovery-surface/spec.md → Bank import retry and outcome fidelity | Initial data retry reloads | test/features/routed_surface/bank_import_test.dart | test_initial_data_retry_reloads | 🟢 green |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | History row opens details | test/features/routed_surface/bank_import_test.dart | test_history_row_opens_details | 🟢 green |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Empty history offers import | test/features/routed_surface/bank_import_test.dart | test_empty_history_offers_import | 🟢 green |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Status policy controls actions | test/features/routed_surface/bank_import_test.dart | test_status_policy_controls_actions | 🟢 green |

## Coverage Notes

Fake services under `test/features/routed_surface/` per design. Router tests inject `AppServices` fakes and verify alias redirects preserve query/params. Inventory test proves dashboard provider checks capability registration before query. `fvm flutter analyze` and `fvm flutter test --dart-define=platform=vm` gate.
