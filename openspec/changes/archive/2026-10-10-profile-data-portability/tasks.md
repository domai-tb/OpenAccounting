## 1. Table Definitions (specs/db/spec.md)

- [x] 1.1 Write failing test `test_profile_data_portability_001_all_tables_created_on_fresh_install` in `test/db/profile_portability_schema_test.dart` for scenario "All Tables Created on Fresh Install" (assert it fails for the expected reason).
- [x] 1.2 Implement the specified behavior for "All Tables Created on Fresh Install" to pass the test.
- [x] 1.3 Refactor this behavior; rerun `test_profile_data_portability_001_all_tables_created_on_fresh_install` in `test/db/profile_portability_schema_test.dart` and keep the full suite green.
- [x] 1.4 Write failing test `test_profile_data_portability_002_pre_v13_profile_is_valid_before_marker_migration` in `test/db/profile_portability_schema_test.dart` for scenario "Pre-v13 profile is valid before the coordinated feature migration" (assert it fails for the expected reason).
- [x] 1.5 Implement the specified behavior for "Pre-v13 profile is valid before the coordinated feature migration" to pass the test.
- [x] 1.6 Refactor this behavior; rerun `test_profile_data_portability_002_pre_v13_profile_is_valid_before_marker_migration` in `test/db/profile_portability_schema_test.dart` and keep the full suite green.
- [x] 1.7 Write test `test_profile_data_portability_003_missing_v7_payment_table_is_created_by_the_v7_to` in `test/db/profile_portability_schema_test.dart` for scenario "Missing v7 payment table is created by the v7-to-v8 migration"; the existing migration behavior already satisfies it.
- [x] 1.8 Verify the specified behavior for "Missing v7 payment table is created by the v7-to-v8 migration" with the regression test.
- [x] 1.9 Refactor this behavior; rerun `test_profile_data_portability_003_missing_v7_payment_table_is_created_by_the_v7_to` in `test/db/profile_portability_schema_test.dart`; database suite passes.
- [x] 1.10 Write failing test `test_profile_data_portability_004_missing_payment_table_at_v8_or_later_preserves_the_incomplete_signal` in `test/db/profile_portability_schema_test.dart` for scenario "Missing payment table at v8 or later preserves the incomplete signal" (assert it fails for the expected reason).
- [x] 1.11 Implement the specified behavior for "Missing payment table at v8 or later preserves the incomplete signal" to pass the test.
- [x] 1.12 Refactor this behavior; rerun `test_profile_data_portability_004_missing_payment_table_at_v8_or_later_preserves_the_incomplete_signal` in `test/db/profile_portability_schema_test.dart`; database tests and analyzer pass, with only the documented baseline full-suite failure.
- [x] 1.13 Write test `test_profile_data_portability_005_current_payment_table_repair_preserves_existing` in `test/db/profile_portability_schema_test.dart` for scenario "Current payment table repair preserves existing rows"; the existing transactional repair already preserves the row.
- [x] 1.14 Verify the specified behavior for "Current payment table repair preserves existing rows" with the regression test.
- [x] 1.15 Refactor this behavior; rerun `test_profile_data_portability_005_current_payment_table_repair_preserves_existing` in `test/db/profile_portability_schema_test.dart`; database tests and analyzer pass, with only the documented baseline full-suite failure.
- [x] 1.16 Write failing test `test_profile_data_portability_006_v12_to_v13_migration_adds_shared_markers_and_mileage` in `test/db/profile_portability_schema_test.dart` for scenario "V12-to-v13 migration adds shared markers and mileage tables" (assert it fails for the expected reason).
- [x] 1.17 Implement the specified behavior for "V12-to-v13 migration adds shared markers and mileage tables" to pass the test.
- [x] 1.18 Refactor this behavior; rerun `test_profile_data_portability_006_v12_to_v13_migration_adds_shared_markers_and_mileage` in `test/db/profile_portability_schema_test.dart` and keep the full suite green.
- [x] 1.19 Write test `test_profile_data_portability_007_v9_migration_adds_category_history` in `test/db/profile_portability_schema_test.dart` for scenario "V9 migration adds category history"; the existing v9 migration already provides the behavior.
- [x] 1.20 Verify the specified behavior for "V9 migration adds category history" with the regression test.
- [x] 1.21 Refactor this behavior; rerun `test_profile_data_portability_007_v9_migration_adds_category_history` in `test/db/profile_portability_schema_test.dart`; database tests and analyzer pass, with only the documented baseline full-suite failure.
- [x] 1.22 Write failing test `test_profile_data_portability_008_unknown_lazy_table_state_is_not_repaired_by_init` in `test/db/profile_portability_schema_test.dart` for scenario "Unknown lazy-table state is not repaired by initialization" (assert it fails for the expected reason).
- [x] 1.23 Implement the specified behavior for "Unknown lazy-table state is not repaired by initialization" to pass the test.
- [x] 1.24 Refactor this behavior; rerun `test_profile_data_portability_008_unknown_lazy_table_state_is_not_repaired_by_init` in `test/db/profile_portability_schema_test.dart` and keep the full suite green.
- [x] 1.25 Write failing test `test_profile_data_portability_009_table_count_verification` in `test/db/profile_portability_schema_test.dart` for scenario "Table Count Verification" (assert it fails for the expected reason).
- [x] 1.26 Implement the specified behavior for "Table Count Verification" to pass the test.
- [x] 1.27 Refactor this behavior; rerun `test_profile_data_portability_009_table_count_verification` in `test/db/profile_portability_schema_test.dart` and keep the full suite green.
- [x] 1.28 Write failing test `test_profile_data_portability_010_unknown_or_malformed_application_tables_fail_sch` in `test/db/profile_portability_schema_test.dart` for scenario "Unknown or malformed application tables fail schema health" (assert it fails for the expected reason).
- [x] 1.29 Implement the specified behavior for "Unknown or malformed application tables fail schema health" to pass the test.
- [x] 1.30 Refactor this behavior; rerun `test_profile_data_portability_010_unknown_or_malformed_application_tables_fail_sch` in `test/db/profile_portability_schema_test.dart` and keep the full suite green.
- [x] 1.31 Write failing test `test_profile_data_portability_011_missing_table_detection` in `test/db/profile_portability_schema_test.dart` for scenario "Missing Table Detection" (assert it fails for the expected reason).
- [x] 1.32 Implement the specified behavior for "Missing Table Detection" to pass the test.
- [x] 1.33 Refactor this behavior; rerun `test_profile_data_portability_011_missing_table_detection` in `test/db/profile_portability_schema_test.dart` and keep the full suite green.

