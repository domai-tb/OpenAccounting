## 1. Table Definitions

- [ ] 1.1 Write failing test `test_all_tables_created_on_fresh_install` in `test/core/db/inventory_stocktake_migration_test.dart` for scenario "All Tables Created on Fresh Install"; confirm it fails at the expected boundary.
- [ ] 1.2 Implement the specified behavior for "All Tables Created on Fresh Install" to pass 1.1.
- [ ] 1.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 1.4 Write failing test `test_table_count_verification` in `test/core/db/inventory_stocktake_migration_test.dart` for scenario "Table Count Verification"; confirm it fails at the expected boundary.
- [ ] 1.5 Implement the specified behavior for "Table Count Verification" to pass 1.4.
- [ ] 1.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 1.7 Write failing test `test_missing_table_detection` in `test/core/db/inventory_stocktake_migration_test.dart` for scenario "Missing Table Detection"; confirm it fails at the expected boundary.
- [ ] 1.8 Implement the specified behavior for "Missing Table Detection" to pass 1.7.
- [ ] 1.9 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 2. Explicit feature-table migrations

- [ ] 2.1 Write failing test `test_named_inventory_table_migration` in `test/core/db/inventory_stocktake_migration_test.dart` for scenario "Named inventory table migration"; confirm it fails at the expected boundary.
- [ ] 2.2 Implement the specified behavior for "Named inventory table migration" to pass 2.1.
- [ ] 2.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 2.4 Write failing test `test_named_stocktake_table_migration` in `test/core/db/inventory_stocktake_migration_test.dart` for scenario "Named stocktake table migration"; confirm it fails at the expected boundary.
- [ ] 2.5 Implement the specified behavior for "Named stocktake table migration" to pass 2.4.
- [ ] 2.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 2.7 Write failing test `test_empty_recorded_header_insert_is_rejected_by_the_database` in `test/core/db/inventory_stocktake_migration_test.dart` for scenario "Empty recorded header insert is rejected by the database"; confirm it fails at the expected boundary.
- [ ] 2.8 Implement the specified behavior for "Empty recorded header insert is rejected by the database" to pass 2.7.
- [ ] 2.9 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 2.10 Write failing test `test_recorded_count_immutability_is_enforced_by_the_database` in `test/core/db/inventory_stocktake_migration_test.dart` for scenario "Recorded count immutability is enforced by the database"; confirm it fails at the expected boundary.
- [ ] 2.11 Implement the specified behavior for "Recorded count immutability is enforced by the database" to pass 2.10.
- [ ] 2.12 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 2.13 Write failing test `test_failed_stocktake_migration_leaves_prior_schema_intact` in `test/core/db/inventory_stocktake_migration_test.dart` for scenario "Failed stocktake migration leaves prior schema intact"; confirm it fails at the expected boundary.
- [ ] 2.14 Implement the specified behavior for "Failed stocktake migration leaves prior schema intact" to pass 2.13.
- [ ] 2.15 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 3. Inventory movement storage

- [ ] 3.1 Write failing test `test_automatic_movement_recorded` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Automatic movement recorded"; confirm it fails at the expected boundary.
- [ ] 3.2 Implement the specified behavior for "Automatic movement recorded" to pass 3.1.
- [ ] 3.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 3.4 Write failing test `test_storno_movement_recorded` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Storno movement recorded"; confirm it fails at the expected boundary.
- [ ] 3.5 Implement the specified behavior for "Storno movement recorded" to pass 3.4.
- [ ] 3.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 3.7 Write failing test `test_incoming_and_document_only_finalization_has_no_automatic_movement` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Incoming and document-only finalization has no automatic movement"; confirm it fails at the expected boundary.
- [ ] 3.8 Implement the specified behavior for "Incoming and document-only finalization has no automatic movement" to pass 3.7.
- [ ] 3.9 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 3.10 Write failing test `test_count_snapshots_are_not_movement_rows` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Count snapshots are not movement rows"; confirm it fails at the expected boundary.
- [ ] 3.11 Implement the specified behavior for "Count snapshots are not movement rows" to pass 3.10.
- [ ] 3.12 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 4. Physical stocktake capture and recording

