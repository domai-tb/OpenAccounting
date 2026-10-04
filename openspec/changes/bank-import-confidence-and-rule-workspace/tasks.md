# Implementation Tasks

Each scenario follows red-green-refactor order. Keep import and retry writes atomic, profile-scoped, and behind the typed repository boundary defined in `design.md`.

## 1. Score-Based Matching

- [ ] 1.1 Write failing test: `test_high_confidence_match` in `test/features/bank_import/bank_import_service_test.dart` for “High-confidence match” (assert it fails for the right reason).
- [ ] 1.2 Implement the behavior specified by “High-confidence match” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 1.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 1.4 Write failing test: `test_no_match` in `test/features/bank_import/bank_import_service_test.dart` for “No match” (assert it fails for the right reason).
- [ ] 1.5 Implement the behavior specified by “No match” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 1.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 1.7 Write failing test: `test_tied_top_candidates_are_not_auto_linked` in `test/features/bank_import/bank_import_service_test.dart` for “Tied top candidates are not auto-linked” (assert it fails for the right reason).
- [ ] 1.8 Implement the behavior specified by “Tied top candidates are not auto-linked” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 1.9 Refactor the related code; focused tests and the full suite stay green.
- [ ] 1.10 Write failing test: `test_candidate_query_failure_is_not_a_no_match` in `test/features/bank_import/bank_import_service_test.dart` for “Candidate query failure is not a no-match” (assert it fails for the right reason).
- [ ] 1.11 Implement the behavior specified by “Candidate query failure is not a no-match” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 1.12 Refactor the related code; focused tests and the full suite stay green.

## 2. Auto-Filter Rule CRUD

- [x] 2.1 Write failing test: `test_create_filter_rule` in `test/features/bank_import/category_rule_repository_test.dart` for “Create filter rule” (assert it fails for the right reason).
- [x] 2.2 Implement the behavior specified by “Create filter rule” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 2.3 Refactor the related code; focused tests and the full suite stay green.
- [x] 2.4 Write failing test: `test_reject_an_invalid_filter_rule` in `test/features/bank_import/category_rule_repository_test.dart` for “Reject an invalid filter rule” (assert it fails for the right reason).
- [x] 2.5 Implement the behavior specified by “Reject an invalid filter rule” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 2.6 Refactor the related code; focused tests and the full suite stay green.
- [x] 2.7 Write failing test: `test_equal_priority_rules_use_rule_id_order` in `test/features/bank_import/category_rule_repository_test.dart` for “Equal-priority rules use rule ID order” (assert it fails for the right reason).
- [x] 2.8 Implement the behavior specified by “Equal-priority rules use rule ID order” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 2.9 Refactor the related code; focused tests and the full suite stay green.
- [x] 2.10 Write failing test: `test_edit_and_prioritize_a_rule` in `test/features/bank_import/category_rule_repository_test.dart` for “Edit and prioritize a rule” (assert it fails for the right reason).
- [x] 2.11 Implement the behavior specified by “Edit and prioritize a rule” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 2.12 Refactor the related code; focused tests and the full suite stay green.
- [x] 2.13 Write failing test: `test_delete_filter_rule` in `test/features/bank_import/category_rule_repository_test.dart` for “Delete filter rule” (assert it fails for the right reason).
- [x] 2.14 Implement the behavior specified by “Delete filter rule” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 2.15 Refactor the related code; focused tests and the full suite stay green.

## 3. Custom Template Creation

- [x] 3.1 Write failing test: `test_create_custom_template` in `test/features/bank_import/custom_template_repository_test.dart` for “Create custom template” (assert it fails for the right reason).
- [x] 3.2 Implement the behavior specified by “Create custom template” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 3.3 Refactor the related code; focused tests and the full suite stay green.
- [x] 3.4 Write failing test: `test_reject_invalid_or_colliding_custom_template` in `test/features/bank_import/custom_template_repository_test.dart` for “Reject invalid or colliding custom template” (assert it fails for the right reason).
- [x] 3.5 Implement the behavior specified by “Reject invalid or colliding custom template” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 3.6 Refactor the related code; focused tests and the full suite stay green.
- [x] 3.7 Write failing test: `test_edit_existing_template` in `test/features/bank_import/custom_template_repository_test.dart` for “Edit existing template” (assert it fails for the right reason).
- [x] 3.8 Implement the behavior specified by “Edit existing template” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 3.9 Refactor the related code; focused tests and the full suite stay green.
- [x] 3.10 Write failing test: `test_predefined_templates_are_protected` in `test/features/bank_import/custom_template_repository_test.dart` for “Predefined templates are protected” (assert it fails for the right reason).
- [x] 3.11 Implement the behavior specified by “Predefined templates are protected” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 3.12 Refactor the related code; focused tests and the full suite stay green.

