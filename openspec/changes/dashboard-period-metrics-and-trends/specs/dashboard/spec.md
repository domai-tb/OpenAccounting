## MODIFIED Requirements

### Requirement: Schnellzugriff-Links (Quick-Links widget)

The Quick-Links widget SHALL display user-configurable shortcut links to common application actions. Links SHALL be
stored as a JSON array of `{label, route}` objects in `unternehmen.dashboard_config`. Default links SHALL resolve to
supported application routes. Users SHALL be able to add, edit, remove, and reorder links in the dashboard
customization surface. A route SHALL be accepted only if it is in the application router's allowed destination list;
unsupported routes SHALL be rejected before persistence with a localized validation message.

#### Scenario: Default quick links
- **GIVEN** the dashboard loads with no saved Quick-Links configuration
- **WHEN** the Quick-Links widget renders
- **THEN** it SHALL display the default supported links for a new invoice, reports, and inventory

#### Scenario: Custom quick link
- **GIVEN** the user has opened the dashboard customization surface
- **WHEN** the user adds a quick link labeled "Mein Shop" pointing to supported route `/reports`
- **THEN** the link SHALL appear in the widget
- **AND** clicking it SHALL navigate to `/reports`

#### Scenario: Add, edit, and reorder a quick link
- **GIVEN** the user has opened the dashboard customization surface
- **WHEN** the user adds a supported route, edits its label, and reorders it
- **THEN** the changed label/order SHALL appear immediately and persist after application restart

#### Scenario: Remove a quick link
- **GIVEN** a saved quick link is visible
- **WHEN** the user removes it from customization
- **THEN** it SHALL disappear from the widget and remain absent after application restart

#### Scenario: Quick link with invalid route
- **GIVEN** the user enters a route that is not in the application router's allowed destination list
- **WHEN** the user clicks save
- **THEN** the app SHALL display a localized validation message
- **AND** the unsupported link SHALL NOT be persisted
- **AND** navigation SHALL not occur

#### Scenario: Legacy persisted quick link is filtered on load
- **GIVEN** a saved dashboard config contains a quick link whose route is no longer in the allowed destination list
- **WHEN** the dashboard loads
- **THEN** that link SHALL be filtered through the same allowlist without navigating to it
- **AND** it SHALL appear as a removable invalid-link state

## ADDED Requirements

### Requirement: Period-scoped dashboard overview

The dashboard SHALL provide an annual calendar-year selector and display income, expenses, profit, margin, and open receivables/payables for the selected year or year end. Income and expenses SHALL come from the accepted annual `AccountingPeriodSummary` and use its approved accounting basis; month/quarter requests SHALL render that workspace's unavailable state. Profit SHALL equal the reporting result's recognized income less deductible expenses. Margin SHALL equal profit divided by income times 100 when income is positive; otherwise it SHALL be shown as unavailable. An estimated VAT reserve SHALL be shown only when the canonical tax-reporting source provides a period value, and SHALL be labeled as an estimate. Until `accounting-reporting-workspaces` is accepted, the summary widget SHALL show its unavailable state naming that prerequisite and SHALL NOT substitute invoice totals, invoice-date journal totals, or unconfirmed bank rows.

#### Scenario: Select a reporting period
- **GIVEN** the dashboard has loaded and the selected calendar year is supported by the annual summary
- **WHEN** the user selects that year
- **THEN** each flow KPI uses that year and each open-balance KPI uses its year-end date
- **AND** the selected year and its exact period boundaries are shown in the dashboard header

#### Scenario: Unsupported month, quarter, or year
- **GIVEN** the user requests a month, quarter, or calendar year without an accepted form mapping/source
- **WHEN** the dashboard requests the period metrics
- **THEN** it SHALL show the reporting workspace's localized unavailable state naming the missing period/form/source
- **AND** it SHALL NOT present a partial-year, annual, or all-time value under the requested period label

