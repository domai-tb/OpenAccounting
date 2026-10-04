## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/bank-import/spec.md → Score-Based Matching | High-confidence match | test/features/bank_import/bank_import_service_test.dart | test_high_confidence_match | 🟢 green |
| specs/bank-import/spec.md → Score-Based Matching | No match | test/features/bank_import/bank_import_service_test.dart | test_no_match | 🟢 green |
| specs/bank-import/spec.md → Score-Based Matching | Tied top candidates are not auto-linked | test/features/bank_import/bank_import_service_test.dart | test_tied_top_candidates_are_not_auto_linked | 🟢 green |
| specs/bank-import/spec.md → Score-Based Matching | Candidate query failure is not a no-match | test/features/bank_import/bank_import_service_test.dart | test_candidate_query_failure_is_not_a_no_match | 🟢 green |
| specs/bank-import/spec.md → Auto-Filter Rule CRUD | Create filter rule | test/features/bank_import/category_rule_repository_test.dart | test_create_filter_rule | 🟢 green |
| specs/bank-import/spec.md → Auto-Filter Rule CRUD | Reject an invalid filter rule | test/features/bank_import/category_rule_repository_test.dart | test_reject_an_invalid_filter_rule | 🟢 green |
| specs/bank-import/spec.md → Auto-Filter Rule CRUD | Equal-priority rules use rule ID order | test/features/bank_import/category_rule_repository_test.dart | test_equal_priority_rules_use_rule_id_order | 🟢 green |
| specs/bank-import/spec.md → Auto-Filter Rule CRUD | Edit and prioritize a rule | test/features/bank_import/category_rule_repository_test.dart | test_edit_and_prioritize_a_rule | 🟢 green |
| specs/bank-import/spec.md → Auto-Filter Rule CRUD | Delete filter rule | test/features/bank_import/category_rule_repository_test.dart | test_delete_filter_rule | 🟢 green |
| specs/bank-import/spec.md → Custom Template Creation | Create custom template | test/features/bank_import/custom_template_repository_test.dart | test_create_custom_template | 🟢 green |
| specs/bank-import/spec.md → Custom Template Creation | Reject invalid or colliding custom template | test/features/bank_import/custom_template_repository_test.dart | test_reject_invalid_or_colliding_custom_template | 🟢 green |
| specs/bank-import/spec.md → Custom Template Creation | Edit existing template | test/features/bank_import/custom_template_repository_test.dart | test_edit_existing_template | 🟢 green |
| specs/bank-import/spec.md → Custom Template Creation | Predefined templates are protected | test/features/bank_import/custom_template_repository_test.dart | test_predefined_templates_are_protected | 🟢 green |
| specs/bank-import/spec.md → Manual vs Automatic Mode | Missing profile mode defaults to manual | test/features/bank_import/import_mode_migration_test.dart | test_missing_profile_mode_defaults_to_manual | 🟢 green |
| specs/bank-import/spec.md → Manual vs Automatic Mode | Version-9 profile migrates without changing company data | test/features/bank_import/import_mode_migration_test.dart | test_version_9_profile_migrates_without_changing_company_data | 🟢 green |
| specs/bank-import/spec.md → Manual vs Automatic Mode | Failed mode migration rolls back | test/features/bank_import/import_mode_migration_test.dart | test_failed_mode_migration_rolls_back | 🟢 green |
| specs/bank-import/spec.md → Manual vs Automatic Mode | Automatic mode | test/features/bank_import/import_mode_test.dart | test_automatic_mode | 🟢 green |
| specs/bank-import/spec.md → Manual vs Automatic Mode | Manual mode | test/features/bank_import/import_mode_test.dart | test_manual_mode | 🟢 green |
| specs/bank-import/spec.md → Manual vs Automatic Mode | Import mode remains profile-scoped | test/features/bank_import/import_mode_migration_test.dart | test_import_mode_remains_profile_scoped | 🟢 green |
| specs/bank-import/spec.md → Per-Session Import Mode Override | Override for single import | test/features/bank_import/import_mode_test.dart | test_override_for_single_import | 🟢 green |
| specs/bank-import/spec.md → Per-Session Import Mode Override | Override does not persist | test/features/bank_import/import_mode_test.dart | test_override_does_not_persist | 🟢 green |
| specs/bank-import/spec.md → Banking workspace follows the design system | Banking resolves the typed use case | test/features/routed_surface/bank_import_test.dart | test_banking_resolves_the_typed_use_case | 🔴 red |
| specs/bank-import/spec.md → Banking workspace follows the design system | Rule controls work from the keyboard | test/features/routed_surface/bank_import_test.dart | test_rule_controls_work_from_the_keyboard | 🔴 red |
| specs/bank-import/spec.md → Banking workspace follows the design system | History and review controls work from the keyboard | test/features/routed_surface/bank_import_test.dart | test_history_and_review_controls_work_from_the_keyboard | 🔴 red |
| specs/bank-import/spec.md → Banking workspace follows the design system | Narrow banking window keeps actions reachable | test/features/routed_surface/bank_import_test.dart | test_narrow_banking_window_keeps_actions_reachable | 🔴 red |
| specs/bank-import/spec.md → Banking workspace follows the design system | Desktop banking views expose localized accessible controls | test/features/routed_surface/bank_import_test.dart | test_desktop_banking_views_expose_localized_accessible_controls | 🔴 red |
| specs/bank-import/spec.md → Bank Transactions Table | Transaction linked to journal entry | test/features/bank_import/bank_import_service_test.dart | test_transaction_linked_to_journal_entry | 🔴 red |
| specs/bank-import/spec.md → Bank Transactions Table | Transaction stored without journal link | test/features/bank_import/bank_import_service_test.dart | test_transaction_stored_without_journal_link | 🔴 red |
| specs/bank-import/spec.md → Bank Transactions Table | Import assigns row review status from its decisions | test/features/bank_import/bank_import_service_test.dart | test_import_assigns_row_review_status_from_its_decisions | 🔴 red |
| specs/bank-import/spec.md → Bank Transactions Table | Automatic mode does not link a low-confidence candidate | test/features/bank_import/bank_import_service_test.dart | test_automatic_mode_does_not_link_a_low_confidence_candidate | 🟢 green |
| specs/bank-import/spec.md → Bank Transactions Table | Explicit review closes a new row | test/features/bank_import/bank_import_service_test.dart | test_explicit_review_closes_a_new_row | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | History row opens details | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_history_row_opens_details | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Empty history offers import | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_empty_history_offers_import | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Status policy controls actions | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_status_policy_controls_actions | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Retry resumes persisted failed rows under the original identity | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_retry_resumes_persisted_failed_rows_under_the_original_identity | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Repeated retry processes only remaining failures | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_repeated_retry_processes_only_remaining_failures | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Retried row becomes duplicate | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_retried_row_becomes_duplicate | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Duplicate-only import completes | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_duplicate_only_import_completes | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Legacy, malformed, and unsupported payloads are not guessed | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_legacy_malformed_and_unsupported_payloads_are_not_guessed | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Rejected whole-file attempt cannot be retried from history | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_rejected_whole_file_attempt_cannot_be_retried_from_history | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Rule-categorized, manually categorized, linked, and reviewed rows have distinct states | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_rule_categorized_manually_categorized_linked_and_reviewed_rows_have_distinct_states | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Untouched rule suggestion remains distinguishable from a user choice | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_untouched_rule_suggestion_remains_distinguishable_from_a_user_choice | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Review state is scoped across completed and partial attempts | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_review_state_is_scoped_across_completed_and_partial_attempts | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Manual review is scoped to the selected import | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_manual_review_is_scoped_to_the_selected_import | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Reviewing a row removes it from the unresolved set | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_reviewing_a_row_removes_it_from_the_unresolved_set | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Completed attempt metadata stays immutable while child review remains available | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_completed_attempt_metadata_stays_immutable_while_child_review_remains_available | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Manual review does not create a posting | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_manual_review_does_not_create_a_posting | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Retry failure leaves the prior attempt usable | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_retry_failure_leaves_the_prior_attempt_usable | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | History search filters before stable pagination | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_history_search_filters_before_stable_pagination | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | Detail return restores the same history query | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_detail_return_restores_the_same_history_query | 🔴 red |
| specs/bank-import-recovery-surface/spec.md → Import history is actionable | History keyboard actions preserve focus | test/integration/audit/bank-import-confidence-and-rule-workspace_test.dart | test_history_keyboard_actions_preserve_focus | 🔴 red |
<!-- Non-executable change (docs/config/schema): map to a mechanical check instead. -->
<!-- | specs/<cap>/spec.md → <Requirement Name> | <Scenario Name> | openspec schema validate anvil | schema-validates | N/A — non-executable | -->

## Coverage Notes

<!-- Any notes on test infrastructure, shared fixtures, or test utilities needed. -->
<!-- For N/A — non-executable entries, justify why no code test exists and name the check that gates the change. -->

All 51 executable scenarios across both delta specs have named Flutter tests. The paths distinguish repository/migration, service, route, and persisted recovery coverage. Every row starts red; no tests were run while preparing this plan.
