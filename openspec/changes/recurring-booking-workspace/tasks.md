## 1. accounting: Buchungsvorlagen

- [ ] 1.1 Write failing test `test_template_creation` in `test/features/accounting/recurring_booking_workspace_test.dart` for scenario "Template creation"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Template creation" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_due_template_is_staged_for_review` in `test/features/accounting/recurring_booking_workspace_test.dart` for scenario "Due template is staged for review"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "Due template is staged for review" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_template_execution` in `test/features/accounting/recurring_booking_workspace_test.dart` for scenario "Template execution"; assert it fails for the right reason.
- [ ] 1.8 Implement the specified behavior for "Template execution" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.10 Write failing test `test_template_with_article` in `test/features/accounting/recurring_booking_workspace_test.dart` for scenario "Template with article"; assert it fails for the right reason.
- [ ] 1.11 Implement the specified behavior for "Template with article" to pass 1.10.
- [ ] 1.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.13 Write failing test `test_template_lifecycle` in `test/features/accounting/recurring_booking_workspace_test.dart` for scenario "Template lifecycle"; assert it fails for the right reason.
- [ ] 1.14 Implement the specified behavior for "Template lifecycle" to pass 1.13.
- [ ] 1.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.16 Write failing test `test_unavailable_mapping_or_shared_contract_fails_closed` in `test/features/accounting/recurring_booking_workspace_test.dart` for scenario "Unavailable mapping or shared contract fails closed"; assert it fails for the right reason.
- [ ] 1.17 Implement the specified behavior for "Unavailable mapping or shared contract fails closed" to pass 1.16.
- [ ] 1.18 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.19 Write failing test `test_template_with_deleted_category` in `test/features/accounting/recurring_booking_workspace_test.dart` for scenario "Template with deleted category"; assert it fails for the right reason.
- [ ] 1.20 Implement the specified behavior for "Template with deleted category" to pass 1.19.
- [ ] 1.21 Refactor the affected code; keep the focused and full suites green.

## 2. recurring-booking-workspace: Manage recurring booking templates

- [ ] 2.1 Write failing test `test_create_and_review_a_scheduled_template` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Create and review a scheduled template"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Create and review a scheduled template" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_reject_an_invalid_template_schedule` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Reject an invalid template schedule"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Reject an invalid template schedule" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.

## 3. recurring-booking-workspace: Surface due booking instances for review

- [ ] 3.1 Write failing test `test_review_a_due_instance` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Review a due instance"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Review a due instance" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_repeated_refresh_does_not_duplicate_a_due_instance` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Repeated refresh does not duplicate a due instance"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Repeated refresh does not duplicate a due instance" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.7 Write failing test `test_paused_template_has_no_actionable_due_instance` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Paused template has no actionable due instance"; assert it fails for the right reason.
- [ ] 3.8 Implement the specified behavior for "Paused template has no actionable due instance" to pass 3.7.
- [ ] 3.9 Refactor the affected code; keep the focused and full suites green.

## 4. recurring-booking-workspace: Confirmed direct bookings use the shared posting boundary

