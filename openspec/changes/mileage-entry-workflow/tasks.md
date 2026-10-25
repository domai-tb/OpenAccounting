# Mileage Entry Workflow Tasks

## Historical baseline record

The prior contract's 24 implementation tasks were marked complete before this revision. That record does not establish coverage or completion for the new structured eligibility facts, policy effective dates/rates, fail-closed exclusions, half-up calculation contract, v23/v24 migrations, or the corrected 45-scenario test matrix. The previous nine focused test results are recorded as historical only in `verify.md`.

## Revised-contract implementation — core slice complete; follow-ups open

The Round 6 independent review approved the corrected contract at baseline HEAD `335056f0533ea7d6a38f8e0d624bb9a6e1308594` (recorded in `review.md`). The authorized core v25 migration, additive v28 correction lifecycle repair, role-configuration service, transactional posting and correction operations, EÜR source reader, profile/schema inventories, and bank-import selector are implemented and covered by focused runtime runs. The 65-row test matrix remains the source of scenario status; the exhaustive schema/version matrix, full unsafe-role matrix, incomplete EÜR group regression, and other bank-specific selectors remain open. The role-settings UI and focused workflow/router tests passed in the 2026-10-24 verification and were independently approved after correcting the evidence label. Task 85's account-creation UI passed its focused runtime run and was independently approved at scoped diff SHA `a957ac0b578c0dcc42c83ce761a066bf9c40660d41d78bfa0c14c429c64d9445`. The policy-boundary assertion task remains separate from those scenario rows.

### Completed bounded implementation checkpoints

- [x] Generate stable UUIDv4 trip IDs and verify persisted identity plus exact integer distance in `test_record_a_business_trip` (2026-10-18 focused run; see `verify.md`).
- [x] Add the localized mileage entry workspace at `/banking?view=mileage`, preserving existing Banking routes and query parameters; wire record/edit/calculate/post actions through `AppServices` and `MileageEntryUseCases` (2026-10-18 focused run; see `verify.md`).
- [x] Add regression coverage that v22 unknown calculated trips are demoted while posted facts are preserved, and that the additive v24 correction also repairs v23 profiles; the focused mileage migration tests pass (see `verify.md`).
- [x] Reject `NULL` in all seven required calculation-snapshot columns through direct SQL, and guard `postTripWithPort` against untrusted eligibility/policy snapshots before invoking the posting port (see `verify.md`).
- [x] Fail current-v28 startup closed without recreating a missing mapping or period-closure table, and add v28 correction lifecycle proof with full normalized trigger-DDL health/repair checks (including marker-retaining weakened guards) while preserving v27 trip and journal rows; see the named migration regressions in `verify.md`.
- [x] Reject malformed v25 mileage mapping primary-key, role-check, foreign-key, and closure date/range schemas in migration and customer-disclosure health checks; see `verify.md`.
- [x] Keep direct SQL correction application and posted-trip terminal transitions fail-closed when given a fabricated accounting event ID; the additive v28 guard validates the matching atomic reversal/replacement group while preserving prior trip and journal rows (see `verify.md`).

### `mileage-entry` tests (accepted correction scenarios implemented; policy-boundary assertion verified)

- [x] Add `test_mileage_form_is_keyboard_operable_and_localized` in `test/features/mileage/mileage_entry_workflow_test.dart` (2026-10-18 focused run; see `verify.md`).
- [x] Add `test_posting_is_unavailable_without_each_prerequisite` in `test/features/mileage/mileage_entry_workflow_test.dart` (2026-10-18 focused run; see `verify.md`).
- [x] Add `test_prepare_replacement_correction_without_accounting_changes` in `test/features/mileage/mileage_entry_workflow_test.dart` (2026-10-24 focused run; see `verify.md`).
- [x] Add `test_apply_accepted_replacement_correction_atomically` in `test/features/mileage/mileage_entry_workflow_test.dart` (2026-10-25 focused run; the prior posting is reversed and the replacement posts in one correction group, preserving original facts, a UTC audit timestamp, a business-local journal date, and idempotent retry; see `verify.md`).
- [x] Add `test_undo_posted_trip_through_correction` in `test/features/mileage/mileage_entry_workflow_test.dart` (2026-10-25 focused run; undo applies a void correction with two reversal legs and preserves the original trip and journal; see `verify.md`).
- [x] Add `test_correction_apply_rejects_unprepared_replacement_without_mutation` in `test/features/mileage/mileage_entry_workflow_test.dart` (2026-10-25 focused run; a draft without its complete accepted posting group remains unapplied and unchanged; see `verify.md`).
- [x] Add `test_failed_or_repeated_correction_is_safe` in `test/features/mileage/mileage_entry_workflow_test.dart` (2026-10-25 focused run; injected failure rolls back all writes and a successful retry adds no journal rows; see `verify.md`).
- [x] Add `posted mileage corrections are accessible in both locales and preserve source facts` and `undo preparation locks actions and ignores completion after workspace disposal` in `test/features/mileage/mileage_entry_workflow_test.dart` (2026-10-25 focused run; verify remount-restored Apply, no ordinary Post, failed-apply retry, all original trip facts, and a draft correction with no apply after disposal; see `verify.md`).
- [x] Separately extend and rerun existing `test_calculate_from_an_approved_policy` to assert the v1 effective-date boundary, both supported vehicle classes and rates, exact integer half-up cent rounding, and every fail-closed eligibility exclusion (2026-10-24 focused run; see `verify.md`).

