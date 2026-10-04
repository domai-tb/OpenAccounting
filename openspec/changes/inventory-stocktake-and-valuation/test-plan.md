## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/db/spec.md → Table Definitions | All Tables Created on Fresh Install | test/core/db/inventory_stocktake_migration_test.dart | test_all_tables_created_on_fresh_install | 🔴 red |
| specs/db/spec.md → Table Definitions | Table Count Verification | test/core/db/inventory_stocktake_migration_test.dart | test_table_count_verification | 🔴 red |
| specs/db/spec.md → Table Definitions | Missing Table Detection | test/core/db/inventory_stocktake_migration_test.dart | test_missing_table_detection | 🔴 red |
| specs/db/spec.md → Explicit feature-table migrations | Named inventory table migration | test/core/db/inventory_stocktake_migration_test.dart | test_named_inventory_table_migration | 🔴 red |
| specs/db/spec.md → Explicit feature-table migrations | Named stocktake table migration | test/core/db/inventory_stocktake_migration_test.dart | test_named_stocktake_table_migration | 🔴 red |
| specs/db/spec.md → Explicit feature-table migrations | Empty recorded header insert is rejected by the database | test/core/db/inventory_stocktake_migration_test.dart | test_empty_recorded_header_insert_is_rejected_by_the_database | 🔴 red |
| specs/db/spec.md → Explicit feature-table migrations | Recorded count immutability is enforced by the database | test/core/db/inventory_stocktake_migration_test.dart | test_recorded_count_immutability_is_enforced_by_the_database | 🔴 red |
| specs/db/spec.md → Explicit feature-table migrations | Failed stocktake migration leaves prior schema intact | test/core/db/inventory_stocktake_migration_test.dart | test_failed_stocktake_migration_leaves_prior_schema_intact | 🔴 red |
| specs/inventory/spec.md → Inventory movement storage | Automatic movement recorded | test/features/inventory/stocktake_workspace_test.dart | test_automatic_movement_recorded | 🔴 red |
| specs/inventory/spec.md → Inventory movement storage | Storno movement recorded | test/features/inventory/stocktake_workspace_test.dart | test_storno_movement_recorded | 🔴 red |
| specs/inventory/spec.md → Inventory movement storage | Incoming and document-only finalization has no automatic movement | test/features/inventory/stocktake_workspace_test.dart | test_incoming_and_document_only_finalization_has_no_automatic_movement | 🔴 red |
| specs/inventory/spec.md → Inventory movement storage | Count snapshots are not movement rows | test/features/inventory/stocktake_workspace_test.dart | test_count_snapshots_are_not_movement_rows | 🔴 red |
| specs/inventory/spec.md → Physical stocktake capture and recording | Complete a physical count | test/features/inventory/stocktake_workspace_test.dart | test_complete_a_physical_count | 🔴 red |
| specs/inventory/spec.md → Physical stocktake capture and recording | Missing count cannot be recorded | test/features/inventory/stocktake_workspace_test.dart | test_missing_count_cannot_be_recorded | 🔴 red |
| specs/inventory/spec.md → Physical stocktake capture and recording | Global inventory disabled | test/features/inventory/stocktake_workspace_test.dart | test_global_inventory_disabled | 🔴 red |
| specs/inventory/spec.md → Physical stocktake capture and recording | No inventory-enabled articles are available | test/features/inventory/stocktake_workspace_test.dart | test_no_inventory_enabled_articles_are_available | 🔴 red |
| specs/inventory/spec.md → Physical stocktake capture and recording | Recorded count cannot be overwritten | test/features/inventory/stocktake_workspace_test.dart | test_recorded_count_cannot_be_overwritten | 🔴 red |
| specs/inventory/spec.md → Physical stocktake persistence | Migration creates the declared stocktake tables | test/features/inventory/stocktake_workspace_test.dart | test_migration_creates_the_declared_stocktake_tables | 🔴 red |
| specs/inventory/spec.md → Physical stocktake persistence | Direct SQL cannot create an empty recorded header | test/features/inventory/stocktake_workspace_test.dart | test_direct_sql_cannot_create_an_empty_recorded_header | 🔴 red |
| specs/inventory/spec.md → Physical stocktake persistence | Direct update or delete of recorded stocktake is rejected | test/features/inventory/stocktake_workspace_test.dart | test_direct_update_or_delete_of_recorded_stocktake_is_rejected | 🔴 red |
| specs/inventory/spec.md → Physical stocktake persistence | Duplicate article position is rejected | test/features/inventory/stocktake_workspace_test.dart | test_duplicate_article_position_is_rejected | 🔴 red |
| specs/inventory/spec.md → Stocktake counts are distinct from book quantities | Recorded quantities appear as physical counts | test/features/inventory/stocktake_workspace_test.dart | test_recorded_quantities_appear_as_physical_counts | 🔴 red |
| specs/inventory/spec.md → Stocktake counts are distinct from book quantities | Current stock is not substituted for historical quantity | test/features/inventory/stocktake_workspace_test.dart | test_current_stock_is_not_substituted_for_historical_quantity | 🔴 red |
| specs/inventory/spec.md → Inventory valuation fails closed without policy | Count remains available while valuation policy is unspecified | test/features/inventory/stocktake_workspace_test.dart | test_count_remains_available_while_valuation_policy_is_unspecified | 🔴 red |
| specs/inventory/spec.md → Inventory valuation fails closed without policy | Valuation request fails without side effects | test/features/inventory/stocktake_workspace_test.dart | test_valuation_request_fails_without_side_effects | 🔴 red |

## Coverage Notes

- Each scenario starts red and has one named test in the stated file.
- Inventory workspace scenarios use the focused feature test; schema, migration, table-inventory, and direct-SQL guard scenarios use the migration/database test.
- Implementation must add the listed tests and fixtures before production behavior; no test execution is claimed by this proposal artifact.
