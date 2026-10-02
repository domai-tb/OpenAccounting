## ADDED Requirements

### Requirement: Production report workspaces expose maintained reports

The application SHALL expose typed report workspaces at `/reports` and `/taxes`, replacing generic journal/export record tables. `/reports` SHALL provide EÜR, EKS, GuV, and DATEV workflows; `/taxes` SHALL provide UStVA, ZM, tax-period overview, and export status. Each workflow SHALL use an application service and the maintained accounting/tax specification for its calculation. EKS SHALL require an explicit customer-scoped or all-customer mode. Missing service/data SHALL render a localized unavailable/error state, never a generic raw-table fallback.

#### Scenario: Generate a supported report
- **GIVEN** the selected profile has sufficient data and a supported period
- **WHEN** the user selects EÜR, EKS, GuV, UStVA, ZM, or DATEV and requests a preview
- **THEN** the matching typed service SHALL receive the selected period and customer scope where required
- **AND** the workspace SHALL show its typed result and calculation warnings

#### Scenario: Missing report service or data
- **GIVEN** a requested report service or required data source is unavailable
- **WHEN** the user opens or generates that report
- **THEN** the workspace SHALL show a localized unavailable/error state with retry or configuration guidance
- **AND** it SHALL NOT render a raw database record table as a substitute

### Requirement: Shared accounting period summary

The reporting application service SHALL expose an immutable `AccountingPeriodSummary` for month, quarter, and year periods supported by the company fiscal calendar. It SHALL include the selected period, recognized income, expenses, profit, margin, monthly series, expense/VAT distributions, tax estimate source/status, and unresolved-record count. Income and expenses SHALL use the canonical balanced posting and settlement basis; profit SHALL match the EÜR result for the selected scope; margin SHALL equal profit divided by income times 100 when income is positive and SHALL be unavailable otherwise. Dashboard consumers SHALL read this summary rather than calculate parallel totals.

#### Scenario: Return a complete selected-period summary
- **GIVEN** balanced posted entries, settlements, EÜR, and tax-period results exist for a selected period
- **WHEN** the reporting service builds its period summary
- **THEN** it SHALL return the requested period and canonical income, expense, profit, margin, monthly series, distributions, tax source/status, and unresolved count
- **AND** the summary totals SHALL equal the corresponding generated reports

#### Scenario: Empty or zero-income period
- **GIVEN** the selected period has no recognized income or expense
- **WHEN** the summary is generated
- **THEN** income, expenses, and profit SHALL be zero
- **AND** margin SHALL be unavailable rather than infinity or a fabricated percentage

#### Scenario: Canonical accounting inputs are not ready
- **GIVEN** the balanced posting or settlement source is not available for the selected period
- **WHEN** the summary is requested
- **THEN** it SHALL identify the period as incomplete and expose the unresolved-record count
- **AND** it SHALL NOT fall back to invoice totals or positive unconfirmed bank rows

### Requirement: Report and tax status is truthful

Tax workspaces SHALL show the period and one of `Geschätzt`, `Berechnet`, `Geprüft`, or `Übermittelt` only when evidence supports that state. A local calculation or saved export SHALL NOT be labeled `Übermittelt`; that state requires an external submission receipt or explicit supported submission confirmation. Each unresolved input SHALL be linked to its source record where available.

#### Scenario: Display a local calculation as calculated
- **GIVEN** a tax report is calculated and saved locally with no external submission receipt
- **WHEN** the user returns to the tax workspace
- **THEN** the period SHALL show `Berechnet` or its localized equivalent
- **AND** it SHALL NOT show `Übermittelt`

#### Scenario: Report calculation is provisional
- **GIVEN** one or more required records remain unmatched or incomplete
- **WHEN** the tax report preview is displayed
- **THEN** it SHALL show `Geschätzt` and the unresolved record count
- **AND** each available issue link SHALL open the relevant record

### Requirement: DATEV EXTF export follows its structured CSV contract

DATEV export SHALL produce the currently supported official DATEV EXTF Buchungsstapel CSV format, including a valid format-versioned header, required field order, encoding, and debit/credit/account/tax/partner/document data supported by the source entries. It SHALL validate each record before reporting success and SHALL not describe the file as fixed-width text. Version-specific output SHALL be covered by an inspectable fixture aligned with the official DATEV specification.

#### Scenario: Export a valid DATEV period
- **GIVEN** company DATEV identifiers and balanced account-backed entries exist for a selected period
- **WHEN** the user exports DATEV
- **THEN** the file SHALL contain a valid EXTF header and rows with the supported account, tax, partner, and document fields
- **AND** a DATEV-format fixture validator SHALL accept the file structure

#### Scenario: Reject incomplete DATEV mapping
- **GIVEN** a posting in the selected period lacks a required account or required export field
- **WHEN** the user exports DATEV
- **THEN** the export SHALL fail with the affected source record and field identified
- **AND** no successful export-history entry SHALL be recorded

### Requirement: Report artifacts use the export lifecycle

Report and tax exports SHALL use the existing safe artifact-destination, validation, integrity, and export-history contract. A successful export SHALL record period, report type, destination, status, and integrity metadata only after the file is written and validated. Failed writes SHALL remain failed and SHALL not display a success state.

#### Scenario: Complete a user-selected report export
- **GIVEN** a valid report preview and an available user-selected destination
- **WHEN** the user exports the report
- **THEN** the file SHALL be written and reopened/validated at that destination
- **AND** the successful export SHALL appear in history with its period and report type

#### Scenario: Export destination fails
- **GIVEN** the user-selected destination is unavailable or the written file fails validation
- **WHEN** report export is attempted
- **THEN** the workspace SHALL show a localized failure and recovery action
- **AND** no successful export-history row SHALL be recorded
