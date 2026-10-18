# Mileage Entry Workflow Test Plan

This matrix maps all 16 `mileage-entry` scenarios and all 29 `db` scenarios (45 total) to one named test target each. The nine named mileage tests already exist and were reported passing against the earlier contract; they have not been rerun against this revised contract, and their coverage of the new structured eligibility policy is not established. The other 36 tests are missing and remain planned. No missing test is reported as passing.

| Spec | Scenario | Test file | Test name | Evidence status |
|---|---|---|---|---|
| `specs/mileage-entry/spec.md` | Record a business trip | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_record_a_business_trip` | Exists; prior-contract run only, revised contract not verified |
| `specs/mileage-entry/spec.md` | Reject invalid trip facts | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_reject_invalid_trip_facts` | Exists; prior-contract run only, revised contract not verified |
| `specs/mileage-entry/spec.md` | Use the form with keyboard and supported locales | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_mileage_form_is_keyboard_operable_and_localized` | MISSING — planned, not run |
| `specs/mileage-entry/spec.md` | Preserve posted source facts | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_preserve_posted_source_facts` | Exists; prior-contract run only, revised contract not verified |
| `specs/mileage-entry/spec.md` | Editing a calculated trip invalidates its calculation | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_editing_calculated_trip_invalidates_calculation` | Exists; prior-contract run only, revised contract not verified |
| `specs/mileage-entry/spec.md` | Calculate from an approved policy | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_calculate_from_an_approved_policy` | Exists; prior-contract run only; effective dates, classes, rates, and half-up assertions need revalidation |
| `specs/mileage-entry/spec.md` | Keep an unresolved trip out of accounting | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_keep_an_unresolved_trip_out_of_accounting` | Exists; prior-contract run only, revised contract not verified |
| `specs/mileage-entry/spec.md` | Do not treat the EKS allowance as the general deduction | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_do_not_treat_the_eks_allowance_as_the_general_deduction` | Exists; prior-contract run only, revised contract not verified |
| `specs/mileage-entry/spec.md` | Post a confirmed resolved mileage expense | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_post_a_confirmed_resolved_mileage_expense` | Exists; prior-contract run only, revised contract not verified |
| `specs/mileage-entry/spec.md` | Keep posting unavailable while a prerequisite is missing | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_posting_is_unavailable_without_each_prerequisite` | MISSING — planned, not run |
| `specs/mileage-entry/spec.md` | Reject duplicate or incomplete posting | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_reject_duplicate_or_incomplete_posting` | Exists; prior-contract run only, revised contract not verified |
| `specs/mileage-entry/spec.md` | Prepare a replacement correction without changing accounting | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_prepare_replacement_correction_without_accounting_changes` | MISSING — planned, not run |
| `specs/mileage-entry/spec.md` | Apply an accepted replacement correction | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_apply_accepted_replacement_correction_atomically` | MISSING — planned, not run |
| `specs/mileage-entry/spec.md` | Undo a posted trip | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_undo_posted_trip_through_correction` | MISSING — planned, not run |
| `specs/mileage-entry/spec.md` | Keep correction execution unavailable without an accepted operation | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_correction_apply_is_unavailable_without_accepted_operation` | MISSING — planned, not run |
| `specs/mileage-entry/spec.md` | Failed or repeated correction is safe | `test/features/mileage/mileage_entry_workflow_test.dart` | `test_failed_or_repeated_correction_is_safe` | MISSING — planned, not run |
| `specs/db/spec.md` | Create mileage tables on fresh install | `test/db/mileage_schema_test.dart` | `test_create_mileage_tables_on_fresh_install` | MISSING — planned, not run |
| `specs/db/spec.md` | Reject direct inserts into finalized trip states | `test/db/mileage_schema_test.dart` | `test_reject_direct_insert_into_finalized_trip_state` | MISSING — planned, not run |
| `specs/db/spec.md` | Gate mileage migration until export inventories agree | `test/db/mileage_migration_test.dart` | `test_gate_v23_migration_until_all_dependencies_agree` | MISSING — planned, not run |
| `specs/db/spec.md` | Roll back failed mileage migration | `test/db/mileage_migration_test.dart` | `test_failed_mileage_migration_rolls_back` | MISSING — planned, not run |
| `specs/db/spec.md` | Preserve mileage data on downgrade attempt | `test/db/mileage_migration_test.dart` | `test_downgrade_rejects_without_changing_mileage_data` | MISSING — planned, not run |
| `specs/db/spec.md` | Protect posted trip facts at the database boundary | `test/db/mileage_schema_test.dart` | `test_database_rejects_mutating_or_deleting_posted_trip` | MISSING — planned, not run |
| `specs/db/spec.md` | Allow only valid trip lifecycle transitions | `test/db/mileage_schema_test.dart` | `test_database_allows_only_valid_trip_lifecycle_transitions` | MISSING — planned, not run |
| `specs/db/spec.md` | Allow posted correction transition only with a matching applied correction | `test/db/mileage_schema_test.dart` | `test_database_requires_matching_applied_correction_for_terminal_transition` | MISSING — planned, not run |
| `specs/db/spec.md` | Require the replacement to be posted before finalizing its source correction | `test/db/mileage_schema_test.dart` | `test_database_requires_posted_replacement_before_source_correction` | MISSING — planned, not run |
| `specs/db/spec.md` | Keep correction history immutable after application or cancellation | `test/db/mileage_schema_test.dart` | `test_database_keeps_applied_and_cancelled_corrections_immutable` | MISSING — planned, not run |
| `specs/db/spec.md` | Reject unlinked or invalid lifecycle transitions | `test/db/mileage_schema_test.dart` | `test_database_rejects_unlinked_or_invalid_lifecycle_transitions` | MISSING — planned, not run |
| `specs/db/spec.md` | All Tables Created on Fresh Install | `test/db/mileage_schema_health_test.dart` | `test_fresh_install_matches_versioned_table_inventory` | MISSING — planned, not run |
| `specs/db/spec.md` | Pre-v13 profile is valid before the coordinated feature migration | `test/db/mileage_schema_health_test.dart` | `test_pre_v13_profile_is_valid_before_mileage_tables_are_required` | MISSING — planned, not run |
| `specs/db/spec.md` | Pre-v9 profile is valid before later feature migrations | `test/db/mileage_schema_health_test.dart` | `test_pre_v9_profile_is_valid_before_later_tables_are_required` | MISSING — planned, not run |
| `specs/db/spec.md` | Missing v7 payment table is created by the v7-to-v8 migration | `test/db/mileage_migration_test.dart` | `test_v7_to_v8_migration_creates_missing_payment_table` | MISSING — planned, not run |
| `specs/db/spec.md` | Missing payment table at v8 or later preserves the incomplete signal | `test/db/mileage_schema_health_test.dart` | `test_missing_payment_table_at_v8_fails_before_repair` | MISSING — planned, not run |
| `specs/db/spec.md` | Current payment table repair preserves existing rows | `test/db/mileage_migration_test.dart` | `test_payment_table_repair_preserves_existing_rows` | MISSING — planned, not run |
| `specs/db/spec.md` | V12-to-v13 migration adds shared markers and mileage tables | `test/db/mileage_migration_test.dart` | `test_v12_to_v13_migration_adds_markers_and_mileage_tables` | MISSING — planned, not run |
| `specs/db/spec.md` | V9 migration adds category history | `test/db/mileage_schema_health_test.dart` | `test_v9_requires_category_history` | MISSING — planned, not run |
| `specs/db/spec.md` | Unknown lazy-table state is not repaired by initialization | `test/db/mileage_schema_health_test.dart` | `test_unknown_lazy_table_is_not_created_by_feature_initialization` | MISSING — planned, not run |
| `specs/db/spec.md` | Table Count Verification | `test/db/mileage_schema_health_test.dart` | `test_table_inventory_matches_schema_version_and_initialized_lazy_tables` | MISSING — planned, not run |
| `specs/db/spec.md` | Version-aware table count verification | `test/db/mileage_schema_health_test.dart` | `test_version_18_inventory_has_expected_table_count` | MISSING — planned, not run |
| `specs/db/spec.md` | Unknown or malformed application tables fail schema health | `test/db/mileage_schema_health_test.dart` | `test_unknown_or_malformed_application_table_fails_health` | MISSING — planned, not run |
| `specs/db/spec.md` | Missing Table Detection | `test/db/mileage_migration_test.dart` | `test_failed_required_table_creation_rolls_back_version_and_schema` | MISSING — planned, not run |
| `specs/db/spec.md` | Present document-email tables match their declared schema | `test/db/mileage_schema_health_test.dart` | `test_present_document_email_tables_require_declared_schema` | MISSING — planned, not run |
| `specs/db/spec.md` | Missing mileage tables are checked at their required version | `test/db/mileage_schema_health_test.dart` | `test_missing_mileage_table_at_v13_fails_without_repair` | MISSING — planned, not run |
| `specs/db/spec.md` | Block mileage completeness until export inventories include its tables | `test/db/mileage_export_gate_test.dart` | `test_mileage_export_completeness_waits_for_both_inventories` | MISSING — planned, not run |
| `specs/db/spec.md` | Keep exports incomplete for undeclared mileage tables | `test/db/mileage_export_gate_test.dart` | `test_export_with_undeclared_mileage_table_is_incomplete` | MISSING — planned, not run |
| `specs/db/spec.md` | v22-to-v23 migration adds eligibility fields and lifecycle enforcement | `test/db/mileage_migration_test.dart` | `test_v22_to_v23_migration_adds_eligibility_fields_and_triggers` | MISSING — planned, not run |

## Coverage and evidence notes

- Scenario count: 16 `mileage-entry` + 29 `db` = 45 mapped rows.
- Existing executable tests: 9. Their earlier 9/9 result is historical evidence only; none were rerun after this contract revision.
- Missing tests: 36 (7 feature scenarios and all 29 database scenarios). Every missing row remains explicitly unverified.
- The future test files in this matrix are targets, not existing files. OpenSpec structural validation and `git diff --check` can validate artifact structure/formatting, but cannot substitute for these behavioral tests.

## Version correction

The stale duplicate `V8-to-v9 migration adds shared markers and mileage tables` scenario was removed. Its correct table-creation coverage remains in `V12-to-v13 migration adds shared markers and mileage tables`; the distinct `V9 migration adds category history` scenario remains. The v12-to-v13 test target remains MISSING — planned, not run.
