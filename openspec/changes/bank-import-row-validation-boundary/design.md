## Context

The archived `bank-import-workflow-integrity` change already implements independent persistence attempts, `ImportRowFailure`, retry UI state, deduplication, and additive `bank_imports` outcome columns. The 2026-09-29 A-004 evidence shows the remaining boundary defect in `lib/features/bank_import/bank_import_service.dart`: `_validateImport` validates every `RawTx` date and amount before `_createHistory` and before the row loop at lines 217-245 and 427-460. CSV parsing also throws immediately for a malformed date/amount, CAMT parsing does the same inside the `Ntry` loop, and `_EditableBankRow.toRawTx()` throws before the service is called.

Current interfaces matter here. `RawTx` is used directly by parser tests, deduplication/scoring, the page review model, and `importTransactions`; `ImportRowFailure` already carries a `RawTx`, one-based row number, and JSON conversion. `bank_imports` already has `anzahl_importiert`, `anzahl_auto_kategorisiert`, `anzahl_manuelle_pruefung`, `anzahl_fehlgeschlagen`, and `fehler_details`. The change should reuse these boundaries rather than add another database table or a second import workflow.

## Goals / Non-Goals

**Goals:**

- Allow valid rows to persist when sibling CSV/CAMT/review date or amount cells are invalid or empty.
- Preserve invalid parser values through the production parse → review → confirm flow without formatting a nullable date.
- Preserve `RawTx.sourceRowNumber`, expose it read-only through `ImportRowFailure.sourceRowNumber`, and keep `rowNumber` as the confirmed-batch ordinal.
- Preserve raw date/amount text in safe JSON with explicit nullable `parsed_datum`.
- Use canonical German `Datum ungültig`/`Betrag ungültig` diagnostics consistently across CSV, CAMT, and review edits, persisted during history finalization.
- Define date-first precedence for rows where both date and amount are invalid/empty, with one failure carrying both raw values and ordered diagnostics.
- Keep file/account/empty/template/header and CAMT structural errors as batch rejection.
- Keep history counts/status and corrected retry behavior truthful and deduplicated.
- Define Linux/VM executable evidence and macOS/Windows static-only evidence.

**Non-Goals:**

- Changing the automatic/manual import mode contract or exposing mode controls.
- Implementing receipt matching, payment posting, or reconciliation.
- Changing the SHA-256 dedupe inputs, duplicate override policy, database schema, or migration version.
- Adding a CSV/XML dependency or replacing the existing parser strategy.

## Decisions

### 1. Extend the existing row value instead of adding a parallel import pipeline

Extend `RawTx` minimally so valid callers keep their current constructor and fields while an unparsed row can carry `datum == null`, `betrag` as the original text, `rawDatum`, `rawBetrag`, and `sourceRowNumber`. Keep `ImportRowFailure.transaction` as the same `RawTx` so `retryableRows`, existing page mapping, and current tests remain on one type. Valid parser rows continue to expose the existing normalized two-decimal `betrag`; invalid rows retain their raw text in the value used for validation and explicit raw metadata.

`RawTx.sourceRowNumber` is the source identity: CSV parsers set the physical source line, CAMT parsers set the one-based `<Ntry>` ordinal, and review rows retain that value through edits. `ImportRowFailure.sourceRowNumber` is read-only and delegates to `transaction.sourceRowNumber`; it does not replace `rowNumber`, which remains the one-based ordinal of the confirmed input list. For legacy manually constructed rows without source metadata, the service shall assign the confirmed ordinal to a copied row before creating a failure so every returned failure has a source identity. These are end-state behaviors, not task 0.2 work.

An alternative `ImportInputRow` wrapper was rejected because it would duplicate the existing row shape, force a second `importRows` API, and require adapters in the page, service, retry result, and tests. Making `RawTx` carry a nullable parsed date is the smallest interface change that preserves source data without a sentinel date.

### 2. Use an exact CSV/CAMT row-versus-batch matrix

`parseCsv` and `parseCamtXml` SHALL continue to throw for empty input, missing CSV headers or required mappings, no matching template, unsupported/non-CAMT XML, missing required CAMT `<Amt>` or date elements, unclosed quotes, mismatched tags, and unclosed `<Ntry>`/XML structures. They SHALL stop throwing for an invalid or empty date/amount *value* in an otherwise closed CSV row or CAMT `<Ntry>` and return a `RawTx` carrying its source row and raw text. `kontoId <= 0` and an empty confirmed row list remain service-level batch `BankImportException` cases.

For CAMT, a closed `<Ntry>` containing `<Amt>bad</Amt>`, `<Amt></Amt>`, or `<BookgDt><Dt></Dt></BookgDt>` is row-level. A `<Ntry>` without `<Amt>`, without any required booking/value date element, or with the exact malformed nesting `<BookgDt><Dt>2026-03-15</ValDt></BookgDt>` is batch-level. Add an explicit tag-stack/nesting guard and required-element guard before row extraction; generic opening/closing counts alone are insufficient. This distinction is fixed by the fixtures named in the delta spec and test plan.

