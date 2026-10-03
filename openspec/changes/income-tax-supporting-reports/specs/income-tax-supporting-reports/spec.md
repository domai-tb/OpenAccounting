## ADDED Requirements

### Requirement: Generate versioned S/G supporting workpapers from accounting records

The Taxes workspace SHALL provide separate read-only supporting reports for Anlage S and Anlage G. Each report result SHALL identify its selected schedule, supported period, official form edition, calculation/mapping version, source coverage, contributing record scope, and unresolved-record count. Each displayed field SHALL derive from an accepted accounting source and a versioned, reviewed line mapping. The workspace SHALL NOT infer schedule eligibility, copy EÜR/EKS totals without an accepted mapping, or claim legal completeness or tax-authority submission. A missing form edition, source, period, classification, mapping, or completeness contract SHALL make the affected report/field unavailable rather than show a guessed or zero-filled amount.

#### Scenario: Supported schedule fields have traceable values

- **GIVEN** the user selects a schedule and period with accepted form mapping and complete accounting inputs
- **WHEN** the supporting report loads
- **THEN** every available field SHALL show its amount, form edition, mapping version, source coverage, and contributing-record path
- **AND** the report SHALL leave source records unchanged.

#### Scenario: Unsupported tax-year form edition

- **GIVEN** no reviewed S/G field mapping exists for the selected tax year
- **WHEN** the user opens that schedule period
- **THEN** the report SHALL show a localized unsupported-period state
- **AND** SHALL NOT reuse a prior-year field mapping or return an unlabeled total.

#### Scenario: Accounting source or classification is incomplete

- **GIVEN** the selected period contains unresolved records or the schedule classification/source mapping is absent or ambiguous
- **WHEN** the report is generated
- **THEN** affected fields SHALL be unavailable with a localized reason and coverage count
- **AND** the report SHALL NOT present the result as complete.

#### Scenario: Workpaper is not filed

- **GIVEN** a complete supporting report is displayed
- **WHEN** the user views or exports it
- **THEN** the output SHALL identify itself as a supporting workpaper
- **AND** no submission or filing-success state SHALL be shown.

### Requirement: S/G workpapers follow the desktop design system

The Taxes view SHALL provide keyboard-accessible schedule and period selectors, visible focus, semantic table/status information, source-record drill-down, active-locale dates and amounts, German and English messages, and responsive behavior for narrow windows and text scaling as specified in `DESIGN.md`. Status and availability SHALL NOT rely on color alone.

#### Scenario: Workpaper can be reviewed by keyboard

- **GIVEN** a user navigates the S/G report with keyboard focus
- **WHEN** they select a period and open a contributing-record path
- **THEN** selectors, report fields, source details, and return actions SHALL remain keyboard reachable with visible focus
- **AND** unavailable states and field explanations SHALL be announced in the active locale.