## 2. Export a complete, versioned profile archive (specs/profile-data-portability/spec.md)

- [x] 2.1 Write failing test `test_profile_data_portability_012_export_a_populated_profile` in `test/features/setup/profile_data_portability_test.dart` for scenario "Export a populated profile" (assert it fails for the expected reason).
- [x] 2.2 Implement the specified behavior for "Export a populated profile" to pass the test.
- [x] 2.3 Refactor this behavior; rerun `test_profile_data_portability_012_export_a_populated_profile` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 2.4 Write failing test `test_profile_data_portability_013_export_excludes_secrets` in `test/features/setup/profile_data_portability_test.dart` for scenario "Export excludes secrets" (assert it fails for the expected reason).
- [x] 2.5 Implement the specified behavior for "Export excludes secrets" to pass the test.
- [x] 2.6 Refactor this behavior; rerun `test_profile_data_portability_013_export_excludes_secrets` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 2.7 Write failing test `test_profile_data_portability_014_referenced_source_file_is_unavailable` in `test/features/setup/profile_data_portability_test.dart` for scenario "Referenced source file is unavailable" (assert it fails for the expected reason).
- [x] 2.8 Implement the specified behavior for "Referenced source file is unavailable" to pass the test.
- [x] 2.9 Refactor this behavior; rerun `test_profile_data_portability_014_referenced_source_file_is_unavailable` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.

## 3. Export is consistent, bounded, and safe to save (specs/profile-data-portability/spec.md)

- [x] 3.1 Write failing test `test_profile_data_portability_015_successful_export_is_verified_before_publication` in `test/features/setup/profile_data_portability_test.dart` for scenario "Successful export is verified before publication" (assert it fails for the expected reason).
- [x] 3.2 Implement the specified behavior for "Successful export is verified before publication" to pass the test.
- [x] 3.3 Refactor this behavior; rerun `test_profile_data_portability_015_successful_export_is_verified_before_publication` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 3.4 Write failing test `test_profile_data_portability_016_destination_or_validation_failure` in `test/features/setup/profile_data_portability_test.dart` for scenario "Destination or validation failure" (assert it fails for the expected reason).
- [x] 3.5 Implement the specified behavior for "Destination or validation failure" to pass the test.
- [x] 3.6 Refactor this behavior; rerun `test_profile_data_portability_016_destination_or_validation_failure` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 3.7 Write failing test `test_profile_data_portability_017_user_cancels_export` in `test/features/setup/profile_data_portability_test.dart` for scenario "User cancels export" (assert it fails for the expected reason).
- [x] 3.8 Implement the specified behavior for "User cancels export" to pass the test.
- [x] 3.9 Refactor this behavior; rerun `test_profile_data_portability_017_user_cancels_export` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.

