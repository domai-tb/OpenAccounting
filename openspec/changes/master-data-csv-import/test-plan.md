## Test Plan

<!-- Every scenario from specs/ is mapped to a concrete test. -->
<!-- LIVE LEDGER: flip each row from 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/master-data-csv-import/spec.md → Local CSV import is scoped to supported master data | Parse a mapped customer source | test/features/master_data_csv_import/csv_import_scope_test.dart | test_master_data_csv_import_parse_a_mapped_customer_source | 🔴 red |
| specs/master-data-csv-import/spec.md → Local CSV import is scoped to supported master data | Reject an invalid source before persistence | test/features/master_data_csv_import/csv_import_scope_test.dart | test_master_data_csv_import_reject_an_invalid_source_before_persistence | 🔴 red |
| specs/master-data-csv-import/spec.md → Local CSV import is scoped to supported master data | Choose whether the first row is a header | test/features/master_data_csv_import/csv_import_scope_test.dart | test_master_data_csv_import_choose_whether_the_first_row_is_a_header | 🔴 red |
| specs/master-data-csv-import/spec.md → Field mapping is typed and mapping templates are profile-local | Save and reuse an article create mapping | test/features/master_data_csv_import/mapping_template_test.dart | test_master_data_csv_import_save_and_reuse_an_article_create_mapping | 🔴 red |
| specs/master-data-csv-import/spec.md → Field mapping is typed and mapping templates are profile-local | Reject a conflicting or cross-entity mapping | test/features/master_data_csv_import/mapping_template_test.dart | test_master_data_csv_import_reject_a_conflicting_or_cross_entity_mapping | 🔴 red |
| specs/master-data-csv-import/spec.md → Field mapping is typed and mapping templates are profile-local | Keep templates inside their profile | test/features/master_data_csv_import/mapping_template_test.dart | test_master_data_csv_import_keep_templates_inside_their_profile | 🔴 red |
| specs/master-data-csv-import/spec.md → Preview validates every row before import | Review valid and invalid rows | test/features/master_data_csv_import/preview_test.dart | test_master_data_csv_import_review_valid_and_invalid_rows | 🔴 red |
| specs/master-data-csv-import/spec.md → Preview validates every row before import | Reject an ambiguous numeric value | test/features/master_data_csv_import/preview_test.dart | test_master_data_csv_import_reject_an_ambiguous_numeric_value | 🔴 red |
| specs/master-data-csv-import/spec.md → Preview validates every row before import | Accept decimal comma after outer trim | test/features/master_data_csv_import/preview_test.dart | test_master_data_csv_import_accept_decimal_comma_after_outer_trim | 🔴 red |
| specs/master-data-csv-import/spec.md → Preview validates every row before import | Accept decimal point after outer trim | test/features/master_data_csv_import/preview_test.dart | test_master_data_csv_import_accept_decimal_point_after_outer_trim | 🔴 red |
| specs/master-data-csv-import/spec.md → Preview validates every row before import | Reject grouping, alternate separators, exponents, and partial numbers | test/features/master_data_csv_import/preview_test.dart | test_master_data_csv_import_reject_grouping_alternate_separators_exponents_and_partial_numbers | 🔴 red |
| specs/master-data-csv-import/spec.md → Preview validates every row before import | Cancel before confirmation | test/features/master_data_csv_import/preview_test.dart | test_master_data_csv_import_cancel_before_confirmation | 🔴 red |
| specs/master-data-csv-import/spec.md → Duplicate handling never silently overwrites a record | Confirm a unique duplicate update | test/features/master_data_csv_import/duplicate_handling_test.dart | test_master_data_csv_import_confirm_a_unique_duplicate_update | 🔴 red |
| specs/master-data-csv-import/spec.md → Duplicate handling never silently overwrites a record | Leave an ambiguous duplicate unchanged | test/features/master_data_csv_import/duplicate_handling_test.dart | test_master_data_csv_import_leave_an_ambiguous_duplicate_unchanged | 🔴 red |
| specs/master-data-csv-import/spec.md → Duplicate handling never silently overwrites a record | Skip an existing record by default | test/features/master_data_csv_import/duplicate_handling_test.dart | test_master_data_csv_import_skip_an_existing_record_by_default | 🔴 red |
| specs/master-data-csv-import/spec.md → Article updates preserve paired selling prices | Create an article from one selected price basis | test/features/master_data_csv_import/article_price_test.dart | test_master_data_csv_import_create_an_article_from_one_selected_price_basis | 🔴 red |
| specs/master-data-csv-import/spec.md → Article updates preserve paired selling prices | Update other article fields while preserving prices | test/features/master_data_csv_import/article_price_test.dart | test_master_data_csv_import_update_other_article_fields_while_preserving_prices | 🔴 red |
| specs/master-data-csv-import/spec.md → Article updates preserve paired selling prices | Reject supplied price fields on article Update | test/features/master_data_csv_import/article_price_test.dart | test_master_data_csv_import_reject_supplied_price_fields_on_article_update | 🔴 red |
| specs/master-data-csv-import/spec.md → Confirmed imports are atomic and have no accounting side effects | Commit a reviewed batch | test/features/master_data_csv_import/batch_test.dart | test_master_data_csv_import_commit_a_reviewed_batch | 🔴 red |
| specs/master-data-csv-import/spec.md → Confirmed imports are atomic and have no accounting side effects | Roll back when a write fails | test/features/master_data_csv_import/batch_test.dart | test_master_data_csv_import_roll_back_when_a_write_fails | 🔴 red |
| specs/master-data-csv-import/spec.md → Confirmed imports are atomic and have no accounting side effects | Keep import separate from accounting effects | test/features/master_data_csv_import/batch_test.dart | test_master_data_csv_import_keep_import_separate_from_accounting_effects | 🔴 red |
| specs/master-data-csv-import/spec.md → Import review follows the localized accessible workspace design | Review and confirm with keyboard | test/features/master_data_csv_import/workspace_accessibility_test.dart | test_master_data_csv_import_review_and_confirm_with_keyboard | 🔴 red |
| specs/master-data-csv-import/spec.md → Import review follows the localized accessible workspace design | Show a localized unavailable state | test/features/master_data_csv_import/workspace_accessibility_test.dart | test_master_data_csv_import_show_a_localized_unavailable_state | 🔴 red |

## Coverage Notes

- Every spec scenario maps to one named executable test and starts red.
- Decimal point and decimal comma parsing, rejection grammar, and repository precision validation are covered by preview/parser tests.
- Article update tests prove supplied price and derivation fields reject the whole row without changing saved values.
- Template persistence, batch transaction rollback, and localized keyboard review use profile-backed repository and widget test fixtures.
