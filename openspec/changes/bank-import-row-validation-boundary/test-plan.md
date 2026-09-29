> **Gate status: IMPLEMENTED / VERIFIED.** Parent orchestration approved this package. All six named scenarios were first run red against the pre-fix boundary and now pass on Linux/VM; exact evidence is recorded in `verify.md`.

## Test Plan

<!-- Every scenario from specs/ mapped exactly once. All rows intentionally start red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| `specs/bank-import-row-validation-boundary/spec.md` → Import rows are validated independently from batch structure | Mixed malformed dates retain valid rows and raw diagnostics | `test/integration/audit/bank-import-row-validation-boundary_test.dart` | `test_bank_import_row_validation_mixed_malformed_dates` | ✅ 1 passed |
| `specs/bank-import-row-validation-boundary/spec.md` → Import rows are validated independently from batch structure | Mixed malformed amounts retain valid rows and raw diagnostics | `test/integration/audit/bank-import-row-validation-boundary_test.dart` | `test_bank_import_row_validation_mixed_malformed_amounts` | ✅ 1 passed |
| `specs/bank-import-row-validation-boundary/spec.md` → Import rows are validated independently from batch structure | Self-closing CAMT cells are empty row values | `test/integration/audit/bank-import-row-validation-boundary_test.dart` | `test_bank_import_row_validation_self_closing_camt_cells_are_empty_row_failures` | ✅ 1 passed |
| `specs/bank-import-row-validation-boundary/spec.md` → Import rows are validated independently from batch structure | Malformed structure and batch preconditions remain batch rejection | `test/integration/audit/bank-import-row-validation-boundary_test.dart` | `test_bank_import_row_validation_malformed_structure_is_batch_rejection` | ✅ 1 passed |
| `specs/bank-import-row-validation-boundary/spec.md` → Review edits use the same row failure, identity, diagnostic, and recovery contract | Invalid edited review row is reported beside a valid row | `test/features/bank_import/row_validation_boundary_test.dart` | `test_bank_import_parse_review_confirm_preserves_invalid_date_with_valid_row` | ✅ 1 passed |
| `specs/bank-import-row-validation-boundary/spec.md` → Review edits use the same row failure, identity, diagnostic, and recovery contract | History status, counts, and diagnostics describe persisted outcomes | `test/integration/audit/bank-import-row-validation-boundary_test.dart` | `test_bank_import_row_validation_history_status_counts_and_diagnostics` | ✅ 1 passed |
| `specs/bank-import-row-validation-boundary/spec.md` → Review edits use the same row failure, identity, diagnostic, and recovery contract | Corrected retry deduplicates persisted rows and imports only corrections | `test/integration/audit/bank-import-row-validation-boundary_test.dart` | `test_bank_import_row_validation_corrected_retry_deduplicates_persisted_rows` | ✅ 1 passed |

## Fixture and Coverage Notes

- `test_bank_import_row_validation_mixed_malformed_dates` ran both fixtures and passed valid persistence, exact CSV/CAMT source ordinals, canonical diagnostics, raw fields, and null-safe JSON.
- `test_bank_import_row_validation_mixed_malformed_amounts` ran both fixtures and passed valid persistence, canonical amount diagnostics, and raw amount preservation including empty strings.
- `test_bank_import_row_validation_self_closing_camt_cells_are_empty_row_failures` passed a valid sibling plus `<Amt/>` and `<Dt/>`; both self-closing values remained row-level failures with empty raw fields and canonical diagnostics.
- `test_bank_import_row_validation_malformed_structure_is_batch_rejection` passed every listed batch rejection fixture with `BankImportException` and zero persisted transactions.
- `test_bank_import_parse_review_confirm_preserves_invalid_date_with_valid_row` passed through the production `BankImportPage`, retained `not-a-date` in review, confirmed one valid row plus one canonical date failure, and finalized history.
- The history test passed returned and persisted counts/statuses, decoded raw diagnostics, all-failed status, and one date-first dual-invalid failure with ordered categories and combined error.
- The corrected-retry test passed one corrected import, one duplicate skip, two persisted rows, and unique hashes.
- Compile-only prerequisite: task 0.2 SHALL change only `RawTx.datum` nullability and migrate existing call sites so current valid paths compile, then run static analysis/format checks before any of the six test files or red tests are written. It SHALL NOT add the `ImportRowFailure.sourceRowNumber` getter, populate raw metadata, or change `toJson()`; those are later red/behavior tasks. This prerequisite is not an additional scenario row.
- Linux/VM executable evidence: focused boundary plus existing bank-import suites passed 39 tests; full `fvm flutter test --dart-define=platform=vm` passed 763 tests.
- macOS and Windows remain static-only evidence per the package; Linux analyzer, formatting, diff-check, and strict OpenSpec validation all passed.
- The implementation and six required tests are now part of the scoped change; all six rows are green.
