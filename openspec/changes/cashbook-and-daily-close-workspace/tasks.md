## 0. Review gate and v26 opening-source storage

- [x] 0.1 Before implementation, obtain fresh independent approval of the revised cashbook contract. Until its v26 source and v27 close evidence are implemented, keep cash writes, balances, close finalization, and PDFs unavailable. Fresh independent Round 4 contract approval is recorded in `review.md`; implementation remains open.
- [x] 0.2 Write failing test `test_v26_opening_source_migration_preserves_legacy_history_without_backfill` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "v26 migration preserves legacy history without backfill"; assert it fails for the right reason.
- [x] 0.3 Implement and verify the v26 source table migration, constraints, and no-backfill behavior to pass 0.2.
- [x] 0.4 Refactor the v26 source migration; keep focused and full suites green.
- [x] 0.5 Write failing test `test_fresh_and_upgraded_v26_opening_source_schemas_match` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Fresh and upgraded v26 source schemas match"; compare columns, foreign keys, unique constraints, triggers, and reject weakened `effective_date` and `currency_code` GLOB constraints with named schema-health regressions.
- [x] 0.6 Implement matching fresh-schema DDL and migration behavior to pass 0.5; make schema-health validation compare the complete required date and currency GLOB patterns.
- [x] 0.7 Refactor schema declarations; keep focused and full suites green.
- [x] 0.8 Write failing test `test_opening_source_identity_is_unique_and_immutable` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Opening-source identity is unique and immutable"; assert conflicting identity and update/delete attempts are rejected.
- [x] 0.9 Implement source uniqueness and immutability to pass 0.8.
- [x] 0.10 Refactor source constraints and triggers; keep focused and full suites green.
- [x] 0.11 Write and verify `test_setup_opening_source_commits_atomically` in `test/features/setup/cashbook_opening_source_test.dart` for scenario "Setup opening source commits atomically"; inject failures at company creation, new-account creation, existing-account association, category creation, journal insertion, saldo update, and source insertion across new and existing Kasse paths. Assert the complete company, account, category, journal, and source state is unchanged after each failure.
- [x] 0.12 Implement setup transaction wiring for the source record to pass 0.11.
- [x] 0.13 Refactor setup source persistence; keep focused and full suites green.
- [x] 0.14 Write failing test `test_setup_retry_preserves_opening_source_identity` in `test/features/setup/cashbook_opening_source_test.dart` for scenario "Setup retry preserves opening source identity"; assert exact retry after a later cash movement changes account saldo still succeeds and preserves the original source, while a conflicting opening amount changes nothing.
- [x] 0.15 Implement idempotent setup source retry and conflict behavior to pass 0.14; keep retry identity validation independent of current account saldo while retaining creation-time saldo verification.
- [x] 0.16 Refactor retry behavior; keep focused and full suites green.
- [x] 0.16a Resolve the second consecutive v26 implementation-review REVISE follow-up: add weakened-schema and saldo-only regressions, update the onboarding integration test to reject a conflicting retry while preserving source, journal, and saldo, and pass focused migration, setup, onboarding, and scoped-analysis checks.
- [x] 0.16b Fix the independent currency GLOB case-sensitivity finding: reject lowercase-only `[a-z][a-z][a-z]` schema DDL while preserving SQL identifier and whitespace normalization and case-sensitive string literals; pass the focused migration suite and scoped analysis.
- [x] 0.16c Resolve the second consecutive v26 schema-health review REVISE: strip line and block comments only after masking quoted SQL literals, reject weakened date and currency GLOB checks with expected fragments in comments, and pass the focused migration suite and scoped analysis.
- [x] 0.17 Write failing test `test_fresh_and_upgraded_v27_close_schemas_match` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Fresh and upgraded v27 close schemas match"; confirm the red failure identifies the missing `zaehlung_json` column.
- [x] 0.18 Implement v27 close-evidence fields and trigger parity in fresh and migrated schemas to pass 0.17; focused migration tests pass 7/7.
- [x] 0.19 Refactor v27 schema declarations; keep focused and full suites green.
- [x] 0.19a Preserve custom schema-version ownership for file-backed profiles: disable Drift auto-migrations in `AppDatabase.forProfile` and pass the v27 reopen / v26 upgrade missing-source regressions with unchanged database path, version, and missing-table state.
- [x] 0.20 Write failing test `test_v25_profile_does_not_require_v26_opening_source_table` in `test/features/setup/profile_data_portability_test.dart` for scenario "Pre-v26 profile does not require the opening-source table".
- [x] 0.21 Implement v26 version-pending table inventory behavior to pass 0.20.
- [x] 0.22 Refactor profile inventory version rules; keep focused and full suites green.
- [x] 0.23 Write failing test `test_v26_profile_export_preserves_opening_source_rows` in `test/features/setup/profile_data_portability_test.dart` for scenario "v26 profile export preserves opening-source rows".
- [x] 0.24 Implement typed v26 source-row export, including a valid empty source table, to pass 0.23.
- [x] 0.25 Refactor source-row serialization; keep focused and full suites green.
- [x] 0.26 Write failing test `test_missing_v26_source_schema_blocks_complete_export` in `test/features/setup/profile_data_portability_test.dart` for scenario "Missing v26 source schema blocks complete export".
- [x] 0.27 Implement fail-closed export validation for a missing or malformed v26 source table to pass 0.26.
- [x] 0.28 Refactor schema validation; keep focused and full suites green.
- [x] 0.29 Write failing test `test_v25_customer_disclosure_treats_opening_source_as_pending` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "v25 customer disclosure remains version-pending".
- [x] 0.30 Implement v26 source-table version handling in disclosure schema checks to pass 0.29.
- [x] 0.31 Refactor disclosure version checks; keep focused and full suites green.
- [x] 0.32 Write failing test `test_v26_customer_disclosure_checks_but_does_not_project_opening_sources` in `test/features/stammdaten/customer_data_disclosure_export_test.dart` for scenario "v26 source table is checked but not projected".
- [x] 0.33 Implement source schema validation without customer-row projection to pass 0.32.
- [x] 0.34 Refactor disclosure serialization; keep focused and full suites green.
- [x] 0.35 Write failing direct-SQL tests `test_opening_source_insert_or_replace_preserves_original_when_recursive_triggers_are_off` and `test_finalized_close_insert_or_replace_preserves_original_when_recursive_triggers_are_off` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart`; both must assert complete evidence remains unchanged.
- [x] 0.36 Add source and finalized-close pre-insert guards, plus schema-health parity, to reject `INSERT OR REPLACE` without relying on recursive triggers.
- [x] 0.37 Refactor the immutability guards and schema checks, including source-reference collation and case-only REPLACE protection; the disclosure-level collation regression is `test_v26_customer_disclosure_rejects_nocase_opening_source_unique_index` under the existing v26 disclosure scenario; keep focused and full suites green.

## 1. accounting: Tagesabschluss

- [ ] 1.1 Write failing test `test_tagesabschluss_creation` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Tagesabschluss creation"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Tagesabschluss creation" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_counting_discrepancy` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Counting discrepancy"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "Counting discrepancy" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_close_integrity_hash_uses_canonical_utf8_bytes` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for inherited scenario "GoBD signature"; assert canonical field order, integer cents, UTF-8 bytes, and SHA-256 digest only, with no authenticated-signature claim.
- [ ] 1.8 Implement the inherited integrity-digest scenario without an authenticated-signature claim to pass 1.7.
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
- [ ] 1.19 Write failing test `test_expected_cash_source_is_unavailable` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Expected cash source is unavailable"; assert a missing, mismatched, or incomplete v26 source blocks writes, balances, closes, and PDFs without fallback values.
- [ ] 1.20 Implement the specified behavior for "Expected cash source is unavailable" to pass 1.19.
- [ ] 1.21 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.22 Write failing test `test_daily_close_columns_map_expected_count_and_account` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Daily close columns map to expected and counted values"; assert `betrag`, `kassenbestand`, `differenz`, and explicit `konto_id` mapping.
- [ ] 1.23 Implement the specified behavior for "Daily close columns map to expected and counted values" to pass 1.22.
- [ ] 1.24 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.25 Write failing test `test_finalized_close_requires_digest_verification` in `test/features/accounting/cashbook_and_daily_close_workspace_test.dart` for scenario "Finalized close requires digest verification"; assert unknown, missing, or mismatched evidence remains unverified.
- [ ] 1.26 Implement the specified behavior for "Finalized close requires digest verification" to pass 1.25.
- [ ] 1.27 Refactor the affected code; keep the focused and full suites green.

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
- [ ] 3.4 Write failing test `test_incomplete_or_ambiguous_cash_history_is_unavailable` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Incomplete or ambiguous cash history is unavailable"; assert there is no usable amount and no zero or `konten.saldo` fallback.
- [ ] 3.5 Implement the specified behavior for "Incomplete or ambiguous cash history is unavailable" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.7 Write failing test `test_verified_setup_opening_counted_once` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Verified opening cash is counted once"; after v26 source integration supplies the event, assert `konten.saldo` is corroborating metadata and is not added.
- [ ] 3.8 Implement the specified behavior for "Verified opening cash is counted once" to pass 3.7.
- [ ] 3.9 Refactor the affected code; keep the focused and full suites green.

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
- [ ] 4.13 Write failing test `test_concurrent_close_finalization_cannot_duplicate_a_record` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Concurrent close finalization cannot duplicate a record"; assert it fails for the right reason.
- [ ] 4.14 Implement the specified behavior for "Concurrent close finalization cannot duplicate a record" to pass 4.13.
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
- [ ] 6.4 Write failing test `test_finalized_close_cannot_be_rewritten` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Finalized close cannot be rewritten"; assert it fails for the right reason.
- [ ] 6.5 Implement the specified behavior for "Finalized close cannot be rewritten" to pass 6.4.
- [ ] 6.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.7 Write failing test `test_failed_evidence_migration_rolls_back` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Failed evidence migration rolls back"; assert it fails for the right reason.
- [ ] 6.8 Implement the specified behavior for "Failed evidence migration rolls back" to pass 6.7.
- [ ] 6.9 Refactor the affected code; keep the focused and full suites green.