- [ ] 4.1 Write failing test `test_confirm_a_ready_direct_mode_instance` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Confirm a ready direct-mode instance"; assert it fails for the right reason.
- [ ] 4.2 Implement the specified behavior for "Confirm a ready direct-mode instance" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_keep_direct_mode_pending_without_the_shared_contract` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Keep direct mode pending without the shared contract"; assert it fails for the right reason.
- [ ] 4.5 Implement the specified behavior for "Keep direct mode pending without the shared contract" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.

## 5. recurring-booking-workspace: Beleg mode hands off to incoming-invoice drafting

- [ ] 5.1 Write failing test `test_create_an_incoming_invoice_draft_from_a_reviewed_instance` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Create an incoming-invoice draft from a reviewed instance"; assert it fails for the right reason.
- [ ] 5.2 Implement the specified behavior for "Create an incoming-invoice draft from a reviewed instance" to pass 5.1.
- [ ] 5.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.4 Write failing test `test_keep_beleg_mode_reviewable_when_draft_handoff_is_unavailable` in `test/features/recurring_booking_workspace/recurring_booking_workspace_test.dart` for scenario "Keep Beleg mode reviewable when draft handoff is unavailable"; assert it fails for the right reason.
- [ ] 5.5 Implement the specified behavior for "Keep Beleg mode reviewable when draft handoff is unavailable" to pass 5.4.
- [ ] 5.6 Refactor the affected code; keep the focused and full suites green.

## 6. recurring: Buchungsvorlage Modus

- [ ] 6.1 Write failing test `test_direkt_mode` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Direkt mode"; assert it fails for the right reason.
- [ ] 6.2 Implement the specified behavior for "Direkt mode" to pass 6.1.
- [ ] 6.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.4 Write failing test `test_beleg_mode` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Beleg mode"; assert it fails for the right reason.
- [ ] 6.5 Implement the specified behavior for "Beleg mode" to pass 6.4.
- [ ] 6.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.7 Write failing test `test_financial_effect_is_blocked_without_the_shared_contract` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Financial effect is blocked without the shared contract"; assert it fails for the right reason.
- [ ] 6.8 Implement the specified behavior for "Financial effect is blocked without the shared contract" to pass 6.7.
- [ ] 6.9 Refactor the affected code; keep the focused and full suites green.

## 7. recurring: Buchungsvorlage Art

- [ ] 7.1 Write failing test `test_ausgabe_direction` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Ausgabe direction"; assert it fails for the right reason.
- [ ] 7.2 Implement the specified behavior for "Ausgabe direction" to pass 7.1.
- [ ] 7.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 7.4 Write failing test `test_einnahme_direction` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Einnahme direction"; assert it fails for the right reason.
- [ ] 7.5 Implement the specified behavior for "Einnahme direction" to pass 7.4.
- [ ] 7.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 7.7 Write failing test `test_reject_an_unresolved_tax_or_account_interpretation` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Reject an unresolved tax or account interpretation"; assert it fails for the right reason.
- [ ] 7.8 Implement the specified behavior for "Reject an unresolved tax or account interpretation" to pass 7.7.
- [ ] 7.9 Refactor the affected code; keep the focused and full suites green.

## 8. recurring: Buchungsvorlage Auto-Generation

- [ ] 8.1 Write failing test `test_auto_generate_journal_entry` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Auto-generate journal entry"; assert it fails for the right reason.
- [ ] 8.2 Implement the specified behavior for "Auto-generate journal entry" to pass 8.1.
- [ ] 8.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.4 Write failing test `test_repeated_scan_is_idempotent` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Repeated scan is idempotent"; assert it fails for the right reason.
- [ ] 8.5 Implement the specified behavior for "Repeated scan is idempotent" to pass 8.4.
- [ ] 8.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.7 Write failing test `test_inactive_template_skipped` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Inactive template skipped"; assert it fails for the right reason.
- [ ] 8.8 Implement the specified behavior for "Inactive template skipped" to pass 8.7.
- [ ] 8.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.10 Write failing test `test_missing_posting_contract_blocks_execution` in `test/features/recurring/recurring_booking_workspace_test.dart` for scenario "Missing posting contract blocks execution"; assert it fails for the right reason.
- [ ] 8.11 Implement the specified behavior for "Missing posting contract blocks execution" to pass 8.10.
- [ ] 8.12 Refactor the affected code; keep the focused and full suites green.

## 9. typed-route-workspaces: Canonical route inventory

- [ ] 9.1 Write failing test `test_every_canonical_route_has_a_useful_surface` in `test/core/recurring_booking_workspace_routes_test.dart` for scenario "Every canonical route has a useful surface"; assert it fails for the right reason.
- [ ] 9.2 Implement the specified behavior for "Every canonical route has a useful surface" to pass 9.1.
- [ ] 9.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.4 Write failing test `test_recurring_workspace_resolves_through_its_use_case` in `test/core/recurring_booking_workspace_routes_test.dart` for scenario "Recurring workspace resolves through its use case"; assert it fails for the right reason.
- [ ] 9.5 Implement the specified behavior for "Recurring workspace resolves through its use case" to pass 9.4.
- [ ] 9.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.7 Write failing test `test_database_outage_is_not_an_empty_route` in `test/core/recurring_booking_workspace_routes_test.dart` for scenario "Database outage is not an empty route"; assert it fails for the right reason.
- [ ] 9.8 Implement the specified behavior for "Database outage is not an empty route" to pass 9.7.
- [ ] 9.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.10 Write failing test `test_alias_matrix_preserves_deep_links` in `test/core/recurring_booking_workspace_routes_test.dart` for scenario "Alias matrix preserves deep links"; assert it fails for the right reason.
- [ ] 9.11 Implement the specified behavior for "Alias matrix preserves deep links" to pass 9.10.
- [ ] 9.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.13 Write failing test `test_route_matrix_exposes_a_truthful_boundary` in `test/core/recurring_booking_workspace_routes_test.dart` for scenario "Route matrix exposes a truthful boundary"; assert it fails for the right reason.
- [ ] 9.14 Implement the specified behavior for "Route matrix exposes a truthful boundary" to pass 9.13.
- [ ] 9.15 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
