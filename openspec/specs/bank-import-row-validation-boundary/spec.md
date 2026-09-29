# bank-import-row-validation-boundary Specification

## Purpose
TBD - created by archiving change bank-import-row-validation-boundary. Update Purpose after archive.

## Requirements

### Requirement: Import rows are validated independently from batch structure

CSV and CAMT row date/amount values SHALL be validated inside the existing per-row import loop. Invalid or empty date/amount cells in a structurally valid row SHALL produce an `ImportRowFailure`; they SHALL NOT abort valid sibling rows. File/account/input-empty/template/header errors and malformed CSV/XML structure SHALL remain batch-level `BankImportException` outcomes before row persistence. The parse → review → confirm pipeline SHALL preserve raw invalid cells into the review controllers and SHALL not format a null parsed date.

The exact parser matrix is:

| Input | Row-level failure | Batch-level rejection |
|---|---|---|
| CSV | `Datum` cell is invalid or empty; `Betrag` cell is invalid or empty | Empty input; no header; missing required `Datum`/`Betrag` mapping; unclosed quote or otherwise malformed CSV structure |
| CAMT | A closed `<Ntry>` has an invalid or empty `<Dt>` value, including `<Dt/>`; a closed `<Ntry>` has an invalid or empty `<Amt>` value, including `<Amt/>` | Empty input; unsupported XML/non-CAMT; missing required `<Amt>` or `<BookgDt>/<ValDt>/<Dt>` element in an `<Ntry>`; nested tag mismatch such as `<BookgDt><Dt>2026-03-15</ValDt></BookgDt>`; unclosed XML/`<Ntry>` tags |
| Service/page | — | `kontoId` is missing/non-positive, or the confirmed input row list is empty |

Row-level diagnostics SHALL use the same canonical German categories for CSV, CAMT, and edited review rows: `Datum ungültig` and `Betrag ungültig`. A diagnostic MAY append row/source context, but its category prefix SHALL remain stable. Making `RawTx.datum` nullable for compilation alone does not satisfy this requirement: source identity, raw-field propagation, and safe diagnostic JSON remain separate behavior contracts.

#### Scenario: Mixed malformed dates retain valid rows and raw diagnostics

- **GIVEN** a CSV fixture with `15.03.2026;10,00;Valid CSV;A`, `not-a-date;20,00;Bad CSV date;B`, and `;30,00;Empty CSV date;C`, and a structurally valid CAMT fixture with one closed `<Ntry>` dated `2026-03-15`, one closed `<Ntry>` whose `<BookgDt><Dt></Dt></BookgDt>` is empty, and one closed `<Ntry>` with `not-a-date` in `<BookgDt><Dt>`
- **WHEN** each fixture is imported into a valid account
- **THEN** the valid row is persisted, each malformed row is returned as one `ImportRowFailure` with a `Datum ungültig` diagnostic, `rowNumber` remains its one-based confirmed-batch ordinal, `sourceRowNumber` identifies its CSV physical line or CAMT `<Ntry>` ordinal, and `toJson()` directly contains `raw_datum`, `raw_betrag`, `source_row`, and `parsed_datum: null` without throwing; the direct JSON assertion is red until nullable serialization is implemented

#### Scenario: Mixed malformed amounts retain valid rows and raw diagnostics

- **GIVEN** a CSV fixture with `15.03.2026;10,00;Valid CSV;A`, `16.03.2026;not-a-number;Bad CSV amount;B`, and `17.03.2026;;Empty CSV amount;C`, and a structurally valid CAMT fixture with one closed `<Ntry>` amount `10.00`, one closed `<Ntry>` amount `bad`, and one closed `<Ntry>` containing an empty `<Amt></Amt>` element
- **WHEN** each fixture is imported into a valid account
- **THEN** the valid row is persisted, each malformed row is returned as an `ImportRowFailure` with a `Betrag ungültig` diagnostic, the raw amount (including the empty string) is preserved in `raw_betrag`, and no malformed row reaches `bank_transaktionen`

#### Scenario: Self-closing CAMT cells are empty row values

