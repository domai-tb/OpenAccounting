## ADDED Requirements

### Requirement: Cashbook view uses typed committed cash events

The existing `/banking` workspace SHALL expose Cashbook and Daily Close views using isolated route state (`view=cashbook` and `view=close`) while preserving existing bank-import views and query state. Cashbook history SHALL show only events identified by the accepted `balanced-journal-postings-and-settlement-events` service as committed balanced `cash_payment` groups linked to an explicit cash account. Its typed rows SHALL provide event date, direction, amount and basis, category, tax treatment, description, posting identity, and selected receipt reference where present. Cash income and expense forms SHALL collect the inputs required by that posting service; the view SHALL NOT calculate tax, choose fallback category/account mappings, or write directly to `journal`. An imported bank row, free-text match, or legacy journal row SHALL NOT become a cash movement unless the accepted posting service identifies it as such. Cashbook writes and Daily Close SHALL remain unavailable until the separate `account-opening-balance-source` contract has fresh independent approval and is implemented at v24, in addition to the accepted posting and receipt boundaries. If any prerequisite or required mapping is absent, the view SHALL show a localized unavailable state and SHALL NOT commit a cash event. Committed cash history SHALL not be edited or deleted in this workspace; corrections SHALL use the accepted linked accounting correction operation.

#### Scenario: Approved cash event appears in the cashbook

- **GIVEN** `account-opening-balance-source` is independently approved and implemented at v24, and the accepted posting service commits a balanced cash income event for an explicit account and returns its category, tax treatment, description, posting identity, and selected receipt reference
- **WHEN** the user records the event and opens Cashbook history
- **THEN** one typed row SHALL display the returned fields and posting identity
- **AND** no page-level SQL or second cash transaction record SHALL be created.

#### Scenario: Missing posting contract blocks cash entry

- **GIVEN** the v24 opening-source prerequisite is pending, or the balanced cash-event writer or a required account, category, tax, or receipt mapping is unavailable
- **WHEN** the user attempts to record cash income or expense
- **THEN** the workspace SHALL show a localized unavailable or validation state
- **AND** no journal group, receipt link, or partial posting SHALL be committed.

#### Scenario: Imported or legacy row is not treated as cash

- **GIVEN** a bank import is unmatched or a legacy journal row lacks a verified balanced cash-account identity
- **WHEN** Cashbook history loads
- **THEN** that row SHALL NOT be represented as a confirmed cash movement
- **AND** any affected history completeness SHALL be unavailable or unverified rather than silently counted.

#### Scenario: Committed cash event cannot be silently rewritten

- **GIVEN** a committed cash event is displayed in Cashbook history
- **WHEN** the user attempts to edit or delete it from this workspace
- **THEN** the action SHALL be rejected
- **AND** the original posting group SHALL remain unchanged.

### Requirement: Cash balance uses a complete account/date result

The Cashbook and Daily Close SHALL consume one typed account/date result with `company_id`, `account_id`, `as_of_date`, nullable integer `balance_cents`, uppercase ISO 4217 `currency_code`, stable `source_reference`, `complete`, and an unavailable reason when incomplete. `as_of_date` SHALL be the end of that local calendar date. A complete result SHALL have an unambiguous company/account/date, use one supported two-decimal currency without conversion, and identify its source. An incomplete result SHALL have no usable balance amount. The report source SHALL include only the verified opening event supplied by the separately approved and implemented `account-opening-balance-source` v24 contract and committed balanced `cash_payment` groups through the requested date for that account. Until that contract is independently approved and implemented, the result SHALL be incomplete and unavailable.

The setup opening event SHALL contribute exactly once. If `konten.saldo` contains the same setup opening amount, it SHALL be checked only as corroborating metadata and SHALL NOT be added to the opening event or treated as another movement. Missing, duplicate, conflicting, or ambiguous opening identity; an unsupported currency; incomplete legacy coverage; an unbalanced or unlinked legacy row that could affect the account; or any other unresolved account/date source SHALL make the result incomplete. The workspace SHALL display the result returned by the source and SHALL NOT locally sum rows, use `konten.saldo` as an as-of balance, infer zero, or use descriptions/imports as a source. An incomplete balance SHALL be unavailable—not zero—and SHALL block close finalization and PDF generation.

#### Scenario: Complete balance is shown from the report result

- **GIVEN** the account/date source returns a complete balance with integer cents, currency, source reference, account, and date
- **WHEN** Cashbook loads the balance
- **THEN** the workspace SHALL show those exact returned values and complete status
- **AND** it SHALL NOT recalculate the amount from journal rows or `konten.saldo`.

#### Scenario: Verified opening cash is counted once

- **GIVEN** `account-opening-balance-source` is independently approved and implemented at v24, and its verified opening event and `konten.saldo` contain the same account, date, currency, and amount
- **WHEN** the account/date result is produced
- **THEN** the opening amount SHALL contribute once from the setup event
- **AND** `konten.saldo` SHALL be corroborating metadata and SHALL NOT be added a second time.

#### Scenario: Incomplete or ambiguous cash history is unavailable

