## 1. Dunning Level Configuration

- [ ] 1.1 Write failing test `test_mahnwesen_fresh_profile_seeds_the_documented_fixed_fee_model` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.2 Implement the `Fresh profile seeds the documented fixed-fee model` behavior from `specs/mahnwesen/spec.md` to pass 1.1
- [ ] 1.3 Refactor; full suite stays green
- [ ] 1.4 Write failing test `test_mahnwesen_configure_level_with_multiplier` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.5 Implement the `Configure level with multiplier` behavior from `specs/mahnwesen/spec.md` to pass 1.4
- [ ] 1.6 Refactor; full suite stays green
- [ ] 1.7 Write failing test `test_mahnwesen_configure_level_without_multiplier` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.8 Implement the `Configure level without multiplier` behavior from `specs/mahnwesen/spec.md` to pass 1.7
- [ ] 1.9 Refactor; full suite stays green
- [ ] 1.10 Write failing test `test_mahnwesen_editing_a_level_does_not_rewrite_prior_letters` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.11 Implement the `Editing a level does not rewrite prior letters` behavior from `specs/mahnwesen/spec.md` to pass 1.10
- [ ] 1.12 Refactor; full suite stays green
- [ ] 1.13 Write failing test `test_mahnwesen_initialization_preserves_customized_levels` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.14 Implement the `Initialization preserves customized levels` behavior from `specs/mahnwesen/spec.md` to pass 1.13
- [ ] 1.15 Refactor; full suite stays green
- [ ] 1.16 Write failing test `test_mahnwesen_stage_date_uses_one_absolute_threshold` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.17 Implement the `Stage date uses one absolute threshold` behavior from `specs/mahnwesen/spec.md` to pass 1.16
- [ ] 1.18 Refactor; full suite stays green

## 2. Mahnung Snapshot

- [ ] 2.1 Write failing test `test_mahnwesen_create_dunning_letter` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.2 Implement the `Create dunning letter` behavior from `specs/mahnwesen/spec.md` to pass 2.1
- [ ] 2.3 Refactor; full suite stays green
- [ ] 2.4 Write failing test `test_mahnwesen_rechnung_changes_after_snapshot` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.5 Implement the `Rechnung changes after snapshot` behavior from `specs/mahnwesen/spec.md` to pass 2.4
- [ ] 2.6 Refactor; full suite stays green
- [ ] 2.7 Write failing test `test_mahnwesen_no_balance_cannot_produce_a_reminder` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.8 Implement the `No balance cannot produce a reminder` behavior from `specs/mahnwesen/spec.md` to pass 2.7
- [ ] 2.9 Refactor; full suite stays green

## 3. Dunning Evaluation and Exclusions

- [ ] 3.1 Write failing test `test_mahnwesen_assisted_run_creates_confirmed_eligible_reminders` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.2 Implement the `Assisted run creates confirmed eligible reminders` behavior from `specs/mahnwesen/spec.md` to pass 3.1
- [ ] 3.3 Refactor; full suite stays green
- [ ] 3.4 Write failing test `test_mahnwesen_full_payment_or_exclusion_prevents_a_new_reminder` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.5 Implement the `Full payment or exclusion prevents a new reminder` behavior from `specs/mahnwesen/spec.md` to pass 3.4
- [ ] 3.6 Refactor; full suite stays green
- [ ] 3.7 Write failing test `test_mahnwesen_stage_transition_is_exact_and_ordered` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.8 Implement the `Stage transition is exact and ordered` behavior from `specs/mahnwesen/spec.md` to pass 3.7
- [ ] 3.9 Refactor; full suite stays green
- [ ] 3.10 Write failing test `test_mahnwesen_repeated_run_does_not_duplicate_a_stage_reminder` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.11 Implement the `Repeated run does not duplicate a stage reminder` behavior from `specs/mahnwesen/spec.md` to pass 3.10
- [ ] 3.12 Refactor; full suite stays green

## 4. Late-Payment Interest Uses the Settled Open Principal

**Prerequisite gate:** keep implementation blocked until the accepted invoice-money, settlement-event, and balanced-posting contracts are available.

- [ ] 4.1 Write failing test `test_mahnwesen_tier_transition_and_partial_payment_have_deterministic_cents` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.2 Implement the `Tier transition and partial payment have deterministic cents` behavior from `specs/mahnwesen/spec.md` to pass 4.1
- [ ] 4.3 Refactor; full suite stays green
- [ ] 4.4 Write failing test `test_mahnwesen_full_settlement_stops_accrual_on_its_effective_date` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.5 Implement the `Full settlement stops accrual on its effective date` behavior from `specs/mahnwesen/spec.md` to pass 4.4
- [ ] 4.6 Refactor; full suite stays green
- [ ] 4.7 Write failing test `test_mahnwesen_unpaid_fees_are_not_compounded` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.8 Implement the `Unpaid fees are not compounded` behavior from `specs/mahnwesen/spec.md` to pass 4.7
- [ ] 4.9 Refactor; full suite stays green

