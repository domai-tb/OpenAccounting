## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/accounting/spec.md → Buchungsvorlagen | Template creation | test/features/accounting/recurring_booking_workspace_test.dart | test_template_creation | 🔴 red |
| specs/specs/accounting/spec.md → Buchungsvorlagen | Due template is staged for review | test/features/accounting/recurring_booking_workspace_test.dart | test_due_template_is_staged_for_review | 🔴 red |
| specs/specs/accounting/spec.md → Buchungsvorlagen | Template execution | test/features/accounting/recurring_booking_workspace_test.dart | test_template_execution | 🔴 red |
| specs/specs/accounting/spec.md → Buchungsvorlagen | Template with article | test/features/accounting/recurring_booking_workspace_test.dart | test_template_with_article | 🔴 red |
| specs/specs/accounting/spec.md → Buchungsvorlagen | Template lifecycle | test/features/accounting/recurring_booking_workspace_test.dart | test_template_lifecycle | 🔴 red |
| specs/specs/accounting/spec.md → Buchungsvorlagen | Unavailable mapping or shared contract fails closed | test/features/accounting/recurring_booking_workspace_test.dart | test_unavailable_mapping_or_shared_contract_fails_closed | 🔴 red |
| specs/specs/accounting/spec.md → Buchungsvorlagen | Template with deleted category | test/features/accounting/recurring_booking_workspace_test.dart | test_template_with_deleted_category | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Manage recurring booking templates | Create and review a scheduled template | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_create_and_review_a_scheduled_template | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Manage recurring booking templates | Reject an invalid template schedule | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_reject_an_invalid_template_schedule | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Surface due booking instances for review | Review a due instance | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_review_a_due_instance | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Surface due booking instances for review | Repeated refresh does not duplicate a due instance | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_repeated_refresh_does_not_duplicate_a_due_instance | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Surface due booking instances for review | Paused template has no actionable due instance | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_paused_template_has_no_actionable_due_instance | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Confirmed direct bookings use the shared posting boundary | Confirm a ready direct-mode instance | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_confirm_a_ready_direct_mode_instance | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Confirmed direct bookings use the shared posting boundary | Keep direct mode pending without the shared contract | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_keep_direct_mode_pending_without_the_shared_contract | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Beleg mode hands off to incoming-invoice drafting | Create an incoming-invoice draft from a reviewed instance | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_create_an_incoming_invoice_draft_from_a_reviewed_instance | 🔴 red |
| specs/specs/recurring-booking-workspace/spec.md → Beleg mode hands off to incoming-invoice drafting | Keep Beleg mode reviewable when draft handoff is unavailable | test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart | test_keep_beleg_mode_reviewable_when_draft_handoff_is_unavailable | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Modus | Direkt mode | test/features/recurring/recurring_booking_workspace_test.dart | test_direkt_mode | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Modus | Beleg mode | test/features/recurring/recurring_booking_workspace_test.dart | test_beleg_mode | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Modus | Financial effect is blocked without the shared contract | test/features/recurring/recurring_booking_workspace_test.dart | test_financial_effect_is_blocked_without_the_shared_contract | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Art | Ausgabe direction | test/features/recurring/recurring_booking_workspace_test.dart | test_ausgabe_direction | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Art | Einnahme direction | test/features/recurring/recurring_booking_workspace_test.dart | test_einnahme_direction | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Art | Reject an unresolved tax or account interpretation | test/features/recurring/recurring_booking_workspace_test.dart | test_reject_an_unresolved_tax_or_account_interpretation | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Auto-Generation | Auto-generate journal entry | test/features/recurring/recurring_booking_workspace_test.dart | test_auto_generate_journal_entry | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Auto-Generation | Repeated scan is idempotent | test/features/recurring/recurring_booking_workspace_test.dart | test_repeated_scan_is_idempotent | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Auto-Generation | Inactive template skipped | test/features/recurring/recurring_booking_workspace_test.dart | test_inactive_template_skipped | 🔴 red |
| specs/specs/recurring/spec.md → Buchungsvorlage Auto-Generation | Missing posting contract blocks execution | test/features/recurring/recurring_booking_workspace_test.dart | test_missing_posting_contract_blocks_execution | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Every canonical route has a useful surface | test/core/recurring_booking_workspace_routes_test.dart | test_every_canonical_route_has_a_useful_surface | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Recurring workspace resolves through its use case | test/core/recurring_booking_workspace_routes_test.dart | test_recurring_workspace_resolves_through_its_use_case | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Database outage is not an empty route | test/core/recurring_booking_workspace_routes_test.dart | test_database_outage_is_not_an_empty_route | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Alias matrix preserves deep links | test/core/recurring_booking_workspace_routes_test.dart | test_alias_matrix_preserves_deep_links | 🔴 red |
| specs/specs/typed-route-workspaces/spec.md → Canonical route inventory | Route matrix exposes a truthful boundary | test/core/recurring_booking_workspace_routes_test.dart | test_route_matrix_exposes_a_truthful_boundary | 🔴 red |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
