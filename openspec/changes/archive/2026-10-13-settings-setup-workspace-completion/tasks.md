## 1. backup: Platform-specific backup paths

- [x] 1.1 Write failing test `test_linux_backup_path` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Linux backup path"; assert it fails for the right reason.
- [x] 1.2 Implement the specified behavior for "Linux backup path" to pass 1.1.
- [x] 1.3 Refactor the affected code; keep the focused and full suites green.
- [x] 1.4 Write failing test `test_macos_backup_path` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "macOS backup path"; assert it fails for the right reason.
- [x] 1.5 Implement the specified behavior for "macOS backup path" to pass 1.4.
- [x] 1.6 Refactor the affected code; keep the focused and full suites green.
- [x] 1.7 Write failing test `test_windows_backup_path` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Windows backup path"; assert it fails for the right reason.
- [x] 1.8 Implement the specified behavior for "Windows backup path" to pass 1.7.
- [x] 1.9 Refactor the affected code; keep the focused and full suites green.

## 2. backup: Backup scheduling

- [x] 2.1 Write failing test `test_manual_only_skips_startup_backup` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Manual-only skips startup backup"; assert it fails for the right reason.
- [x] 2.2 Implement the specified behavior for "Manual-only skips startup backup" to pass 2.1.
- [x] 2.3 Refactor the affected code; keep the focused and full suites green.
- [x] 2.4 Write failing test `test_due_scheduled_backup_runs_once_after_database_readiness` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Due scheduled backup runs once after database readiness"; assert it fails for the right reason.
- [x] 2.5 Implement the specified behavior for "Due scheduled backup runs once after database readiness" to pass 2.4.
- [x] 2.6 Refactor the affected code; keep the focused and full suites green.
- [x] 2.7 Write failing test `test_recent_backup_suppresses_duplicate_startup_work` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Recent backup suppresses duplicate startup work"; assert it fails for the right reason.
- [x] 2.8 Implement the specified behavior for "Recent backup suppresses duplicate startup work" to pass 2.7.
- [x] 2.9 Refactor the affected code; keep the focused and full suites green.
- [x] 2.10 Write failing test `test_failed_scheduled_backup_remains_due` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Failed scheduled backup remains due"; assert it fails for the right reason.
- [x] 2.11 Implement the specified behavior for "Failed scheduled backup remains due" to pass 2.10.
- [x] 2.12 Refactor the affected code; keep the focused and full suites green.

## 3. backup: Restore is staged and applied before database open

- [x] 3.1 Write failing test `test_live_settings_restore_waits_for_restart` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Live Settings restore waits for restart"; assert it fails for the right reason.
- [x] 3.2 Implement the specified behavior for "Live Settings restore waits for restart" to pass 3.1.
- [x] 3.3 Refactor the affected code; keep the focused and full suites green.
- [x] 3.4 Write failing test `test_startup_restore_applies_before_opening_the_database` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Startup restore applies before opening the database"; assert it fails for the right reason.
- [x] 3.5 Implement the specified behavior for "Startup restore applies before opening the database" to pass 3.4.
- [x] 3.6 Refactor the affected code; keep the focused and full suites green.
- [x] 3.7 Write failing test `test_invalid_restore_does_not_replace_the_database` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Invalid restore does not replace the database"; assert it fails for the right reason.
- [x] 3.8 Implement the specified behavior for "Invalid restore does not replace the database" to pass 3.7.
- [x] 3.9 Refactor the affected code; keep the focused and full suites green.
- [x] 3.10 Write failing test `test_startup_replacement_failure_restores_the_prior_database` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Startup replacement failure restores the prior database"; assert it fails for the right reason.
- [x] 3.11 Implement the specified behavior for "Startup replacement failure restores the prior database" to pass 3.10.
- [x] 3.12 Refactor the affected code; keep the focused and full suites green.
- [x] 3.13 Write failing test `test_a_second_process_cannot_open_the_same_profile` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "A second process cannot open the same profile"; assert it fails for the right reason.
- [x] 3.14 Implement the specified behavior for "A second process cannot open the same profile" to pass 3.13.
- [x] 3.15 Refactor the affected code; keep the focused and full suites green.
- [x] 3.16 Write failing test `test_restore_blocks_every_profile_mutation` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore blocks every profile mutation"; assert it fails for the right reason.
- [x] 3.17 Implement the specified behavior for "Restore blocks every profile mutation" to pass 3.16.
- [x] 3.18 Refactor the affected code; keep the focused and full suites green.
- [x] 3.19 Write failing test `test_restore_staging_failure_reopens_writes` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore staging failure reopens writes"; assert it fails for the right reason.
- [x] 3.20 Implement the specified behavior for "Restore staging failure reopens writes" to pass 3.19.
- [x] 3.21 Refactor the affected code; keep the focused and full suites green.

