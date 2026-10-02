## 1. Canonical keyed payment fingerprint

- [x] 1.1 Write failing test `test_keyed_payment_persists_canonical_fingerprint_and_applies_once` and assert missing fingerprint columns/values are the reason
- [x] 1.2 Implement canonical cents, target, derived direction, date policy, and persisted fingerprint to pass 1.1
- [x] 1.3 Refactor fingerprint constants and keep the focused test green
- [x] 1.4 Write failing test `test_invalid_keyed_request_has_no_effect` and assert typed validation/no-side-effect behavior
- [x] 1.5 Implement typed request validation and rollback boundary to pass 1.4
- [x] 1.6 Refactor validation without weakening the no-effect assertions
- [x] 1.7 Write failing test `test_keyed_amount_with_more_than_two_decimals_is_rejected` and assert `amountScale` rather than rounding
- [x] 1.8 Implement strict two-decimal request parsing to pass 1.7
- [x] 1.9 Refactor amount parsing around the existing money helper; focused tests stay green
- [x] 1.10 Write failing test `test_double_inputs_use_exact_decimal_text_without_binary_rounding`
- [x] 1.11 Implement int/shortest-round-trip-double decimal text conversion without binary rounding to pass 1.10
- [x] 1.12 Refactor amount conversion; focused tests stay green
- [x] 1.13 Write failing test `test_missing_date_uses_injected_utc_request_day`
- [x] 1.14 Implement injected UTC clock/date-policy canonicalization to pass 1.13
- [x] 1.15 Refactor date parsing; focused tests stay green
- [x] 1.16 Write failing test `test_unknown_partner_direction_is_rejected`
- [x] 1.17 Implement raw partner direction validation to pass 1.16
- [x] 1.18 Refactor direction derivation; focused tests stay green

## 1A. Public typed errors and validation precedence

- [x] 1A.1 Write failing test `test_typed_idempotency_conflict_exposes_stable_ordered_fields`
- [x] 1A.2 Implement the public error enums, wire values, immutable mismatch ordering, and conflict mapping to pass 1A.1
- [x] 1A.3 Refactor error construction while keeping the focused conflict test green
- [x] 1A.4 Write failing test `test_public_error_codes_use_explicit_snake_case_wire_values` and assert every public error/mismatch enum maps to its complete documented wire value
- [x] 1A.5 Implement explicit error and mismatch wire maps and serialize through them without using enum names to pass 1A.4
- [x] 1A.6 Refactor wire serialization while keeping the complete mapping assertion green
- [x] 1A.7 Write failing test `test_invalid_request_precedes_date_and_direction_errors`
- [x] 1A.8 Implement invalid key/amount/target precedence to pass 1A.7
- [x] 1A.9 Refactor request validation ordering; focused tests stay green
- [x] 1A.10 Write failing test `test_amount_scale_precedes_date_errors`
- [x] 1A.11 Implement exact decimal-text scale detection to pass 1A.10
- [x] 1A.12 Refactor amount parsing; focused tests stay green
- [x] 1A.13 Write failing test `test_date_errors_precede_unknown_direction_errors`
- [x] 1A.14 Implement strict date validation precedence to pass 1A.13
- [x] 1A.15 Refactor date/direction boundary; focused tests stay green
- [x] 1A.16 Write failing test `test_valid_amount_and_date_expose_unknown_direction`
- [x] 1A.17 Implement unknown-direction typed error to pass 1A.16
- [x] 1A.18 Refactor direction error mapping; focused tests stay green
- [x] 1A.19 Write failing test `test_typed_error_defensively_copies_immutable_mismatch_fields`
- [x] 1A.20 Implement defensive mismatch-list copying and an unmodifiable public view to pass 1A.19
- [x] 1A.21 Refactor typed exception construction while keeping the immutability assertions green
- [x] 1A.22 Write failing test `test_typed_error_preserves_human_readable_to_string_message`
- [x] 1A.23 Implement `ForderungenException.toString()` as the unchanged human-readable message to pass 1A.22
- [x] 1A.24 Refactor typed error presentation while keeping the exact-message assertion green

## 2. Fingerprint-safe replay and conflicts