- [ ] 4.1 Write failing test `test_complete_a_physical_count` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Complete a physical count"; confirm it fails at the expected boundary.
- [ ] 4.2 Implement the specified behavior for "Complete a physical count" to pass 4.1.
- [ ] 4.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 4.4 Write failing test `test_missing_count_cannot_be_recorded` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Missing count cannot be recorded"; confirm it fails at the expected boundary.
- [ ] 4.5 Implement the specified behavior for "Missing count cannot be recorded" to pass 4.4.
- [ ] 4.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 4.7 Write failing test `test_global_inventory_disabled` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Global inventory disabled"; confirm it fails at the expected boundary.
- [ ] 4.8 Implement the specified behavior for "Global inventory disabled" to pass 4.7.
- [ ] 4.9 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 4.10 Write failing test `test_no_inventory_enabled_articles_are_available` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "No inventory-enabled articles are available"; confirm it fails at the expected boundary.
- [ ] 4.11 Implement the specified behavior for "No inventory-enabled articles are available" to pass 4.10.
- [ ] 4.12 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 4.13 Write failing test `test_recorded_count_cannot_be_overwritten` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Recorded count cannot be overwritten"; confirm it fails at the expected boundary.
- [ ] 4.14 Implement the specified behavior for "Recorded count cannot be overwritten" to pass 4.13.
- [ ] 4.15 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 5. Physical stocktake persistence

- [ ] 5.1 Write failing test `test_migration_creates_the_declared_stocktake_tables` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Migration creates the declared stocktake tables"; confirm it fails at the expected boundary.
- [ ] 5.2 Implement the specified behavior for "Migration creates the declared stocktake tables" to pass 5.1.
- [ ] 5.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 5.4 Write failing test `test_direct_sql_cannot_create_an_empty_recorded_header` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Direct SQL cannot create an empty recorded header"; confirm it fails at the expected boundary.
- [ ] 5.5 Implement the specified behavior for "Direct SQL cannot create an empty recorded header" to pass 5.4.
- [ ] 5.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 5.7 Write failing test `test_direct_update_or_delete_of_recorded_stocktake_is_rejected` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Direct update or delete of recorded stocktake is rejected"; confirm it fails at the expected boundary.
- [ ] 5.8 Implement the specified behavior for "Direct update or delete of recorded stocktake is rejected" to pass 5.7.
- [ ] 5.9 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 5.10 Write failing test `test_duplicate_article_position_is_rejected` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Duplicate article position is rejected"; confirm it fails at the expected boundary.
- [ ] 5.11 Implement the specified behavior for "Duplicate article position is rejected" to pass 5.10.
- [ ] 5.12 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 6. Stocktake counts are distinct from book quantities

- [ ] 6.1 Write failing test `test_recorded_quantities_appear_as_physical_counts` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Recorded quantities appear as physical counts"; confirm it fails at the expected boundary.
- [ ] 6.2 Implement the specified behavior for "Recorded quantities appear as physical counts" to pass 6.1.
- [ ] 6.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 6.4 Write failing test `test_current_stock_is_not_substituted_for_historical_quantity` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Current stock is not substituted for historical quantity"; confirm it fails at the expected boundary.
- [ ] 6.5 Implement the specified behavior for "Current stock is not substituted for historical quantity" to pass 6.4.
- [ ] 6.6 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 7. Inventory valuation fails closed without policy

- [ ] 7.1 Write failing test `test_count_remains_available_while_valuation_policy_is_unspecified` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Count remains available while valuation policy is unspecified"; confirm it fails at the expected boundary.
- [ ] 7.2 Implement the specified behavior for "Count remains available while valuation policy is unspecified" to pass 7.1.
- [ ] 7.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [ ] 7.4 Write failing test `test_valuation_request_fails_without_side_effects` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Valuation request fails without side effects"; confirm it fails at the expected boundary.
- [ ] 7.5 Implement the specified behavior for "Valuation request fails without side effects" to pass 7.4.
- [ ] 7.6 Refactor the affected persistence or workspace code; keep focused and full suites green.

## Implementation Notes

- Use `design.md` for the ordered migration, transaction boundary, trigger behavior, and service composition.
- Keep count capture separate from inventory movements, valuation, and journal posting.
- Add the explicitly listed tests and fixtures before production behavior; keep every test-plan row red until it passes.