The service validates each row after creating history and before deduplication/persistence. It always evaluates date before amount. If both fail, it creates one `ImportRowFailure` with `diagnostics == ['Datum ungültig', 'Betrag ungültig']` and `error == 'Datum ungültig; Betrag ungültig'`; it still retains both raw fields. A single row failure uses the corresponding one-item list. These canonical German categories are shared by CSV, CAMT, and edited review controllers; context may follow the combined error, but history stores the categories at write time rather than translating them later.

### 3. Route edited review text through the service

`parseCsv`/`parseCamtXml` SHALL return an invalid-date `RawTx` with `datum == null`, `rawDatum` equal to the source text, and `sourceRowNumber` set. The production page SHALL construct `_EditableBankRow` using `rawDatum` when present and SHALL use an explicit null guard before `_formatDate(source.datum!)`; opening review must therefore preserve `not-a-date` or an empty string rather than crash. `_EditableBankRow.toRawTx()` SHALL stop throwing for date/amount text and instead retain the controller text plus a nullable parsed date when it can be parsed. `_importRows()` SHALL call the existing service with those rows. The service owns canonical amount normalization and date/amount diagnostics for both parsed and edited rows, so the page cannot accidentally reject the whole selection before history creation. The regression test must exercise this production-facing path, not only a service-only surrogate.

### 4. Persist safe, structured diagnostics using the existing column

`ImportRowFailure.toJson()` SHALL never dereference a nullable `datum`. It SHALL always include `row`, `source_row`, `raw_datum`, `raw_betrag`, `parsed_datum`, `verwendungszweck`, `partner`, `diagnostics`, and `error`. `parsed_datum` is an ISO date string when a date parsed successfully and explicit JSON `null` when it did not; `raw_datum` and `raw_betrag` preserve empty strings as empty strings. `_finalizeHistory()` SHALL serialize one such object per failed row into `fehler_details`; rejected batch attempts may continue to use a diagnostic message object. Existing count columns remain the source of truth for persisted rows, duplicates, manual review, and failures.

The mixed-date test SHALL directly invoke `toJson()` on a failure with `datum == null` and assert the key/value contract before implementation. Task 0.2 keeps the old date serialization behavior only long enough to compile; the first run must fail at the existing batch rejection, then the source-identity/raw-field assertions fail until task 1.3, and the nullable serialization assertion fails until task 1.4. This is the selected red probe for the nullable serialization boundary. The production-facing parse → review → confirm test SHALL directly prove review construction retains the invalid raw date and does not call `_formatDate` with null.

### 5. Preserve the existing retry and dedupe semantics

The first pass creates one history row, attempts all rows independently, and returns failed rows. A retry submits only corrected failed rows from the existing page outcome; if the UI also resubmits a prior valid row, `_hasDuplicate` skips it. No new retry token, migration, or duplicate-key policy is introduced.

## Risks / Trade-offs

- **[Nullable parsed date reaches an old caller] →** Make only the nullable-date/call-site migration a compile-only prerequisite before any of the six behavior tests; update every in-repository caller, guard scoring/hash/formatting, and run static analysis before writing red tests. Do not add the source getter or diagnostic JSON behavior at that gate. The review constructor explicitly prefers raw text and only formats a non-null date.
- **[A permissive parser could hide malformed structure] →** Retain explicit quote/tag-count and required-element checks and test both row-value and structural CAMT fixtures.
- **[Canonical diagnostics could drift by input path] →** Centralize row failure classification in the service and assert exact category prefixes for CSV, CAMT, and edited review cases.
- **[Both fields invalid could produce two failures or non-deterministic wording] →** Validate date first, then amount without short-circuiting; return one failure with ordered categories and both raw fields.
- **[Raw diagnostics are stored as JSON text] →** Keep stable machine fields (`row`, `source_row`, `raw_datum`, `raw_betrag`, `parsed_datum`, `error`) and do not parse history text to compute counts.
- **[Source line and confirmed-row numbers differ when headers/blank lines are present] →** Persist both; keep `rowNumber` compatibility and use `sourceRowNumber` for source navigation.

## Migration Plan

No database migration is required. The existing `bank_imports` columns and `fehler_details` field are present in the current schema and additive compatibility path. Implementation updates the entity, parser/service, page conversion, and tests; existing databases continue to read/write the same columns. Rollback is a source revert with no schema rollback step.

The implementation order begins with a compile-only `RawTx.datum` nullability and existing-call-site migration. It preserves the pre-change failure API and date serialization behavior and does not add `sourceRowNumber`, raw metadata population, or null-safe JSON. After that static gate passes, the mixed-date red test is written; row-level capture, source identity/getter, and nullable raw diagnostic serialization are then implemented in separate behavior tasks before the remaining scenario work.

## Open Questions

- Should a future public API expose source identity beyond `RawTx.sourceRowNumber` and the read-only failure getter? This change keeps both fields internal and does not rename `rowNumber`.
- Should raw diagnostics be localized at read time? This package fixes canonical German messages at write time for stable history/audit records; a broader localization policy remains outside A-004.
- The archived contract does not define different user-facing wording for CSV and CAMT. This package intentionally shares the `Datum ungültig`/`Betrag ungültig` categories; richer copy remains outside scope.
