## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Current State |
|-------------|----------|-----------|-----------|---------------|
| specs/accounting/spec.md → Tagesabschluss | Tagesabschluss creation | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_tagesabschluss_creation | 🟢 green |
| specs/accounting/spec.md → Tagesabschluss | Counting discrepancy | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_counting_discrepancy | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | GoBD signature | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_close_integrity_hash_uses_canonical_utf8_bytes | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Daily close columns map to expected and counted values | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_daily_close_columns_map_expected_count_and_account | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Finalized close requires digest verification | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_finalized_close_requires_digest_verification | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Double close prevention | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_double_close_prevention | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Concurrent finalization is serialized | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_concurrent_finalization_is_serialized | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Ambiguous legacy close identity | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_ambiguous_legacy_close_identity | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Expected cash source is unavailable | test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_expected_cash_source_is_unavailable | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Cashbook view uses typed committed cash events | Approved cash event appears in the cashbook | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_approved_cash_event_appears_in_the_cashbook | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Cashbook view uses typed committed cash events | Missing posting contract blocks cash entry | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_missing_posting_contract_blocks_cash_entry | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Cashbook view uses typed committed cash events | Imported or legacy row is not treated as cash | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_imported_or_legacy_row_is_not_treated_as_cash | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Cashbook view uses typed committed cash events | Committed cash event cannot be silently rewritten | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_committed_cash_event_cannot_be_silently_rewritten | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Setup opening source has one durable account-scoped identity | Setup opening source commits atomically | test/features/setup/cashbook_opening_source_test.dart | test_setup_opening_source_commits_atomically | 🟢 green |
| specs/cashbook-and-daily-close-workspace/spec.md → Setup opening source has one durable account-scoped identity | Setup retry preserves opening source identity | test/features/setup/cashbook_opening_source_test.dart | test_setup_retry_preserves_opening_source_identity | 🟢 green |
| specs/cashbook-and-daily-close-workspace/spec.md → Cash balance uses a complete account/date result | Complete balance is shown from the report result | test/features/accounting/cashbook_and_daily_close_workspace_test.dart; test/features/cashbook/account_date_balance_source_test.dart | test_tagesabschluss_creation; resolves a verified opening source plus one committed balanced cash payment | 🟢 green |
| specs/cashbook-and-daily-close-workspace/spec.md → Cash balance uses a complete account/date result | Verified opening cash is counted once | test/features/cashbook/account_date_balance_source_test.dart | resolves a verified opening source plus one committed balanced cash payment | 🟢 green |
| specs/cashbook-and-daily-close-workspace/spec.md → Cash balance uses a complete account/date result | Incomplete or ambiguous cash history is unavailable | test/features/cashbook/account_date_balance_source_test.dart | fails closed for missing or mismatched opening evidence and legacy account rows | 🟢 green |
| specs/cashbook-and-daily-close-workspace/spec.md → Daily close records use the approved close result | Complete daily close is finalized | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_complete_daily_close_is_finalized | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Daily close records use the approved close result | Expected balance or persistence mapping is unavailable | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_expected_balance_or_persistence_mapping_is_unavailable | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Daily close records use the approved close result | Discrepancy requires an explanation | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_discrepancy_requires_an_explanation | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Daily close records use the approved close result | Existing close remains read-only | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_existing_close_remains_read_only | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Daily close records use the approved close result | Concurrent close finalization cannot duplicate a record | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_concurrent_close_finalization_cannot_duplicate_a_record | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Daily close records use the approved close result | Ambiguous legacy closes block finalization | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_ambiguous_legacy_closes_block_finalization | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Daily close records use the approved close result | Single unsigned legacy close blocks finalization | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_single_unsigned_legacy_close_blocks_finalization | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Cashbook views follow desktop localization and accessibility rules | Localized keyboard use remains complete | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_localized_keyboard_use_remains_complete | 🔴 red |
| specs/cashbook-and-daily-close-workspace/spec.md → Cashbook views follow desktop localization and accessibility rules | Narrow layout keeps close actions reachable | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_narrow_layout_keeps_close_actions_reachable | 🔴 red |
| specs/db/spec.md → v27 stores daily-close evidence and protects finalized rows | Close evidence migration preserves existing history | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_close_evidence_migration_preserves_existing_history | 🔴 red |
| specs/db/spec.md → v26 stores an account-scoped setup opening source | v26 migration preserves legacy history without backfill | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_v26_opening_source_migration_preserves_legacy_history_without_backfill | 🟢 green |
| specs/db/spec.md → v26 stores an account-scoped setup opening source | Fresh and upgraded v26 source schemas match | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_fresh_and_upgraded_v26_opening_source_schemas_match | 🟢 green |
| specs/db/spec.md → v26 stores an account-scoped setup opening source | Opening-source identity is unique and immutable | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_opening_source_identity_is_unique_and_immutable | 🟢 green |
| specs/db/spec.md → v27 stores daily-close evidence and protects finalized rows | Finalized close cannot be rewritten | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_finalized_close_cannot_be_rewritten | 🔴 red |
| specs/db/spec.md → v27 stores daily-close evidence and protects finalized rows | Failed evidence migration rolls back | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_failed_evidence_migration_rolls_back | 🔴 red |
| specs/db/spec.md → v27 stores daily-close evidence and protects finalized rows | Fresh and upgraded v27 close schemas match | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_fresh_and_upgraded_v27_close_schemas_match | 🟢 green |
| specs/db/spec.md → Tagesabschluss finalization prevents duplicate identities | Duplicate guard runs in a serialized transaction | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_duplicate_guard_runs_in_a_serialized_transaction | 🔴 red |
| specs/db/spec.md → Tagesabschluss finalization prevents duplicate identities | Legacy rows without one verified identity block a new close | test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_legacy_rows_without_one_verified_identity_block_a_new_close | 🔴 red |
| specs/pdf/spec.md → Tagesabschluss PDF | Tagesabschluss generation | test/features/pdf/cashbook_and_daily_close_workspace_test.dart | test_tagesabschluss_generation | 🔴 red |
| specs/pdf/spec.md → Tagesabschluss PDF | Counting discrepancy | test/features/pdf/cashbook_and_daily_close_workspace_test.dart | test_tagesabschluss_pdf_flags_counting_discrepancy | 🔴 red |
| specs/pdf/spec.md → Tagesabschluss PDF | Incomplete or legacy close has no PDF | test/features/pdf/cashbook_and_daily_close_workspace_test.dart | test_incomplete_or_legacy_close_has_no_pdf | 🔴 red |
| specs/pdf/spec.md → Tagesabschluss PDF | Changed snapshot has no PDF | test/features/pdf/cashbook_and_daily_close_workspace_test.dart | test_changed_snapshot_is_not_exported | 🔴 red |
| specs/receipts-and-payment-reconciliation/spec.md → Cash posting and receipt reference commit atomically | Failed receipt reference rolls back the balanced cash posting | test/features/cashbook_and_daily_close_workspace/cashbook_and_daily_close_workspace_test.dart | test_cash_posting_and_receipt_reference_roll_back_together | 🔴 red |
| specs/profile-data-portability/spec.md → v26 account-opening sources are preserved in complete profile archives | Pre-v26 profile does not require the opening-source table | test/features/setup/profile_data_portability_test.dart | test_v25_profile_does_not_require_v26_opening_source_table | 🟢 green |
| specs/profile-data-portability/spec.md → v26 account-opening sources are preserved in complete profile archives | v26 profile export preserves opening-source rows | test/features/setup/profile_data_portability_test.dart | test_v26_profile_export_preserves_opening_source_rows | 🟢 green |
| specs/profile-data-portability/spec.md → v26 account-opening sources are preserved in complete profile archives | Missing v26 source schema blocks complete export | test/features/setup/profile_data_portability_test.dart | test_missing_v26_source_schema_blocks_complete_export | 🟢 green |
| specs/customer-data-disclosure-export/spec.md → Opening-source schema is checked without disclosing company cash data | v25 customer disclosure remains version-pending | test/features/stammdaten/customer_data_disclosure_export_test.dart | test_v25_customer_disclosure_treats_opening_source_as_pending | 🟢 green |
| specs/customer-data-disclosure-export/spec.md → Opening-source schema is checked without disclosing company cash data | v26 source table is checked but not projected | test/features/stammdaten/customer_data_disclosure_export_test.dart | test_v26_customer_disclosure_checks_but_does_not_project_opening_sources; test_v26_customer_disclosure_rejects_nocase_opening_source_unique_index | 🟢 green |