## 4. backup: Restore from encrypted backup

- [x] 4.1 Write failing test `test_restore_from_encrypted_backup` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore from encrypted backup"; assert it fails for the right reason.
- [x] 4.2 Implement the specified behavior for "Restore from encrypted backup" to pass 4.1.
- [x] 4.3 Refactor the affected code; keep the focused and full suites green.
- [x] 4.4 Write failing test `test_restore_with_corrupted_encrypted_backup` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore with corrupted encrypted backup"; assert it fails for the right reason.
- [x] 4.5 Implement the specified behavior for "Restore with corrupted encrypted backup" to pass 4.4.
- [x] 4.6 Refactor the affected code; keep the focused and full suites green.
- [x] 4.7 Write failing test `test_encrypted_backup_with_wrong_passphrase_on_restore` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Encrypted backup with wrong passphrase on restore"; assert it fails for the right reason.
- [x] 4.8 Implement the specified behavior for "Encrypted backup with wrong passphrase on restore" to pass 4.7.
- [x] 4.9 Refactor the affected code; keep the focused and full suites green.

## 5. backup: Restore from backup

- [x] 5.1 Write failing test `test_restore_from_local_backup` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore from local backup"; assert it fails for the right reason.
- [x] 5.2 Implement the specified behavior for "Restore from local backup" to pass 5.1.
- [x] 5.3 Refactor the affected code; keep the focused and full suites green.
- [x] 5.4 Write failing test `test_restore_with_missing_backup_file` in `test/core/backup/settings_setup_workspace_completion_test.dart` for scenario "Restore with missing backup file"; assert it fails for the right reason.
- [x] 5.5 Implement the specified behavior for "Restore with missing backup file" to pass 5.4.
- [x] 5.6 Refactor the affected code; keep the focused and full suites green.

## 6. localization-settings-and-data-protection: Settings controls change live persisted application state

- [x] 6.1 Write failing test `test_language_switch_retains_context` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Language switch retains context"; assert it fails for the right reason.
- [x] 6.2 Implement the specified behavior for "Language switch retains context" to pass 6.1.
- [x] 6.3 Refactor the affected code; keep the focused and full suites green.
- [x] 6.4 Write failing test `test_theme_privacy_changes_are_durable` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Theme/privacy changes are durable"; assert it fails for the right reason.
- [x] 6.5 Implement the specified behavior for "Theme/privacy changes are durable" to pass 6.4.
- [x] 6.6 Refactor the affected code; keep the focused and full suites green.
- [x] 6.7 Write failing test `test_supported_region_format_is_durable` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Supported region format is durable"; assert it fails for the right reason.
- [x] 6.8 Implement the specified behavior for "Supported region format is durable" to pass 6.7.
- [x] 6.9 Refactor the affected code; keep the focused and full suites green.
- [x] 6.10 Write failing test `test_preference_persistence_fails` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Preference persistence fails"; assert it fails for the right reason.
- [x] 6.11 Implement the specified behavior for "Preference persistence fails" to pass 6.10.
- [x] 6.12 Refactor the affected code; keep the focused and full suites green.

## 7. localization-settings-and-data-protection: Local-first backup and integrations report real outcomes

