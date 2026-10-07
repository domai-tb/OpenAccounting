## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🟢 green → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Result |
|-------------|----------|-----------|-----------|---------------|
| specs/accounting/spec.md → Schnellbuchungen | Quick booking preset | test/features/quick_booking/quick_booking_execution_test.dart | test_quick_booking_preset | 🟢 green |
| specs/accounting/spec.md → Schnellbuchungen | Quick booking execution | test/features/quick_booking/quick_booking_execution_test.dart | test_quick_booking_execution | 🟢 green |
| specs/accounting/spec.md → Schnellbuchungen | Quick booking with invalid preset | test/features/quick_booking/quick_booking_execution_test.dart | test_quick_booking_with_invalid_preset | 🟢 green |
| specs/db/spec.md → Quick-booking presets store explicit execution semantics | Fresh schema stores the complete preset contract | test/db/quick_booking_migration_test.dart | test_fresh_schema_stores_the_complete_preset_contract | 🟢 green |
| specs/db/spec.md → Quick-booking presets store explicit execution semantics | Legacy preset migration preserves values | test/db/quick_booking_migration_test.dart | test_legacy_preset_migration_preserves_values | 🟢 green |
| specs/db/spec.md → Quick-booking presets store explicit execution semantics | Failed table rebuild rolls back | test/db/quick_booking_migration_test.dart | test_failed_table_rebuild_rolls_back | 🟢 green |
| specs/quick-booking-workspace/spec.md → Quick-booking presets preserve explicit transaction inputs | Create a complete preset | test/features/quick_booking/quick_booking_workspace_test.dart | test_create_a_complete_preset | 🟢 green |
| specs/quick-booking-workspace/spec.md → Quick-booking presets preserve explicit transaction inputs | Legacy preset requires review | test/features/quick_booking/quick_booking_workspace_test.dart | test_legacy_preset_requires_review | 🟢 green |
| specs/quick-booking-workspace/spec.md → Quick-booking presets preserve explicit transaction inputs | Referenced configuration is no longer active | test/features/quick_booking/quick_booking_workspace_test.dart | test_referenced_configuration_is_no_longer_active | 🟢 green |
| specs/quick-booking-workspace/spec.md → Execute presets through approved accounting posting | Posting service accepts the preset | test/features/quick_booking/quick_booking_workspace_test.dart | test_posting_service_accepts_the_preset | 🟢 green |
| specs/quick-booking-workspace/spec.md → Execute presets through approved accounting posting | Posting contract is unavailable | test/features/quick_booking/quick_booking_workspace_test.dart | test_posting_contract_is_unavailable | 🟢 green |
| specs/quick-booking-workspace/spec.md → Execute presets through approved accounting posting | Preset has no default amount | test/features/quick_booking/quick_booking_workspace_test.dart | test_preset_has_no_default_amount | 🟢 green |
| specs/quick-booking-workspace/spec.md → Quick Bookings compose within Banking without changing other views | Open Quick Bookings and return to import state | test/core/quick_booking_route_test.dart | test_open_quick_bookings_and_return_to_import_state | 🟢 green |
| specs/quick-booking-workspace/spec.md → Quick Bookings compose within Banking without changing other views | Execution is unavailable | test/features/quick_booking/quick_bookings_view_test.dart | test_execution_is_unavailable | 🟢 green |
| specs/quick-booking-workspace/spec.md → Quick Bookings follow the desktop design schema | Preset management is keyboard accessible | test/features/quick_booking/quick_bookings_view_test.dart | test_preset_management_is_keyboard_accessible | 🟢 green |
| specs/typed-route-workspaces/spec.md → Quick-booking Banking view state | Quick-booking view uses typed route state | test/core/quick_booking_route_test.dart | test_quick_booking_view_uses_typed_route_state | 🟢 green |
| specs/typed-route-workspaces/spec.md → Quick-booking Banking view state | Database outage is not an empty quick-booking view | test/core/quick_booking_route_test.dart | test_database_outage_is_not_an_empty_quick_booking_view | 🟢 green |
<!-- Non-executable change (docs/config/schema): map to a mechanical check instead. -->
<!-- | specs/<cap>/spec.md → <Requirement Name> | <Scenario Name> | openspec schema validate anvil | schema-validates | N/A — non-executable | -->

## Coverage Notes

<!-- Any notes on test infrastructure, shared fixtures, or test utilities needed. -->
<!-- For N/A — non-executable entries, justify why no code test exists and name the check that gates the change. -->

All 17 executable scenarios passed. Quick-booking, Banking route, and schema-migration tests: 28/28. Changed-file analysis and Dart formatting are clean. The full suite retains 3 previously reported failures in the analyzer gate and localized accessible-surface tests; no Quick Bookings tests failed.
