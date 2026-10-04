## 1. Database archive state

- [ ] 1.1 Write failing test `test_fresh_profile_includes_contact_archive_columns` in `test/core/db/master_data_archive_migration_test.dart` for scenario "Fresh profile includes contact archive columns"; assert it fails for the expected behavior.
- [ ] 1.2 Implement the specified behavior for "Fresh profile includes contact archive columns" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_existing_profile_migrates_without_changing_records` in `test/core/db/master_data_archive_migration_test.dart` for scenario "Existing profile migrates without changing records"; assert it fails for the expected behavior.
- [ ] 1.5 Implement the specified behavior for "Existing profile migrates without changing records" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_archive_and_restore_preserve_customer_identity` in `test/core/db/master_data_archive_migration_test.dart` for scenario "Archive and restore preserve customer identity"; assert it fails for the expected behavior.
- [ ] 1.8 Implement the specified behavior for "Archive and restore preserve customer identity" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.

## 2. Customer and supplier workspaces

- [ ] 2.1 Write failing test `test_search_paginate_inspect_and_edit_a_supplier` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Search, paginate, inspect, and edit a supplier"; assert it fails for the expected behavior.
- [ ] 2.2 Implement the specified behavior for "Search, paginate, inspect, and edit a supplier" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_archive_a_referenced_customer` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Archive a referenced customer"; assert it fails for the expected behavior.
- [ ] 2.5 Implement the specified behavior for "Archive a referenced customer" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.7 Write failing test `test_bulk_archive_selected_suppliers` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Bulk archive selected suppliers"; assert it fails for the expected behavior.
- [ ] 2.8 Implement the specified behavior for "Bulk archive selected suppliers" to pass 2.7.
- [ ] 2.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.10 Write failing test `test_restore_an_archived_customer` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Restore an archived customer"; assert it fails for the expected behavior.
- [ ] 2.11 Implement the specified behavior for "Restore an archived customer" to pass 2.10.
- [ ] 2.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.13 Write failing test `test_existing_number_and_vat_form_behavior_is_preserved` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Existing number and VAT form behavior is preserved"; assert it fails for the expected behavior.
- [ ] 2.14 Implement the specified behavior for "Existing number and VAT form behavior is preserved" to pass 2.13.
- [ ] 2.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.16 Write failing test `test_search_or_save_fails` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Search or save fails"; assert it fails for the expected behavior.
- [ ] 2.17 Implement the specified behavior for "Search or save fails" to pass 2.16.
- [ ] 2.18 Refactor the affected code; keep the focused and full suites green.

## 3. Production master-data entry points

- [ ] 3.1 Write failing test `test_open_a_documented_master_data_workspace` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Open a documented master-data workspace"; assert it fails for the expected behavior.
- [ ] 3.2 Implement the specified behavior for "Open a documented master-data workspace" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_article_group_actions_use_the_group_service` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Article group actions use the group service"; assert it fails for the expected behavior.
- [ ] 3.5 Implement the specified behavior for "Article group actions use the group service" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.7 Write failing test `test_workspace_has_no_supported_production_data_source` in `test/features/stammdaten/master_data_workspaces_test.dart` for scenario "Workspace has no supported production data source"; assert it fails for the expected behavior.
- [ ] 3.8 Implement the specified behavior for "Workspace has no supported production data source" to pass 3.7.
- [ ] 3.9 Refactor the affected code; keep the focused and full suites green.

## 4. Typed route actions

- [ ] 4.1 Write failing test `test_settings_link_opens_a_typed_master_data_surface` in `test/core/router/master_data_routes_test.dart` for scenario "Settings link opens a typed master-data surface"; assert it fails for the expected behavior.
- [ ] 4.2 Implement the specified behavior for "Settings link opens a typed master-data surface" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_invalid_master_data_record_is_safely_reported` in `test/core/router/master_data_routes_test.dart` for scenario "Invalid master-data record is safely reported"; assert it fails for the expected behavior.
- [ ] 4.5 Implement the specified behavior for "Invalid master-data record is safely reported" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.

## 5. Canonical route inventory

- [ ] 5.1 Write failing test `test_every_canonical_route_has_a_useful_surface` in `test/core/router/master_data_routes_test.dart` for scenario "Every canonical route has a useful surface"; assert it fails for the expected behavior.
- [ ] 5.2 Implement the specified behavior for "Every canonical route has a useful surface" to pass 5.1.
- [ ] 5.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.4 Write failing test `test_contact_detail_discriminator_selects_the_correct_record_type` in `test/core/router/master_data_routes_test.dart` for scenario "Contact detail discriminator selects the correct record type"; assert it fails for the expected behavior.
- [ ] 5.5 Implement the specified behavior for "Contact detail discriminator selects the correct record type" to pass 5.4.
- [ ] 5.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.7 Write failing test `test_missing_or_invalid_contact_discriminator_does_not_guess` in `test/core/router/master_data_routes_test.dart` for scenario "Missing or invalid contact discriminator does not guess"; assert it fails for the expected behavior.
- [ ] 5.8 Implement the specified behavior for "Missing or invalid contact discriminator does not guess" to pass 5.7.
- [ ] 5.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.10 Write failing test `test_article_and_article_group_routes_use_their_typed_owner` in `test/core/router/master_data_routes_test.dart` for scenario "Article and article-group routes use their typed owner"; assert it fails for the expected behavior.
- [ ] 5.11 Implement the specified behavior for "Article and article-group routes use their typed owner" to pass 5.10.
- [ ] 5.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.13 Write failing test `test_database_outage_is_not_an_empty_route` in `test/core/router/master_data_routes_test.dart` for scenario "Database outage is not an empty route"; assert it fails for the expected behavior.
- [ ] 5.14 Implement the specified behavior for "Database outage is not an empty route" to pass 5.13.
- [ ] 5.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.16 Write failing test `test_alias_matrix_preserves_deep_links` in `test/core/router/master_data_routes_test.dart` for scenario "Alias matrix preserves deep links"; assert it fails for the expected behavior.
- [ ] 5.17 Implement the specified behavior for "Alias matrix preserves deep links" to pass 5.16.
- [ ] 5.18 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.19 Write failing test `test_route_matrix_exposes_a_truthful_boundary` in `test/core/router/master_data_routes_test.dart` for scenario "Route matrix exposes a truthful boundary"; assert it fails for the expected behavior.
- [ ] 5.20 Implement the specified behavior for "Route matrix exposes a truthful boundary" to pass 5.19.
- [ ] 5.21 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for route ownership, persistence migration, and service boundaries.
- Follow the delta specs for required behavior and failure states.
- Keep each scenario test red before implementation, then green before refactoring.