- [x] 7.1 Write failing test `test_a_backup_can_be_created_and_restored` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "A backup can be created and restored"; assert it fails for the right reason.
- [x] 7.2 Implement the specified behavior for "A backup can be created and restored" to pass 7.1.
- [x] 7.3 Refactor the affected code; keep the focused and full suites green.
- [x] 7.4 Write failing test `test_integration_failure_is_truthful` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Integration failure is truthful"; assert it fails for the right reason.
- [x] 7.5 Implement the specified behavior for "Integration failure is truthful" to pass 7.4.
- [x] 7.6 Refactor the affected code; keep the focused and full suites green.
- [x] 7.7 Write failing test `test_erasure_has_no_approved_policy` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Erasure has no approved policy"; assert it fails for the right reason.
- [x] 7.8 Implement the specified behavior for "Erasure has no approved policy" to pass 7.7.
- [x] 7.9 Refactor the affected code; keep the focused and full suites green.

## 8. profile-workspace-lifecycle: Selection switches the running application coherently

- [x] 8.1 Write failing test `test_user_switches_profiles` in `test/features/profile_workspace_lifecycle/settings_setup_workspace_completion_test.dart` for scenario "User switches profiles"; assert it fails for the right reason.
- [x] 8.2 Implement the specified behavior for "User switches profiles" to pass 8.1.
- [x] 8.3 Refactor the affected code; keep the focused and full suites green.
- [x] 8.4 Write failing test `test_active_profile_selection_is_a_no_op` in `test/features/profile_workspace_lifecycle/settings_setup_workspace_completion_test.dart` for scenario "Active profile selection is a no-op"; assert it fails for the right reason.
- [x] 8.5 Implement the specified behavior for "Active profile selection is a no-op" to pass 8.4.
- [x] 8.6 Refactor the affected code; keep the focused and full suites green.
- [x] 8.7 Write failing test `test_corrupt_or_unavailable_profile_is_recoverable` in `test/features/profile_workspace_lifecycle/settings_setup_workspace_completion_test.dart` for scenario "Corrupt or unavailable profile is recoverable"; assert it fails for the right reason.
- [x] 8.8 Implement the specified behavior for "Corrupt or unavailable profile is recoverable" to pass 8.7.
- [x] 8.9 Refactor the affected code; keep the focused and full suites green.

## 9. profiles: Separate databases per profile

- [x] 9.1 Write failing test `test_new_profile_creates_isolated_database` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "New profile creates isolated database"; assert it fails for the right reason.
- [x] 9.2 Implement the specified behavior for "New profile creates isolated database" to pass 9.1.
- [x] 9.3 Refactor the affected code; keep the focused and full suites green.
- [x] 9.4 Write failing test `test_additional_profile_is_registered_without_changing_the_active_profile` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Additional profile is registered without changing the active profile"; assert it fails for the right reason.
- [x] 9.5 Implement the specified behavior for "Additional profile is registered without changing the active profile" to pass 9.4.
- [x] 9.6 Refactor the affected code; keep the focused and full suites green.
- [x] 9.7 Write failing test `test_profile_isolation` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Profile isolation"; assert it fails for the right reason.
- [x] 9.8 Implement the specified behavior for "Profile isolation" to pass 9.7.
- [x] 9.9 Refactor the affected code; keep the focused and full suites green.
- [x] 9.10 Write failing test `test_legacy_profile_catalog_is_migrated_without_data_loss` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Legacy profile catalog is migrated without data loss"; assert it fails for the right reason.
- [x] 9.11 Implement the specified behavior for "Legacy profile catalog is migrated without data loss" to pass 9.10.
- [x] 9.12 Refactor the affected code; keep the focused and full suites green.
- [x] 9.13 Write failing test `test_profile_selection_uses_the_registered_catalog` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Profile selection uses the registered catalog"; assert it fails for the right reason.
- [x] 9.14 Implement the specified behavior for "Profile selection uses the registered catalog" to pass 9.13.
- [x] 9.15 Refactor the affected code; keep the focused and full suites green.
- [x] 9.16 Write failing test `test_unregistered_active_pointer_is_not_loaded_after_restart` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Unregistered active pointer is not loaded after restart"; assert it fails for the right reason.
- [x] 9.17 Implement the specified behavior for "Unregistered active pointer is not loaded after restart" to pass 9.16.
- [x] 9.18 Refactor the affected code; keep the focused and full suites green.
- [x] 9.19 Write failing test `test_corrupted_profile_json_falls_back_to_default` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Corrupted profile.json falls back to default"; assert it fails for the right reason.
- [x] 9.20 Implement the specified behavior for "Corrupted profile.json falls back to default" to pass 9.19.
- [x] 9.21 Refactor the affected code; keep the focused and full suites green.
- [x] 9.22 Write failing test `test_corrupted_profile_catalog_with_multiple_validated_profiles` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Corrupted profile catalog with multiple validated profiles"; assert it fails for the right reason.
- [x] 9.23 Implement the specified behavior for "Corrupted profile catalog with multiple validated profiles" to pass 9.22.
- [x] 9.24 Refactor the affected code; keep the focused and full suites green.
- [x] 9.25 Write failing test `test_invalid_profile_candidates_are_preserved_but_unavailable` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Invalid profile candidates are preserved but unavailable"; assert it fails for the right reason.
- [x] 9.26 Implement the specified behavior for "Invalid profile candidates are preserved but unavailable" to pass 9.25.
- [x] 9.27 Refactor the affected code; keep the focused and full suites green.
- [x] 9.28 Write failing test `test_valid_but_outdated_candidate_remains_unchanged_until_selected` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Valid but outdated candidate remains unchanged until selected"; assert it fails for the right reason.
- [x] 9.29 Implement the specified behavior for "Valid but outdated candidate remains unchanged until selected" to pass 9.28.
- [x] 9.30 Refactor the affected code; keep the focused and full suites green.

