## ADDED Requirements

### Requirement: Typed report workspaces expose only supported calculations

The application SHALL expose typed workspaces at `/reports` and `/taxes` for EÜR, EKS, management GuV, UStVA, ZM, DATEV, and report status/history. A workspace SHALL call the corresponding application service and SHALL use its named maintained accounting/tax contract. It SHALL NOT fall back to a generic database table or derive report totals in the page.

A report is available only when its calculation contract, source data, period, required profile configuration, and versioned mapping are supported. For financial summaries, EÜR, GuV, UStVA, and DATEV, both `balanced-journal-postings-and-settlement-events` and `invoice-money-invariants` MUST be independently approved before their canonical posting/settlement values can be exposed. Until then, these outputs SHALL be unavailable with the blocking dependency named. Invoice totals, invoice-date journal summaries, and positive unconfirmed bank rows SHALL NOT be substituted. EKS remains unavailable until its accepted form version and `Bewilligungszeitraum` period contract are defined. ZM is limited to the supported transaction scope in the modified `accounting` capability.

Supported periods SHALL use the following exact boundaries; all ranges are start-inclusive and end-exclusive:

| Result | Supported period | Availability rule |
| --- | --- | --- |
| EÜR and annual summary | One calendar year; only tax year 2025 has a form contract in this change | Requires the 2025 form mapping and approved accounting source; all other years unavailable until their own accepted form version/mapping exists |
| Management GuV | One calendar year | Requires approved balanced postings and explicit calendar-year source data; no other fiscal calendar inferred |
| UStVA | One calendar month or one three-month calendar quarter | Requires the company's explicitly configured monthly/quarterly rhythm, an accepted year-specific Kennzahl map, complete source coverage, and the approved accounting source |
| ZM preview | One calendar month | Supports only qualifying outgoing intra-community goods supplies; quarterly election and other transaction types are unavailable |
| DATEV Buchungsstapel | One calendar month per file | Uses accepted posting dates; business-year start must be 1 January |
| EKS | None in this change | Unavailable until the form version, field mapping, and benefit-period boundaries are accepted |

Every result SHALL identify its report type, exact period endpoints, calculation/form/interface version, source contract version, unresolved-record count, and source record IDs where available. A missing or unsupported value SHALL be reported as unresolved, not replaced by zero. The only report file added by this change is the version-pinned DATEV CSV; EÜR, EKS, GuV, UStVA, and ZM are on-screen previews only. No workspace action SHALL claim that a preview or local file was filed with an authority.

#### Scenario: Generate a supported report preview

- **GIVEN** the selected report has an accepted calculation contract, supported period, complete required fields, and approved source contracts
- **WHEN** the user requests a preview
- **THEN** the matching typed service receives the exact period and required customer scope
- **AND** the result displays its calculation/source version, period, and provenance

#### Scenario: Financial prerequisite is still unapproved

- **GIVEN** either `balanced-journal-postings-and-settlement-events` or `invoice-money-invariants` lacks independent approval
- **WHEN** the user requests EÜR, GuV, UStVA, DATEV, or an annual summary
- **THEN** the workspace shows an unavailable state naming the unapproved prerequisite
- **AND** it displays no complete or estimated total from invoice amounts, invoice-date journal summaries, or unconfirmed bank rows

#### Scenario: Unsupported EÜR year does not reuse 2025

- **GIVEN** the user selects tax year 2026 or another year without an accepted form version and fixture
- **WHEN** the user opens or previews EÜR
- **THEN** EÜR is unavailable for that year with the missing year-specific form version identified
- **AND** the 2025 line layout is not used as a fallback

#### Scenario: EKS period contract is unavailable

- **GIVEN** the user selects EKS before an accepted benefit-period and form-version contract exists
- **WHEN** the user opens the EKS workspace
- **THEN** the workspace explains that EKS is unavailable until those contracts are accepted
- **AND** it does not present a calendar-year result as a completed Anlage EKS

#### Scenario: Unsupported ZM transaction prevents a false empty report

