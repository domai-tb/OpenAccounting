# Mileage Entry Workflow Tasks

## Historical baseline record

The prior contract's 24 implementation tasks were marked complete before this revision. That record does not establish coverage or completion for the new structured eligibility facts, policy effective dates/rates, fail-closed exclusions, half-up calculation contract, v23 migration, or the corrected 45-scenario test matrix. The previous nine focused test results are recorded as historical only in `verify.md`.

## Revised-contract tests — in progress

Implementation proceeds under the user's direct 2026-10-18 authorization despite the stale Round 5 review gate. Keep the review and inventory tasks open until their requirements are resolved with evidence. The 36 missing scenario rows remain planned unless their named tests pass. Separately, the existing policy test needs contract-specific assertions before it can establish the revised policy requirement; that extension is not a missing scenario row.

### Completed bounded implementation checkpoints

- [x] Generate stable UUIDv4 trip IDs and verify persisted identity plus exact integer distance in `test_record_a_business_trip` (2026-10-18 focused run; see `verify.md`).

### `mileage-entry` tests (7 missing scenarios; 1 existing-test assertion task)

- [ ] Add `test_mileage_form_is_keyboard_operable_and_localized` in `test/features/mileage/mileage_entry_workflow_test.dart`.
- [ ] Add `test_posting_is_unavailable_without_each_prerequisite` in `test/features/mileage/mileage_entry_workflow_test.dart`.
- [ ] Add `test_prepare_replacement_correction_without_accounting_changes` in `test/features/mileage/mileage_entry_workflow_test.dart`.
- [ ] Add `test_apply_accepted_replacement_correction_atomically` in `test/features/mileage/mileage_entry_workflow_test.dart`.
- [ ] Add `test_undo_posted_trip_through_correction` in `test/features/mileage/mileage_entry_workflow_test.dart`.
- [ ] Add `test_correction_apply_is_unavailable_without_accepted_operation` in `test/features/mileage/mileage_entry_workflow_test.dart`.
- [ ] Add `test_failed_or_repeated_correction_is_safe` in `test/features/mileage/mileage_entry_workflow_test.dart`.
- [ ] Separately extend and rerun existing `test_calculate_from_an_approved_policy` to assert the v1 effective-date boundary, both supported vehicle classes and rates, exact integer half-up cent rounding, and every fail-closed eligibility exclusion. The current test predates this contract and does not establish these assertions; this is not a missing scenario row.

### `db` tests (29 missing scenarios)

- [ ] Add `test_create_mileage_tables_on_fresh_install` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_reject_direct_insert_into_finalized_trip_state` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_gate_v23_migration_until_all_dependencies_agree` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_failed_mileage_migration_rolls_back` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_downgrade_rejects_without_changing_mileage_data` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_database_rejects_mutating_or_deleting_posted_trip` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_allows_only_valid_trip_lifecycle_transitions` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_requires_matching_applied_correction_for_terminal_transition` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_requires_posted_replacement_before_source_correction` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_keeps_applied_and_cancelled_corrections_immutable` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_rejects_unlinked_or_invalid_lifecycle_transitions` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_fresh_install_matches_versioned_table_inventory` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_pre_v13_profile_is_valid_before_mileage_tables_are_required` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_pre_v9_profile_is_valid_before_later_tables_are_required` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_v7_to_v8_migration_creates_missing_payment_table` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_missing_payment_table_at_v8_fails_before_repair` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_payment_table_repair_preserves_existing_rows` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_v12_to_v13_migration_adds_markers_and_mileage_tables` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_v9_requires_category_history` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_unknown_lazy_table_is_not_created_by_feature_initialization` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_table_inventory_matches_schema_version_and_initialized_lazy_tables` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_version_18_inventory_has_expected_table_count` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_unknown_or_malformed_application_table_fails_health` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_failed_required_table_creation_rolls_back_version_and_schema` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_present_document_email_tables_require_declared_schema` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_missing_mileage_table_at_v13_fails_without_repair` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_mileage_export_completeness_waits_for_both_inventories` in `test/db/mileage_export_gate_test.dart`.
- [ ] Add `test_export_with_undeclared_mileage_table_is_incomplete` in `test/db/mileage_export_gate_test.dart`.
- [x] Add focused v22-to-v23 eligibility/lifecycle coverage in `test/db/mileage_lifecycle_migration_test.dart` (2026-10-18; three migration tests passed; exhaustive migration/lifecycle coverage remains open).

## Contract and dependency gates — open

- [x] Record Round 5's spec-only approval at `d6d441c4c4e0779c83282f5fb16b824630d89688`; this approval is invalidated by the version correction in this revision.
- [ ] Obtain fresh independent review of the corrected DB contract before dependent implementation.
- [ ] Resolve the inventory dependency with both owners: `profile-data-portability` is 46 names/v13 while `customer-data-disclosure-export` is 55 names/v19. The common inventory and version-aware presence rules remain unaccepted; keep mileage migration and complete-export claims blocked.
- [x] Reconcile the DB migration-version conflict: mileage tables and shared markers are created at v13 from v12; v9 remains the category-history migration. This closes the spec conflict only; no migration implementation is established.
- [ ] After the review and inventory gates close, implement only against this contract and update each matrix row from planned/missing to evidence-backed status after running its named test.
- [ ] Reconcile the accepted account mapping and atomic posting integration; preserve the rule that unresolved trips stay unresolved and mileage posting has no cash or VAT leg.

## Evidence discipline

- `test-plan.md` is the row-by-row 45-scenario index: The 2026-10-18 focused run passed 10 mileage workflow tests, 3 lifecycle migration tests, and 8 inventory migration tests; most rows remain missing or partial. The existing policy-test assertion task is separate from those missing rows.
- Structural OpenSpec validation and formatting checks do not prove runtime behavior, migrations, posting, or correction semantics.
- Do not mark tests complete from a proposed test name, prior review, or historical run.
