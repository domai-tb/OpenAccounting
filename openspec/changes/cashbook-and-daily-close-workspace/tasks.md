## 1. accounting: Tagesabschluss

- [ ] 1.1 Write failing test `test_tagesabschluss_creation` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Tagesabschluss creation"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Tagesabschluss creation" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_counting_discrepancy` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Counting discrepancy"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "Counting discrepancy" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_gobd_signature` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "GoBD signature"; assert it fails for the right reason.
- [ ] 1.8 Implement the specified behavior for "GoBD signature" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.10 Write failing test `test_double_close_prevention` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Double close prevention"; assert it fails for the right reason.
- [ ] 1.11 Implement the specified behavior for "Double close prevention" to pass 1.10.
- [ ] 1.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.13 Write failing test `test_concurrent_finalization_is_serialized` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Concurrent finalization is serialized"; assert it fails for the right reason.
- [ ] 1.14 Implement the specified behavior for "Concurrent finalization is serialized" to pass 1.13.
- [ ] 1.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.16 Write failing test `test_ambiguous_legacy_close_identity` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Ambiguous legacy close identity"; assert it fails for the right reason.
- [ ] 1.17 Implement the specified behavior for "Ambiguous legacy close identity" to pass 1.16.
- [ ] 1.18 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.19 Write failing test `test_expected_cash_source_is_unavailable` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Expected cash source is unavailable"; assert it fails for the right reason.
- [ ] 1.20 Implement the specified behavior for "Expected cash source is unavailable" to pass 1.19.
- [ ] 1.21 Refactor the affected code; keep the focused and full suites green.

## 2. cashbook-and-daily-close-workspace: Cashbook view uses typed committed cash events

- [ ] 2.1 Write failing test `test_approved_cash_event_appears_in_the_cashbook` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Approved cash event appears in the cashbook"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Approved cash event appears in the cashbook" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_missing_posting_contract_blocks_cash_entry` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Missing posting contract blocks cash entry"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Missing posting contract blocks cash entry" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.7 Write failing test `test_imported_or_legacy_row_is_not_treated_as_cash` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Imported or legacy row is not treated as cash"; assert it fails for the right reason.
- [ ] 2.8 Implement the specified behavior for "Imported or legacy row is not treated as cash" to pass 2.7.
- [ ] 2.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.10 Write failing test `test_committed_cash_event_cannot_be_silently_rewritten` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Committed cash event cannot be silently rewritten"; assert it fails for the right reason.
- [ ] 2.11 Implement the specified behavior for "Committed cash event cannot be silently rewritten" to pass 2.10.
- [ ] 2.12 Refactor the affected code; keep the focused and full suites green.

## 3. cashbook-and-daily-close-workspace: Cash balance uses an authoritative complete report

- [ ] 3.1 Write failing test `test_complete_balance_is_shown_from_the_report_result` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Complete balance is shown from the report result"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Complete balance is shown from the report result" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_incomplete_historical_source_fails_closed` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Incomplete historical source fails closed"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Incomplete historical source fails closed" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.

## 4. cashbook-and-daily-close-workspace: Daily close records use the approved close result