### `db` tests (remaining planned scenarios; see each checkbox below)

- [ ] Add `test_create_mileage_tables_on_fresh_install` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_reject_direct_insert_into_finalized_trip_state` in `test/db/mileage_schema_test.dart`.
- [x] Add v24-to-v25 mapping/snapshot migration coverage in `test/db/mileage_lifecycle_migration_test.dart`; it preserves existing account, category, journal, and trip rows and creates no default mapping values (2026-10-18; see `verify.md`).
- [ ] Add `test_failed_mileage_migration_rolls_back` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_downgrade_rejects_without_changing_mileage_data` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_database_rejects_mutating_or_deleting_posted_trip` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_allows_only_valid_trip_lifecycle_transitions` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_requires_matching_applied_correction_for_terminal_transition` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_requires_posted_replacement_before_source_correction` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_keeps_applied_and_cancelled_corrections_immutable` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_database_rejects_unlinked_or_invalid_lifecycle_transitions` in `test/db/mileage_schema_test.dart`.
- [ ] Add `test_fresh_install_matches_versioned_table_inventory` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_pre_v13_profile_is_valid_before_mileage_tables_are_required` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_pre_v9_profile_is_valid_before_later_tables_are_required` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_v7_to_v8_migration_creates_missing_payment_table` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_missing_payment_table_at_v8_fails_before_repair` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_payment_table_repair_preserves_existing_rows` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_v12_to_v13_migration_adds_markers_and_mileage_tables` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_v9_requires_category_history` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_unknown_lazy_table_is_not_created_by_feature_initialization` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_table_inventory_matches_schema_version_and_initialized_lazy_tables` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_version_18_inventory_has_expected_table_count` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_unknown_or_malformed_application_table_fails_health` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_failed_required_table_creation_rolls_back_version_and_schema` in `test/db/mileage_migration_test.dart`.
- [ ] Add `test_present_document_email_tables_require_declared_schema` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `test_missing_mileage_table_at_v13_fails_without_repair` in `test/db/mileage_schema_health_test.dart`.
- [ ] Add `fresh_profile_has_no_default_mileage_role_mapping` in `test/db/mileage_posting_account_mapping_test.dart`.
- [ ] Add `v24_profile_is_healthy_without_mapping_table` in `test/db/mileage_posting_account_mapping_test.dart`.
- [ ] Add `v25_requires_mapping_schema_but_allows_no_mapping_row` in `test/db/mileage_posting_account_mapping_test.dart`.
- [x] Verify mileage legs persist category and mapping snapshots in `test/features/accounting/euer_test.dart` (`posting is atomic, idempotent, rejects conflicting retry, and snapshots both legs`; 2026-10-18; see `verify.md`).
- [ ] Add `test_v24_profile_export_is_complete_without_mapping_table` in `test/db/mileage_export_gate_test.dart`.
- [ ] Add `test_v25_inventory_requires_mapping_table_and_exports_version_aware` in `test/db/mileage_export_gate_test.dart`.
- [ ] Add `test_profile_and_customer_exports_apply_v13_and_v25_presence_rules` in `test/db/mileage_export_gate_test.dart`.
- [ ] Add `test_export_with_undeclared_mileage_table_is_incomplete` in `test/db/mileage_export_gate_test.dart`.
- [x] Add focused v22-to-v25 migration/lifecycle coverage in `test/db/mileage_lifecycle_migration_test.dart` (2026-10-18; seven migration/lifecycle tests passed in the final focused run; exhaustive migration/lifecycle coverage remains open).

## Contract and implementation gates — core review closed; follow-ups open

