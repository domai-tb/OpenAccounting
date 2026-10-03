## MODIFIED Requirements

### Requirement: Import history is actionable

Import history SHALL provide typed rows with ingestion status, imported/duplicate/failed counts, timestamp, and available detail, retry, review, search, and pagination actions. Persisted history statuses SHALL be `importiert` (ingestion completed, including a duplicate-only attempt), `teilweise` (some rows persisted while row failures remain), and `fehlgeschlagen` (row failures remain and no transaction has persisted, or the file was rejected). Retry SHALL be available only for `teilweise` or `fehlgeschlagen` attempts whose persisted row-failure payload validates. A retry SHALL process only the attempt's persisted failed rows under the same `bank_imports.id`; it SHALL preserve successful child rows and their transaction IDs and SHALL update the original history attempt. A failed row resolved as a duplicate SHALL be removed from the failure payload and increase the prior duplicate aggregate exactly once. Prior duplicate outcomes SHALL be retained across retries. Rejected file/parser attempts and legacy or malformed payloads without complete row data SHALL be non-retryable and SHALL offer selection of the source file as a new attempt.

An unresolved manual-review transaction is a persisted row with `status = 'neu'`. `status = 'geprueft'` means an explicit user review/category decision without a journal link; `status = 'gebucht'` means linked to an existing journal entry. A rule-categorized but unconfirmed row remains `neu`; a manually categorized row is `geprueft`; a linked row is `gebucht`; already-reviewed rows are not in the queue. The manual-review count SHALL be derived from `status = 'neu'`, not trusted from the legacy stored scalar. Category correction/confirmation or association with an existing journal entry SHALL update only the selected bank transaction and transition its status as specified by the `bank-import` change. An `importiert` attempt's metadata remains read-only, while its unresolved child transactions remain available through the separate manual-review action. Review edits MUST NOT change import metadata, retry payload, or create journal entries/payments.

`fehler_details` row-failure payloads SHALL use the versioned, validated schema in the `bank-import` change design. Retrying a row SHALL retain it in the payload until successful persistence or duplicate resolution; successful or duplicate-resolved rows SHALL be removed from the failure payload. Retry, persisted child rows, remaining payload, status, duplicate aggregate, and counts SHALL update atomically. A failure-free duplicate-only attempt SHALL be `importiert`, even when it has no persisted transactions. The detail view SHALL show safe localized diagnostics and may show validated bank fields as reviewed row data, but raw bank values MUST NOT appear in error/status text or logs. Retryable values remain in the active profile database and its existing backup/deletion lifecycle; successful payload values are cleared and profile deletion removes remaining values.

History search state SHALL use canonical route query parameters `view=history`, `q`, one-based `page`, and optional `importId`. Search SHALL be case-insensitive across filename, template type, and status only, and filtering SHALL happen before pagination. Results SHALL be sorted by timestamp descending then import ID descending, use 50 rows per page, and report total count and `hasMore`. Opening detail or retry and returning SHALL preserve the complete query. If changes make the requested page invalid, the query SHALL move to the last valid page.

#### Scenario: History row opens details

- **GIVEN** a completed or partial import attempt exists
- **WHEN** the user activates its history row
- **THEN** the typed detail shows attempt metadata, safe failure diagnostics, the number of unresolved child transactions, and only the retry/review actions allowed by the attempt and row states

#### Scenario: Empty history offers import

- **GIVEN** no imports exist
- **WHEN** history renders
- **THEN** it shows a localized explanatory empty state and a primary action to select a file

#### Scenario: Status policy controls actions

- **GIVEN** history contains `importiert`, `teilweise`, and `fehlgeschlagen` attempts, including rejected attempts and attempts with and without unresolved rows
- **WHEN** a row renders
- **THEN** only validated `teilweise`/`fehlgeschlagen` row-failure payloads offer retry, `importiert` attempts do not offer retry, every attempt with unresolved transactions offers review, and rejected or invalid payloads offer a new file selection instead of retry

#### Scenario: Retry resumes persisted failed rows under the original identity

- **GIVEN** a partial attempt has a valid version-1 row-failure payload with a reviewed category, journal selection, source date/amount text, partner, purpose, and Gegenkonto, alongside successful transaction rows
- **WHEN** the user reopens that attempt, corrects the failed row if necessary, and retries
- **THEN** the service validates and processes only the failed row under the original `bank_imports.id`, the persisted row retains every field needed for retry, successful child rows and transaction IDs remain unchanged, and the original attempt shows the updated counts and status

#### Scenario: Repeated retry processes only remaining failures

- **GIVEN** a retry succeeds for some failed rows but leaves another row failed
- **WHEN** the user retries the same history attempt again
- **THEN** only the remaining versioned failed rows are processed, no new history row is created, and prior successful transaction IDs remain unchanged

#### Scenario: Retried row becomes duplicate