## 7. db: Tagesabschluss finalization prevents duplicate identities

- [ ] 7.1 Write failing test `test_duplicate_guard_runs_in_a_serialized_transaction` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Duplicate guard runs in a serialized transaction"; assert it fails for the right reason.
- [ ] 7.2 Implement the specified behavior for "Duplicate guard runs in a serialized transaction" to pass 7.1.
- [ ] 7.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 7.4 Write failing test `test_legacy_rows_without_one_verified_identity_block_a_new_close` in `test/db/cashbook_and_daily_close_workspace_migration_test.dart` for scenario "Legacy rows without one verified identity block a new close"; assert it fails for the right reason.
- [ ] 7.5 Implement the specified behavior for "Legacy rows without one verified identity block a new close" to pass 7.4.
- [ ] 7.6 Refactor the affected code; keep the focused and full suites green.

## 8. pdf: Tagesabschluss PDF

- [ ] 8.1 Write failing test `test_tagesabschluss_generation` in `test/features/pdf/cashbook_and_daily_close_workspace_test.dart` for scenario "Tagesabschluss generation"; assert it reads the stored verified snapshot and labels the digest as integrity-only.
- [ ] 8.2 Implement the specified behavior for "Tagesabschluss generation" to pass 8.1.
- [ ] 8.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.4 Write failing test `test_tagesabschluss_pdf_flags_counting_discrepancy` in `test/features/pdf/cashbook_and_daily_close_workspace_test.dart` for scenario "Counting discrepancy"; assert the stored nonzero difference is flagged without recalculation or posting.
- [ ] 8.5 Implement the specified behavior for "Counting discrepancy" to pass 8.4.
- [ ] 8.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.7 Write failing test `test_incomplete_or_legacy_close_has_no_pdf` in `test/features/pdf/cashbook_and_daily_close_workspace_test.dart` for scenario "Incomplete or legacy close has no PDF"; assert missing/incomplete v26 source, legacy rows, or incomplete v27 close evidence produces no artifact.
- [ ] 8.8 Implement the specified behavior for "Incomplete or legacy close has no PDF" to pass 8.7.
- [ ] 8.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.10 Write failing test `test_changed_snapshot_is_not_exported` in `test/features/pdf/cashbook_and_daily_close_workspace_test.dart` for scenario "Changed snapshot has no PDF"; assert malformed, unknown-version, non-canonical, and hash-mismatched evidence produces no artifact.
- [ ] 8.11 Implement the specified behavior for "Changed snapshot has no PDF" to pass 8.10.
- [ ] 8.12 Refactor the affected code; keep the focused and full suites green.

