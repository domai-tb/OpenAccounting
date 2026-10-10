## MODIFIED Requirements

### Requirement: Schnellbuchungen

The system SHALL provide reusable quick-booking presets for frequent transactions. An executable preset SHALL preserve transaction direction, explicit payment account, active category, tax-rate reference, amount basis, optional default amount, and description. Execution SHALL call the accepted typed accounting posting service, which owns posting legs, tax behavior, snapshots, idempotency, and correction identity. The quick-booking feature SHALL NOT insert directly into `journal` or execute an incomplete legacy preset. Presets missing newly required direction/tax/basis values SHALL remain unchanged and require user review. Tax-rate identity and effective-date applicability SHALL be resolved by the posting owner; the preset SHALL NOT assume an `aktiv` flag because the `ust_saetze` schema has none. Execution SHALL remain unavailable until the accepted posting service supports direct cash/bank events and all preset inputs.

#### Scenario: Quick booking preset

- **GIVEN** a user creates a complete Schnellbuchung with name, direction, payment account, category, tax rate, amount basis, optional amount, and description
- **WHEN** the preset is saved
- **THEN** the typed use case SHALL store those explicit values after reference validation.

#### Scenario: Quick booking execution

- **GIVEN** a complete preset and an accepted posting service for its exact transaction type
- **WHEN** the user activates the preset
- **THEN** the posting service SHALL create and return one committed posting group with those inputs
- **AND** the system SHALL not create a direct, unbalanced journal row.

#### Scenario: Quick booking with invalid preset

- **GIVEN** a preset has missing legacy inputs, an inactive/deleted category, a missing or unsupported account/payment type, or a tax rate the posting owner cannot resolve as configured and supported for the business date
- **WHEN** it is displayed or executed
- **THEN** the preset SHALL be marked for review and no posting SHALL be created until its inputs are valid.