## Coverage Notes

- Every scenario in all seven change delta specs is mapped to one named test using capability-relative `specs/<capability>/spec.md` paths. Twelve of 46 rows are green, including the routed Tagesabschluss creation UI scenario; the other 34 rows remain red.
- The atomicity row passed with 11 deterministic SQLite abort-trigger failures across company creation, new-account creation, existing-account association, category creation, journal insertion, saldo update, and source insertion. New and existing Kasse paths each assert that complete company, account, category, journal, and source state is unchanged after failure.
- The retry row passes after a later committed `Einnahme` changes Kasse saldo from `125.00` to `150.00`: an exact `125.00` setup retry preserves the opening source, opening journal, later movement, and current saldo; a conflicting `150.00` opening retry remains rejected without changing them.
- The supplementary v26 implementation-review regressions below passed at base HEAD `5272cbaf128cb5feb6c6bb7674e85e92cd3d7ff9`; they do not change the 46 mapped delta-spec scenario rows.
- The supplementary v26/v27 trigger-semantics regressions `test_v26_schema_health_rejects_weakened_opening_source_immutability_triggers` and `test_v27_schema_health_rejects_legacy_signature_bypass` passed in the focused 9-test migration suite. Both first failed because schema health accepted weakened stored trigger DDL.
- The supplementary v26 migration regression `test_v26_schema_health_rejects_partial_opening_source_unique_index` checks that a partial unique `journal_id` index cannot satisfy the canonical source identity constraint.
- The migration source-reference regressions `test_v26_schema_health_rejects_nocase_opening_source_unique_index` and `test_opening_source_case_only_insert_or_replace_preserves_original` cover BINARY-index health enforcement and preservation of original evidence on case-only REPLACE conflicts; both passed in the four-file focused suite (86/86). With the pre-insert collation guard temporarily disabled, the case-only REPLACE test failed because the insert succeeded (row id 2); restoring the guard passed the test 1/1.
- The customer-disclosure collation regression `test_v26_customer_disclosure_rejects_nocase_opening_source_unique_index` maps to the existing v26 schema-check scenario. Its fixture uses the canonical three unique indexes with only `source_reference` collated NOCASE. A deliberate red run with the collation guard disabled returned `complete` instead of `incomplete`; after restoring the guard, the focused test passed 1/1.
- Remaining red scenarios include v27 evidence, portability, report, database, AppServices, and UI behavior.
- Tests are planned for the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.