- [x] 2.1 Write failing test `test_identical_key_and_fingerprint_returns_original_effect`
- [x] 2.2 Implement identical replay lookup inside the transaction to pass 2.1
- [x] 2.3 Refactor replay result mapping; focused tests stay green
- [x] 2.4 Write failing test `test_reused_key_with_different_amount_is_typed_conflict`
- [x] 2.5 Implement typed amount mismatch conflict with rollback to pass 2.4
- [x] 2.6 Refactor conflict-field assertions; focused tests stay green
- [x] 2.7 Write failing test `test_reused_key_with_different_target_is_typed_conflict`
- [x] 2.8 Implement target mismatch comparison to pass 2.7
- [x] 2.9 Refactor target comparison; focused tests stay green
- [x] 2.10 Write failing test `test_reused_key_with_different_date_is_typed_conflict`
- [x] 2.11 Implement effective-date/date-policy comparison to pass 2.10
- [x] 2.12 Refactor canonical date parsing; focused tests stay green
- [x] 2.13 Write failing test `test_concurrent_identical_keyed_requests_commit_one_effect`
- [x] 2.14 Implement unique-key loser reload and transaction rollback to pass 2.13
- [x] 2.15 Refactor race handling; all focused replay tests stay green
- [x] 2.16 Write failing test `test_concurrent_conflicting_key_race_reloads_loser_with_ordered_fields` using the permitted deferred WAL fixture for both initial payment attempts
- [x] 2.17 Implement the barrier seam, production-immediate loser reload, complete ordered mismatch list, and zero-side-effect rollback without changing production `BEGIN IMMEDIATE` wiring to pass 2.16
- [x] 2.18 Refactor unique-key race handling; identical and conflicting replay tests stay green
- [x] 2.19 Write failing test `test_persistent_sqlite_lock_exhausts_exactly_three_retries`
- [x] 2.20 Implement the one-time preflight/setup boundary, attempt callback, persistent-lock retry bound, typed `concurrentWriteConflict`, and full rollback with zero setup SQL during attempts to pass 2.19
- [x] 2.21 Refactor lock retry/backoff handling; assert exactly three attempts and unchanged journal/relation/balance snapshots
- [x] 2.22 Write failing test `test_deferred_wal_sqlite_busy_snapshot_reloads_and_classifies_idempotency_conflict` using a test-only transaction factory that opens only the initial payment attempt with `BEGIN DEFERRED`, while asserting production defaults remain `BEGIN IMMEDIATE`
- [x] 2.23 Implement the scoped transaction-factory override, extended `SQLITE_BUSY_SNAPSHOT` detection, stale-transaction rollback, fresh production-immediate key reload, and mismatch classification to pass 2.22
- [x] 2.24 Refactor unique-key/extended-lock handling; assert the deferred override never reaches migration/startup/write-off paths and no direct `concurrentWriteConflict` mapping occurs for `SQLITE_BUSY_SNAPSHOT`

## 3. Version 7 legacy migration

- [x] 3.1 Write failing test `test_v7_lazy_table_migrates_without_changing_legacy_rows`
- [x] 3.2 Implement v7-to-v8 table/nullable-column migration and legacy-unknown classification to pass 3.1
- [x] 3.3 Refactor migration SQL and verify rollback; migration tests stay green
- [x] 3.4 Write failing test `test_missing_v7_relation_table_is_created_safely`
- [x] 3.5 Implement missing-table creation and startup hook to pass 3.4
- [x] 3.6 Refactor feature-schema ownership while preserving base table-count tests
- [x] 3.7 Write failing test `test_present_v7_relation_table_repairs_missing_constraints`
- [x] 3.8 Implement v7 constraint/index repair to pass 3.7
- [x] 3.9 Refactor repair verification while preserving the base 39-table assertion
- [x] 3.10 Write failing test `test_duplicate_legacy_key_rolls_migration_back`
- [x] 3.11 Implement duplicate-constraint rollback and `schemaMigrationFailed` mapping to pass 3.10
- [x] 3.12 Refactor migration rollback checks; migration tests stay green
- [x] 3.13 Write failing test `test_migration_failure_preserves_base_table_count`
- [x] 3.14 Implement injected DDL failure handling and startup ordering to pass 3.13
- [x] 3.15 Refactor feature callback ownership; migration tests stay green
- [x] 3.16 Write failing test `test_app_database_post_ddl_failure_rolls_back_before_startup_side_effects`
- [x] 3.17 Implement the injected `AppDatabase.forTesting` post-DDL failure seam and pre-trigger/seed/service ordering to pass 3.16
- [x] 3.18 Refactor startup failure assertions; migration tests stay green
- [x] 3.19 Write failing test `test_current_v8_repairs_missing_feature_table_transactionally`
- [x] 3.20 Implement current-v8 repair transaction and verification to pass 3.19
- [x] 3.21 Refactor repair path while preserving the base 39-table assertion
- [x] 3.22 Write failing test `test_legacy_key_returns_unknown_fingerprint_conflict`
- [x] 3.23 Implement the legacy-key reservation/conflict code to pass 3.22
- [x] 3.24 Refactor legacy classification queries; migration/replay tests stay green
- [x] 3.25 Write failing test `test_fresh_upgrade_current_v8_repair_and_rollback_share_raw_begin_migration_path` with recording fresh, v7-upgrade, current-v8-repair, and injected-failure fixtures
- [x] 3.26 Implement one shared `MigrationRunner` raw-`BEGIN`/`COMMIT`/`ROLLBACK` helper for fresh/schema startup and current-v8 repair without adding a production transaction delegate to pass 3.25
- [x] 3.27 Refactor migration ownership and startup ordering; keep the recording executor assertions and rollback evidence green

