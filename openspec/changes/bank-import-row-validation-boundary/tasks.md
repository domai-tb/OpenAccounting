> **Gate status: IMPLEMENTED / VERIFIED.** Parent orchestration approved this package for implementation. All tasks below are complete; executable evidence is recorded in `verify.md`.

## 0. Compile-only migration before behavior tests

- [x] 0.1 Confirm the implementation branch is still `dev`, the working tree contains no unrelated edits, and the current A-004 source locations/types/schema match the evidence in `proposal.md` and `design.md`.
- [x] 0.2 Compile-only prerequisite, before writing any of the six red tests: make `RawTx.datum` nullable and migrate only the existing constructor, `copyWith`, parser/service/page, and test call sites so the current valid paths compile. Preserve the pre-change `ImportRowFailure` API and JSON behavior at this gate (a temporary non-null assertion at the old date serialization call site is allowed solely to preserve that behavior). Do not add `ImportRowFailure.sourceRowNumber`, populate raw metadata, change `toJson()`, or implement row-level validation in this task. Run `fvm flutter analyze`, formatting, and a compile/test discovery check; do not write the six behavior tests here.
- [x] 0.3 Keep `bank_imports` schema/migration code unchanged; prove `fehler_details` and all outcome count columns are present in the existing test database after the compile-only migration.

## 1. Mixed malformed dates retain valid rows and raw diagnostics

- [x] 1.1 Write failing `test_bank_import_row_validation_mixed_malformed_dates` from `test-plan.md`; parameterize the exact CSV/CAMT fixtures including invalid and empty date cells, assert valid persistence and row identity, and retain direct source-identity and `failure.toJson()['parsed_datum'] == null`/raw-field assertions. The first run MUST fail at the existing parser/service batch rejection, not at nullable call-site compilation; use only already-compiling map/dynamic probes for the not-yet-present source getter.
- [x] 1.2 Implement only row-level date capture and validation in `parseCsv`, `parseCamtXml`, and the import loop so invalid/empty cell values become failures while valid rows continue. Leave the source getter and safe structured JSON behavior unimplemented so the same red test advances to those intended behavior failures.
- [x] 1.3 Implement the dedicated source-identity behavior: add/populate `rawDatum`, `rawBetrag`, and `sourceRowNumber` through parser/review/service paths, add the read-only delegating `ImportRowFailure.sourceRowNumber`, and preserve the confirmed-batch `rowNumber`. This follows the red assertions; it is not part of task 0.2.
- [x] 1.4 Implement the dedicated nullable diagnostic behavior: make `ImportRowFailure.toJson()` null-safe and serialize `raw_datum`, `raw_betrag`, `source_row`, explicit nullable `parsed_datum`, and the other required fields. The direct JSON assertion must remain red until this task.
- [x] 1.5 Refactor the date parser/model path without changing valid normalized dates or the `rowNumber`/`sourceRowNumber` distinction; rerun the focused test and existing upload/CAMT/parser regression tests with the full VM suite green.

## 2. Mixed malformed amounts retain valid rows and raw diagnostics

- [x] 2.1 Write failing `test_bank_import_row_validation_mixed_malformed_amounts` from `test-plan.md`; cover invalid and empty CSV amounts plus invalid and empty CAMT `<Amt>` fixtures, preserve raw amount text, and assert only valid rows persist.
- [x] 2.2 Implement row-level amount capture/normalization so `_parseBetrag` errors, including empty values, become `ImportRowFailure` with canonical `Betrag ungültig` after history creation while valid rows use the existing canonical storage value.
- [x] 2.3 Refactor amount diagnostics and ensure dedupe/scoring run only after successful normalization; rerun the focused amount test, dedup tests, and full VM suite.

## 3. Invalid edited review rows use the same boundary

