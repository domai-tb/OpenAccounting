## 1. Local CSV import is scoped to supported master data

- [ ] 1.1 Write failing test `test_master_data_csv_import_parse_a_mapped_customer_source` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.2 Implement `Parse a mapped customer source` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 1.3 Refactor; full suite stays green
- [ ] 1.4 Write failing test `test_master_data_csv_import_reject_an_invalid_source_before_persistence` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.5 Implement `Reject an invalid source before persistence` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 1.6 Refactor; full suite stays green
- [ ] 1.7 Write failing test `test_master_data_csv_import_choose_whether_the_first_row_is_a_header` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.8 Implement `Choose whether the first row is a header` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 1.9 Refactor; full suite stays green

## 2. Field mapping is typed and mapping templates are profile-local

- [ ] 2.1 Write failing test `test_master_data_csv_import_save_and_reuse_an_article_create_mapping` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.2 Implement `Save and reuse an article create mapping` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 2.3 Refactor; full suite stays green
- [ ] 2.4 Write failing test `test_master_data_csv_import_reject_a_conflicting_or_cross_entity_mapping` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.5 Implement `Reject a conflicting or cross-entity mapping` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 2.6 Refactor; full suite stays green
- [ ] 2.7 Write failing test `test_master_data_csv_import_keep_templates_inside_their_profile` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.8 Implement `Keep templates inside their profile` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 2.9 Refactor; full suite stays green

## 3. Preview validates every row before import

- [ ] 3.1 Write failing test `test_master_data_csv_import_review_valid_and_invalid_rows` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.2 Implement `Review valid and invalid rows` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 3.3 Refactor; full suite stays green
- [ ] 3.4 Write failing test `test_master_data_csv_import_reject_an_ambiguous_numeric_value` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.5 Implement `Reject an ambiguous numeric value` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 3.6 Refactor; full suite stays green
- [ ] 3.7 Write failing test `test_master_data_csv_import_accept_decimal_comma_after_outer_trim` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.8 Implement `Accept decimal comma after outer trim` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 3.9 Refactor; full suite stays green
- [ ] 3.10 Write failing test `test_master_data_csv_import_accept_decimal_point_after_outer_trim` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.11 Implement `Accept decimal point after outer trim` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 3.12 Refactor; full suite stays green
- [ ] 3.13 Write failing test `test_master_data_csv_import_reject_grouping_alternate_separators_exponents_and_partial_numbers` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.14 Implement `Reject grouping, alternate separators, exponents, and partial numbers` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 3.15 Refactor; full suite stays green
- [ ] 3.16 Write failing test `test_master_data_csv_import_cancel_before_confirmation` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.17 Implement `Cancel before confirmation` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 3.18 Refactor; full suite stays green

## 4. Duplicate handling never silently overwrites a record

- [ ] 4.1 Write failing test `test_master_data_csv_import_confirm_a_unique_duplicate_update` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.2 Implement `Confirm a unique duplicate update` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 4.3 Refactor; full suite stays green
- [ ] 4.4 Write failing test `test_master_data_csv_import_leave_an_ambiguous_duplicate_unchanged` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.5 Implement `Leave an ambiguous duplicate unchanged` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 4.6 Refactor; full suite stays green
- [ ] 4.7 Write failing test `test_master_data_csv_import_skip_an_existing_record_by_default` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.8 Implement `Skip an existing record by default` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 4.9 Refactor; full suite stays green

## 5. Article updates preserve paired selling prices

- [ ] 5.1 Write failing test `test_master_data_csv_import_create_an_article_from_one_selected_price_basis` from `test-plan.md` (assert it fails for the right reason)
- [ ] 5.2 Implement `Create an article from one selected price basis` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 5.3 Refactor; full suite stays green
- [ ] 5.4 Write failing test `test_master_data_csv_import_update_other_article_fields_while_preserving_prices` from `test-plan.md` (assert it fails for the right reason)
- [ ] 5.5 Implement `Update other article fields while preserving prices` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 5.6 Refactor; full suite stays green
- [ ] 5.7 Write failing test `test_master_data_csv_import_reject_supplied_price_fields_on_article_update` from `test-plan.md` (assert it fails for the right reason)
- [ ] 5.8 Implement `Reject supplied price fields on article Update` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 5.9 Refactor; full suite stays green

## 6. Confirmed imports are atomic and have no accounting side effects

- [ ] 6.1 Write failing test `test_master_data_csv_import_commit_a_reviewed_batch` from `test-plan.md` (assert it fails for the right reason)
- [ ] 6.2 Implement `Commit a reviewed batch` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 6.3 Refactor; full suite stays green
- [ ] 6.4 Write failing test `test_master_data_csv_import_roll_back_when_a_write_fails` from `test-plan.md` (assert it fails for the right reason)
- [ ] 6.5 Implement `Roll back when a write fails` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 6.6 Refactor; full suite stays green
- [ ] 6.7 Write failing test `test_master_data_csv_import_keep_import_separate_from_accounting_effects` from `test-plan.md` (assert it fails for the right reason)
- [ ] 6.8 Implement `Keep import separate from accounting effects` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 6.9 Refactor; full suite stays green

## 7. Import review follows the localized accessible workspace design

- [ ] 7.1 Write failing test `test_master_data_csv_import_review_and_confirm_with_keyboard` from `test-plan.md` (assert it fails for the right reason)
- [ ] 7.2 Implement `Review and confirm with keyboard` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 7.3 Refactor; full suite stays green
- [ ] 7.4 Write failing test `test_master_data_csv_import_show_a_localized_unavailable_state` from `test-plan.md` (assert it fails for the right reason)
- [ ] 7.5 Implement `Show a localized unavailable state` behavior from `specs/master-data-csv-import/spec.md` to pass the test above
- [ ] 7.6 Refactor; full suite stays green
