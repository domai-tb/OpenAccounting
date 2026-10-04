## 1. Export one customer's explicitly linked data (specs/customer-data-disclosure-export/spec.md)

- [ ] 1.1 Write failing test `test_customer_data_disclosure_export_001_export_an_unambiguous_customer_s_linked_records` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Export an unambiguous customer's linked records" (assert it fails for the expected reason).
- [ ] 1.2 Implement the specified behavior for "Export an unambiguous customer's linked records" to pass the test.
- [ ] 1.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_001_export_an_unambiguous_customer_s_linked_records` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 1.4 Write failing test `test_customer_data_disclosure_export_002_no_customer_is_selected_or_the_id_is_invalid` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "No customer is selected or the ID is invalid" (assert it fails for the expected reason).
- [ ] 1.5 Implement the specified behavior for "No customer is selected or the ID is invalid" to pass the test.
- [ ] 1.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_002_no_customer_is_selected_or_the_id_is_invalid` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 1.7 Write failing test `test_customer_data_disclosure_export_003_unlinked_data_is_not_guessed` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Unlinked data is not guessed" (assert it fails for the expected reason).
- [ ] 1.8 Implement the specified behavior for "Unlinked data is not guessed" to pass the test.
- [ ] 1.9 Refactor this behavior; rerun `test_customer_data_disclosure_export_003_unlinked_data_is_not_guessed` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 1.10 Write failing test `test_customer_data_disclosure_export_004_unclassified_fields_prevent_a_complete_outcome` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Unclassified fields prevent a complete outcome" (assert it fails for the expected reason).
- [ ] 1.11 Implement the specified behavior for "Unclassified fields prevent a complete outcome" to pass the test.
- [ ] 1.12 Refactor this behavior; rerun `test_customer_data_disclosure_export_004_unclassified_fields_prevent_a_complete_outcome` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.

## 2. Linked evidence has a truthful completeness state (specs/customer-data-disclosure-export/spec.md)

- [ ] 2.1 Write failing test `test_customer_data_disclosure_export_005_linked_evidence_is_profile_local_and_readable` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Linked evidence is profile-local and readable" (assert it fails for the expected reason).
- [ ] 2.2 Implement the specified behavior for "Linked evidence is profile-local and readable" to pass the test.
- [ ] 2.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_005_linked_evidence_is_profile_local_and_readable` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 2.4 Write failing test `test_customer_data_disclosure_export_006_linked_evidence_is_missing_or_has_unresolved_thi` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Linked evidence is missing or has unresolved third-party content" (assert it fails for the expected reason).
- [ ] 2.5 Implement the specified behavior for "Linked evidence is missing or has unresolved third-party content" to pass the test.
- [ ] 2.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_006_linked_evidence_is_missing_or_has_unresolved_thi` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 2.7 Write failing test `test_customer_data_disclosure_export_007_profile_local_symlink_targets_evidence_outside_t` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Profile-local symlink targets evidence outside the profile" (assert it fails for the expected reason).
- [ ] 2.8 Implement the specified behavior for "Profile-local symlink targets evidence outside the profile" to pass the test.
- [ ] 2.9 Refactor this behavior; rerun `test_customer_data_disclosure_export_007_profile_local_symlink_targets_evidence_outside_t` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.

## 3. Customer disclosure export is separate from erasure and profile portability (specs/customer-data-disclosure-export/spec.md)

- [ ] 3.1 Write failing test `test_customer_data_disclosure_export_008_user_sees_the_export_scope_before_saving` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "User sees the export scope before saving" (assert it fails for the expected reason).
- [ ] 3.2 Implement the specified behavior for "User sees the export scope before saving" to pass the test.
- [ ] 3.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_008_user_sees_the_export_scope_before_saving` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 3.4 Write failing test `test_customer_data_disclosure_export_009_export_failure_or_cancellation` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Export failure or cancellation" (assert it fails for the expected reason).
- [ ] 3.5 Implement the specified behavior for "Export failure or cancellation" to pass the test.
- [ ] 3.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_009_export_failure_or_cancellation` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 3.7 Write failing test `test_customer_data_disclosure_export_010_retry_after_interrupted_archive_creation` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Retry after interrupted archive creation" (assert it fails for the expected reason).
- [ ] 3.8 Implement the specified behavior for "Retry after interrupted archive creation" to pass the test.
- [ ] 3.9 Refactor this behavior; rerun `test_customer_data_disclosure_export_010_retry_after_interrupted_archive_creation` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.