- [ ] 4.1 Write failing test `test_complete_daily_close_is_finalized` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Complete daily close is finalized"; assert it fails for the right reason.
- [ ] 4.2 Implement the specified behavior for "Complete daily close is finalized" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_expected_balance_or_persistence_mapping_is_unavailable` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Expected balance or persistence mapping is unavailable"; assert it fails for the right reason.
- [ ] 4.5 Implement the specified behavior for "Expected balance or persistence mapping is unavailable" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.7 Write failing test `test_discrepancy_requires_an_explanation` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Discrepancy requires an explanation"; assert it fails for the right reason.
- [ ] 4.8 Implement the specified behavior for "Discrepancy requires an explanation" to pass 4.7.
- [ ] 4.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.10 Write failing test `test_existing_close_remains_read_only` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Existing close remains read-only"; assert it fails for the right reason.
- [ ] 4.11 Implement the specified behavior for "Existing close remains read-only" to pass 4.10.
- [ ] 4.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.13 Write failing test `test_concurrent_close_finalization_cannot_duplicate_a_signed_record` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Concurrent close finalization cannot duplicate a signed record"; assert it fails for the right reason.
- [ ] 4.14 Implement the specified behavior for "Concurrent close finalization cannot duplicate a signed record" to pass 4.13.
- [ ] 4.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.16 Write failing test `test_ambiguous_legacy_closes_block_finalization` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Ambiguous legacy closes block finalization"; assert it fails for the right reason.
- [ ] 4.17 Implement the specified behavior for "Ambiguous legacy closes block finalization" to pass 4.16.
- [ ] 4.18 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.19 Write failing test `test_single_unsigned_legacy_close_blocks_finalization` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Single unsigned legacy close blocks finalization"; assert it fails for the right reason.
- [ ] 4.20 Implement the specified behavior for "Single unsigned legacy close blocks finalization" to pass 4.19.
- [ ] 4.21 Refactor the affected code; keep the focused and full suites green.

## 5. cashbook-and-daily-close-workspace: Cashbook views follow desktop localization and accessibility rules

- [ ] 5.1 Write failing test `test_localized_keyboard_use_remains_complete` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Localized keyboard use remains complete"; assert it fails for the right reason.
- [ ] 5.2 Implement the specified behavior for "Localized keyboard use remains complete" to pass 5.1.
- [ ] 5.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.4 Write failing test `test_narrow_layout_keeps_close_actions_reachable` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Narrow layout keeps close actions reachable"; assert it fails for the right reason.
- [ ] 5.5 Implement the specified behavior for "Narrow layout keeps close actions reachable" to pass 5.4.
- [ ] 5.6 Refactor the affected code; keep the focused and full suites green.

## 6. db: Tagesabschluss evidence storage and immutability

- [ ] 6.1 Write failing test `test_close_evidence_migration_preserves_existing_history` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Close evidence migration preserves existing history"; assert it fails for the right reason.
- [ ] 6.2 Implement the specified behavior for "Close evidence migration preserves existing history" to pass 6.1.
- [ ] 6.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.4 Write failing test `test_signed_close_cannot_be_rewritten` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Signed close cannot be rewritten"; assert it fails for the right reason.
- [ ] 6.5 Implement the specified behavior for "Signed close cannot be rewritten" to pass 6.4.
- [ ] 6.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.7 Write failing test `test_failed_evidence_migration_rolls_back` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Failed evidence migration rolls back"; assert it fails for the right reason.
- [ ] 6.8 Implement the specified behavior for "Failed evidence migration rolls back" to pass 6.7.
- [ ] 6.9 Refactor the affected code; keep the focused and full suites green.

## 7. db: Tagesabschluss finalization prevents duplicate identities

- [ ] 7.1 Write failing test `test_duplicate_guard_runs_in_a_serialized_transaction` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Duplicate guard runs in a serialized transaction"; assert it fails for the right reason.
- [ ] 7.2 Implement the specified behavior for "Duplicate guard runs in a serialized transaction" to pass 7.1.
- [ ] 7.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 7.4 Write failing test `test_legacy_rows_without_one_verified_signed_identity_block_a_new_close` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Legacy rows without one verified signed identity block a new close"; assert it fails for the right reason.
- [ ] 7.5 Implement the specified behavior for "Legacy rows without one verified signed identity block a new close" to pass 7.4.
- [ ] 7.6 Refactor the affected code; keep the focused and full suites green.

## 8. pdf: Tagesabschluss PDF renders the finalized snapshot

- [ ] 8.1 Write failing test `test_complete_signed_close_produces_its_pdf` in `test/features/pdf/cashbook_and_daily_close_workspace_test.dart` for scenario "Complete signed close produces its PDF"; assert it fails for the right reason.
- [ ] 8.2 Implement the specified behavior for "Complete signed close produces its PDF" to pass 8.1.
- [ ] 8.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.4 Write failing test `test_incomplete_or_unsigned_close_has_no_pdf` in `test/features/pdf/cashbook_and_daily_close_workspace_test.dart` for scenario "Incomplete or unsigned close has no PDF"; assert it fails for the right reason.
- [ ] 8.5 Implement the specified behavior for "Incomplete or unsigned close has no PDF" to pass 8.4.
- [ ] 8.6 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