#### Scenario: Invalid or unavailable period
- **GIVEN** the fiscal calendar is unavailable or the selected date range is invalid
- **WHEN** the dashboard requests the period metrics
- **THEN** it SHALL show a localized validation or unavailable state for affected KPIs
- **AND** it SHALL NOT present all-time values as if they belonged to the selected period

#### Scenario: Historical open balance snapshot
- **GIVEN** an invoice was issued by the selected year end and paid after that date, and another invoice was issued after that date
- **WHEN** open receivables are calculated at the selected year end
- **THEN** the first invoice SHALL be included at its remaining balance at that date, derived from the `receivables-ledger-integrity` statement plus approved settlement allocations/keyed `zahlung` effective dates (authoritative date: bank booking/value or manual cash date, verbatim)
- **AND** the later-issued invoice SHALL be excluded

#### Scenario: Historical payable snapshot uses supplier allocations
- **GIVEN** a supplier payable was issued by the selected year end with a settlement allocation dated after that date
- **WHEN** open payables are calculated at the selected year end
- **THEN** the payable SHALL be included at its remaining balance at that date from its `rechnung_eingang` item plus approved supplier settlement allocations
- **AND** a payable issued after that date SHALL be excluded

#### Scenario: Settlement split and reversal follow allocation dates
- **GIVEN** one bank transaction holds two approved allocation rows with different settlement dates straddling the selected year end, and a later reversal reclassifies one allocation in the reversal period
- **WHEN** the as-of balance is calculated
- **THEN** only the allocation effective on/before the year end SHALL reduce the balance
- **AND** the reversal SHALL affect only the reversal period, leaving the prior year-end snapshot unchanged

#### Scenario: Write-off or legacy history without an effective date is unavailable
- **GIVEN** an open item has a write-off/correction event without an accepted effective date, or its period mixes `legacy_unverified` rows
- **WHEN** its as-of balance is requested
- **THEN** the affected KPI SHALL show a localized incomplete-history unavailable state identifying the missing effective date/unverified rows
- **AND** it SHALL NOT silently exclude the event or infer the balance from current status

### Requirement: Comparable KPI trends

For a selected period with a corresponding prior-year period, the dashboard SHALL show the absolute and percentage change for income, expenses, and profit. Percentage change SHALL be `(current - prior) / abs(prior) * 100`. When the comparison baseline is zero or unavailable, the dashboard SHALL show the absolute values and a localized "not comparable" state instead of dividing by zero or showing a fabricated percentage.

#### Scenario: Show a comparable year-over-year trend
- **GIVEN** current and prior-year accounting data exist for the selected period
- **WHEN** the dashboard renders the headline KPIs
- **THEN** it SHALL display current and prior values and their calculated absolute and percentage changes

#### Scenario: Handle a zero comparison baseline
- **GIVEN** the prior-year value for a KPI is zero or unavailable
- **WHEN** the dashboard renders its trend
- **THEN** it SHALL display the current and prior values with a localized not-comparable label
- **AND** it SHALL NOT render an infinite, NaN, or misleading percentage

#### Scenario: Compare a negative prior profit
- **GIVEN** the prior-year profit is negative and the selected-period profit is positive
- **WHEN** the dashboard calculates the comparison
- **THEN** it SHALL use the absolute prior amount as the percentage denominator
- **AND** it SHALL show the signed absolute change and the correctly finite percentage

### Requirement: Period trend visualizations

For the selected supported calendar year, the dashboard SHALL provide the annual summary's monthly income and expense trends, profit development, expense distribution, and the VAT distribution returned by the canonical reporting services. Visualizations SHALL include a numeric value, active year, and accessible text summary; charts SHALL supplement rather than replace exact amounts.

#### Scenario: Render supported trend data
- **GIVEN** the reporting workspace returns monthly totals and expense/VAT distribution for the selected period
- **WHEN** trend widgets render
- **THEN** each series SHALL display the returned period values and categories
- **AND** the user SHALL be able to read the same values through accessible semantics