## 4. Customer export follows the desktop design system (specs/customer-data-disclosure-export/spec.md)

- [ ] 4.1 Write failing test `test_customer_data_disclosure_export_011_keyboard_operation` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Keyboard operation" (assert it fails for the expected reason).
- [ ] 4.2 Implement the specified behavior for "Keyboard operation" to pass the test.
- [ ] 4.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_011_keyboard_operation` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 4.4 Write failing test `test_customer_data_disclosure_export_012_cancel_destination_selection_in_a_narrow_window` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Cancel destination selection in a narrow window with enlarged text" (assert it fails for the expected reason).
- [ ] 4.5 Implement the specified behavior for "Cancel destination selection in a narrow window with enlarged text" to pass the test.
- [ ] 4.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_012_cancel_destination_selection_in_a_narrow_window` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 4.7 Write failing test `test_customer_data_disclosure_export_013_unknown_table_state_prevents_complete_disclosure` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Unknown table state prevents complete disclosure" (assert it fails for the expected reason).
- [ ] 4.8 Implement the specified behavior for "Unknown table state prevents complete disclosure" to pass the test.
- [ ] 4.9 Refactor this behavior; rerun `test_customer_data_disclosure_export_013_unknown_table_state_prevents_complete_disclosure` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 4.10 Write failing test `test_customer_data_disclosure_export_014_pre_v9_profile_remains_valid_but_is_not_a_comple` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Pre-v9 profile remains valid but is not a complete export source" (assert it fails for the expected reason).
- [ ] 4.11 Implement the specified behavior for "Pre-v9 profile remains valid but is not a complete export source" to pass the test.
- [ ] 4.12 Refactor this behavior; rerun `test_customer_data_disclosure_export_014_pre_v9_profile_remains_valid_but_is_not_a_comple` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 4.13 Write failing test `test_customer_data_disclosure_export_015_missing_payment_table_is_detected_before_startup` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Missing payment table is detected before startup repair" (assert it fails for the expected reason).
- [ ] 4.14 Implement the specified behavior for "Missing payment table is detected before startup repair" to pass the test.
- [ ] 4.15 Refactor this behavior; rerun `test_customer_data_disclosure_export_015_missing_payment_table_is_detected_before_startup` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 4.16 Write failing test `test_customer_data_disclosure_export_016_mileage_and_category_tables_remain_outside_custo` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Mileage and category tables remain outside customer payload" (assert it fails for the expected reason).
- [ ] 4.17 Implement the specified behavior for "Mileage and category tables remain outside customer payload" to pass the test.
- [ ] 4.18 Refactor this behavior; rerun `test_customer_data_disclosure_export_016_mileage_and_category_tables_remain_outside_custo` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.

## 5. Customer disclosure uses declared relationship paths (specs/db/spec.md)

- [ ] 5.1 Write failing test `test_customer_data_disclosure_export_017_new_relationship_is_not_in_the_reviewed_inventor` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "New relationship is not in the reviewed inventory" (assert it fails for the expected reason).
- [ ] 5.2 Implement the specified behavior for "New relationship is not in the reviewed inventory" to pass the test.
- [ ] 5.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_017_new_relationship_is_not_in_the_reviewed_inventor` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 5.4 Write failing test `test_customer_data_disclosure_export_018_snapshot_cannot_be_acquired_consistently` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Snapshot cannot be acquired consistently" (assert it fails for the expected reason).
- [ ] 5.5 Implement the specified behavior for "Snapshot cannot be acquired consistently" to pass the test.
- [ ] 5.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_018_snapshot_cannot_be_acquired_consistently` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.

