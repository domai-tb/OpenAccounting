## ADDED Requirements

### Requirement: S/G availability is explicit and contains no guessed report values

The Taxes workspace SHALL offer explicit Anlage S and Anlage G selections through the typed availability use case. In this change both schedules SHALL return an unavailable result because no accepted S/G form-year, period, classification, and accounting-source contract exists. The result SHALL identify those blocker reasons and SHALL NOT expose numeric S/G field values, source coverage counts, copied EÜR/EKS/GuV totals, source-record claims, exports, or filing status. A period selector SHALL remain unavailable until an accepted schedule-period contract exists. This state SHALL NOT change accounting records.

#### Scenario: User selects a schedule before its contracts are accepted

- **GIVEN** no accepted S/G form-year, period, classification, and accounting-source contract is registered
- **WHEN** the user selects Anlage S or Anlage G
- **THEN** the typed result SHALL be unavailable and list the missing contract reasons
- **AND** no period picker, numeric field, source count, or report export SHALL be shown.

#### Scenario: EÜR data is not substituted for an S/G field

- **GIVEN** an EÜR result exists but no accepted S/G line mapping exists
- **WHEN** the user opens either S/G selection
- **THEN** the S/G result SHALL remain unavailable
- **AND** the EÜR result SHALL not be copied, relabeled, or summarized as S/G data.

#### Scenario: Schedule eligibility is not inferred

- **GIVEN** the company profile contains a name, occupation, tax number, or transaction descriptions
- **WHEN** the user opens the S/G availability view
- **THEN** the application SHALL require an explicit schedule selection and SHALL NOT infer legal eligibility from those fields.

#### Scenario: Missing schedule selection has a typed boundary

- **GIVEN** `/taxes?view=income-tax-schedules` has no valid `schedule=s|g` value
- **WHEN** the route resolves
- **THEN** the page SHALL show a localized schedule-selection state without requesting accounting data or displaying numeric amounts.

### Requirement: S/G availability follows the desktop design system

The availability view SHALL provide keyboard-accessible schedule selection, visible focus, semantic status information, German and English messages, and responsive behavior at supported narrow widths and text scaling as required by `DESIGN.md`. Status SHALL NOT rely on color alone.

#### Scenario: Availability can be reviewed by keyboard

- **GIVEN** a user navigates the S/G availability view with keyboard focus
- **WHEN** they select a schedule and open its blocker explanation
- **THEN** the selection, blocker details, and return action SHALL remain keyboard reachable with visible focus
- **AND** the unavailable state SHALL be announced in the active locale.