## 5. Dunning Operations Have a Typed Workspace

- [ ] 5.1 Write failing test `test_mahnwesen_user_reviews_an_eligible_dunning_run` from `test-plan.md` (assert it fails for the right reason)
- [ ] 5.2 Implement the `User reviews an eligible dunning run` behavior from `specs/mahnwesen/spec.md` to pass 5.1
- [ ] 5.3 Refactor; full suite stays green
- [ ] 5.4 Write failing test `test_mahnwesen_dunning_data_source_is_unavailable` from `test-plan.md` (assert it fails for the right reason)
- [ ] 5.5 Implement the `Dunning data source is unavailable` behavior from `specs/mahnwesen/spec.md` to pass 5.4
- [ ] 5.6 Refactor; full suite stays green
- [ ] 5.7 Write failing test `test_mahnwesen_narrow_window_remains_keyboard_accessible` from `test-plan.md` (assert it fails for the right reason)
- [ ] 5.8 Implement the `Narrow window remains keyboard accessible` behavior from `specs/mahnwesen/spec.md` to pass 5.7
- [ ] 5.9 Refactor; full suite stays green

## 6. Dunning Balance Source Fails Closed

**Prerequisite gate:** keep monetary implementation blocked until the accepted invoice-money, settlement-event, and balanced-posting contracts are available.

- [ ] 6.1 Write failing test `test_mahnwesen_missing_or_conflicting_balance_source_blocks_every_balance_dependent_operation` from `test-plan.md` (assert it fails for the right reason)
- [ ] 6.2 Implement the `Missing or conflicting balance source blocks every balance-dependent operation` behavior from `specs/mahnwesen/spec.md` to pass 6.1
- [ ] 6.3 Refactor; full suite stays green
- [ ] 6.4 Write failing test `test_mahnwesen_invalid_settlement_event_is_not_replaced_by_invoice_totals` from `test-plan.md` (assert it fails for the right reason)
- [ ] 6.5 Implement the `Invalid settlement event is not replaced by invoice totals` behavior from `specs/mahnwesen/spec.md` to pass 6.4
- [ ] 6.6 Refactor; full suite stays green

## 7. Mail-Versand via SMTP

- [ ] 7.1 Write failing test `test_mahnwesen_send_dunning_letter` from `test-plan.md` (assert it fails for the right reason)
- [ ] 7.2 Implement the `Send dunning letter` behavior from `specs/mahnwesen/spec.md` to pass 7.1
- [ ] 7.3 Refactor; full suite stays green
- [ ] 7.4 Write failing test `test_mahnwesen_smtp_not_configured` from `test-plan.md` (assert it fails for the right reason)
- [ ] 7.5 Implement the `SMTP not configured` behavior from `specs/mahnwesen/spec.md` to pass 7.4
- [ ] 7.6 Refactor; full suite stays green
- [ ] 7.7 Write failing test `test_mahnwesen_retrying_a_pending_letter_does_not_create_a_second_record` from `test-plan.md` (assert it fails for the right reason)
- [ ] 7.8 Implement the `Retrying a pending letter does not create a second record` behavior from `specs/mahnwesen/spec.md` to pass 7.7
- [ ] 7.9 Refactor; full suite stays green

## 8. Invoice Dunning Level

- [ ] 8.1 Write failing test `test_mahnwesen_invoice_at_level_2` from `test-plan.md` (assert it fails for the right reason)
- [ ] 8.2 Implement the `Invoice at level 2` behavior from `specs/mahnwesen/spec.md` to pass 8.1
- [ ] 8.3 Refactor; full suite stays green
- [ ] 8.4 Write failing test `test_mahnwesen_failed_send_does_not_advance_the_level` from `test-plan.md` (assert it fails for the right reason)
- [ ] 8.5 Implement the `Failed send does not advance the level` behavior from `specs/mahnwesen/spec.md` to pass 8.4
- [ ] 8.6 Refactor; full suite stays green
- [ ] 8.7 Write failing test `test_mahnwesen_invoice_payment_resets_level` from `test-plan.md` (assert it fails for the right reason)
- [ ] 8.8 Implement the `Invoice payment resets level` behavior from `specs/mahnwesen/spec.md` to pass 8.7
- [ ] 8.9 Refactor; full suite stays green

## 9. Collection Package