## 6. Customer export completeness uses an accepted table inventory (specs/db/spec.md)

- [ ] 6.1 Write failing test `test_customer_data_disclosure_export_019_profile_table_inventory_has_not_been_accepted` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Profile table inventory has not been accepted" (assert it fails for the expected reason).
- [ ] 6.2 Implement the specified behavior for "Profile table inventory has not been accepted" to pass the test.
- [ ] 6.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_019_profile_table_inventory_has_not_been_accepted` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 6.4 Write failing test `test_customer_data_disclosure_export_020_required_or_unknown_customer_table_is_missing_or` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Required or unknown customer table is missing or present" (assert it fails for the expected reason).
- [ ] 6.5 Implement the specified behavior for "Required or unknown customer table is missing or present" to pass the test.
- [ ] 6.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_020_required_or_unknown_customer_table_is_missing_or` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.

## 7. Table Definitions (specs/db/spec.md)

- [ ] 7.1 Write failing test `test_customer_data_disclosure_export_021_all_tables_created_on_fresh_install` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "All Tables Created on Fresh Install" (assert it fails for the expected reason).
- [ ] 7.2 Implement the specified behavior for "All Tables Created on Fresh Install" to pass the test.
- [ ] 7.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_021_all_tables_created_on_fresh_install` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.4 Write failing test `test_customer_data_disclosure_export_022_pre_v9_profile_is_valid_before_later_feature_mig` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Pre-v9 profile is valid before later feature migrations" (assert it fails for the expected reason).
- [ ] 7.5 Implement the specified behavior for "Pre-v9 profile is valid before later feature migrations" to pass the test.
- [ ] 7.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_022_pre_v9_profile_is_valid_before_later_feature_mig` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.7 Write failing test `test_customer_data_disclosure_export_023_missing_v7_payment_table_is_created_by_the_v7_to` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Missing v7 payment table is created by the v7-to-v8 migration" (assert it fails for the expected reason).
- [ ] 7.8 Implement the specified behavior for "Missing v7 payment table is created by the v7-to-v8 migration" to pass the test.
- [ ] 7.9 Refactor this behavior; rerun `test_customer_data_disclosure_export_023_missing_v7_payment_table_is_created_by_the_v7_to` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.10 Write failing test `test_customer_data_disclosure_export_024_missing_payment_table_at_v8_or_later_preserves_t` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Missing payment table at v8 or later preserves the incomplete signal" (assert it fails for the expected reason).
- [ ] 7.11 Implement the specified behavior for "Missing payment table at v8 or later preserves the incomplete signal" to pass the test.
- [ ] 7.12 Refactor this behavior; rerun `test_customer_data_disclosure_export_024_missing_payment_table_at_v8_or_later_preserves_t` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.13 Write failing test `test_customer_data_disclosure_export_025_current_payment_table_repair_preserves_existing` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Current payment table repair preserves existing rows" (assert it fails for the expected reason).
- [ ] 7.14 Implement the specified behavior for "Current payment table repair preserves existing rows" to pass the test.
- [ ] 7.15 Refactor this behavior; rerun `test_customer_data_disclosure_export_025_current_payment_table_repair_preserves_existing` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.16 Write failing test `test_customer_data_disclosure_export_026_v8_to_v9_migration_adds_shared_markers_and_milea` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "V8-to-v9 migration adds shared markers and mileage tables" (assert it fails for the expected reason).
- [ ] 7.17 Implement the specified behavior for "V8-to-v9 migration adds shared markers and mileage tables" to pass the test.
- [ ] 7.18 Refactor this behavior; rerun `test_customer_data_disclosure_export_026_v8_to_v9_migration_adds_shared_markers_and_milea` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.19 Write failing test `test_customer_data_disclosure_export_027_v10_migration_adds_category_history` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "V10 migration adds category history" (assert it fails for the expected reason).
- [ ] 7.20 Implement the specified behavior for "V10 migration adds category history" to pass the test.
- [ ] 7.21 Refactor this behavior; rerun `test_customer_data_disclosure_export_027_v10_migration_adds_category_history` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.22 Write failing test `test_customer_data_disclosure_export_028_unknown_lazy_table_state_is_not_repaired_by_init` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Unknown lazy-table state is not repaired by initialization" (assert it fails for the expected reason).
- [ ] 7.23 Implement the specified behavior for "Unknown lazy-table state is not repaired by initialization" to pass the test.
- [ ] 7.24 Refactor this behavior; rerun `test_customer_data_disclosure_export_028_unknown_lazy_table_state_is_not_repaired_by_init` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.25 Write failing test `test_customer_data_disclosure_export_029_table_count_verification` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Table Count Verification" (assert it fails for the expected reason).
- [ ] 7.26 Implement the specified behavior for "Table Count Verification" to pass the test.
- [ ] 7.27 Refactor this behavior; rerun `test_customer_data_disclosure_export_029_table_count_verification` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.28 Write failing test `test_customer_data_disclosure_export_030_unknown_or_malformed_application_tables_fail_sch` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Unknown or malformed application tables fail schema health" (assert it fails for the expected reason).
- [ ] 7.29 Implement the specified behavior for "Unknown or malformed application tables fail schema health" to pass the test.
- [ ] 7.30 Refactor this behavior; rerun `test_customer_data_disclosure_export_030_unknown_or_malformed_application_tables_fail_sch` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.
- [ ] 7.31 Write failing test `test_customer_data_disclosure_export_031_missing_table_detection` in `test/core/database/customer_disclosure_schema_test.dart` for scenario "Missing Table Detection" (assert it fails for the expected reason).
- [ ] 7.32 Implement the specified behavior for "Missing Table Detection" to pass the test.
- [ ] 7.33 Refactor this behavior; rerun `test_customer_data_disclosure_export_031_missing_table_detection` in `test/core/database/customer_disclosure_schema_test.dart` and keep the full suite green.

