## 1. Table Definitions

- [x] 1.1 Write failing test `test_all_tables_created_on_fresh_install` in `test/db/inventory_stocktake_migration_test.dart` for scenario "All Tables Created on Fresh Install"; confirm it fails at the expected boundary.
- [x] 1.2 Implement the specified behavior for "All Tables Created on Fresh Install" to pass 1.1.
- [x] 1.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 1.4 Write failing test `test_table_count_verification` in `test/db/inventory_stocktake_migration_test.dart` for scenario "Table Count Verification"; confirm it fails at the expected boundary.
- [x] 1.5 Implement the specified behavior for "Table Count Verification" to pass 1.4.
- [x] 1.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 1.7 Write failing test `test_missing_table_detection` in `test/db/inventory_stocktake_migration_test.dart` for scenario "Missing Table Detection"; confirm it fails at the expected boundary.
- [x] 1.8 Implement the specified behavior for "Missing Table Detection" to pass 1.7.
- [x] 1.9 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 2. Explicit feature-table migrations

- [x] 2.1 Write failing test `test_named_inventory_table_migration` in `test/db/inventory_stocktake_migration_test.dart` for scenario "Named inventory table migration"; confirm it fails at the expected boundary.
- [x] 2.2 Implement the specified behavior for "Named inventory table migration" to pass 2.1.
- [x] 2.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 2.4 Write failing test `test_named_stocktake_table_migration` in `test/db/inventory_stocktake_migration_test.dart` for scenario "Named stocktake table migration"; confirm it fails at the expected boundary.
- [x] 2.5 Implement the specified behavior for "Named stocktake table migration" to pass 2.4.
- [x] 2.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 2.7 Write failing test `test_empty_recorded_header_insert_is_rejected_by_the_database` in `test/db/inventory_stocktake_migration_test.dart` for scenario "Empty recorded header insert is rejected by the database"; confirm it fails at the expected boundary.
- [x] 2.8 Implement the specified behavior for "Empty recorded header insert is rejected by the database" to pass 2.7.
- [x] 2.9 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 2.10 Write failing test `test_recorded_count_immutability_is_enforced_by_the_database` in `test/db/inventory_stocktake_migration_test.dart` for scenario "Recorded count immutability is enforced by the database"; confirm it fails at the expected boundary.
- [x] 2.11 Implement the specified behavior for "Recorded count immutability is enforced by the database" to pass 2.10.
- [x] 2.12 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 2.13 Write failing test `test_failed_stocktake_migration_leaves_prior_schema_intact` in `test/db/inventory_stocktake_migration_test.dart` for scenario "Failed stocktake migration leaves prior schema intact"; confirm it fails at the expected boundary.
- [x] 2.14 Implement the specified behavior for "Failed stocktake migration leaves prior schema intact" to pass 2.13.
- [x] 2.15 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 3. Inventory movement storage

- [x] 3.1 Write failing test `test_automatic_movement_recorded` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Automatic movement recorded"; confirm it fails at the expected boundary.
- [x] 3.2 Implement the specified behavior for "Automatic movement recorded" to pass 3.1.
- [x] 3.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 3.4 Write failing test `test_storno_movement_recorded` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Storno movement recorded"; confirm it fails at the expected boundary.
- [x] 3.5 Implement the specified behavior for "Storno movement recorded" to pass 3.4.
- [x] 3.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 3.7 Write failing test `test_incoming_and_document_only_finalization_has_no_automatic_movement` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Incoming and document-only finalization has no automatic movement"; confirm it fails at the expected boundary.
- [x] 3.8 Implement the specified behavior for "Incoming and document-only finalization has no automatic movement" to pass 3.7.
- [x] 3.9 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 3.10 Write failing test `test_count_snapshots_are_not_movement_rows` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Count snapshots are not movement rows"; confirm it fails at the expected boundary.
- [x] 3.11 Implement the specified behavior for "Count snapshots are not movement rows" to pass 3.10.
- [x] 3.12 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 4. Physical stocktake capture and recording

- [x] 4.1 Write failing test `test_complete_a_physical_count` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Complete a physical count"; confirm it fails at the expected boundary.
- [x] 4.2 Implement the specified behavior for "Complete a physical count" to pass 4.1.
- [x] 4.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 4.4 Write failing test `test_missing_count_cannot_be_recorded` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Missing count cannot be recorded"; confirm it fails at the expected boundary.
- [x] 4.5 Implement the specified behavior for "Missing count cannot be recorded" to pass 4.4.
- [x] 4.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 4.7 Write failing test `test_global_inventory_disabled` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Global inventory disabled"; confirm it fails at the expected boundary.
- [x] 4.8 Implement the specified behavior for "Global inventory disabled" to pass 4.7.
- [x] 4.9 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 4.10 Write failing test `test_no_inventory_enabled_articles_are_available` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "No inventory-enabled articles are available"; confirm it fails at the expected boundary.
- [x] 4.11 Implement the specified behavior for "No inventory-enabled articles are available" to pass 4.10.
- [x] 4.12 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 4.13 Write failing test `test_recorded_count_cannot_be_overwritten` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Recorded count cannot be overwritten"; confirm it fails at the expected boundary.
- [x] 4.14 Implement the specified behavior for "Recorded count cannot be overwritten" to pass 4.13.
- [x] 4.15 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 5. Physical stocktake persistence