- **GIVEN** a selected month contains no supported qualifying outgoing supply but contains a potentially reportable service, triangular delivery, §6b movement, or other unsupported transaction
- **WHEN** the user previews ZM
- **THEN** the preview is unavailable and links the affected source record
- **AND** it does not report that the period has no reportable transactions

### Requirement: Annual accounting period summary uses one canonical result

The reporting service SHALL expose an immutable `AccountingPeriodSummary` only for a supported calendar year for which the matching EÜR form and accepted accounting sources are available. Its start is January 1 and its end-exclusive boundary is January 1 of the following year. It SHALL include recognized income, expenses, profit, margin, monthly trend values for that same year, expense/tax distributions, source versions, and unresolved-record count. Income and expenses SHALL come from the approved balanced-posting/settlement contract; profit SHALL match the EÜR result for that same year and form version; margin SHALL equal profit divided by income times 100 when income is positive and otherwise be unavailable. Month and quarter summaries are not supported. The summary SHALL not be exposed as complete when any required source, mapping, or period result is unavailable.

#### Scenario: Return a complete supported annual summary

- **GIVEN** accepted posting, settlement, money, and matching annual EÜR contracts exist for a calendar year
- **WHEN** the reporting service builds that year's summary
- **THEN** it returns the exact January 1 through next-January-1 period, canonical totals, monthly series, distributions, source versions, and unresolved count
- **AND** the income, expense, and profit totals equal the matching report results

#### Scenario: Unsupported annual period has no summary

- **GIVEN** the selected year has no supported EÜR form version or accepted financial source
- **WHEN** the summary is requested
- **THEN** the service returns an unavailable result with the missing version/source identified
- **AND** it does not produce a month/quarter estimate or complete annual total

#### Scenario: Empty or zero-income supported year

- **GIVEN** the selected supported year has complete source data but no recognized income or expenses
- **WHEN** the summary is generated
- **THEN** income, expenses, and profit are zero
- **AND** margin is unavailable rather than infinity or a fabricated percentage

### Requirement: Report status reflects evidence and unresolved input

The workspace SHALL distinguish `Unverfügbar`, `Geschätzt`, `Berechnet`, `Geprüft`, and `Übermittelt` according to evidence. A missing source contract or required field SHALL be `Unverfügbar`; `Geschätzt` may be used only when a supported calculation explicitly marks itself provisional and exposes unresolved inputs; `Berechnet` requires complete required data and a supported calculation version; `Geprüft` requires the named review evidence; and `Übermittelt` requires an external submission receipt or explicit supported confirmation. Local previews and local files SHALL NOT be labeled `Übermittelt`.

#### Scenario: Local result is not submitted

- **GIVEN** a complete result or DATEV file is saved locally without an external receipt
- **WHEN** the user returns to the workspace
- **THEN** its status is `Berechnet` or `Geprüft` only when evidence supports that state
- **AND** it is not shown as `Übermittelt`

#### Scenario: Required inputs are unresolved

- **GIVEN** a supported calculation has one or more unresolved records or fields
- **WHEN** the user previews it
- **THEN** the workspace shows `Geschätzt` only if the calculation contract explicitly permits a provisional result
- **AND** otherwise it shows `Unverfügbar` with the unresolved count and source links

### Requirement: Reporting workspaces remain accessible at desktop sizes

Report tables and period controls SHALL follow the shared design system, support keyboard navigation and visible focus, and adapt without clipping at narrow desktop window widths. Loading, empty, unavailable, and error states SHALL be localized and distinguishable without relying on color alone.

#### Scenario: Narrow workspace and keyboard navigation

- **GIVEN** the report workspace is displayed at a narrow desktop window width
- **WHEN** the user navigates period controls and a dense result table by keyboard
- **THEN** controls remain reachable in a logical focus order with visible focus
- **AND** report labels and values remain readable without horizontal clipping
- **AND** loading, empty, unavailable, and error states use localized text and accessible semantics