- [x] Record Round 5's spec-only approval at `d6d441c4c4e0779c83282f5fb16b824630d89688`; this approval is invalidated by the version correction in this revision.
- [x] Obtain fresh independent review of the corrected contract before dependent implementation; Round 6 `APPROVE` is recorded in `review.md`. A separate limited approval of the v25 core implementation is recorded there; the user-facing correction and undo controls now have a dedicated localized widget scenario, while fresh UI-slice review and the broader schema/report follow-ups remain open.
- [x] Align maintained `db`, profile-portability, and customer-disclosure inventories: retain 55 known names through v19, add both v25 mileage posting tables for 57 known names, and define version-aware health/export behavior; runtime inventory coverage is tracked separately in `test-plan.md`.
- [x] Reconcile the DB migration-version conflict: mileage tables and shared markers are created at v13 from v12, v9 remains the category-history migration, and mileage mapping/snapshot fields are added at v25. Fresh schema and v24 upgrade paths are covered by the focused migration tests.
- [x] Implement the reviewed core backend slice against the contract and update tested matrix rows with named runtime evidence; remaining matrix scenarios and user-facing settings stay open.
- [x] Define explicit profile-local travel-expense and private-contribution Sachkonto/category roles, trusted category provenance, fail-closed behavior, a role-keyed mapping table with at most one row per role, and the two-leg `(mileage_trip, trip UUID)` contract from live repository evidence; no fixed account numbers or defaults are approved. Extend the maintained account requirement to support explicit Sachkonten while preserving existing types/rows. The original contract-only checkpoint had no production code; implementation status is recorded below (2026-10-18; see `verify.md`).
- [x] Capture the two production-path tests before implementation; the historical red run had 11 workflow tests pass and both new tests fail with `Bad state: posting unavailable`. Both now pass in the latest six-file run (2026-10-18; exact results in `verify.md`).
- [x] Implement v25 mapping persistence and explicit service-level role configuration; exclude Sachkonto from the bank-import selector (focused regression passed). The role-settings UI focused runtime test and independent review passed; account CRUD and other bank-specific selector filters remain open.
- [x] Wire the canonical two-leg mileage posting operation so journal group, per-leg mapping snapshots, trip state, and posting event ID commit atomically; same-payload replay returns the group and conflicting payload rejects. The v25 inclusive date-range closure table is empty by default and both the posting command and lifecycle trigger reject a trip date covered by an explicit closure (focused test evidence in `verify.md`).
- [x] Verify exactly-once EÜR inclusion in legacy and settlement modes in `test/features/accounting/euer_test.dart` (`settlement EÜR includes mileage once and keeps stored mapping after category edits`; see `verify.md`).
- [x] Verify category edits do not change historical EÜR values or mileage provenance in `test/features/accounting/euer_test.dart` (`settlement EÜR includes mileage once and keeps stored mapping after category edits`; 2026-10-18; see `verify.md`).
- [ ] Add `euer_rejects_incomplete_mileage_source_group` in `test/features/accounting/euer_test.dart`.
- [x] Verify the bank-import selector retains bank/cash accounts and excludes Sachkonto in `test/features/bank_import/import_mode_test.dart` (`bank-import selector keeps bank and cash accounts but excludes Sachkonto`; see `verify.md`).
- [x] Add user-facing Sachkonto creation for explicit mileage roles; the localized account-type choice persists Sachkonto without bank fields, while the default bank-account path keeps its existing optional-IBAN behavior (2026-10-24 focused run; independently approved at scoped diff SHA `a957ac0b578c0dcc42c83ce761a066bf9c40660d41d78bfa0c14c429c64d9445`; see `verify.md`).
- [x] Add localized mileage role-settings UI and account/category selection; implementation and the focused workflow/router tests pass, and independent review approved the slice after the evidence-label correction (2026-10-24; see `verify.md`).

## Evidence discipline

- `test-plan.md` is the row-by-row 65-scenario index: earlier focused runs passed 97, 68, 36, and 30 tests respectively; the 2026-10-25 mileage workflow, EÜR, and lifecycle-migration run passed 55 tests. The matrix still has missing and partial scenarios covering the exhaustive schema/version inventory, incomplete EÜR groups, and other bank-specific selectors. Role-settings, Sachkonto-creation, and atomic correction runtime evidence is recorded in `test-plan.md`; the exact current matrix remains there.
- Structural OpenSpec validation and formatting checks do not prove runtime behavior, migrations, posting, or correction semantics.
- Do not mark tests complete from a proposed test name, prior review, or historical run.

## 2026-10-22 mileage workspace regression slice

- [x] Reject whole-kilometer distances above 9,999,999,999 before converting to hundredths, including the large input `184467440737095517`.
- [x] Require deliberate trip-kind, vehicle-source, and vehicle-class selection for new trips; no eligible defaults are preselected.
- [x] Preserve successful save, calculate, and post commits when the follow-up list refresh fails; after a committed post, use the effective displayed state to disable both edit and post retries.
- [x] Add trip search and lifecycle-state filtering with a reset action.
- [x] Keep posting prerequisite errors visible in the selected trip card while the prerequisite guard remains fail-closed.
- These bounded workspace regressions are covered in `test-plan.md` and `verify.md`; the broader 65-scenario matrix and its documented gaps remain open.