- [x] 3.1 Write failing `test_bank_import_parse_review_confirm_preserves_invalid_date_with_valid_row` from `test-plan.md`; use `BankImportPage` with its injected file reader and real parser/service, assert the invalid raw date remains in review without a nullable `_formatDate` crash, then confirm and assert history, persistence, source identity, raw value, canonical category, and status.
- [x] 3.2 Change parser-to-review mapping and `_EditableBankRow.toRawTx()`/`_importRows()` to retain raw controller text, use a null-safe date display (`rawDatum` before `_formatDate`), and defer date/amount validation to `BankImportService`, preserving `sourceRowNumber` and retry mapping.
- [x] 3.3 Refactor page/service handoff and failure-row rendering while keeping valid edits, category values, and current retry UI behavior intact; rerun the focused widget/service test and VM suite.

## 4. History status, counts, and diagnostics describe persisted outcomes

- [x] 4.1 Write failing `test_bank_import_row_validation_history_status_counts_and_diagnostics` from `test-plan.md`; assert the mixed partial row and all-failed row against both `ImportResult` and `bank_imports`, including decoded raw fields, `source_row`, explicit nullable `parsed_datum`, exact canonical diagnostic prefixes, and the dual-invalid date-first single-failure contract.
- [x] 4.2 Add ordered `diagnostics` to `ImportRowFailure`, validate date before amount without short-circuiting, and finalize `teilweise`/`fehlgeschlagen` using persisted imported/duplicate/failed counts without changing legacy fallback writes. The source identity and null-safe structured `toJson()` contract is already covered by the dedicated red/behavior tasks 1.1, 1.3, and 1.4; this task only wires diagnostics into history at write time.
- [x] 4.3 Refactor history reading/UI projections to consume the existing count columns and diagnostic text; rerun history/failure-accounting tests plus the full VM suite.

## 5. Corrected retry deduplicates persisted rows and imports only corrections

- [x] 5.1 Write failing `test_bank_import_row_validation_corrected_retry_deduplicates_persisted_rows` from `test-plan.md`; fail one row on the first pass, correct it, resubmit it with the persisted row, and assert one new row/one duplicate and stable hashes.
- [x] 5.2 Route the existing retry path through only failed rows after correction, retain the original source identity/raw values until correction, and keep `_hasDuplicate` as the single duplicate decision.
- [x] 5.3 Refactor retry mapping/history assertions without adding a retry-specific table or key; rerun retry/dedup regression tests and the full VM suite.

## 6. Malformed structure and batch preconditions remain batch rejection

- [x] 6.1 Write failing `test_bank_import_row_validation_malformed_structure_is_batch_rejection` from `test-plan.md`; cover empty input, missing header/template/mapping, invalid account, empty confirmed rows, unclosed CSV quote, CAMT unsupported/missing required elements, exact nested `<BookgDt><Dt>2026-03-15</ValDt></BookgDt>`, and unclosed tags. Assert `BankImportException`, no successful row persistence, and no row-level `ImportRowFailure` result.
- [x] 6.2 Add an explicit CAMT tag-stack/nesting guard and required-element guard before row extraction, preserving page `recordRejectedImport` handling while changing only cell-level date/amount handling; ensure malformed structure and preconditions never create a partial transaction batch.
- [x] 6.3 Refactor parser error messages/recovery metadata and rerun upload/CAMT regression tests, focused row-boundary tests, and the full VM suite.
- [x] 6.4 Clarify and test self-closing CAMT `<Amt/>` and `<Dt/>` as present empty row values, preserve absent required elements as batch rejection, and verify the parser, spec, and review contract agree.

## 7. Cross-platform evidence and handoff

- [x] 7.1 On Linux, run the focused VM tests, relevant existing bank-import tests, then `fvm flutter test --dart-define=platform=vm`; record exact pass/fail counts and flip all test-plan rows only after the named tests are green.
- [x] 7.2 On macOS and Windows, run only `fvm flutter analyze`, formatting, `git diff --check`, and strict OpenSpec validation; record these as static evidence without claiming VM/database execution.
- [x] 7.3 Re-run strict change validation with `openspec validate bank-import-row-validation-boundary --type change --strict --json` and `openspec validate --specs --strict`, inspect for spec drift, and create `verify.md` only after review approval, TDD evidence, and all tasks are complete.
