## 1. accounting: Anlagenverzeichnis

- [ ] 1.1 Write failing test `test_asset_registration` in `test/features/accounting/fixed_asset_register_workspace_test.dart` for scenario "Asset registration"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Asset registration" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_kfz_with_private_share` in `test/features/accounting/fixed_asset_register_workspace_test.dart` for scenario "KFZ with private share"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "KFZ with private share" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_non_kfz_private_use_amount_remains_unavailable` in `test/features/accounting/fixed_asset_register_workspace_test.dart` for scenario "Non-KFZ private-use amount remains unavailable"; assert it fails for the right reason.
- [ ] 1.8 Implement the specified behavior for "Non-KFZ private-use amount remains unavailable" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.10 Write failing test `test_asset_disposal` in `test/features/accounting/fixed_asset_register_workspace_test.dart` for scenario "Asset disposal"; assert it fails for the right reason.
- [ ] 1.11 Implement the specified behavior for "Asset disposal" to pass 1.10.
- [ ] 1.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.13 Write failing test `test_aveuer_integration` in `test/features/accounting/fixed_asset_register_workspace_test.dart` for scenario "AVEÜR integration"; assert it fails for the right reason.
- [ ] 1.14 Implement the specified behavior for "AVEÜR integration" to pass 1.13.
- [ ] 1.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.16 Write failing test `test_unresolved_afa_or_disposal_inputs` in `test/features/accounting/fixed_asset_register_workspace_test.dart` for scenario "Unresolved AfA or disposal inputs"; assert it fails for the right reason.
- [ ] 1.17 Implement the specified behavior for "Unresolved AfA or disposal inputs" to pass 1.16.
- [ ] 1.18 Refactor the affected code; keep the focused and full suites green.

## 2. db: Asset schedule schema preserves legacy records and history

- [ ] 2.1 Write failing test `test_existing_asset_data_survives_migration` in `test/core/db/fixed_asset_register_workspace_migration_test.dart` for scenario "Existing asset data survives migration"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Existing asset data survives migration" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_schedule_history_remains_immutable` in `test/core/db/fixed_asset_register_workspace_migration_test.dart` for scenario "Schedule history remains immutable"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Schedule history remains immutable" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.

## 3. fixed-asset-register-workspace: Reachable fixed-asset register

- [ ] 3.1 Write failing test `test_create_and_update_an_asset_record` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Create and update an asset record"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Create and update an asset record" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_reject_invalid_new_asset_inputs` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Reject invalid new asset inputs"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Reject invalid new asset inputs" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.7 Write failing test `test_preserve_assets_with_schedule_history` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Preserve assets with schedule history"; assert it fails for the right reason.
- [ ] 3.8 Implement the specified behavior for "Preserve assets with schedule history" to pass 3.7.
- [ ] 3.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.10 Write failing test `test_do_not_reinterpret_legacy_asset_fields` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Do not reinterpret legacy asset fields"; assert it fails for the right reason.
- [ ] 3.11 Implement the specified behavior for "Do not reinterpret legacy asset fields" to pass 3.10.
- [ ] 3.12 Refactor the affected code; keep the focused and full suites green.

## 4. fixed-asset-register-workspace: Traceable annual depreciation schedule

- [ ] 4.1 Write failing test `test_show_a_supported_full_year_linear_amount` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Show a supported full-year linear amount"; assert it fails for the right reason.
- [ ] 4.2 Implement the specified behavior for "Show a supported full-year linear amount" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_non_kfz_private_use_rule_is_unresolved` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Non-KFZ private-use rule is unresolved"; assert it fails for the right reason.
- [ ] 4.5 Implement the specified behavior for "Non-KFZ private-use rule is unresolved" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.7 Write failing test `test_fail_closed_on_partial_year_or_disposal_calculations` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Fail closed on partial-year or disposal calculations"; assert it fails for the right reason.
- [ ] 4.8 Implement the specified behavior for "Fail closed on partial-year or disposal calculations" to pass 4.7.
- [ ] 4.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.10 Write failing test `test_fail_closed_on_ambiguous_source_values` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Fail closed on ambiguous source values"; assert it fails for the right reason.
- [ ] 4.11 Implement the specified behavior for "Fail closed on ambiguous source values" to pass 4.10.
- [ ] 4.12 Refactor the affected code; keep the focused and full suites green.

## 5. fixed-asset-register-workspace: Asset changes have no journal side effect

- [ ] 5.1 Write failing test `test_save_an_asset_without_posting` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Save an asset without posting"; assert it fails for the right reason.
- [ ] 5.2 Implement the specified behavior for "Save an asset without posting" to pass 5.1.
- [ ] 5.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.4 Write failing test `test_block_an_unsupported_financial_effect` in `test/features/fixed_asset_register_workspace/fixed_asset_register_workspace_test.dart` for scenario "Block an unsupported financial effect"; assert it fails for the right reason.
- [ ] 5.5 Implement the specified behavior for "Block an unsupported financial effect" to pass 5.4.
- [ ] 5.6 Refactor the affected code; keep the focused and full suites green.

## 6. typed-route-workspaces: Canonical route inventory

- [ ] 6.1 Write failing test `test_every_canonical_route_has_a_useful_surface` in `test/core/router/fixed_asset_register_workspace_routes_test.dart` for scenario "Every canonical route has a useful surface"; assert it fails for the right reason.
- [ ] 6.2 Implement the specified behavior for "Every canonical route has a useful surface" to pass 6.1.
- [ ] 6.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.4 Write failing test `test_database_outage_is_not_an_empty_route` in `test/core/router/fixed_asset_register_workspace_routes_test.dart` for scenario "Database outage is not an empty route"; assert it fails for the right reason.
- [ ] 6.5 Implement the specified behavior for "Database outage is not an empty route" to pass 6.4.
- [ ] 6.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.7 Write failing test `test_alias_matrix_preserves_deep_links` in `test/core/router/fixed_asset_register_workspace_routes_test.dart` for scenario "Alias matrix preserves deep links"; assert it fails for the right reason.
- [ ] 6.8 Implement the specified behavior for "Alias matrix preserves deep links" to pass 6.7.
- [ ] 6.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.10 Write failing test `test_route_matrix_exposes_a_truthful_boundary` in `test/core/router/fixed_asset_register_workspace_routes_test.dart` for scenario "Route matrix exposes a truthful boundary"; assert it fails for the right reason.
- [ ] 6.11 Implement the specified behavior for "Route matrix exposes a truthful boundary" to pass 6.10.
- [ ] 6.12 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
