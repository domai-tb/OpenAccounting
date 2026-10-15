## ADDED Requirements

### Requirement: Annual dashboard summary consumes the supported report result

The new annual financial summary SHALL consume the `AccountingPeriodSummary` returned by the reporting service; it SHALL NOT calculate a second income, expense, profit, margin, or tax total in dashboard SQL or widget code. It SHALL show only a supported calendar year and its exact period/source version. Until the matching EÜR form and balanced-posting/settlement and invoice-money contracts are independently approved, the summary widget SHALL show a localized unavailable state and SHALL NOT display invoice totals, invoice-date journal totals, or unconfirmed bank rows as complete period metrics. Existing non-financial dashboard widgets retain their own contracts.

#### Scenario: Summary widget uses the canonical annual result

- **GIVEN** the selected calendar year has an available `AccountingPeriodSummary`
- **WHEN** the dashboard loads the annual summary widget
- **THEN** it displays the values, year boundaries, source version, and unresolved count from that result
- **AND** it does not recalculate parallel totals

#### Scenario: Summary dependencies are not approved

- **GIVEN** either required accounting prerequisite or the matching annual EÜR form is not approved/supported
- **WHEN** the dashboard loads the annual summary widget
- **THEN** it shows the unavailable reason and period
- **AND** it displays no complete or estimated financial total from a fallback source

#### Scenario: Unsupported dashboard summary period

- **GIVEN** the user requests a month, quarter, or unsupported tax year
- **WHEN** the dashboard requests its financial summary
- **THEN** it reports the period as unavailable
- **AND** it does not display a partial-year or annual value under the wrong period label