## 4. Settings reports the exact export scope (specs/profile-data-portability/spec.md)

- [x] 4.1 Write failing test `test_profile_data_portability_018_user_distinguishes_export_types` in `test/features/setup/profile_data_portability_test.dart` for scenario "User distinguishes export types" (assert it fails for the expected reason).
- [x] 4.2 Implement the specified behavior for "User distinguishes export types" to pass the test.
- [x] 4.3 Refactor this behavior; rerun `test_profile_data_portability_018_user_distinguishes_export_types` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 4.4 Write failing test `test_profile_data_portability_019_export_action_is_unavailable` in `test/features/setup/profile_data_portability_test.dart` for scenario "Export action is unavailable" (assert it fails for the expected reason).
- [x] 4.5 Implement the specified behavior for "Export action is unavailable" to pass the test.
- [x] 4.6 Refactor this behavior; rerun `test_profile_data_portability_019_export_action_is_unavailable` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 4.7 Write failing test `test_profile_data_portability_020_erasure_policy_is_unresolved` in `test/features/setup/profile_data_portability_test.dart` for scenario "Erasure policy is unresolved" (assert it fails for the expected reason).
- [x] 4.8 Implement the specified behavior for "Erasure policy is unresolved" to pass the test.
- [x] 4.9 Refactor this behavior; rerun `test_profile_data_portability_020_erasure_policy_is_unresolved` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 4.10 Write failing test `test_profile_data_portability_021_table_inventory_or_durable_marker_is_incomplete` in `test/features/setup/profile_data_portability_test.dart` for scenario "Table inventory or durable marker is incomplete" (assert it fails for the expected reason).
- [x] 4.11 Implement the specified behavior for "Table inventory or durable marker is incomplete" to pass the test.
- [x] 4.12 Refactor this behavior; rerun `test_profile_data_portability_021_table_inventory_or_durable_marker_is_incomplete` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 4.13 Write failing test `test_profile_data_portability_022_version_12_profile_remains_valid_before_v13_migration` in `test/features/setup/profile_data_portability_test.dart` for scenario "Version-12 profile remains valid before the v13 migration" (assert it fails for the expected reason).
- [x] 4.14 Implement the specified behavior for "Version-12 profile remains valid before the v13 migration" to pass the test.
- [x] 4.15 Refactor this behavior; rerun `test_profile_data_portability_022_version_12_profile_remains_valid_before_v13_migration` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 4.16 Write failing test `test_profile_data_portability_023_missing_payment_table_is_detected_before_startup` in `test/features/setup/profile_data_portability_test.dart` for scenario "Missing payment table is detected before startup repair" (assert it fails for the expected reason).
- [x] 4.17 Implement the specified behavior for "Missing payment table is detected before startup repair" to pass the test.
- [x] 4.18 Refactor this behavior; rerun `test_profile_data_portability_023_missing_payment_table_is_detected_before_startup` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 4.19 Write failing test `test_profile_data_portability_024_mileage_and_category_tables_follow_their_migrati` in `test/features/setup/profile_data_portability_test.dart` for scenario "Mileage and category tables follow their migration versions" (assert it fails for the expected reason).
- [x] 4.20 Implement the specified behavior for "Mileage and category tables follow their migration versions" to pass the test.
- [x] 4.21 Refactor this behavior; rerun `test_profile_data_portability_024_mileage_and_category_tables_follow_their_migrati` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.
- [x] 4.22 Write failing test `test_profile_data_portability_025_excluded_file_reference_contains_no_host_path` in `test/features/setup/profile_data_portability_test.dart` for scenario "Excluded file reference contains no host path" (assert it fails for the expected reason).
- [x] 4.23 Implement the specified behavior for "Excluded file reference contains no host path" to pass the test.
- [x] 4.24 Refactor this behavior; rerun `test_profile_data_portability_025_excluded_file_reference_contains_no_host_path` in `test/features/setup/profile_data_portability_test.dart` and keep the full suite green.

## 5. Legacy payment rows have an explicit unknown-fingerprint policy (specs/receivable-request-fingerprint-and-conditional-writeoff/spec.md)