### Supplementary account/date balance core checks

These unit checks cover the standalone calculator slice and do not change the status of the 46 mapped end-to-end scenario rows above.

| Test File | Test Name | Current Result |
|-----------|-----------|----------------|
| test/features/cashbook/account_date_balance_test.dart | counts the verified opening once and only committed scoped cash movements | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | returns unavailable when the approved opening source is absent | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | returns unavailable for missing, duplicated, or unverified opening evidence | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | returns unavailable when the opening event is also presented as a cash movement | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | returns unavailable for incomplete history, unbalanced cash, or duplicate posting identity | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | carries account currency, rejects mixed currencies, and refuses integer-cent overflow | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | scopes opening cardinality to the requested account in a multi-account batch | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | rejects unsupported or malformed cashbook currency codes | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | accepts the exact JSON-safe cent limit and rejects 2^53 plus one | 🟢 passed |
| test/features/cashbook/account_date_balance_test.dart | returns unavailable when individually safe amounts exceed the JSON-safe aggregate | 🟢 passed |

The pure calculator suite verifies exact integer cents under the app's two-decimal convention. It carries the account currency without conversion, accepts only the explicit supported two-decimal ISO currency set, rejects unsupported/malformed codes and mismatches, scopes opening evidence to the requested account, and fails closed when a source value or aggregate exceeds JSON's exact integer range. All ten tests passed in the focused rerun after the reviewer corrections.

