## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/accounting/spec.md → Anlagenverzeichnis | Asset registration | test/features/accounting/fixed_asset_register_workspace_test.dart | test_asset_registration | 🔴 red |
| specs/specs/accounting/spec.md → Anlagenverzeichnis | KFZ with private share | test/features/accounting/fixed_asset_register_workspace_test.dart | test_kfz_with_private_share | 🔴 red |
| specs/specs/accounting/spec.md → Anlagenverzeichnis | Non-KFZ private-use amount remains unavailable | test/features/accounting/fixed_asset_register_workspace_test.dart | test_non_kfz_private_use_amount_remains_unavailable | 🔴 red |
| specs/specs/accounting/spec.md → Anlagenverzeichnis | Asset disposal | test/features/accounting/fixed_asset_register_workspace_test.dart | test_asset_disposal | 🔴 red |
| specs/specs/accounting/spec.md → Anlagenverzeichnis | AVEÜR integration | test/features/accounting/fixed_asset_register_workspace_test.dart | test_aveuer_integration | 🔴 red |
| specs/specs/accounting/spec.md → Anlagenverzeichnis | Unresolved AfA or disposal inputs | test/features/accounting/fixed_asset_register_workspace_test.dart | test_unresolved_afa_or_disposal_inputs | 🔴 red |
| specs/specs/db/spec.md → Asset schedule schema preserves legacy records and history | Existing asset data survives migration | test/core/db/fixed_asset_register_workspace_migration_test.dart | test_existing_asset_data_survives_migration | 🔴 red |
| specs/specs/db/spec.md → Asset schedule schema preserves legacy records and history | Schedule history remains immutable | test/core/db/fixed_asset_register_workspace_migration_test.dart | test_schedule_history_remains_immutable | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Reachable fixed-asset register | Create and update an asset record | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_create_and_update_an_asset_record | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Reachable fixed-asset register | Reject invalid new asset inputs | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_reject_invalid_new_asset_inputs | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Reachable fixed-asset register | Preserve assets with schedule history | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_preserve_assets_with_schedule_history | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Reachable fixed-asset register | Do not reinterpret legacy asset fields | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_do_not_reinterpret_legacy_asset_fields | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Traceable annual depreciation schedule | Show a supported full-year linear amount | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_show_a_supported_full_year_linear_amount | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Traceable annual depreciation schedule | Non-KFZ private-use rule is unresolved | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_non_kfz_private_use_rule_is_unresolved | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Traceable annual depreciation schedule | Fail closed on partial-year or disposal calculations | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_fail_closed_on_partial_year_or_disposal_calculations | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Traceable annual depreciation schedule | Fail closed on ambiguous source values | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_fail_closed_on_ambiguous_source_values | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Asset changes have no journal side effect | Save an asset without posting | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_save_an_asset_without_posting | 🔴 red |
| specs/specs/fixed-asset-register-workspace/spec.md → Asset changes have no journal side effect | Block an unsupported financial effect | test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart | test_block_an_unsupported_financial_effect | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Every canonical route has a useful surface | test/core/router/fixed_asset_register_workspace_routes_test.dart | test_every_canonical_route_has_a_useful_surface | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Database outage is not an empty route | test/core/router/fixed_asset_register_workspace_routes_test.dart | test_database_outage_is_not_an_empty_route | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Alias matrix preserves deep links | test/core/router/fixed_asset_register_workspace_routes_test.dart | test_alias_matrix_preserves_deep_links | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Route matrix exposes a truthful boundary | test/core/router/fixed_asset_register_workspace_routes_test.dart | test_route_matrix_exposes_a_truthful_boundary | 🔴 red |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