- [x] 5.1 Write failing test `test_profile_data_portability_026_a_v7_lazy_table_migrates_without_changing_legacy` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "A v7 lazy table migrates without changing legacy rows" (assert it fails for the expected reason).
- [x] 5.2 Implement the specified behavior for "A v7 lazy table migrates without changing legacy rows" to pass the test.
- [x] 5.3 Refactor this behavior; rerun `test_profile_data_portability_026_a_v7_lazy_table_migrates_without_changing_legacy` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.4 Write failing test `test_profile_data_portability_027_a_missing_v7_relation_table_is_created_safely` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "A missing v7 relation table is created safely" (assert it fails for the expected reason).
- [x] 5.5 Implement the specified behavior for "A missing v7 relation table is created safely" to pass the test.
- [x] 5.6 Refactor this behavior; rerun `test_profile_data_portability_027_a_missing_v7_relation_table_is_created_safely` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.7 Write failing test `test_profile_data_portability_028_a_present_v7_relation_table_repairs_missing_cons` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "A present v7 relation table repairs missing constraints" (assert it fails for the expected reason).
- [x] 5.8 Implement the specified behavior for "A present v7 relation table repairs missing constraints" to pass the test.
- [x] 5.9 Refactor this behavior; rerun `test_profile_data_portability_028_a_present_v7_relation_table_repairs_missing_cons` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.10 Write failing test `test_profile_data_portability_029_a_duplicate_legacy_key_rolls_the_migration_back` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "A duplicate legacy key rolls the migration back" (assert it fails for the expected reason).
- [x] 5.11 Implement the specified behavior for "A duplicate legacy key rolls the migration back" to pass the test.
- [x] 5.12 Refactor this behavior; rerun `test_profile_data_portability_029_a_duplicate_legacy_key_rolls_the_migration_back` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.13 Write failing test `test_profile_data_portability_030_a_migration_failure_preserves_the_base_table_cou` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "A migration failure preserves the base table count" (assert it fails for the expected reason).
- [x] 5.14 Implement the specified behavior for "A migration failure preserves the base table count" to pass the test.
- [x] 5.15 Refactor this behavior; rerun `test_profile_data_portability_030_a_migration_failure_preserves_the_base_table_cou` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.16 Write failing test `test_profile_data_portability_031_appdatabase_post_ddl_failure_rolls_back_before_s` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "AppDatabase post-DDL failure rolls back before startup side effects" (assert it fails for the expected reason).
- [x] 5.17 Implement the specified behavior for "AppDatabase post-DDL failure rolls back before startup side effects" to pass the test.
- [x] 5.18 Refactor this behavior; rerun `test_profile_data_portability_031_appdatabase_post_ddl_failure_rolls_back_before_s` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.19 Write failing test `test_profile_data_portability_032_a_current_version_profile_stops_on_missing_payment_table` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "A current v8 profile repairs a missing feature table transactionally" (assert it fails for the expected reason).
- [x] 5.20 Implement the specified behavior for "A current v8 profile repairs a missing feature table transactionally" to pass the test.
- [x] 5.21 Refactor this behavior; rerun `test_profile_data_portability_032_a_current_version_profile_stops_on_missing_payment_table` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.22 Write failing test `test_profile_data_portability_033_a_current_version_repair_preserves_a_present_pay` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "A current-version repair preserves a present payment table" (assert it fails for the expected reason).
- [x] 5.23 Implement the specified behavior for "A current-version repair preserves a present payment table" to pass the test.
- [x] 5.24 Refactor this behavior; rerun `test_profile_data_portability_033_a_current_version_repair_preserves_a_present_pay` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.25 Write failing test `test_profile_data_portability_034_fresh_startup_schema_upgrade_current_version_repair_and_rollback` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "Fresh startup, schema upgrade, current-v8 repair, and rollback share the raw-BEGIN migration path" (assert it fails for the expected reason).
- [x] 5.26 Implement the specified behavior for "Fresh startup, schema upgrade, current-v8 repair, and rollback share the raw-BEGIN migration path" to pass the test.
- [x] 5.27 Refactor this behavior; rerun `test_profile_data_portability_034_fresh_startup_schema_upgrade_current_version_repair_and_rollback` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
- [x] 5.28 Write failing test `test_profile_data_portability_035_a_request_cannot_claim_a_legacy_key` in `test/db/receivable_request_fingerprint_migration_test.dart` for scenario "A request cannot claim a legacy key" (assert it fails for the expected reason).
- [x] 5.29 Implement the specified behavior for "A request cannot claim a legacy key" to pass the test.
- [x] 5.30 Refactor this behavior; rerun `test_profile_data_portability_035_a_request_cannot_claim_a_legacy_key` in `test/db/receivable_request_fingerprint_migration_test.dart` and keep the full suite green.
