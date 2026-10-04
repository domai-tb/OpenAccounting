## Test Plan

<!-- Every scenario from specs/ is mapped to a concrete named test. -->
<!-- During implementation, update each state from 🔴 red to 🟢 green when the test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/db/spec.md → Customer and supplier archive state migration | Fresh profile includes contact archive columns | test/core/db/master_data_archive_migration_test.dart | test_fresh_profile_includes_contact_archive_columns | 🔴 red |
| specs/db/spec.md → Customer and supplier archive state migration | Existing profile migrates without changing records | test/core/db/master_data_archive_migration_test.dart | test_existing_profile_migrates_without_changing_records | 🔴 red |
| specs/db/spec.md → Customer and supplier archive state migration | Archive and restore preserve customer identity | test/core/db/master_data_archive_migration_test.dart | test_archive_and_restore_preserve_customer_identity | 🔴 red |
| specs/stammdaten/spec.md → Customer and supplier workspaces | Search, paginate, inspect, and edit a supplier | test/features/stammdaten/master_data_workspaces_test.dart | test_search_paginate_inspect_and_edit_a_supplier | 🔴 red |
| specs/stammdaten/spec.md → Customer and supplier workspaces | Archive a referenced customer | test/features/stammdaten/master_data_workspaces_test.dart | test_archive_a_referenced_customer | 🔴 red |
| specs/stammdaten/spec.md → Customer and supplier workspaces | Bulk archive selected suppliers | test/features/stammdaten/master_data_workspaces_test.dart | test_bulk_archive_selected_suppliers | 🔴 red |
| specs/stammdaten/spec.md → Customer and supplier workspaces | Restore an archived customer | test/features/stammdaten/master_data_workspaces_test.dart | test_restore_an_archived_customer | 🔴 red |
| specs/stammdaten/spec.md → Customer and supplier workspaces | Existing number and VAT form behavior is preserved | test/features/stammdaten/master_data_workspaces_test.dart | test_existing_number_and_vat_form_behavior_is_preserved | 🔴 red |
| specs/stammdaten/spec.md → Customer and supplier workspaces | Search or save fails | test/features/stammdaten/master_data_workspaces_test.dart | test_search_or_save_fails | 🔴 red |
| specs/stammdaten/spec.md → Production master-data entry points | Open a documented master-data workspace | test/features/stammdaten/master_data_workspaces_test.dart | test_open_a_documented_master_data_workspace | 🔴 red |
| specs/stammdaten/spec.md → Production master-data entry points | Article group actions use the group service | test/features/stammdaten/master_data_workspaces_test.dart | test_article_group_actions_use_the_group_service | 🔴 red |
| specs/stammdaten/spec.md → Production master-data entry points | Workspace has no supported production data source | test/features/stammdaten/master_data_workspaces_test.dart | test_workspace_has_no_supported_production_data_source | 🔴 red |
| specs/typed-route-workspaces/spec.md → Master-data route actions are typed and reachable | Settings link opens a typed master-data surface | test/core/router/master_data_routes_test.dart | test_settings_link_opens_a_typed_master_data_surface | 🔴 red |
| specs/typed-route-workspaces/spec.md → Master-data route actions are typed and reachable | Invalid master-data record is safely reported | test/core/router/master_data_routes_test.dart | test_invalid_master_data_record_is_safely_reported | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Every canonical route has a useful surface | test/core/router/master_data_routes_test.dart | test_every_canonical_route_has_a_useful_surface | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Contact detail discriminator selects the correct record type | test/core/router/master_data_routes_test.dart | test_contact_detail_discriminator_selects_the_correct_record_type | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Missing or invalid contact discriminator does not guess | test/core/router/master_data_routes_test.dart | test_missing_or_invalid_contact_discriminator_does_not_guess | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Article and article-group routes use their typed owner | test/core/router/master_data_routes_test.dart | test_article_and_article_group_routes_use_their_typed_owner | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Database outage is not an empty route | test/core/router/master_data_routes_test.dart | test_database_outage_is_not_an_empty_route | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Alias matrix preserves deep links | test/core/router/master_data_routes_test.dart | test_alias_matrix_preserves_deep_links | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Route matrix exposes a truthful boundary | test/core/router/master_data_routes_test.dart | test_route_matrix_exposes_a_truthful_boundary | 🔴 red |

## Coverage Notes

- All scenarios begin red and map one-to-one to a named test.
- Customer/supplier workspace behavior maps to feature-level widget or use-case tests; route scenarios map to router tests; archive migration scenarios map to database migration tests.
- The repository currently has limited test infrastructure. Implementation must add the listed tests and any needed fixtures before changing production behavior.