## 10. profiles: Delete profile

- [x] 10.1 Write failing test `test_delete_inactive_profile` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Delete inactive profile"; assert it fails for the right reason.
- [x] 10.2 Implement the specified behavior for "Delete inactive profile" to pass 10.1.
- [x] 10.3 Refactor the affected code; keep the focused and full suites green.
- [x] 10.4 Write failing test `test_cannot_delete_active_profile` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Cannot delete active profile"; assert it fails for the right reason.
- [x] 10.5 Implement the specified behavior for "Cannot delete active profile" to pass 10.4.
- [x] 10.6 Refactor the affected code; keep the focused and full suites green.
- [x] 10.7 Write failing test `test_delete_last_remaining_profile` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Delete last remaining profile"; assert it fails for the right reason.
- [x] 10.8 Implement the specified behavior for "Delete last remaining profile" to pass 10.7.
- [x] 10.9 Refactor the affected code; keep the focused and full suites green.
- [x] 10.10 Write failing test `test_unregistered_data_is_not_automatically_purged` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Unregistered data is not automatically purged"; assert it fails for the right reason.
- [x] 10.11 Implement the specified behavior for "Unregistered data is not automatically purged" to pass 10.10.
- [x] 10.12 Refactor the affected code; keep the focused and full suites green.

## 11. settings-workspace: Settings provides a designed, reachable capability index

- [x] 11.1 Write failing test `test_user_opens_an_available_settings_section` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "User opens an available Settings section"; assert it fails for the right reason.
- [x] 11.2 Implement the specified behavior for "User opens an available Settings section" to pass 11.1.
- [x] 11.3 Refactor the affected code; keep the focused and full suites green.
- [x] 11.4 Write failing test `test_a_section_owner_is_unavailable` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "A section owner is unavailable"; assert it fails for the right reason.
- [x] 11.5 Implement the specified behavior for "A section owner is unavailable" to pass 11.4.
- [x] 11.6 Refactor the affected code; keep the focused and full suites green.
- [x] 11.7 Write failing test `test_settings_stays_accessible_at_narrow_width_and_larger_text_scale` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Settings stays accessible at narrow width and larger text scale"; assert it fails for the right reason.
- [x] 11.8 Implement the specified behavior for "Settings stays accessible at narrow width and larger text scale" to pass 11.7.
- [x] 11.9 Refactor the affected code; keep the focused and full suites green.

## 12. settings-workspace: Settings profile actions follow the canonical profile contract

