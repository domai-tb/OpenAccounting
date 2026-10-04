## 1. backup: Platform-specific backup paths

- [ ] 1.1 Write failing test `test_linux_backup_path` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Linux backup path"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Linux backup path" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_macos_backup_path` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "macOS backup path"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "macOS backup path" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_windows_backup_path` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Windows backup path"; assert it fails for the right reason.
- [ ] 1.8 Implement the specified behavior for "Windows backup path" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.

## 2. backup: Backup scheduling

- [ ] 2.1 Write failing test `test_manual_only_skips_startup_backup` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Manual-only skips startup backup"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Manual-only skips startup backup" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_due_scheduled_backup_runs_once_after_database_readiness` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Due scheduled backup runs once after database readiness"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Due scheduled backup runs once after database readiness" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.7 Write failing test `test_recent_backup_suppresses_duplicate_startup_work` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Recent backup suppresses duplicate startup work"; assert it fails for the right reason.
- [ ] 2.8 Implement the specified behavior for "Recent backup suppresses duplicate startup work" to pass 2.7.
- [ ] 2.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.10 Write failing test `test_failed_scheduled_backup_remains_due` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Failed scheduled backup remains due"; assert it fails for the right reason.
- [ ] 2.11 Implement the specified behavior for "Failed scheduled backup remains due" to pass 2.10.
- [ ] 2.12 Refactor the affected code; keep the focused and full suites green.

## 3. backup: Restore is staged and applied before database open

- [ ] 3.1 Write failing test `test_live_settings_restore_waits_for_restart` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Live Settings restore waits for restart"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Live Settings restore waits for restart" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_startup_restore_applies_before_opening_the_database` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Startup restore applies before opening the database"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Startup restore applies before opening the database" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.7 Write failing test `test_invalid_restore_does_not_replace_the_database` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Invalid restore does not replace the database"; assert it fails for the right reason.
- [ ] 3.8 Implement the specified behavior for "Invalid restore does not replace the database" to pass 3.7.
- [ ] 3.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.10 Write failing test `test_startup_replacement_failure_restores_the_prior_database` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Startup replacement failure restores the prior database"; assert it fails for the right reason.
- [ ] 3.11 Implement the specified behavior for "Startup replacement failure restores the prior database" to pass 3.10.
- [ ] 3.12 Refactor the affected code; keep the focused and full suites green.

## 4. backup: Restore from encrypted backup