## 4. Manual vs Automatic Mode

- [x] 4.1 Write failing test: `test_missing_profile_mode_defaults_to_manual` in `test/features/bank_import/import_mode_migration_test.dart` for “Missing profile mode defaults to manual” (assert it fails for the right reason).
- [x] 4.2 Implement the behavior specified by “Missing profile mode defaults to manual” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 4.3 Refactor the related code; focused tests and the full suite stay green.
- [x] 4.4 Write failing test: `test_version_9_profile_migrates_without_changing_company_data` in `test/features/bank_import/import_mode_migration_test.dart` for “Version-9 profile migrates without changing company data” (assert it fails for the right reason).
- [x] 4.5 Implement the behavior specified by “Version-9 profile migrates without changing company data” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 4.6 Refactor the related code; focused tests and the full suite stay green.
- [x] 4.7 Write failing test: `test_failed_mode_migration_rolls_back` in `test/features/bank_import/import_mode_migration_test.dart` for “Failed mode migration rolls back” (assert it fails for the right reason).
- [x] 4.8 Implement the behavior specified by “Failed mode migration rolls back” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 4.9 Refactor the related code; focused tests and the full suite stay green.
- [ ] 4.10 Write failing test: `test_automatic_mode` in `test/features/bank_import/import_mode_test.dart` for “Automatic mode” (assert it fails for the right reason).
- [ ] 4.11 Implement the behavior specified by “Automatic mode” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 4.12 Refactor the related code; focused tests and the full suite stay green.
- [ ] 4.13 Write failing test: `test_manual_mode` in `test/features/bank_import/import_mode_test.dart` for “Manual mode” (assert it fails for the right reason).
- [ ] 4.14 Implement the behavior specified by “Manual mode” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 4.15 Refactor the related code; focused tests and the full suite stay green.
- [x] 4.16 Write failing test: `test_import_mode_remains_profile_scoped` in `test/features/bank_import/import_mode_migration_test.dart` for “Import mode remains profile-scoped” (assert it fails for the right reason).
- [x] 4.17 Implement the behavior specified by “Import mode remains profile-scoped” in `specs/bank-import/spec.md` to pass the preceding test.
- [x] 4.18 Refactor the related code; focused tests and the full suite stay green.

## 5. Per-Session Import Mode Override

- [ ] 5.1 Write failing test: `test_override_for_single_import` in `test/features/bank_import/import_mode_test.dart` for “Override for single import” (assert it fails for the right reason).
- [ ] 5.2 Implement the behavior specified by “Override for single import” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 5.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 5.4 Write failing test: `test_override_does_not_persist` in `test/features/bank_import/import_mode_test.dart` for “Override does not persist” (assert it fails for the right reason).
- [ ] 5.5 Implement the behavior specified by “Override does not persist” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 5.6 Refactor the related code; focused tests and the full suite stay green.

## 6. Banking workspace follows the design system