- **GIVEN** a failed row remains in the retry payload and an identical transaction now exists in the active account
- **WHEN** the user retries the import
- **THEN** the row is removed from the retry payload without inserting a child row, `duplikate` increases by exactly one over its prior aggregate, and previous successful rows and duplicate outcomes remain unchanged

#### Scenario: Duplicate-only import completes

- **GIVEN** every submitted row is already present and no row-level failures remain
- **WHEN** the import or final retry completes
- **THEN** the attempt is `importiert`, its duplicate count records all duplicate outcomes, and zero persisted child transactions does not make it `fehlgeschlagen`

#### Scenario: Legacy, malformed, and unsupported payloads are not guessed

- **GIVEN** an attempt has legacy message-only JSON, malformed JSON, an unknown payload version, or invalid row fields
- **WHEN** the user opens its history detail
- **THEN** the UI shows a safe non-retryable diagnostic, creates no transaction from inferred fields, and offers selection of the source file as a new attempt

#### Scenario: Rejected whole-file attempt cannot be retried from history

- **GIVEN** a parser or template rejection was recorded without persisted rows or source file contents
- **WHEN** the user opens its history detail
- **THEN** it is identified as a rejected-file attempt with no row retry action and the user can select the source file for a new attempt

#### Scenario: Rule-categorized, manually categorized, linked, and reviewed rows have distinct states

- **GIVEN** one imported row has an unconfirmed rule-assigned category and no journal link (`neu`), one has a manually assigned category and no link (`geprueft`), one is linked to an existing journal entry (`gebucht`), one was already explicitly reviewed without a link (`geprueft`), and one has neither category nor link (`neu`)
- **WHEN** the user opens manual review for that import
- **THEN** only the two `neu` rows appear, including the rule-categorized-but-unconfirmed row, and the derived history count is `2`

#### Scenario: Untouched rule suggestion remains distinguishable from a user choice

- **GIVEN** Review displays a category suggested by a matching rule
- **WHEN** the user leaves the suggestion untouched, explicitly accepts it, or selects another category
- **THEN** the typed review row distinguishes `regel_vorschlag` from `benutzerentscheidung`, only explicit accept/change sets the user decision, and persistence/retry retains that provenance so an unaccepted suggestion remains `neu`

#### Scenario: Review state is scoped across completed and partial attempts

- **GIVEN** a completed attempt and a partial attempt each contain rows with `neu`, `geprueft`, and `gebucht` status
- **WHEN** the user selects Review from either history row
- **THEN** the queue contains only `neu` rows for that selected `import_id`, regardless of the parent attempt's ingestion status, and each history count is derived from its own `neu` rows

#### Scenario: Manual review is scoped to the selected import

- **GIVEN** two imports each contain unresolved `neu` transactions
- **WHEN** the user selects Review from one history row
- **THEN** only `neu` transactions whose `import_id` matches the selected row appear

#### Scenario: Reviewing a row removes it from the unresolved set

- **GIVEN** a transaction with status `neu` appears in manual review
- **WHEN** the user confirms or changes its category, or links it to an existing journal entry
- **THEN** only that bank transaction changes to `geprueft` or `gebucht`, it no longer appears in the unresolved query, and the derived history count decreases by one

#### Scenario: Completed attempt metadata stays immutable while child review remains available

- **GIVEN** a completed import attempt has unresolved transactions
- **WHEN** the user reviews and classifies one transaction
- **THEN** the transaction is updated and the unresolved count changes, but the completed import's filename, account, timestamp, ingestion status, and retry data remain unchanged

#### Scenario: Manual review does not create a posting

- **GIVEN** a `neu` transaction is open in manual review
- **WHEN** the user confirms or changes its category, or associates it with an existing journal entry
- **THEN** only that bank transaction's category, journal link, and review status change; no journal entry or payment is created

#### Scenario: Retry failure leaves the prior attempt usable

- **GIVEN** a validated retry payload and successful child rows exist
- **WHEN** a database write or history update fails during retry
- **THEN** the transaction rolls back so the prior successful children, attempt ID, remaining payload, status, and counts remain usable and consistent

#### Scenario: History search filters before stable pagination

- **GIVEN** history has more than 50 attempts with mixed filenames, templates, and statuses
- **WHEN** the user searches a filename, template, or status and advances a page
- **THEN** only matching typed attempts are paginated in timestamp-descending/ID-descending order with correct total and `hasMore`, while bank transaction raw values are not searchable

#### Scenario: Detail return restores the same history query

- **GIVEN** the user is on a filtered history page with an import selected
- **WHEN** the user opens detail or retry and returns
- **THEN** the route restores the same query, page, and selected import ID; an invalidated page is clamped to the last valid page

#### Scenario: History keyboard actions preserve focus

- **GIVEN** history search, pagination, detail, or a retry action has keyboard focus
- **WHEN** the user searches, changes page, opens/closes detail, or retries
- **THEN** all actions have localized semantic names, focus remains visible, and returning from a detail surface restores focus to the invoking history row/control