- [x] 12.1 Write failing test `test_profile_changes_show_canonical_outcomes` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Profile changes show canonical outcomes"; assert it fails for the right reason.
- [x] 12.2 Implement the specified behavior for "Profile changes show canonical outcomes" to pass 12.1.
- [x] 12.3 Refactor the affected code; keep the focused and full suites green.
- [x] 12.4 Write failing test `test_unsafe_or_failed_profile_action_is_rejected` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Unsafe or failed profile action is rejected"; assert it fails for the right reason.
- [x] 12.5 Implement the specified behavior for "Unsafe or failed profile action is rejected" to pass 12.4.
- [x] 12.6 Refactor the affected code; keep the focused and full suites green.

## 13. settings-workspace: Backup settings expose completed local-first operations

- [x] 13.1 Write failing test `test_successful_local_backup_is_visible` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Successful local backup is visible"; assert it fails for the right reason.
- [x] 13.2 Implement the specified behavior for "Successful local backup is visible" to pass 13.1.
- [x] 13.3 Refactor the affected code; keep the focused and full suites green.
- [x] 13.4 Write failing test `test_backup_or_restore_fails` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Backup or restore fails"; assert it fails for the right reason.
- [x] 13.5 Implement the specified behavior for "Backup or restore fails" to pass 13.4.
- [x] 13.6 Refactor the affected code; keep the focused and full suites green.
- [x] 13.7 Write failing test `test_backup_history_status_distinguishes_never_current_stale_and_failed` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Backup history status distinguishes never, current, stale, and failed"; assert it fails for the right reason.
- [x] 13.8 Implement the specified behavior for "Backup history status distinguishes never, current, stale, and failed" to pass 13.7.
- [x] 13.9 Refactor the affected code; keep the focused and full suites green.

## 14. settings-workspace: Settings never overstates data portability or erasure

- [x] 14.1 Write failing test `test_supported_export_is_distinguished_from_a_full_data_dump` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Supported export is distinguished from a full data dump"; assert it fails for the right reason.
- [x] 14.2 Implement the specified behavior for "Supported export is distinguished from a full data dump" to pass 14.1.
- [x] 14.3 Refactor the affected code; keep the focused and full suites green.
- [x] 14.4 Write failing test `test_erasure_policy_is_unresolved` in `test/features/settings/settings_setup_workspace_completion_test.dart` for scenario "Erasure policy is unresolved"; assert it fails for the right reason.
- [x] 14.5 Implement the specified behavior for "Erasure policy is unresolved" to pass 14.4.
- [x] 14.6 Refactor the affected code; keep the focused and full suites green.

## 15. setup-onboarding-integrity: First-run concepts are explicit and non-deceptive

- [x] 15.1 Write failing test `test_required_first_run_decisions_are_visible` in `test/features/setup_onboarding_integrity/settings_setup_workspace_completion_test.dart` for scenario "Required first-run decisions are visible"; assert it fails for the right reason.
- [x] 15.2 Implement the specified behavior for "Required first-run decisions are visible" to pass 15.1.
- [x] 15.3 Refactor the affected code; keep the focused and full suites green.
- [x] 15.4 Write failing test `test_blank_identity_is_handled_honestly` in `test/features/setup_onboarding_integrity/settings_setup_workspace_completion_test.dart` for scenario "Blank identity is handled honestly"; assert it fails for the right reason.
- [x] 15.5 Implement the specified behavior for "Blank identity is handled honestly" to pass 15.4.
- [x] 15.6 Refactor the affected code; keep the focused and full suites green.

## 16. setup: Four-step wizard flow