- [ ] 4.1 Write failing test `test_restore_from_encrypted_backup` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore from encrypted backup"; assert it fails for the right reason.
- [ ] 4.2 Implement the specified behavior for "Restore from encrypted backup" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_restore_with_corrupted_encrypted_backup` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore with corrupted encrypted backup"; assert it fails for the right reason.
- [ ] 4.5 Implement the specified behavior for "Restore with corrupted encrypted backup" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.7 Write failing test `test_encrypted_backup_with_wrong_passphrase_on_restore` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Encrypted backup with wrong passphrase on restore"; assert it fails for the right reason.
- [ ] 4.8 Implement the specified behavior for "Encrypted backup with wrong passphrase on restore" to pass 4.7.
- [ ] 4.9 Refactor the affected code; keep the focused and full suites green.

## 5. backup: Restore from backup

- [ ] 5.1 Write failing test `test_restore_from_local_backup` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore from local backup"; assert it fails for the right reason.
- [ ] 5.2 Implement the specified behavior for "Restore from local backup" to pass 5.1.
- [ ] 5.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.4 Write failing test `test_restore_with_missing_backup_file` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore with missing backup file"; assert it fails for the right reason.
- [ ] 5.5 Implement the specified behavior for "Restore with missing backup file" to pass 5.4.
- [ ] 5.6 Refactor the affected code; keep the focused and full suites green.

## 6. localization-settings-and-data-protection: Settings controls change live persisted application state

- [ ] 6.1 Write failing test `test_language_switch_retains_context` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Language switch retains context"; assert it fails for the right reason.
- [ ] 6.2 Implement the specified behavior for "Language switch retains context" to pass 6.1.
- [ ] 6.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.4 Write failing test `test_theme_privacy_changes_are_durable` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Theme/privacy changes are durable"; assert it fails for the right reason.
- [ ] 6.5 Implement the specified behavior for "Theme/privacy changes are durable" to pass 6.4.
- [ ] 6.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.7 Write failing test `test_supported_region_format_is_durable` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Supported region format is durable"; assert it fails for the right reason.
- [ ] 6.8 Implement the specified behavior for "Supported region format is durable" to pass 6.7.
- [ ] 6.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.10 Write failing test `test_preference_persistence_fails` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Preference persistence fails"; assert it fails for the right reason.
- [ ] 6.11 Implement the specified behavior for "Preference persistence fails" to pass 6.10.
- [ ] 6.12 Refactor the affected code; keep the focused and full suites green.

## 7. localization-settings-and-data-protection: Local-first backup and integrations report real outcomes

- [ ] 7.1 Write failing test `test_a_backup_can_be_created_and_restored` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "A backup can be created and restored"; assert it fails for the right reason.
- [ ] 7.2 Implement the specified behavior for "A backup can be created and restored" to pass 7.1.
- [ ] 7.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 7.4 Write failing test `test_integration_failure_is_truthful` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Integration failure is truthful"; assert it fails for the right reason.
- [ ] 7.5 Implement the specified behavior for "Integration failure is truthful" to pass 7.4.
- [ ] 7.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 7.7 Write failing test `test_erasure_has_no_approved_policy` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Erasure has no approved policy"; assert it fails for the right reason.
- [ ] 7.8 Implement the specified behavior for "Erasure has no approved policy" to pass 7.7.
- [ ] 7.9 Refactor the affected code; keep the focused and full suites green.

## 8. profile-workspace-lifecycle: Selection switches the running application coherently

- [ ] 8.1 Write failing test `test_user_switches_profiles` in `test/features/profile_workspace_lifecycle/settings_setup_workspace_completion_test.dart` for scenario "User switches profiles"; assert it fails for the right reason.
- [ ] 8.2 Implement the specified behavior for "User switches profiles" to pass 8.1.
- [ ] 8.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.4 Write failing test `test_active_profile_selection_is_a_no_op` in `test/features/profile_workspace_lifecycle/settings_setup_workspace_completion_test.dart` for scenario "Active profile selection is a no-op"; assert it fails for the right reason.
- [ ] 8.5 Implement the specified behavior for "Active profile selection is a no-op" to pass 8.4.
- [ ] 8.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.7 Write failing test `test_corrupt_or_unavailable_profile_is_recoverable` in `test/features/profile_workspace_lifecycle/settings_setup_workspace_completion_test.dart` for scenario "Corrupt or unavailable profile is recoverable"; assert it fails for the right reason.
- [ ] 8.8 Implement the specified behavior for "Corrupt or unavailable profile is recoverable" to pass 8.7.
- [ ] 8.9 Refactor the affected code; keep the focused and full suites green.

## 9. profiles: Separate databases per profile

- [ ] 9.1 Write failing test `test_new_profile_creates_isolated_database` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "New profile creates isolated database"; assert it fails for the right reason.
- [ ] 9.2 Implement the specified behavior for "New profile creates isolated database" to pass 9.1.
- [ ] 9.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.4 Write failing test `test_additional_profile_is_registered_without_changing_the_active_profile` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Additional profile is registered without changing the active profile"; assert it fails for the right reason.
- [ ] 9.5 Implement the specified behavior for "Additional profile is registered without changing the active profile" to pass 9.4.
- [ ] 9.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.7 Write failing test `test_profile_isolation` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Profile isolation"; assert it fails for the right reason.
- [ ] 9.8 Implement the specified behavior for "Profile isolation" to pass 9.7.
- [ ] 9.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.10 Write failing test `test_legacy_profile_catalog_is_migrated_without_data_loss` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Legacy profile catalog is migrated without data loss"; assert it fails for the right reason.
- [ ] 9.11 Implement the specified behavior for "Legacy profile catalog is migrated without data loss" to pass 9.10.
- [ ] 9.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.13 Write failing test `test_profile_selection_uses_the_registered_catalog` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Profile selection uses the registered catalog"; assert it fails for the right reason.
- [ ] 9.14 Implement the specified behavior for "Profile selection uses the registered catalog" to pass 9.13.
- [ ] 9.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.16 Write failing test `test_unregistered_active_pointer_is_not_loaded_after_restart` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Unregistered active pointer is not loaded after restart"; assert it fails for the right reason.
- [ ] 9.17 Implement the specified behavior for "Unregistered active pointer is not loaded after restart" to pass 9.16.
- [ ] 9.18 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.19 Write failing test `test_corrupted_profile_json_falls_back_to_default` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Corrupted profile.json falls back to default"; assert it fails for the right reason.
- [ ] 9.20 Implement the specified behavior for "Corrupted profile.json falls back to default" to pass 9.19.
- [ ] 9.21 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.22 Write failing test `test_corrupted_profile_catalog_with_multiple_validated_profiles` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Corrupted profile catalog with multiple validated profiles"; assert it fails for the right reason.
- [ ] 9.23 Implement the specified behavior for "Corrupted profile catalog with multiple validated profiles" to pass 9.22.
- [ ] 9.24 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.25 Write failing test `test_invalid_profile_candidates_are_preserved_but_unavailable` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Invalid profile candidates are preserved but unavailable"; assert it fails for the right reason.
- [ ] 9.26 Implement the specified behavior for "Invalid profile candidates are preserved but unavailable" to pass 9.25.
- [ ] 9.27 Refactor the affected code; keep the focused and full suites green.

## 10. profiles: Delete profile

- [ ] 10.1 Write failing test `test_delete_inactive_profile` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Delete inactive profile"; assert it fails for the right reason.
- [ ] 10.2 Implement the specified behavior for "Delete inactive profile" to pass 10.1.
- [ ] 10.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 10.4 Write failing test `test_cannot_delete_active_profile` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Cannot delete active profile"; assert it fails for the right reason.
- [ ] 10.5 Implement the specified behavior for "Cannot delete active profile" to pass 10.4.
- [ ] 10.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 10.7 Write failing test `test_delete_last_remaining_profile` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Delete last remaining profile"; assert it fails for the right reason.
- [ ] 10.8 Implement the specified behavior for "Delete last remaining profile" to pass 10.7.
- [ ] 10.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 10.10 Write failing test `test_unregistered_data_is_not_automatically_purged` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Unregistered data is not automatically purged"; assert it fails for the right reason.
- [ ] 10.11 Implement the specified behavior for "Unregistered data is not automatically purged" to pass 10.10.
- [ ] 10.12 Refactor the affected code; keep the focused and full suites green.

## 11. settings-workspace: Settings provides a designed, reachable capability index

- [ ] 11.1 Write failing test `test_user_opens_an_available_settings_section` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "User opens an available Settings section"; assert it fails for the right reason.
- [ ] 11.2 Implement the specified behavior for "User opens an available Settings section" to pass 11.1.
- [ ] 11.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 11.4 Write failing test `test_a_section_owner_is_unavailable` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "A section owner is unavailable"; assert it fails for the right reason.
- [ ] 11.5 Implement the specified behavior for "A section owner is unavailable" to pass 11.4.
- [ ] 11.6 Refactor the affected code; keep the focused and full suites green.

## 12. settings-workspace: Settings profile actions follow the canonical profile contract

- [ ] 12.1 Write failing test `test_profile_changes_show_canonical_outcomes` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Profile changes show canonical outcomes"; assert it fails for the right reason.
- [ ] 12.2 Implement the specified behavior for "Profile changes show canonical outcomes" to pass 12.1.
- [ ] 12.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 12.4 Write failing test `test_unsafe_or_failed_profile_action_is_rejected` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Unsafe or failed profile action is rejected"; assert it fails for the right reason.
- [ ] 12.5 Implement the specified behavior for "Unsafe or failed profile action is rejected" to pass 12.4.
- [ ] 12.6 Refactor the affected code; keep the focused and full suites green.

## 13. settings-workspace: Backup settings expose completed local-first operations

- [ ] 13.1 Write failing test `test_successful_local_backup_is_visible` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Successful local backup is visible"; assert it fails for the right reason.
- [ ] 13.2 Implement the specified behavior for "Successful local backup is visible" to pass 13.1.
- [ ] 13.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 13.4 Write failing test `test_backup_or_restore_fails` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Backup or restore fails"; assert it fails for the right reason.
- [ ] 13.5 Implement the specified behavior for "Backup or restore fails" to pass 13.4.
- [ ] 13.6 Refactor the affected code; keep the focused and full suites green.

## 14. settings-workspace: Settings never overstates data portability or erasure

- [ ] 14.1 Write failing test `test_supported_export_is_distinguished_from_a_full_data_dump` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Supported export is distinguished from a full data dump"; assert it fails for the right reason.
- [ ] 14.2 Implement the specified behavior for "Supported export is distinguished from a full data dump" to pass 14.1.
- [ ] 14.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 14.4 Write failing test `test_erasure_policy_is_unresolved` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Erasure policy is unresolved"; assert it fails for the right reason.
- [ ] 14.5 Implement the specified behavior for "Erasure policy is unresolved" to pass 14.4.
- [ ] 14.6 Refactor the affected code; keep the focused and full suites green.

## 15. setup-onboarding-integrity: First-run concepts are explicit and non-deceptive

- [ ] 15.1 Write failing test `test_required_first_run_decisions_are_visible` in `test/features/setup_onboarding_integrity/settings_setup_workspace_completion_test.dart` for scenario "Required first-run decisions are visible"; assert it fails for the right reason.
- [ ] 15.2 Implement the specified behavior for "Required first-run decisions are visible" to pass 15.1.
- [ ] 15.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 15.4 Write failing test `test_blank_identity_is_handled_honestly` in `test/features/setup_onboarding_integrity/settings_setup_workspace_completion_test.dart` for scenario "Blank identity is handled honestly"; assert it fails for the right reason.
- [ ] 15.5 Implement the specified behavior for "Blank identity is handled honestly" to pass 15.4.
- [ ] 15.6 Refactor the affected code; keep the focused and full suites green.

## 16. setup: Four-step wizard flow

- [ ] 16.1 Write failing test `test_setup_displays_and_saves_real_values` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Setup displays and saves real values"; assert it fails for the right reason.
- [ ] 16.2 Implement the specified behavior for "Setup displays and saves real values" to pass 16.1.
- [ ] 16.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 16.4 Write failing test `test_categories_remain_deferred_when_no_verified_catalog_exists` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Categories remain deferred when no verified catalog exists"; assert it fails for the right reason.
- [ ] 16.5 Implement the specified behavior for "Categories remain deferred when no verified catalog exists" to pass 16.4.
- [ ] 16.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 16.7 Write failing test `test_synthetic_category_rows_are_not_offered_as_configured_records` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Synthetic category rows are not offered as configured records"; assert it fails for the right reason.
- [ ] 16.8 Implement the specified behavior for "Synthetic category rows are not offered as configured records" to pass 16.7.
- [ ] 16.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 16.10 Write failing test `test_invalid_required_setup_value_blocks_progression` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Invalid required setup value blocks progression"; assert it fails for the right reason.
- [ ] 16.11 Implement the specified behavior for "Invalid required setup value blocks progression" to pass 16.10.
- [ ] 16.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 16.13 Write failing test `test_back_navigation_preserves_entered_values` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Back navigation preserves entered values"; assert it fails for the right reason.
- [ ] 16.14 Implement the specified behavior for "Back navigation preserves entered values" to pass 16.13.
- [ ] 16.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 16.16 Write failing test `test_skip_keeps_unconfigured_choices_explicit` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Skip keeps unconfigured choices explicit"; assert it fails for the right reason.
- [ ] 16.17 Implement the specified behavior for "Skip keeps unconfigured choices explicit" to pass 16.16.
- [ ] 16.18 Refactor the affected code; keep the focused and full suites green.

## 17. setup: Bank-account holder survives setup persistence

- [ ] 17.1 Write failing test `test_holder_value_is_persisted_and_reviewed` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Holder value is persisted and reviewed"; assert it fails for the right reason.
- [ ] 17.2 Implement the specified behavior for "Holder value is persisted and reviewed" to pass 17.1.
- [ ] 17.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 17.4 Write failing test `test_existing_database_receives_the_holder_field_safely` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Existing database receives the holder field safely"; assert it fails for the right reason.
- [ ] 17.5 Implement the specified behavior for "Existing database receives the holder field safely" to pass 17.4.
- [ ] 17.6 Refactor the affected code; keep the focused and full suites green.

## 18. setup: Required field validation per step

- [ ] 18.1 Write failing test `test_step_1_validation_failure` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Step 1 validation failure"; assert it fails for the right reason.
- [ ] 18.2 Implement the specified behavior for "Step 1 validation failure" to pass 18.1.
- [ ] 18.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 18.4 Write failing test `test_step_2_validation_failure` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Step 2 validation failure"; assert it fails for the right reason.
- [ ] 18.5 Implement the specified behavior for "Step 2 validation failure" to pass 18.4.
- [ ] 18.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 18.7 Write failing test `test_step_3_validation_failure` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Step 3 validation failure"; assert it fails for the right reason.
- [ ] 18.8 Implement the specified behavior for "Step 3 validation failure" to pass 18.7.
- [ ] 18.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 18.10 Write failing test `test_step_3_permits_deferred_categories_when_no_verified_catalog_exists` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Step 3 permits deferred categories when no verified catalog exists"; assert it fails for the right reason.
- [ ] 18.11 Implement the specified behavior for "Step 3 permits deferred categories when no verified catalog exists" to pass 18.10.
- [ ] 18.12 Refactor the affected code; keep the focused and full suites green.

## 19. setup: Profile selection on startup

- [ ] 19.1 Write failing test `test_multiple_profiles_exist` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Multiple profiles exist"; assert it fails for the right reason.
- [ ] 19.2 Implement the specified behavior for "Multiple profiles exist" to pass 19.1.
- [ ] 19.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 19.4 Write failing test `test_unregistered_directory_exists` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Unregistered directory exists"; assert it fails for the right reason.
- [ ] 19.5 Implement the specified behavior for "Unregistered directory exists" to pass 19.4.
- [ ] 19.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 19.7 Write failing test `test_multiple_profiles_need_catalog_recovery` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Multiple profiles need catalog recovery"; assert it fails for the right reason.
- [ ] 19.8 Implement the specified behavior for "Multiple profiles need catalog recovery" to pass 19.7.
- [ ] 19.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 19.10 Write failing test `test_single_profile_exists` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Single profile exists"; assert it fails for the right reason.
- [ ] 19.11 Implement the specified behavior for "Single profile exists" to pass 19.10.
- [ ] 19.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 19.13 Write failing test `test_profile_switching_requires_restart` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Profile switching requires restart"; assert it fails for the right reason.
- [ ] 19.14 Implement the specified behavior for "Profile switching requires restart" to pass 19.13.
- [ ] 19.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 19.16 Write failing test `test_no_profiles_exist` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "No profiles exist"; assert it fails for the right reason.
- [ ] 19.17 Implement the specified behavior for "No profiles exist" to pass 19.16.
- [ ] 19.18 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