### Supplementary production account/date balance source checks

These tests supplement the delta-spec scenarios above with SQLite-backed source verification and the user-driven route flow.

| Test File | Test Name | Current Result |
|-----------|-----------|----------------|
| test/features/cashbook/account_date_balance_source_test.dart | resolves a verified opening source plus one committed balanced cash payment | 🟢 passed |
| test/features/cashbook/account_date_balance_source_test.dart | fails closed for missing or mismatched opening evidence and legacy account rows | 🟢 passed |
| test/features/cashbook/account_date_balance_source_test.dart | isolates the selected company, account, and requested local date | 🟢 passed |
| test/features/accounting/cashbook_and_daily_close_workspace_test.dart | test_tagesabschluss_creation; prepares only a complete typed balance result | 🟢 passed |

### Supplementary v26 implementation-review regressions

The v26 remediation regressions supplement, rather than change, the 46 delta-spec scenario mapping above. The lowercase-only currency check and comment-injection checks record later independent validator findings and repairs.

| Test File | Test Name | Current Result |
|-----------|-----------|----------------|
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_v26_schema_health_rejects_weakened_opening_effective_date_glob | 🟢 passed |
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_v26_schema_health_rejects_weakened_opening_currency_code_glob | 🟢 passed |
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_v26_schema_health_rejects_lowercase_only_opening_currency_code_glob | 🟢 passed |
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_v26_schema_health_ignores_expected_opening_date_glob_in_comments | 🟢 passed |
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_v26_schema_health_ignores_expected_opening_currency_glob_in_comments | 🟢 passed |
| test/features/setup/cashbook_opening_source_test.dart | test_setup_rejects_initial_nonzero_saldo_without_journal_history | 🟢 passed |
| test/integration/audit/setup-onboarding-integrity_test.dart | test_setup_onboarding_integrity_4_1_conflicting_opening_retry_is_rejected | 🟢 passed |

### Supplementary v27 close-schema migration regression

This migration check verifies the new evidence-column and immutable-row schema parity. It does not change the status of the 46 mapped delta-spec scenario rows above.

| Test File | Test Name | Current Result |
|-----------|-----------|----------------|
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_fresh_and_upgraded_v27_close_schemas_match | 🟢 passed |

The focused migration suite was rerun after the v27 schema-declaration refactor for task 0.19 and passed 7/7 tests. The full suite remains deferred, so task 0.19 stays open.

### Supplementary disclosure and REPLACE immutability regressions

These checks add versioned disclosure schema coverage and verify that SQLite's `INSERT OR REPLACE` conflict handling cannot erase append-only evidence when `recursive_triggers` is off. They do not change the 46 mapped delta-spec scenario rows above.

| Test File | Test Name | Current Result |
|-----------|-----------|----------------|
| test/features/stammdaten/customer_data_disclosure_export_test.dart | test_v26_customer_disclosure_rejects_malformed_opening_source_schema | 🟢 passed |
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_opening_source_insert_or_replace_preserves_original_when_recursive_triggers_are_off | 🟢 passed |
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_finalized_close_insert_or_replace_preserves_original_when_recursive_triggers_are_off | 🟢 passed |

### Supplementary startup migration-ownership regressions

These tests use `AppDatabase.forProfile`, the production profile opener, to verify that the custom `MigrationRunner` retains schema-version ownership when a v27 or v26 database is missing its opening-source table.

| Test File | Test Name | Current Result |
|-----------|-----------|----------------|
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_v27_reopen_fails_closed_when_opening_source_table_is_missing | 🟢 passed |
| test/db/cashbook_and_daily_close_workspace_migration_test.dart | test_v26_to_v27_upgrade_fails_closed_when_opening_source_table_is_missing | 🟢 passed |
