## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row red to green when it passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/mahnwesen/spec.md → Dunning Level Configuration | Fresh profile seeds the documented fixed-fee model | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_fresh_profile_seeds_the_documented_fixed_fee_model | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Level Configuration | Configure level with multiplier | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_configure_level_with_multiplier | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Level Configuration | Configure level without multiplier | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_configure_level_without_multiplier | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Level Configuration | Editing a level does not rewrite prior letters | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_editing_a_level_does_not_rewrite_prior_letters | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Level Configuration | Initialization preserves customized levels | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_initialization_preserves_customized_levels | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Level Configuration | Stage date uses one absolute threshold | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_stage_date_uses_one_absolute_threshold | 🔴 red |
| specs/mahnwesen/spec.md → Mahnung Snapshot | Create dunning letter | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_create_dunning_letter | 🔴 red |
| specs/mahnwesen/spec.md → Mahnung Snapshot | Rechnung changes after snapshot | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_rechnung_changes_after_snapshot | 🔴 red |
| specs/mahnwesen/spec.md → Mahnung Snapshot | No balance cannot produce a reminder | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_no_balance_cannot_produce_a_reminder | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Evaluation and Exclusions | Assisted run creates confirmed eligible reminders | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_assisted_run_creates_confirmed_eligible_reminders | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Evaluation and Exclusions | Full payment or exclusion prevents a new reminder | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_full_payment_or_exclusion_prevents_a_new_reminder | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Evaluation and Exclusions | Stage transition is exact and ordered | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_stage_transition_is_exact_and_ordered | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Evaluation and Exclusions | Repeated run does not duplicate a stage reminder | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_repeated_run_does_not_duplicate_a_stage_reminder | 🔴 red |
| specs/mahnwesen/spec.md → Late-Payment Interest Uses the Settled Open Principal | Tier transition and partial payment have deterministic cents | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_tier_transition_and_partial_payment_have_deterministic_cents | 🔴 red |
| specs/mahnwesen/spec.md → Late-Payment Interest Uses the Settled Open Principal | Full settlement stops accrual on its effective date | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_full_settlement_stops_accrual_on_its_effective_date | 🔴 red |
| specs/mahnwesen/spec.md → Late-Payment Interest Uses the Settled Open Principal | Unpaid fees are not compounded | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_unpaid_fees_are_not_compounded | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Operations Have a Typed Workspace | User reviews an eligible dunning run | test/features/mahnwesen/mahnwesen_workspace_test.dart | test_mahnwesen_user_reviews_an_eligible_dunning_run | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Operations Have a Typed Workspace | Dunning data source is unavailable | test/features/mahnwesen/mahnwesen_workspace_test.dart | test_mahnwesen_dunning_data_source_is_unavailable | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Operations Have a Typed Workspace | Narrow window remains keyboard accessible | test/features/mahnwesen/mahnwesen_workspace_test.dart | test_mahnwesen_narrow_window_remains_keyboard_accessible | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Balance Source Fails Closed | Missing or conflicting balance source blocks every balance-dependent operation | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_missing_or_conflicting_balance_source_blocks_every_balance_dependent_operation | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Balance Source Fails Closed | Invalid settlement event is not replaced by invoice totals | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_invalid_settlement_event_is_not_replaced_by_invoice_totals | 🔴 red |
| specs/mahnwesen/spec.md → Mail-Versand via SMTP | Send dunning letter | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_send_dunning_letter | 🔴 red |
| specs/mahnwesen/spec.md → Mail-Versand via SMTP | SMTP not configured | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_smtp_not_configured | 🔴 red |
| specs/mahnwesen/spec.md → Mail-Versand via SMTP | Retrying a pending letter does not create a second record | test/features/mahnwesen/mahnung_test.dart | test_mahnwesen_retrying_a_pending_letter_does_not_create_a_second_record | 🔴 red |
| specs/mahnwesen/spec.md → Invoice Dunning Level | Invoice at level 2 | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_invoice_at_level_2 | 🔴 red |
| specs/mahnwesen/spec.md → Invoice Dunning Level | Failed send does not advance the level | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_failed_send_does_not_advance_the_level | 🔴 red |
| specs/mahnwesen/spec.md → Invoice Dunning Level | Invoice payment resets level | test/features/mahnwesen/stufen_test.dart | test_mahnwesen_invoice_payment_resets_level | 🔴 red |
| specs/mahnwesen/spec.md → Collection Package | Package contains selected customer evidence | test/features/mahnwesen/collection_package_test.dart | test_mahnwesen_package_contains_selected_customer_evidence | 🔴 red |
| specs/mahnwesen/spec.md → Collection Package | Missing required artifact blocks a complete package | test/features/mahnwesen/collection_package_test.dart | test_mahnwesen_missing_required_artifact_blocks_a_complete_package | 🔴 red |
| specs/mahnwesen/spec.md → Mahnwesen Settings Singleton | Configure grace period | test/features/mahnwesen/mahnwesen_settings_test.dart | test_mahnwesen_configure_grace_period | 🔴 red |
| specs/mahnwesen/spec.md → Mahnwesen Settings Singleton | Default settings on fresh install | test/features/mahnwesen/mahnwesen_settings_test.dart | test_mahnwesen_default_settings_on_fresh_install | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Reference Documentation Matches the Runtime Contract | Documentation exposes the canonical model | test/features/mahnwesen/dunning_docs_parity_test.dart | test_mahnwesen_documentation_exposes_the_canonical_model | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Reference Documentation Matches the Runtime Contract | Percentage-fee example is rejected | test/features/mahnwesen/dunning_docs_parity_test.dart | test_mahnwesen_percentage_fee_example_is_rejected | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Reference Documentation Matches the Runtime Contract | Documentation describes stage progression | test/features/mahnwesen/dunning_docs_parity_test.dart | test_mahnwesen_documentation_describes_stage_progression | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Reference Documentation Matches the Runtime Contract | Unsupported automation and legal claims are not documented as available | test/features/mahnwesen/dunning_docs_parity_test.dart | test_mahnwesen_unsupported_automation_and_legal_claims_are_not_documented_as_available | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Every canonical route has a useful surface | test/features/routed_surface/typed_route_test.dart | test_typed_route_every_canonical_route_has_a_useful_surface | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Database outage is not an empty route | test/features/routed_surface/typed_route_test.dart | test_typed_route_database_outage_is_not_an_empty_route | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Alias matrix preserves deep links | test/features/routed_surface/typed_route_test.dart | test_typed_route_alias_matrix_preserves_deep_links | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Route matrix exposes a truthful boundary | test/features/routed_surface/typed_route_test.dart | test_typed_route_route_matrix_exposes_a_truthful_boundary | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Dunning route exposes its typed workspace | test/features/routed_surface/typed_route_test.dart | test_typed_route_dunning_route_exposes_its_typed_workspace | 🔴 red |
| specs/typed-route-workspaces/spec.md → Canonical route inventory | Dunning route database outage remains actionable | test/features/routed_surface/typed_route_test.dart | test_typed_route_dunning_route_database_outage_remains_actionable | 🔴 red |

## Coverage Notes

All 41 specification scenarios map to executable named tests and start red. Interest and balance-source implementation tasks remain gated on accepted invoice-money, settlement-event, and balanced-posting contracts. No tests were run while producing this planning artifact.