- [x] 16.1 Write failing test `test_setup_displays_and_saves_real_values` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Setup displays and saves real values"; assert it fails for the right reason.
- [x] 16.2 Implement the specified behavior for "Setup displays and saves real values" to pass 16.1.
- [x] 16.3 Refactor the affected code; keep the focused and full suites green.
- [x] 16.4 Write failing test `test_categories_remain_deferred_when_no_verified_catalog_exists` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Categories remain deferred when no verified catalog exists"; assert it fails for the right reason.
- [x] 16.5 Implement the specified behavior for "Categories remain deferred when no verified catalog exists" to pass 16.4.
- [x] 16.6 Refactor the affected code; keep the focused and full suites green.
- [x] 16.7 Write failing test `test_synthetic_category_rows_are_not_offered_as_configured_records` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Synthetic category rows are not offered as configured records"; assert it fails for the right reason.
- [x] 16.8 Implement the specified behavior for "Synthetic category rows are not offered as configured records" to pass 16.7.
- [x] 16.9 Refactor the affected code; keep the focused and full suites green.
- [x] 16.10 Write failing test `test_invalid_required_setup_value_blocks_progression` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Invalid required setup value blocks progression"; assert it fails for the right reason.
- [x] 16.11 Implement the specified behavior for "Invalid required setup value blocks progression" to pass 16.10.
- [x] 16.12 Refactor the affected code; keep the focused and full suites green.
- [x] 16.13 Write failing test `test_back_navigation_preserves_entered_values` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Back navigation preserves entered values"; assert it fails for the right reason.
- [x] 16.14 Implement the specified behavior for "Back navigation preserves entered values" to pass 16.13.
- [x] 16.15 Refactor the affected code; keep the focused and full suites green.
- [x] 16.16 Write failing test `test_skip_keeps_unconfigured_choices_explicit` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Skip keeps unconfigured choices explicit"; assert it fails for the right reason.
- [x] 16.17 Implement the specified behavior for "Skip keeps unconfigured choices explicit" to pass 16.16.
- [x] 16.18 Refactor the affected code; keep the focused and full suites green.
- [x] 16.19 Write failing test `test_catalog_version_without_accepted_provenance_is_not_trusted` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Catalog version without accepted provenance is not trusted"; assert it fails for the right reason.
- [x] 16.20 Implement the specified behavior for "Catalog version without accepted provenance is not trusted" to pass 16.19.
- [x] 16.21 Refactor the affected code; keep the focused and full suites green.

## 17. setup: Bank-account holder survives setup persistence

- [x] 17.1 Write failing test `test_holder_value_is_persisted_and_reviewed` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Holder value is persisted and reviewed"; assert it fails for the right reason.
- [x] 17.2 Implement the specified behavior for "Holder value is persisted and reviewed" to pass 17.1.
- [x] 17.3 Refactor the affected code; keep the focused and full suites green.
- [x] 17.4 Write failing test `test_existing_database_receives_the_holder_field_safely` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Existing database receives the holder field safely"; assert it fails for the right reason.
- [x] 17.5 Implement the specified behavior for "Existing database receives the holder field safely" to pass 17.4.
- [x] 17.6 Refactor the affected code; keep the focused and full suites green.

## 18. setup: Required field validation per step

- [x] 18.1 Write failing test `test_step_1_validation_failure` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Step 1 validation failure"; assert it fails for the right reason.
- [x] 18.2 Implement the specified behavior for "Step 1 validation failure" to pass 18.1.
- [x] 18.3 Refactor the affected code; keep the focused and full suites green.
- [x] 18.4 Write failing test `test_step_2_validation_failure` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Step 2 validation failure"; assert it fails for the right reason.
- [x] 18.5 Implement the specified behavior for "Step 2 validation failure" to pass 18.4.
- [x] 18.6 Refactor the affected code; keep the focused and full suites green.
- [x] 18.7 Write failing test `test_step_3_validation_failure` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Step 3 validation failure"; assert it fails for the right reason.
- [x] 18.8 Implement the specified behavior for "Step 3 validation failure" to pass 18.7.
- [x] 18.9 Refactor the affected code; keep the focused and full suites green.
- [x] 18.10 Write failing test `test_step_3_permits_deferred_categories_when_no_verified_catalog_exists` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Step 3 permits deferred categories when no verified catalog exists"; assert it fails for the right reason.
- [x] 18.11 Implement the specified behavior for "Step 3 permits deferred categories when no verified catalog exists" to pass 18.10.
- [x] 18.12 Refactor the affected code; keep the focused and full suites green.

## 19. setup: Profile selection on startup