- **GIVEN** a structurally valid CAMT fixture with one closed `<Ntry>` containing a valid amount and date, one closed `<Ntry>` containing `<Amt/>`, and one closed `<Ntry>` containing `<BookgDt><Dt/></BookgDt>`
- **WHEN** the fixture is imported into a valid account
- **THEN** parsing returns all three rows; the valid row is persisted; the self-closing amount and date become row-level failures with empty `raw_betrag`/`raw_datum`, source ordinals 2 and 3, and canonical `Betrag ungültig`/`Datum ungültig` diagnostics; the batch is not rejected

#### Scenario: Malformed structure and batch preconditions remain batch rejection

- **GIVEN** any one of these inputs: empty CSV/XML, CSV without a header, CSV with no matching required header/template, CSV with an unclosed quote, CAMT without a CAMT marker, a CAMT `<Ntry>` missing `<Amt>`, a CAMT `<Ntry>` missing every booking/value date element, the exact nested malformed fixture `<BookgDt><Dt>2026-03-15</ValDt></BookgDt>`, an unclosed `<Ntry>`, or a service/page submission with no valid account or an empty confirmed row list
- **WHEN** parsing or upload/import validation runs
- **THEN** the operation raises a batch-level `BankImportException` from the explicit structural/required-element guard, the error identifies the batch/precondition failure, no row-level `ImportRowFailure` result is produced, and no successful transaction is persisted for that input

### Requirement: Review edits use the same row failure, identity, diagnostic, and recovery contract

Edited review rows SHALL pass their raw date and amount text through the same service validation boundary as parsed file rows. A bad edited row SHALL not abort valid sibling rows. The production parse → review → confirm path SHALL retain an invalid parsed date in `_EditableBankRow.dateController` and SHALL avoid calling `_formatDate` with a null value. `RawTx.sourceRowNumber` SHALL carry the source identity; `ImportRowFailure.sourceRowNumber` SHALL be a read-only getter that delegates to the failed transaction's `sourceRowNumber`; `ImportRowFailure.rowNumber` SHALL remain the one-based ordinal of the confirmed input list. `ImportRowFailure.toJson()` SHALL be safe when `RawTx.datum` is null and SHALL include `row`, `source_row`, `raw_datum`, `raw_betrag`, `parsed_datum`, `verwendungszweck`, `partner`, `diagnostics`, and the canonical German `error`. `parsed_datum` SHALL be explicitly present with `null` when date parsing failed, or an ISO date when it succeeded.

If both date and amount are invalid or empty, validation SHALL use date-first precedence and emit exactly one `ImportRowFailure`. Its `diagnostics` list SHALL be `['Datum ungültig', 'Betrag ungültig']` in that order, its combined `error` SHALL preserve that order, and both raw fields SHALL remain in the failure JSON.

#### Scenario: Invalid edited review row is reported beside a valid row

- **GIVEN** a production-facing parse → review → confirm flow starts with one valid CSV row and one row whose parsed date is invalid, opens review without a nullable `_formatDate` crash, preserves the invalid raw date in `_EditableBankRow.dateController`, and the user confirms after leaving that row invalid
- **WHEN** the import is confirmed
- **THEN** the valid row is persisted, the malformed row is returned as one `ImportRowFailure` with its edited/raw value, `sourceRowNumber`, canonical `Datum ungültig` category, and safe JSON diagnostics, and the result status is `teilweise` or `fehlgeschlagen` according to persisted-row count

#### Scenario: History status, counts, and diagnostics describe persisted outcomes

- **GIVEN** a confirmed batch has one persisted valid row and one row-level date/amount failure
- **WHEN** history finalization completes
- **THEN** the history row stores `anzahl_importiert` and `anzahl_transaktionen` equal to one, `anzahl_fehlgeschlagen` equal to one, `duplikate` equal to the actual duplicate count, status `teilweise`, and JSON `fehler_details` containing the row ordinal, `source_row`, raw value, `parsed_datum` (null when date parsing failed), `diagnostics`, and canonical diagnostic; an all-failed batch uses status `fehlgeschlagen` and imported count zero

#### Scenario: Corrected retry deduplicates persisted rows and imports only corrections

- **GIVEN** a first attempt persisted a valid row and returned a malformed row failure
- **WHEN** the user corrects and retries only the failed row while resubmitting the already persisted row through the existing retry path
- **THEN** the corrected row is persisted once, the prior row is counted as a duplicate, no duplicate transaction is created, and the retry result/history counts reflect one import and one duplicate