- [ ] 6.1 Write failing test: `test_banking_resolves_the_typed_use_case` in `test/features/routed_surface/bank_import_test.dart` for “Banking resolves the typed use case” (assert it fails for the right reason).
- [ ] 6.2 Implement the behavior specified by “Banking resolves the typed use case” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 6.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 6.4 Write failing test: `test_rule_controls_work_from_the_keyboard` in `test/features/routed_surface/bank_import_test.dart` for “Rule controls work from the keyboard” (assert it fails for the right reason).
- [ ] 6.5 Implement the behavior specified by “Rule controls work from the keyboard” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 6.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 6.7 Write failing test: `test_history_and_review_controls_work_from_the_keyboard` in `test/features/routed_surface/bank_import_test.dart` for “History and review controls work from the keyboard” (assert it fails for the right reason).
- [ ] 6.8 Implement the behavior specified by “History and review controls work from the keyboard” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 6.9 Refactor the related code; focused tests and the full suite stay green.
- [ ] 6.10 Write failing test: `test_narrow_banking_window_keeps_actions_reachable` in `test/features/routed_surface/bank_import_test.dart` for “Narrow banking window keeps actions reachable” (assert it fails for the right reason).
- [ ] 6.11 Implement the behavior specified by “Narrow banking window keeps actions reachable” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 6.12 Refactor the related code; focused tests and the full suite stay green.
- [ ] 6.13 Write failing test: `test_desktop_banking_views_expose_localized_accessible_controls` in `test/features/routed_surface/bank_import_test.dart` for “Desktop banking views expose localized accessible controls” (assert it fails for the right reason).
- [ ] 6.14 Implement the behavior specified by “Desktop banking views expose localized accessible controls” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 6.15 Refactor the related code; focused tests and the full suite stay green.

## 7. Bank Transactions Table

- [ ] 7.1 Write failing test: `test_transaction_linked_to_journal_entry` in `test/features/bank_import/bank_import_service_test.dart` for “Transaction linked to journal entry” (assert it fails for the right reason).
- [ ] 7.2 Implement the behavior specified by “Transaction linked to journal entry” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 7.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 7.4 Write failing test: `test_transaction_stored_without_journal_link` in `test/features/bank_import/bank_import_service_test.dart` for “Transaction stored without journal link” (assert it fails for the right reason).
- [ ] 7.5 Implement the behavior specified by “Transaction stored without journal link” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 7.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 7.7 Write failing test: `test_import_assigns_row_review_status_from_its_decisions` in `test/features/bank_import/bank_import_service_test.dart` for “Import assigns row review status from its decisions” (assert it fails for the right reason).
- [ ] 7.8 Implement the behavior specified by “Import assigns row review status from its decisions” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 7.9 Refactor the related code; focused tests and the full suite stay green.
- [ ] 7.10 Write failing test: `test_automatic_mode_does_not_link_a_low_confidence_candidate` in `test/features/bank_import/bank_import_service_test.dart` for “Automatic mode does not link a low-confidence candidate” (assert it fails for the right reason).
- [ ] 7.11 Implement the behavior specified by “Automatic mode does not link a low-confidence candidate” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 7.12 Refactor the related code; focused tests and the full suite stay green.
- [ ] 7.13 Write failing test: `test_explicit_review_closes_a_new_row` in `test/features/bank_import/bank_import_service_test.dart` for “Explicit review closes a new row” (assert it fails for the right reason).
- [ ] 7.14 Implement the behavior specified by “Explicit review closes a new row” in `specs/bank-import/spec.md` to pass the preceding test.
- [ ] 7.15 Refactor the related code; focused tests and the full suite stay green.

## 8. Import history is actionable