## 8. Legacy payment rows have an explicit unknown-fingerprint policy (specs/receivable-request-fingerprint-and-conditional-writeoff/spec.md)

- [ ] 8.1 Write failing test `test_customer_data_disclosure_export_032_a_v7_lazy_table_migrates_without_changing_legacy` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "A v7 lazy table migrates without changing legacy rows" (assert it fails for the expected reason).
- [ ] 8.2 Implement the specified behavior for "A v7 lazy table migrates without changing legacy rows" to pass the test.
- [ ] 8.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_032_a_v7_lazy_table_migrates_without_changing_legacy` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.4 Write failing test `test_customer_data_disclosure_export_033_a_missing_v7_relation_table_is_created_safely` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "A missing v7 relation table is created safely" (assert it fails for the expected reason).
- [ ] 8.5 Implement the specified behavior for "A missing v7 relation table is created safely" to pass the test.
- [ ] 8.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_033_a_missing_v7_relation_table_is_created_safely` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.7 Write failing test `test_customer_data_disclosure_export_034_a_present_v7_relation_table_repairs_missing_cons` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "A present v7 relation table repairs missing constraints" (assert it fails for the expected reason).
- [ ] 8.8 Implement the specified behavior for "A present v7 relation table repairs missing constraints" to pass the test.
- [ ] 8.9 Refactor this behavior; rerun `test_customer_data_disclosure_export_034_a_present_v7_relation_table_repairs_missing_cons` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.10 Write failing test `test_customer_data_disclosure_export_035_a_duplicate_legacy_key_rolls_the_migration_back` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "A duplicate legacy key rolls the migration back" (assert it fails for the expected reason).
- [ ] 8.11 Implement the specified behavior for "A duplicate legacy key rolls the migration back" to pass the test.
- [ ] 8.12 Refactor this behavior; rerun `test_customer_data_disclosure_export_035_a_duplicate_legacy_key_rolls_the_migration_back` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.13 Write failing test `test_customer_data_disclosure_export_036_a_migration_failure_preserves_the_base_table_cou` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "A migration failure preserves the base table count" (assert it fails for the expected reason).
- [ ] 8.14 Implement the specified behavior for "A migration failure preserves the base table count" to pass the test.
- [ ] 8.15 Refactor this behavior; rerun `test_customer_data_disclosure_export_036_a_migration_failure_preserves_the_base_table_cou` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.16 Write failing test `test_customer_data_disclosure_export_037_appdatabase_post_ddl_failure_rolls_back_before_s` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "AppDatabase post-DDL failure rolls back before startup side effects" (assert it fails for the expected reason).
- [ ] 8.17 Implement the specified behavior for "AppDatabase post-DDL failure rolls back before startup side effects" to pass the test.
- [ ] 8.18 Refactor this behavior; rerun `test_customer_data_disclosure_export_037_appdatabase_post_ddl_failure_rolls_back_before_s` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.19 Write failing test `test_customer_data_disclosure_export_038_a_current_v8_profile_repairs_a_missing_feature_t` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "A current v8 profile repairs a missing feature table transactionally" (assert it fails for the expected reason).
- [ ] 8.20 Implement the specified behavior for "A current v8 profile repairs a missing feature table transactionally" to pass the test.
- [ ] 8.21 Refactor this behavior; rerun `test_customer_data_disclosure_export_038_a_current_v8_profile_repairs_a_missing_feature_t` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.22 Write failing test `test_customer_data_disclosure_export_039_a_current_version_repair_preserves_a_present_pay` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "A current-version repair preserves a present payment table" (assert it fails for the expected reason).
- [ ] 8.23 Implement the specified behavior for "A current-version repair preserves a present payment table" to pass the test.
- [ ] 8.24 Refactor this behavior; rerun `test_customer_data_disclosure_export_039_a_current_version_repair_preserves_a_present_pay` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.25 Write failing test `test_customer_data_disclosure_export_040_fresh_startup_schema_upgrade_current_v8_repair_a` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "Fresh startup, schema upgrade, current-v8 repair, and rollback share the raw-BEGIN migration path" (assert it fails for the expected reason).
- [ ] 8.26 Implement the specified behavior for "Fresh startup, schema upgrade, current-v8 repair, and rollback share the raw-BEGIN migration path" to pass the test.
- [ ] 8.27 Refactor this behavior; rerun `test_customer_data_disclosure_export_040_fresh_startup_schema_upgrade_current_v8_repair_a` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [ ] 8.28 Write failing test `test_customer_data_disclosure_export_041_a_request_cannot_claim_a_legacy_key` in `test/core/database/receivable_request_fingerprint_migration_test.dart` for scenario "A request cannot claim a legacy key" (assert it fails for the expected reason).
- [ ] 8.29 Implement the specified behavior for "A request cannot claim a legacy key" to pass the test.
- [ ] 8.30 Refactor this behavior; rerun `test_customer_data_disclosure_export_041_a_request_cannot_claim_a_legacy_key` in `test/core/database/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.

## 9. Customer detail exposes scoped data disclosure (specs/stammdaten/spec.md)

- [ ] 9.1 Write failing test `test_customer_data_disclosure_export_042_customer_detail_invokes_the_scoped_export_servic` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Customer detail invokes the scoped export service" (assert it fails for the expected reason).
- [ ] 9.2 Implement the specified behavior for "Customer detail invokes the scoped export service" to pass the test.
- [ ] 9.3 Refactor this behavior; rerun `test_customer_data_disclosure_export_042_customer_detail_invokes_the_scoped_export_servic` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
- [ ] 9.4 Write failing test `test_customer_data_disclosure_export_043_export_service_is_unavailable` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "Export service is unavailable" (assert it fails for the expected reason).
- [ ] 9.5 Implement the specified behavior for "Export service is unavailable" to pass the test.
- [ ] 9.6 Refactor this behavior; rerun `test_customer_data_disclosure_export_043_export_service_is_unavailable` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` and keep the full suite green.