- **GIVEN** the v24 opening-source prerequisite is unapproved or unavailable, the opening identity conflicts or duplicates, or legacy cash history through the requested date is incomplete, unbalanced, or ambiguous
- **WHEN** Cashbook or Daily Close requests the account/date result
- **THEN** the result SHALL be incomplete with no usable amount and an actionable reason
- **AND** the workspace SHALL NOT substitute a journal sum, account `saldo`, or zero.

### Requirement: Daily close records use the approved close result

The Daily Close view SHALL require an explicit company, cash account, and closing date and accept the user's actual count as integer cents in the account's currency. It SHALL obtain expected balance, source reference, currency, and completeness from the account/date result; the UI SHALL NOT calculate them. In the existing `tagesabschluesse` row, `betrag` SHALL mean expected, `kassenbestand` SHALL mean counted, `differenz` SHALL mean counted minus expected, and `konto_id` SHALL be the explicitly selected account. These numeric columns SHALL preserve exact two-decimal currency values corresponding to integer cents. The version-1 `zaehlung_json` and `integrity_hash` contract and verification rules are defined by the accounting delta.

A close SHALL be finalized only when the result is complete, the persisted mapping is valid, and the versioned snapshot and SHA-256 integrity digest can be written atomically. A discrepancy SHALL require a non-empty explanation. The finalization identity SHALL be `(unternehmen_id, konto_id, datum)`; lookup and insert SHALL run in one SQLite `BEGIN IMMEDIATE` transaction. A sole matching record whose snapshot and digest verify SHALL be returned read-only. Any matching legacy row, multiple rows, or ambiguous identity SHALL make finalization unavailable. Unknown or changed snapshot evidence SHALL be shown as unverified and SHALL NOT be presented as finalized. Finalized records SHALL be immutable. Recording a close SHALL NOT post an accounting adjustment or cash movement.

#### Scenario: Complete daily close is finalized

- **GIVEN** the source returns a complete expected balance and the user enters a count and any required explanation
- **WHEN** the user finalizes the close
- **THEN** one row SHALL persist expected in `betrag`, counted in `kassenbestand`, counted minus expected in `differenz`, and the explicit account in `konto_id`
- **AND** its versioned snapshot SHALL retain integer cents, currency, source reference, explanation, and date, with no journal posting or cash movement.

#### Scenario: Expected balance or persistence mapping is unavailable

- **GIVEN** the source is missing or incomplete, the account is ambiguous, or a required persistence field cannot be written
- **WHEN** the user attempts to finalize a close
- **THEN** finalization SHALL return a localized unavailable state
- **AND** no close row, integrity digest, or PDF SHALL be created.

#### Scenario: Discrepancy requires an explanation

- **GIVEN** the complete result and count produce a difference and the user has not entered an explanation
- **WHEN** finalization is attempted
- **THEN** the workspace SHALL require an explanation and keep the close unfinalized
- **AND** no difference adjustment SHALL be posted.

#### Scenario: Existing close remains read-only

- **GIVEN** one integrity-verified close exists for the selected company, cash account, and date
- **WHEN** the user selects that date again
- **THEN** the verified stored snapshot SHALL open read-only
- **AND** no second close row or mutation SHALL occur.

#### Scenario: Concurrent close finalization cannot duplicate a record

- **GIVEN** two finalization requests target the same company, cash account, and date
- **WHEN** both requests run concurrently
- **THEN** the `BEGIN IMMEDIATE` transaction SHALL persist at most one close for that identity
- **AND** the later request SHALL return the verified existing snapshot read-only.

#### Scenario: Ambiguous legacy closes block finalization

- **GIVEN** multiple or company/account-ambiguous legacy close rows match the requested account and date
- **WHEN** a user opens or finalizes that close
- **THEN** the workspace SHALL show a localized unverified-history state
- **AND** SHALL preserve the rows and SHALL NOT create or finalize another row.

#### Scenario: Single unsigned legacy close blocks finalization

- **GIVEN** one legacy close row without a version-1 snapshot and matching integrity digest matches the requested company/account/date
- **WHEN** the user opens or finalizes that close
- **THEN** the row SHALL remain unchanged and unverified
- **AND** the workspace SHALL NOT create another row or label it finalized.

### Requirement: Cashbook views follow desktop localization and accessibility rules

Cashbook and Daily Close controls, values, loading/empty/error/unavailable states, validations, and PDF actions SHALL use the active German or English generated localization catalog. Dates and amounts SHALL use active-locale formatting without changing stored values or report scope. Tabs, filters, tables, count fields, dialogs, and actions SHALL support complete keyboard navigation, visible focus, logical focus order, screen-reader names/roles/states, text scaling, and narrow-window reachability. Status SHALL not be conveyed by color alone.

#### Scenario: Localized keyboard use remains complete

- **GIVEN** Banking is shown in either supported locale with keyboard focus on a cashbook filter or close action
- **WHEN** the user navigates and activates it with the keyboard
- **THEN** the action SHALL run with visible focus and a localized semantic name/state
- **AND** rendered dates and amounts SHALL use the active locale.

#### Scenario: Narrow layout keeps close actions reachable

- **GIVEN** the Banking window narrows and German text is scaled
- **WHEN** Cashbook or Daily Close renders its table, form, or error state
- **THEN** no required text or action SHALL be clipped or rely on color/hover
- **AND** every control SHALL remain reachable through keyboard and semantics.