- [ ] 8.1 Write failing test: `test_history_row_opens_details` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “History row opens details” (assert it fails for the right reason).
- [ ] 8.2 Implement the behavior specified by “History row opens details” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.4 Write failing test: `test_empty_history_offers_import` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Empty history offers import” (assert it fails for the right reason).
- [ ] 8.5 Implement the behavior specified by “Empty history offers import” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.7 Write failing test: `test_status_policy_controls_actions` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Status policy controls actions” (assert it fails for the right reason).
- [ ] 8.8 Implement the behavior specified by “Status policy controls actions” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.9 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.10 Write failing test: `test_retry_resumes_persisted_failed_rows_under_the_original_identity` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Retry resumes persisted failed rows under the original identity” (assert it fails for the right reason).
- [ ] 8.11 Implement the behavior specified by “Retry resumes persisted failed rows under the original identity” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.12 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.13 Write failing test: `test_repeated_retry_processes_only_remaining_failures` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Repeated retry processes only remaining failures” (assert it fails for the right reason).
- [ ] 8.14 Implement the behavior specified by “Repeated retry processes only remaining failures” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.15 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.16 Write failing test: `test_retried_row_becomes_duplicate` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Retried row becomes duplicate” (assert it fails for the right reason).
- [ ] 8.17 Implement the behavior specified by “Retried row becomes duplicate” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.18 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.19 Write failing test: `test_duplicate_only_import_completes` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Duplicate-only import completes” (assert it fails for the right reason).
- [ ] 8.20 Implement the behavior specified by “Duplicate-only import completes” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.21 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.22 Write failing test: `test_legacy_malformed_and_unsupported_payloads_are_not_guessed` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Legacy, malformed, and unsupported payloads are not guessed” (assert it fails for the right reason).
- [ ] 8.23 Implement the behavior specified by “Legacy, malformed, and unsupported payloads are not guessed” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.24 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.25 Write failing test: `test_rejected_whole_file_attempt_cannot_be_retried_from_history` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Rejected whole-file attempt cannot be retried from history” (assert it fails for the right reason).
- [ ] 8.26 Implement the behavior specified by “Rejected whole-file attempt cannot be retried from history” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.27 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.28 Write failing test: `test_rule_categorized_manually_categorized_linked_and_reviewed_rows_have_distinct_states` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Rule-categorized, manually categorized, linked, and reviewed rows have distinct states” (assert it fails for the right reason).
- [ ] 8.29 Implement the behavior specified by “Rule-categorized, manually categorized, linked, and reviewed rows have distinct states” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.30 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.31 Write failing test: `test_untouched_rule_suggestion_remains_distinguishable_from_a_user_choice` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Untouched rule suggestion remains distinguishable from a user choice” (assert it fails for the right reason).
- [ ] 8.32 Implement the behavior specified by “Untouched rule suggestion remains distinguishable from a user choice” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.33 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.34 Write failing test: `test_review_state_is_scoped_across_completed_and_partial_attempts` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Review state is scoped across completed and partial attempts” (assert it fails for the right reason).
- [ ] 8.35 Implement the behavior specified by “Review state is scoped across completed and partial attempts” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.36 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.37 Write failing test: `test_manual_review_is_scoped_to_the_selected_import` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Manual review is scoped to the selected import” (assert it fails for the right reason).
- [ ] 8.38 Implement the behavior specified by “Manual review is scoped to the selected import” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.39 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.40 Write failing test: `test_reviewing_a_row_removes_it_from_the_unresolved_set` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Reviewing a row removes it from the unresolved set” (assert it fails for the right reason).
- [ ] 8.41 Implement the behavior specified by “Reviewing a row removes it from the unresolved set” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.42 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.43 Write failing test: `test_completed_attempt_metadata_stays_immutable_while_child_review_remains_available` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Completed attempt metadata stays immutable while child review remains available” (assert it fails for the right reason).
- [ ] 8.44 Implement the behavior specified by “Completed attempt metadata stays immutable while child review remains available” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.45 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.46 Write failing test: `test_manual_review_does_not_create_a_posting` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Manual review does not create a posting” (assert it fails for the right reason).
- [ ] 8.47 Implement the behavior specified by “Manual review does not create a posting” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.48 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.49 Write failing test: `test_retry_failure_leaves_the_prior_attempt_usable` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Retry failure leaves the prior attempt usable” (assert it fails for the right reason).
- [ ] 8.50 Implement the behavior specified by “Retry failure leaves the prior attempt usable” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.51 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.52 Write failing test: `test_history_search_filters_before_stable_pagination` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “History search filters before stable pagination” (assert it fails for the right reason).
- [ ] 8.53 Implement the behavior specified by “History search filters before stable pagination” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.54 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.55 Write failing test: `test_detail_return_restores_the_same_history_query` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “Detail return restores the same history query” (assert it fails for the right reason).
- [ ] 8.56 Implement the behavior specified by “Detail return restores the same history query” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.57 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.58 Write failing test: `test_history_keyboard_actions_preserve_focus` in `test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart` for “History keyboard actions preserve focus” (assert it fails for the right reason).
- [ ] 8.59 Implement the behavior specified by “History keyboard actions preserve focus” in `specs/bank-import-recovery-surface/spec.md` to pass the preceding test.
- [ ] 8.60 Refactor the related code; focused tests and the full suite stay green.

## 9. Align the bank-import guide

- [ ] 9.1 Update `docs/04-bank-import.md` after behavior changes to match the accepted specs and implemented Dart paths; remove unsupported template, parser, schema, scoring, and posting claims.