- [ ] 9.1 Write failing test `test_mahnwesen_package_contains_selected_customer_evidence` from `test-plan.md` (assert it fails for the right reason)
- [ ] 9.2 Implement the `Package contains selected customer evidence` behavior from `specs/mahnwesen/spec.md` to pass 9.1
- [ ] 9.3 Refactor; full suite stays green
- [ ] 9.4 Write failing test `test_mahnwesen_missing_required_artifact_blocks_a_complete_package` from `test-plan.md` (assert it fails for the right reason)
- [ ] 9.5 Implement the `Missing required artifact blocks a complete package` behavior from `specs/mahnwesen/spec.md` to pass 9.4
- [ ] 9.6 Refactor; full suite stays green

## 10. Mahnwesen Settings Singleton

- [ ] 10.1 Write failing test `test_mahnwesen_configure_grace_period` from `test-plan.md` (assert it fails for the right reason)
- [ ] 10.2 Implement the `Configure grace period` behavior from `specs/mahnwesen/spec.md` to pass 10.1
- [ ] 10.3 Refactor; full suite stays green
- [ ] 10.4 Write failing test `test_mahnwesen_default_settings_on_fresh_install` from `test-plan.md` (assert it fails for the right reason)
- [ ] 10.5 Implement the `Default settings on fresh install` behavior from `specs/mahnwesen/spec.md` to pass 10.4
- [ ] 10.6 Refactor; full suite stays green

## 11. Dunning Reference Documentation Matches the Runtime Contract

- [ ] 11.1 Write failing test `test_mahnwesen_documentation_exposes_the_canonical_model` from `test-plan.md` (assert it fails for the right reason)
- [ ] 11.2 Implement the `Documentation exposes the canonical model` behavior from `specs/mahnwesen/spec.md` to pass 11.1
- [ ] 11.3 Refactor; full suite stays green
- [ ] 11.4 Write failing test `test_mahnwesen_percentage_fee_example_is_rejected` from `test-plan.md` (assert it fails for the right reason)
- [ ] 11.5 Implement the `Percentage-fee example is rejected` behavior from `specs/mahnwesen/spec.md` to pass 11.4
- [ ] 11.6 Refactor; full suite stays green
- [ ] 11.7 Write failing test `test_mahnwesen_documentation_describes_stage_progression` from `test-plan.md` (assert it fails for the right reason)
- [ ] 11.8 Implement the `Documentation describes stage progression` behavior from `specs/mahnwesen/spec.md` to pass 11.7
- [ ] 11.9 Refactor; full suite stays green
- [ ] 11.10 Write failing test `test_mahnwesen_unsupported_automation_and_legal_claims_are_not_documented_as_available` from `test-plan.md` (assert it fails for the right reason)
- [ ] 11.11 Implement the `Unsupported automation and legal claims are not documented as available` behavior from `specs/mahnwesen/spec.md` to pass 11.10
- [ ] 11.12 Refactor; full suite stays green

## 12. Canonical route inventory

- [ ] 12.1 Write failing test `test_typed_route_every_canonical_route_has_a_useful_surface` from `test-plan.md` (assert it fails for the right reason)
- [ ] 12.2 Implement the `Every canonical route has a useful surface` behavior from `specs/typed-route-workspaces/spec.md` to pass 12.1
- [ ] 12.3 Refactor; full suite stays green
- [ ] 12.4 Write failing test `test_typed_route_database_outage_is_not_an_empty_route` from `test-plan.md` (assert it fails for the right reason)
- [ ] 12.5 Implement the `Database outage is not an empty route` behavior from `specs/typed-route-workspaces/spec.md` to pass 12.4
- [ ] 12.6 Refactor; full suite stays green
- [ ] 12.7 Write failing test `test_typed_route_alias_matrix_preserves_deep_links` from `test-plan.md` (assert it fails for the right reason)
- [ ] 12.8 Implement the `Alias matrix preserves deep links` behavior from `specs/typed-route-workspaces/spec.md` to pass 12.7
- [ ] 12.9 Refactor; full suite stays green
- [ ] 12.10 Write failing test `test_typed_route_route_matrix_exposes_a_truthful_boundary` from `test-plan.md` (assert it fails for the right reason)
- [ ] 12.11 Implement the `Route matrix exposes a truthful boundary` behavior from `specs/typed-route-workspaces/spec.md` to pass 12.10
- [ ] 12.12 Refactor; full suite stays green
- [ ] 12.13 Write failing test `test_typed_route_dunning_route_exposes_its_typed_workspace` from `test-plan.md` (assert it fails for the right reason)
- [ ] 12.14 Implement the `Dunning route exposes its typed workspace` behavior from `specs/typed-route-workspaces/spec.md` to pass 12.13
- [ ] 12.15 Refactor; full suite stays green
- [ ] 12.16 Write failing test `test_typed_route_dunning_route_database_outage_remains_actionable` from `test-plan.md` (assert it fails for the right reason)
- [ ] 12.17 Implement the `Dunning route database outage remains actionable` behavior from `specs/typed-route-workspaces/spec.md` to pass 12.16
- [ ] 12.18 Refactor; full suite stays green
