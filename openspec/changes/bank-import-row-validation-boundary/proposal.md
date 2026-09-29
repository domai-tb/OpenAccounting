## Why

The A-004 audit finding is reproducible: `BankImportService._validateImport` rejects the first malformed date or amount before the history row and per-row persistence loop run. One bad statement cell therefore prevents valid rows from being saved, even though the archived bank-import contract already promises recoverable partial imports.

## What Changes

- Move date and amount validation for CSV, CAMT, and edited review rows into the existing per-row `ImportRowFailure` boundary.
- Define the exact boundary: invalid or empty date/amount cells inside a structurally valid row are row failures; empty input, missing template/header, invalid account selection, missing CAMT required elements, and malformed CSV/XML structure are batch `BankImportException` failures.
- Preserve invalid raw date/amount text through parse → review → confirm; opening the review screen must never call `_formatDate` with a null date or replace the raw text with a placeholder.
- Preserve source identity through `RawTx.sourceRowNumber`; expose it from `ImportRowFailure.sourceRowNumber` as a read-only delegating getter while keeping `rowNumber` as the confirmed-batch ordinal.
- Preserve raw date/amount text and a safe, explicit nullable `parsed_datum` field in each failed-row diagnostic and in `bank_imports.fehler_details`.
- Use canonical German row diagnostics (`Datum ungültig` and `Betrag ungültig`) for CSV, CAMT, and edited review failures, persisted at history finalization.
- When both date and amount are invalid or empty, emit one failure in deterministic date-first order, retaining both raw values and both diagnostic categories.
- Keep persisted counts and status truthful: valid rows persist, failed rows do not, and mixed/all-failed batches become `teilweise`/`fehlgeschlagen` respectively.
- Make corrected retries submit only failed rows while existing deduplication continues to skip already persisted rows.
- Add one-to-one red tests for mixed malformed date, mixed malformed amount, the production parse → review → confirm path, history counts/status/diagnostics, corrected retry deduplication, and malformed structure/batch rejection.

**BREAKING**: The internal `RawTx` input contract must represent an unparsed date while retaining the current valid-row callers. The implementation must migrate all in-repository nullable-date call sites before behavior tests and keep the existing `importTransactions` entry point usable for valid `RawTx` lists. That compile-preserving migration changes only the nullable type and existing call sites; the source-identity getter, raw-field propagation, and null-safe diagnostic JSON are deliberately deferred to dedicated red/behavior tasks.

## Capabilities

### New Capabilities

- `bank-import-row-validation-boundary`: Defines the row-versus-batch validation matrix, source identity, canonical diagnostics, and retry contract for bank imports.

### Modified Capabilities

- `bank-import`: The existing import workflow and outcome requirements gain row-level validation and structured raw-value diagnostics. The existing mode and reconciliation requirements are unchanged.

## Impact

- Production paths: `lib/features/bank_import/bank_import_entity.dart`, `bank_import_service.dart`, and the review-row conversion in `bank_import_page.dart`.
- Persistence: reuse the existing `bank_imports.anzahl_*` and `fehler_details` columns; no migration or new table is proposed.
- Tests: add focused bank-import feature/audit coverage under `test/features/bank_import/` and `test/integration/audit/`.
- Platforms: executable behavior evidence is required on Linux/VM. macOS and Windows are limited to static analysis, formatting, and OpenSpec validation for this change.
- Out of scope: automatic/manual import mode exposure, payment/receipt reconciliation, new file formats, and changes to duplicate-key policy.
