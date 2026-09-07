## ADDED Requirements

### Requirement: Dashboard metrics use explicit financial scopes

Each dashboard KPI MUST define and apply its document status/type, active profile/company, reporting period, and booking direction; draft, canceled, supplier, or out-of-period records MUST not enter a differently labeled metric.

Implementation evidence: Open/overdue queries filter only status, income/expense lacks period, and ordinary positive/negative journal assumptions do not match booking art.

#### Scenario: Draft and out-of-period rows are excluded

- Given the database contains draft, canceled, paid, and out-of-period documents
- When the dashboard is loaded for a selected period
- Then only records matching the KPI definition contribute and the displayed count/amount is reproducible from the query

#### Scenario: Income and expense direction is correct

- Given Einnahme and Ausgabe journal rows use positive persisted amounts
- When income/expense totals are calculated
- Then both directions are classified by art and expenses are not omitted or turned into income

#### Scenario: Filing deadline follows configuration

- Given the company has a configured tax filing cadence/date
- When the deadline card is loaded
- Then the card derives its date from configuration and shows an explicit unavailable state if configuration is missing

### Requirement: Dashboard actions open the corresponding workflow

Every KPI card and quick link MUST navigate to the matching filtered list/detail/create workflow, including inventory, dunning, journal, and new-invoice actions; no action may expose a raw route string as its user-facing result.

Implementation evidence: Inventory and dunning cards route to contacts/invoices, Artikel routes to contacts, and Neue Rechnung routes to the invoice list.

#### Scenario: Quick links reach their intended action

- Given the user activates Neue Rechnung, Journal, Artikel, or a warning card
- When navigation occurs
- Then the corresponding creation/list/detail workflow opens with the relevant filter or record context

#### Scenario: Missing target remains safe

- Given a KPI record was deleted before a click
- When the user follows its drilldown
- Then the app shows a localized not-found state and retains the source dashboard without navigating to an unrelated page

### Requirement: Dashboard configuration reports persistence outcomes

Widget visibility and order changes MUST update only after persistence succeeds, or roll back with a localized error and retry action when persistence fails.

Implementation evidence: Reorder and visibility changes fire-and-forget without error handling or rollback.

#### Scenario: Successful customization persists

- Given the dashboard configuration store accepts a change
- When the user toggles or reorders a card
- Then the visible order/state updates and survives reload

#### Scenario: Failed customization rolls back

- Given configuration persistence fails
- When the user changes a card
- Then the previous visible state is restored and an actionable error is announced