## 9. receipts-and-payment-reconciliation: Cash posting and receipt reference commit atomically

- [ ] 9.1 Write failing test `test_cash_posting_and_receipt_reference_roll_back_together` in `test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart` for scenario "Failed receipt reference rolls back the balanced cash posting"; inject reference-persistence failure and assert the posting group, lines, relationship, and balance effect all roll back.
- [ ] 9.2 Implement the specified behavior for "Failed receipt reference rolls back the balanced cash posting" to pass 9.1.
- [ ] 9.3 Refactor the affected code; keep the focused and full suites green.

## 10. Implementation order

- Implement v26 source migration and setup-source transactions only after task 0.1 passes.
- Then implement the complete account/date report and cashbook writers, followed by v27 close evidence/finalization and PDF behavior.
- Keep the separate v28 e-invoice tax migration out of this change; do not change schema order without a fresh contract review.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep mapped scenario rows in `test-plan.md` red until their named end-to-end tests pass.

## Scoped implementation progress: account/date balance core

- Added a standalone calculator that accepts an explicit account currency, a verified opening event, and complete movement evidence. It uses integer cents with the app's two-decimal convention, counts the opening exactly once, aggregates only committed cash-account movements after the opening cutover, accepts only the explicit supported two-decimal ISO currency set, rejects mixed currencies, caps each result at JSON's exact integer limit, and returns unavailable when evidence is incomplete, ambiguous, or outside that limit.
- The focused ten-test unit suite passed and scoped analysis found no issues. The suite covers unsupported and malformed currencies plus positive and negative cases where individually JSON-safe values produce an unsafe aggregate. These checks cover the pure calculator only; profile-export integration, AppServices, report, and UI integration remain open. The v26 source contract and storage/setup implementation now belong to this change; profile portability and application wiring still gate enabling app-level cashbook operations.