- [x] 19.1 Write failing test `test_multiple_profiles_exist` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Multiple profiles exist"; assert it fails for the right reason.
- [x] 19.2 Implement the specified behavior for "Multiple profiles exist" to pass 19.1.
- [x] 19.3 Refactor the affected code; keep the focused and full suites green.
- [x] 19.4 Write failing test `test_unregistered_directory_exists` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Unregistered directory exists"; assert it fails for the right reason.
- [x] 19.5 Implement the specified behavior for "Unregistered directory exists" to pass 19.4.
- [x] 19.6 Refactor the affected code; keep the focused and full suites green.
- [x] 19.7 Write failing test `test_multiple_profiles_need_catalog_recovery` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Multiple profiles need catalog recovery"; assert it fails for the right reason.
- [x] 19.8 Implement the specified behavior for "Multiple profiles need catalog recovery" to pass 19.7.
- [x] 19.9 Refactor the affected code; keep the focused and full suites green.
- [x] 19.10 Write failing test `test_single_profile_exists` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Single profile exists"; assert it fails for the right reason.
- [x] 19.11 Implement the specified behavior for "Single profile exists" to pass 19.10.
- [x] 19.12 Refactor the affected code; keep the focused and full suites green.
- [x] 19.13 Write failing test `test_profile_switching_requires_restart` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "Profile switching requires restart"; assert it fails for the right reason.
- [x] 19.14 Implement the specified behavior for "Profile switching requires restart" to pass 19.13.
- [x] 19.15 Refactor the affected code; keep the focused and full suites green.
- [x] 19.16 Write failing test `test_no_profiles_exist` in `test/features/setup/settings_setup_workspace_completion_test.dart` for scenario "No profiles exist"; assert it fails for the right reason.
- [x] 19.17 Implement the specified behavior for "No profiles exist" to pass 19.16.
- [x] 19.18 Refactor the affected code; keep the focused and full suites green.

## 20. profiles: Safe profile names and canonical local paths

- [x] 20.1 Write failing test `test_corrupt_catalog_with_one_candidate_recovers_without_mutation` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Corrupt catalog with one candidate recovers without mutation"; assert it fails for the right reason.
- [x] 20.2 Implement the specified behavior for "Corrupt catalog with one candidate recovers without mutation" to pass 20.1.
- [x] 20.3 Refactor the affected code; keep the focused and full suites green.
- [x] 20.4 Write failing test `test_corrupt_catalog_with_multiple_candidates_requires_explicit_choice` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Corrupt catalog with multiple candidates requires explicit choice"; assert it fails for the right reason.
- [x] 20.5 Implement the specified behavior for "Corrupt catalog with multiple candidates requires explicit choice" to pass 20.4.
- [x] 20.6 Refactor the affected code; keep the focused and full suites green.

## 21. profiles: Profile switching requires restart

- [x] 21.1 Write failing test `test_switch_profile_persists_selection_and_requires_restart` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Switch profile persists selection and requires restart"; assert it fails for the right reason.
- [x] 21.2 Implement the specified behavior for "Switch profile persists selection and requires restart" to pass 21.1.
- [x] 21.3 Refactor the affected code; keep the focused and full suites green.
- [x] 21.4 Write failing test `test_switch_to_same_profile_is_a_no_op` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Switch to same profile is a no-op"; assert it fails for the right reason.
- [x] 21.5 Implement the specified behavior for "Switch to same profile is a no-op" to pass 21.4.
- [x] 21.6 Refactor the affected code; keep the focused and full suites green.
- [x] 21.7 Write failing test `test_switch_to_non_existent_profile_does_not_fall_back_to_first_available` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Switch to non-existent profile does not fall back to first available"; assert it fails for the right reason.
- [x] 21.8 Implement the specified behavior for "Switch to non-existent profile does not fall back to first available" to pass 21.7.
- [x] 21.9 Refactor the affected code; keep the focused and full suites green.
- [x] 21.10 Write failing test `test_switch_profile_follows_normative_restart` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Switch profile"; assert it fails for the right reason.
- [x] 21.11 Implement the specified behavior for "Switch profile" to pass 21.10.
- [x] 21.12 Refactor the affected code; keep the focused and full suites green.
- [x] 21.13 Write failing test `test_switch_to_nonexistent_profile_no_fallback` in `test/core/profile/settings_setup_workspace_completion_test.dart` for scenario "Switch to non-existent profile"; assert it fails for the right reason.
- [x] 21.14 Implement the specified behavior for "Switch to non-existent profile" to pass 21.13.
- [x] 21.15 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