- [x] 5.1 Write failing test `test_migration_creates_the_declared_stocktake_tables` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Migration creates the declared stocktake tables"; confirm it fails at the expected boundary.
- [x] 5.2 Implement the specified behavior for "Migration creates the declared stocktake tables" to pass 5.1.
- [x] 5.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 5.4 Write failing test `test_direct_sql_cannot_create_an_empty_recorded_header` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Direct SQL cannot create an empty recorded header"; confirm it fails at the expected boundary.
- [x] 5.5 Implement the specified behavior for "Direct SQL cannot create an empty recorded header" to pass 5.4.
- [x] 5.6 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 5.7 Write failing test `test_direct_update_or_delete_of_recorded_stocktake_is_rejected` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Direct update or delete of recorded stocktake is rejected"; confirm it fails at the expected boundary.
- [x] 5.8 Implement the specified behavior for "Direct update or delete of recorded stocktake is rejected" to pass 5.7.
- [x] 5.9 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 5.10 Write failing test `test_duplicate_article_position_is_rejected` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Duplicate article position is rejected"; confirm it fails at the expected boundary.
- [x] 5.11 Implement the specified behavior for "Duplicate article position is rejected" to pass 5.10.
- [x] 5.12 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 6. Stocktake counts are distinct from book quantities

- [x] 6.1 Write failing test `test_recorded_quantities_appear_as_physical_counts` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Recorded quantities appear as physical counts"; confirm it fails at the expected boundary.
- [x] 6.2 Implement the specified behavior for "Recorded quantities appear as physical counts" to pass 6.1.
- [x] 6.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 6.4 Write failing test `test_current_stock_is_not_substituted_for_historical_quantity` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Current stock is not substituted for historical quantity"; confirm it fails at the expected boundary.
- [x] 6.5 Implement the specified behavior for "Current stock is not substituted for historical quantity" to pass 6.4.
- [x] 6.6 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 7. Inventory valuation fails closed without policy

- [x] 7.1 Write failing test `test_count_remains_available_while_valuation_policy_is_unspecified` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Count remains available while valuation policy is unspecified"; confirm it fails at the expected boundary.
- [x] 7.2 Implement the specified behavior for "Count remains available while valuation policy is unspecified" to pass 7.1.
- [x] 7.3 Refactor the affected persistence or workspace code; keep focused and full suites green.
- [x] 7.4 Write failing test `test_valuation_request_fails_without_side_effects` in `test/features/inventory/stocktake_workspace_test.dart` for scenario "Valuation request fails without side effects"; confirm it fails at the expected boundary.
- [x] 7.5 Implement the specified behavior for "Valuation request fails without side effects" to pass 7.4.
- [x] 7.6 Refactor the affected persistence or workspace code; keep focused and full suites green.

## 8. Review round 4 regressions

- [x] 8.1 Add an exact SQLite table-set assertion for the v18 snapshot in `test/db/inventory_stocktake_migration_test.dart`; keep current-version expectations compatible with later ordered migrations.
- [x] 8.2 Align proposal, design, database delta, and test plan with the versioned table counts.
- [x] 8.3 Run focused migration tests after adding the exact v18 snapshot assertion; all 8 migration tests pass.
- [x] 8.4 Add `test_invalid_count_does_not_change_saved_draft_counts` covering malformed and over-precision values in `test/features/inventory/stocktake_workspace_test.dart`.
- [x] 8.5 Validate every nonempty quantity before writing any draft row.
- [x] 8.6 Run focused inventory workspace tests after adding precision prevalidation; all 18 tests pass.
- [x] 8.7 Add `test_nonnegative_four_decimal_count_shows_precision_message` in `test/features/inventory/stocktake_recorded_state_test.dart`.
- [x] 8.8 Map precision validation failures to localized precision feedback in English and German.
- [x] 8.9 Run the precision-feedback widget test; the localized precision message appears and the negative-count message does not.
- [x] 8.10 Add `test_recorded_count_is_physical_and_book_variance_valuation_are_unavailable` in `test/features/inventory/stocktake_recorded_state_test.dart`.
- [x] 8.11 Run the recorded-state widget test; physical count is shown and book, variance, and valuation remain unavailable.

## 9. Atomic draft count persistence

- [x] 9.1 Add `test_bulk_count_save_rolls_back_after_a_mid_write_failure` in `test/features/inventory/stocktake_workspace_test.dart`; force the second count update to fail and assert that the first update and record transition both roll back.
- [x] 9.2 Add a transactional bulk count save/record path and route the draft workspace through it.
- [x] 9.3 Map non-finite counts to localized invalid-count feedback and cover the input in the saved-count preservation widget test.
- [x] 9.4 Run the focused inventory suite; all 29 tests pass.

## Implementation Notes

- Use `design.md` for the ordered migration, transaction boundary, trigger behavior, and service composition.
- Keep count capture separate from inventory movements, valuation, and journal posting.
- Add the explicitly listed tests and fixtures before production behavior; keep every test-plan row red until it passes.
