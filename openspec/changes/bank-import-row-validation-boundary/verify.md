# Verification

Verified 2026-09-29 on branch `dev` with the approved bank-import change and no unrelated route or audit files in the scoped diff.

## TDD evidence

The six required scenarios were added and first run against the pre-fix implementation. The initial failures were the intended batch boundary failures: CSV invalid dates and amounts were rejected by `parseCsv`, empty date cells raised `Datum fehlt`, corrected retry could not parse the malformed row, and the production review test could not open review because parsing rejected the row.

After implementation, the focused command passed all 6 named scenarios:

```text
fvm flutter test --dart-define=platform=vm \
  test/integration/audit/bank-import-row-validation-boundary_test.dart \
  test/features/bank_import/row_validation_boundary_test.dart
6 passed
```

The focused boundary tests were then run with the existing bank-import feature and workflow suites:

```text
fvm flutter test --dart-define=platform=vm \
  test/integration/audit/bank-import-row-validation-boundary_test.dart \
  test/features/bank_import/row_validation_boundary_test.dart \
  test/features/bank_import/upload_test.dart \
  test/features/bank_import/camt_test.dart \
  test/features/bank_import/dedup_test.dart \
  test/features/bank_import/failure_accounting_test.dart \
  test/features/bank_import/history_fields_test.dart \
  test/features/bank_import/parser_dedup_regression_test.dart \
  test/features/bank_import/retry_dedup_test.dart \
  test/integration/audit/bank-import-workflow-integrity_test.dart
39 passed
```

The full Linux/VM suite passed:

```text
fvm flutter test --dart-define=platform=vm
763 passed
```

## Static and specification gates

- `fvm flutter analyze` — passed, no issues found.
- `fvm dart format --line-length=120 --set-exit-if-changed` on all changed Dart files — passed.
- `git diff --check` — passed.
- `openspec validate bank-import-row-validation-boundary --type change --strict --json` — 1 change passed, 0 failed.
- `openspec validate --specs --strict` — 53 specs passed, 0 failed.

No database migration or schema change was required. macOS and Windows were not executed; their evidence remains static-only as defined by the package.

## Post-commit self-closing CAMT cleanup

The post-commit verifier finding was resolved by treating self-closing `<Amt/>` and `<Dt/>` elements as present empty cell values. The parser now retains those rows for service-level validation; absent required elements remain batch rejection. The new boundary test passed:

```text
fvm flutter test --dart-define=platform=vm \
  test/integration/audit/bank-import-row-validation-boundary_test.dart \
  --plain-name test_bank_import_row_validation_self_closing_camt_cells_are_empty_row_failures
1 passed
```

The prior focused boundary plus existing bank-import suite evidence remains 39 passed, and the prior full Linux/VM suite evidence remains 763 passed. The full VM suite was not rerun after this narrow cleanup. Fresh post-cleanup static and specification gates are recorded in the review round below: analyzer, format, diff-check, strict change validation, and strict spec validation all passed.
