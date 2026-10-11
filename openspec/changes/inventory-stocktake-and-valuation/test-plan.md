## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/db/spec.md → Table Definitions | v18 stocktake schema has the exact declared set | test/db/inventory_stocktake_migration_test.dart | test_all_tables_created_on_fresh_install | 🟢 green |
| specs/db/spec.md → Table Definitions | v18 snapshot table inventory is exact | test/db/inventory_stocktake_migration_test.dart | test_table_count_verification | 🟢 green |
| specs/db/spec.md → Table Definitions | Missing Table Detection | test/db/inventory_stocktake_migration_test.dart | test_missing_table_detection | 🟢 green |
| specs/db/spec.md → Explicit feature-table migrations | Named inventory table migration | test/db/inventory_stocktake_migration_test.dart | test_named_inventory_table_migration | 🟢 green |
| specs/db/spec.md → Explicit feature-table migrations | Named stocktake table migration | test/db/inventory_stocktake_migration_test.dart | test_named_stocktake_table_migration | 🟢 green |
| specs/db/spec.md → Explicit feature-table migrations | Empty recorded header insert is rejected by the database | test/db/inventory_stocktake_migration_test.dart | test_empty_recorded_header_insert_is_rejected_by_the_database | 🟢 green |
| specs/db/spec.md → Explicit feature-table migrations | Recorded count immutability is enforced by the database | test/db/inventory_stocktake_migration_test.dart | test_recorded_count_immutability_is_enforced_by_the_database | 🟢 green |
| specs/db/spec.md → Explicit feature-table migrations | Failed stocktake migration leaves prior schema intact | test/db/inventory_stocktake_migration_test.dart | test_failed_stocktake_migration_leaves_prior_schema_intact | 🟢 green |
| specs/inventory/spec.md → Inventory movement storage | Automatic movement recorded | test/features/inventory/stocktake_workspace_test.dart | test_automatic_movement_recorded | 🟢 green |
| specs/inventory/spec.md → Inventory movement storage | Storno movement recorded | test/features/inventory/stocktake_workspace_test.dart | test_storno_movement_recorded | 🟢 green |
| specs/inventory/spec.md → Inventory movement storage | Incoming and document-only finalization has no automatic movement | test/features/inventory/stocktake_workspace_test.dart | test_incoming_and_document_only_finalization_has_no_automatic_movement | 🟢 green |
| specs/inventory/spec.md → Inventory movement storage | Count snapshots are not movement rows | test/features/inventory/stocktake_workspace_test.dart | test_count_snapshots_are_not_movement_rows | 🟢 green |
| specs/inventory/spec.md → Physical stocktake capture and recording | Complete a physical count | test/features/inventory/stocktake_workspace_test.dart | test_complete_a_physical_count | 🟢 green |
| specs/inventory/spec.md → Physical stocktake capture and recording | Missing count cannot be recorded | test/features/inventory/stocktake_workspace_test.dart | test_missing_count_cannot_be_recorded | 🟢 green |
| specs/inventory/spec.md → Physical stocktake capture and recording | Global inventory disabled | test/features/inventory/stocktake_workspace_test.dart | test_global_inventory_disabled | 🟢 green |
| specs/inventory/spec.md → Physical stocktake capture and recording | No inventory-enabled articles are available | test/features/inventory/stocktake_workspace_test.dart | test_no_inventory_enabled_articles_are_available | 🟢 green |
| specs/inventory/spec.md → Physical stocktake capture and recording | Recorded count cannot be overwritten | test/features/inventory/stocktake_workspace_test.dart | test_recorded_count_cannot_be_overwritten | 🟢 green |
| specs/inventory/spec.md → Physical stocktake persistence | Migration creates the declared stocktake tables | test/features/inventory/stocktake_workspace_test.dart | test_migration_creates_the_declared_stocktake_tables | 🟢 green |
| specs/inventory/spec.md → Physical stocktake persistence | Direct SQL cannot create an empty recorded header | test/features/inventory/stocktake_workspace_test.dart | test_direct_sql_cannot_create_an_empty_recorded_header | 🟢 green |
| specs/inventory/spec.md → Physical stocktake persistence | Direct update or delete of recorded stocktake is rejected | test/features/inventory/stocktake_workspace_test.dart | test_direct_update_or_delete_of_recorded_stocktake_is_rejected | 🟢 green |
| specs/inventory/spec.md → Physical stocktake persistence | Duplicate article position is rejected | test/features/inventory/stocktake_workspace_test.dart | test_duplicate_article_position_is_rejected | 🟢 green |
| specs/inventory/spec.md → Stocktake counts are distinct from book quantities | Recorded quantities appear as physical counts | test/features/inventory/stocktake_workspace_test.dart | test_recorded_quantities_appear_as_physical_counts | 🟢 green |
| specs/inventory/spec.md → Stocktake counts are distinct from book quantities | Current stock is not substituted for historical quantity | test/features/inventory/stocktake_workspace_test.dart | test_current_stock_is_not_substituted_for_historical_quantity | 🟢 green |
| specs/inventory/spec.md → Inventory valuation fails closed without policy | Count remains available while valuation policy is unspecified | test/features/inventory/stocktake_workspace_test.dart | test_count_remains_available_while_valuation_policy_is_unspecified | 🟢 green |
| specs/inventory/spec.md → Inventory valuation fails closed without policy | Valuation request fails without side effects | test/features/inventory/stocktake_workspace_test.dart | test_valuation_request_fails_without_side_effects | 🟢 green |
| specs/inventory/spec.md → Draft counts are preserved on invalid input | Malformed, non-finite, or over-precision input does not erase saved draft counts | test/features/inventory/stocktake_workspace_test.dart | test_invalid_count_does_not_change_saved_draft_counts | 🟢 green |
| specs/inventory/spec.md → Physical stocktake persistence | Failed bulk count write leaves prior counts and draft state intact | test/features/inventory/stocktake_workspace_test.dart | test_bulk_count_save_rolls_back_after_a_mid_write_failure | 🟢 green |
| specs/inventory/spec.md → Count validation feedback | Four-decimal nonnegative input shows precision feedback | test/features/inventory/stocktake_recorded_state_test.dart | test_nonnegative_four_decimal_count_shows_precision_message | 🟢 green |
| specs/inventory/spec.md → Recorded stocktake presentation | Recorded physical count is shown while book, variance, and valuation stay unavailable | test/features/inventory/stocktake_recorded_state_test.dart | test_recorded_count_is_physical_and_book_variance_valuation_are_unavailable | 🟢 green |

## Coverage Notes

- Each scenario starts red and has one named test in the stated file.
- Inventory workspace scenarios use the focused feature test; schema, migration, table-inventory, and direct-SQL guard scenarios use the migration/database test.
- Table-inventory assertions verify the 41-table v18 base plus its seven required migration-owned tables; current-version expectations allow later ordered migrations.
- Regression rows added after review round 4 cover draft-count preservation, atomic bulk-write rollback, precision feedback, and recorded-state UI presentation; all 29 focused tests pass.
- This plan records named test contracts; run evidence and full-suite gate state are tracked in `verify.md`.
