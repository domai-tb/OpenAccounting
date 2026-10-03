## ADDED Requirements

### Requirement: Cashbook view uses typed committed cash events

The existing `/banking` workspace SHALL expose Cashbook and Daily Close views using isolated route state (`view=cashbook` and `view=close`) while preserving the existing bank-import views and query state. Cashbook history SHALL show only events identified by the approved accounting posting service as committed and linked to an explicit cash account. Its typed rows SHALL provide the event date, direction, amount/basis, category, tax treatment, description, posting identity, and selected supporting-document reference where present. Cash income and expense forms SHALL collect the source inputs required by that same approved service; the view SHALL NOT compute tax, choose fallback category/account mappings, or write directly to `journal`. An imported bank row, free-text match, or legacy journal row SHALL NOT become a cash movement unless the approved posting service identifies it as such. If the approved writer/projection or required mappings are absent, the view SHALL show a localized unavailable state and SHALL NOT commit a cash event. Committed cash history SHALL not be edited or deleted in this workspace; any correction SHALL use the approved linked accounting correction operation.

#### Scenario: Approved cash event appears in the cashbook

- **GIVEN** the approved posting service is available and returns a committed balanced cash income event with its account, category, tax treatment, description, and selected receipt reference
- **WHEN** the user records the event and opens Cashbook history
- **THEN** one typed cashbook row SHALL display those returned fields and posting identity
- **AND** no page-level SQL or second cash transaction record SHALL be created.

#### Scenario: Missing posting contract blocks cash entry

- **GIVEN** the direct cash-event posting contract is absent, unapproved, or cannot resolve a required account/category/tax mapping
- **WHEN** the user attempts to record cash income or expense
- **THEN** the workspace SHALL show a localized unavailable or validation state
- **AND** no journal row, receipt link, cash balance change, or partial posting SHALL be persisted.

#### Scenario: Imported or legacy row is not treated as cash

- **GIVEN** a bank import is unmatched or a legacy journal row lacks a verified balanced cash-account identity
- **WHEN** Cashbook history loads
- **THEN** that row SHALL NOT be represented as a confirmed cash movement
- **AND** any affected history completeness SHALL be shown as unavailable or unverified rather than silently counted.

#### Scenario: Committed cash event cannot be silently rewritten

- **GIVEN** a committed cash event is displayed in Cashbook history
- **WHEN** the user attempts to edit or delete it from this workspace
- **THEN** the action SHALL be rejected
- **AND** the original posting group SHALL remain unchanged.

### Requirement: Cash balance uses an authoritative complete report

The running cash balance and a daily close's expected cash amount SHALL come only from the separately approved typed `account-cash-balance-source` contract for an explicit cash account and date. An aggregate period-summary report SHALL NOT satisfy this prerequisite unless its accepted contract explicitly adds the account-scoped as-of balance and completeness result. The result SHALL identify account, date scope, currency, source reference, and whether its history is complete and verified. The workspace SHALL display the amount returned by that source without locally summing journal rows, reading `konten.saldo` as an as-of balance, or deriving a balance from descriptions or imported rows. If the source contract/service is unavailable, the account is ambiguous, or source coverage is incomplete or unverified, the balance SHALL be marked unavailable—not zero—and a daily close SHALL NOT be finalized or exported.

#### Scenario: Complete balance is shown from the report result

- **GIVEN** the approved report returns a complete, verified balance for the selected cash account and date
- **WHEN** Cashbook loads the balance
- **THEN** the workspace SHALL show the exact returned amount, currency, account, date scope, and source status
- **AND** it SHALL NOT recalculate the amount from journal rows or `konten.saldo`.

#### Scenario: Incomplete historical source fails closed

- **GIVEN** the report finds an opening balance or cash history whose completeness cannot be verified
- **WHEN** Cashbook or Daily Close requests the balance
- **THEN** the expected/running balance SHALL be unavailable with a localized reason
- **AND** the workspace SHALL NOT substitute a journal sum, account `saldo`, or zero.

### Requirement: Daily close records use the approved close result

The Daily Close view SHALL let the user select an explicit cash account and closing date and enter an actual count. It SHALL obtain expected amount, discrepancy state/value, and source snapshot from the approved balance/close use case; the UI SHALL NOT calculate them. A close SHALL be finalized only when that result is complete and verified, the existing `tagesabschluesse` persistence mapping is approved, and the full record can be signed. The finalization identity SHALL be `(unternehmen_id, konto_id, datum)`. The duplicate lookup and signed insert SHALL run in one SQLite `BEGIN IMMEDIATE` transaction. If exactly one signed close is the only matching row for that identity, the service SHALL return it read-only. Any matching unsigned legacy row, multiple rows, or ambiguous legacy close identity SHALL make finalization unavailable for that identity. If the close result reports a discrepancy, finalization SHALL require a non-empty explanation stored in `zaehlung_json`. Finalized records SHALL be shown as immutable history. Recording a close SHALL NOT post an accounting adjustment or cash movement; any adjustment is a distinct action under the approved posting contract.

#### Scenario: Complete daily close is finalized

- **GIVEN** the approved close use case returns a complete expected balance and discrepancy result for the selected account/date, and the user supplies the actual count and any required explanation
- **WHEN** the user finalizes the close
- **THEN** one signed `tagesabschluesse` record SHALL preserve the approved source result, actual count, discrepancy result, explanation, date, and account
- **AND** the close SHALL create no journal posting or cash movement.

#### Scenario: Expected balance or persistence mapping is unavailable

- **GIVEN** the close service is missing, the report is incomplete, the cash account is ambiguous, or required persisted fields/signature input are not approved
- **WHEN** the user attempts to finalize a close
- **THEN** finalization SHALL return a localized unavailable state
- **AND** no close row, signature, or PDF SHALL be created.

#### Scenario: Discrepancy requires an explanation

- **GIVEN** the approved close result reports a discrepancy and the user has not entered an explanation
- **WHEN** finalization is attempted
- **THEN** the workspace SHALL require an explanation and SHALL keep the close unfinalized
- **AND** no difference adjustment SHALL be posted.

#### Scenario: Existing close remains read-only

- **GIVEN** a signed close already exists for the selected cash account/date
- **WHEN** the user selects that date again
- **THEN** the existing close SHALL open read-only
- **AND** no second close row or mutation of the signed row SHALL occur.

#### Scenario: Concurrent close finalization cannot duplicate a signed record

- **GIVEN** two finalization requests target the same company, cash account, and date
- **WHEN** both requests run concurrently
- **THEN** the transaction-guarded service SHALL persist at most one signed close
- **AND** the other request SHALL return the existing close read-only

#### Scenario: Ambiguous legacy closes block finalization

- **GIVEN** multiple or company/account-ambiguous legacy close rows match the requested account/date
- **WHEN** a user opens or finalizes that close
- **THEN** the workspace SHALL show a localized unverified-history state
- **AND** SHALL NOT create or sign another close row

#### Scenario: Single unsigned legacy close blocks finalization

- **GIVEN** one unsigned legacy close row matches the requested company/account/date
- **WHEN** the user opens or finalizes that close
- **THEN** the row SHALL remain unchanged
- **AND** the workspace SHALL show an unverified-history state and SHALL NOT create another row

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