## 4. Conditional write-off and cross-command atomicity

- [x] 4.1 Write failing test `test_valid_writeoff_commits_one_loss_effect`
- [x] 4.2 Implement in-transaction validation, conditional transition, and linked loss relation to pass 4.1
- [x] 4.3 Refactor write-off SQL; focused tests stay green
- [x] 4.4 Write failing test `test_two_simultaneous_writeoffs_commit_one_effect`
- [x] 4.5 Implement zero-row `alreadyClosed` handling and bounded lock retry to pass 4.4
- [x] 4.6 Refactor race cleanup; no orphan assertion stays green
- [x] 4.7 Write failing test `test_writeoff_and_full_payment_race_has_one_effect_no_orphan`
- [x] 4.8 Implement conditional payment transition/rollback coordination to pass 4.7
- [x] 4.9 Refactor cross-command transaction helpers; all race tests stay green
- [x] 4.10 Write failing test `test_invalid_or_closed_writeoff_has_no_effect`
- [x] 4.11 Implement typed reason/closed validation to pass 4.10
- [x] 4.12 Refactor typed error mapping; focused tests stay green
- [x] 4.13 Write failing test `test_conditional_payment_update_rolls_back_on_observed_balance_race`
- [x] 4.14 Implement the dedicated post-state-read interleaving seam, narrowly scoped deferred WAL fixture, and exact id/status/observed-balance affected-row checks for partial, full, and overpayment branches to pass 4.13 while production remains `BEGIN IMMEDIATE`
- [x] 4.15 Refactor payment/write-off transaction helpers; all race tests stay green
- [x] 4.16 Write failing test `test_persistent_sqlite_lock_exhausts_exactly_three_writeoff_retries`
- [x] 4.17 Implement the one-time preflight/setup boundary, write-off attempt callback, three-attempt lock bound, typed `concurrentWriteConflict`, and rollback with zero setup SQL during attempts to pass 4.16
- [x] 4.18 Refactor write-off retry/backoff handling; assert exactly three attempts and unchanged status/balance/journal/relation snapshots
- [x] 4.19 Write failing test `test_ordinary_zero_row_conditional_payment_update_is_already_closed_for_every_branch` and record the original id/status/cents predicate for partial, full, and overpayment branches
- [x] 4.20 Implement the recording conditional-update result seam, `runUpdate == 0` to `alreadyClosed` mapping, and full provisional-row rollback to pass 4.19
- [x] 4.21 Refactor ordinary conditional payment handling; all three branch assertions remain green under production `BEGIN IMMEDIATE`

## 5. Platform and delivery gates

- [x] 5.1 Run `fvm flutter analyze` and focused VM tests on Linux; keep all test-plan rows red until implementation passes
- [x] 5.2 Run `fvm flutter test --dart-define=platform=vm` and `fvm flutter build linux --debug`; record exact results
- [x] 5.3 Run static macOS/Windows analyzer/config-only checks where supported and record unavailable target tooling explicitly
- [x] 5.4 Run `git diff --check` and re-run strict OpenSpec validation before requesting an independent APPROVE review