#### Scenario: Trend data is missing or invalid
- **GIVEN** the reporting workspace returns an error, no period data, or non-finite values
- **WHEN** trend widgets render
- **THEN** the affected chart SHALL show a localized error or empty state with no fabricated values
- **AND** unaffected headline metrics SHALL remain visible

### Requirement: Accounting-backed operational metrics

Open and overdue invoice metrics SHALL exclude cancelled documents and drafts. Payment metrics SHALL use confirmed accounting payment records, not merely positive imported bank transactions. Unmatched imported transactions SHALL remain visible as reconciliation work and SHALL NOT count as receipts. Metric queries SHALL use the selected period and approved accounting source.

#### Scenario: Render open invoices and receipts
- **GIVEN** the company has open, cancelled, draft, and paid invoices plus confirmed and unmatched bank transactions
- **WHEN** the dashboard loads the selected period
- **THEN** open and overdue totals SHALL exclude cancelled, draft, and paid invoices
- **AND** receipt totals SHALL include only confirmed accounting payments
- **AND** unmatched transactions SHALL appear in the reconciliation attention count

#### Scenario: Accounting source is incomplete
- **GIVEN** a transaction or invoice cannot be classified by the approved accounting source
- **WHEN** its KPI is calculated
- **THEN** the affected amount SHALL be excluded from the total
- **AND** the dashboard SHALL expose an actionable unavailable/reconciliation state with a link to the source record

### Requirement: Actionable dashboard attention items

The dashboard SHALL include actionable attention items for overdue invoices, unreconciled transactions, and tax deadlines returned by the configured tax calendar. Each overdue-invoice item SHALL link to the relevant filtered invoice workspace; each unreconciled-transaction item SHALL link to the existing canonical `/banking` route with its typed selection state (`transactionId=<id>` for a single transaction, coexisting with supported banking query parameters), preserving unrelated query state. Missing or failed source data SHALL render an error state without substituting a hardcoded date or stale count.

#### Scenario: Open an attention item
- **GIVEN** an overdue invoice and an unreconciled transaction exist
- **WHEN** the user activates either attention item
- **THEN** the app SHALL navigate to the corresponding filtered invoice workspace or to `/banking?transactionId=<id>` with that transaction selected and unrelated banking query preserved

#### Scenario: Unmatched filter is applied on the banking route
- **GIVEN** an unmatched-transaction attention item for transaction 42
- **WHEN** the user activates it
- **THEN** the banking workspace SHALL open with transaction 42 selected via its typed `transactionId` state alongside its existing typed search/filter (status/text/date/amount) state
- **AND** a missing, malformed, or unavailable ID SHALL show the route's localized typed not-found state without changing other query state

#### Scenario: Tax calendar is unavailable
- **GIVEN** no filing calendar is configured or its query fails
- **WHEN** tax deadline items load
- **THEN** the dashboard SHALL show a localized configuration/error state
- **AND** it SHALL NOT display a hardcoded filing date

#### Scenario: Open a configured tax deadline
- **GIVEN** a configured tax deadline is due within the attention window
- **WHEN** the user activates that item
- **THEN** the app SHALL navigate to the matching period in the tax-reporting workspace

### Requirement: Localized dashboard interactions

Dashboard metric labels, units, periods, trends, loading/empty/error states, and accessibility semantics SHALL use the active locale. KPI and chart interactions SHALL expose their values and period through accessible semantics and SHALL navigate to the relevant records when activated.

#### Scenario: Render metrics in the selected locale
- **GIVEN** the user selects English and the dashboard contains metric values
- **WHEN** the dashboard loads or the locale changes
- **THEN** all visible dashboard copy, dates, numbers, and accessibility labels SHALL use English formatting without restarting

#### Scenario: No data for a selected period
- **GIVEN** the selected period has no accounting records
- **WHEN** KPI and chart widgets render
- **THEN** they SHALL show localized zero/empty states and accessible labels
- **AND** no German-only static label SHALL remain in the rendered dashboard
