# quick-booking-workspace Specification

## Purpose
TBD - created by archiving change quick-booking-workspace. Update Purpose after archive.

## Requirements

### Requirement: Quick-booking presets preserve explicit transaction inputs

The Banking workspace SHALL provide typed create, read, update, and delete operations for reusable transaction presets. A complete executable preset SHALL contain name, direction (`einnahme` or `ausgabe`), payment account, active category, configured tax-rate reference, amount basis, optional default amount, and description. Existing rows without direction, tax-rate reference, or amount basis SHALL remain unchanged and SHALL be marked for review; the application SHALL NOT infer missing values. A preset SHALL be revalidated against account/category configuration when saved and executed. The posting owner SHALL resolve tax-rate configuration and applicability for the explicit business date; because `ust_saetze` has no `aktiv` field, the preset layer SHALL NOT assume or add one. If the owner cannot prove the selected rate is configured and supported for that date, the preset SHALL remain non-executable.

#### Scenario: Create a complete preset

- **GIVEN** the user enters a name, direction, payment account, category, tax rate, amount basis, optional default amount, and description
- **WHEN** the user saves the preset
- **THEN** the typed use case SHALL validate references and persist the preset
- **AND** the preset SHALL appear as executable only if all required posting inputs are supported by the accepted posting contract.

#### Scenario: Legacy preset requires review

- **GIVEN** an existing preset has no stored direction, tax-rate reference, or amount basis
- **WHEN** the Quick Bookings view loads
- **THEN** the preset SHALL remain unchanged and be marked review required
- **AND** its execute action SHALL be unavailable until a user supplies valid values.

#### Scenario: Referenced configuration is no longer active

- **GIVEN** a preset references a missing or unsupported account/payment type, an inactive or deleted category, or a tax rate the posting owner cannot resolve as configured and supported for the business date
- **WHEN** the preset is saved or activated
- **THEN** the use case SHALL return a localized review/validation result
- **AND** it SHALL NOT substitute another reference or create a posting.

### Requirement: Execute presets through approved accounting posting

Activating a complete preset SHALL submit its exact typed inputs and an explicit business date to the accepted accounting posting use case and SHALL display success only after that use case returns a committed posting identity. Quick-booking UI/repository code SHALL NOT insert directly into `journal`, calculate tax, choose fallback mappings, or create its own transaction record. If the balanced-posting service is absent/unapproved or a required input is unsupported, activation SHALL show an unavailable state and SHALL persist no accounting effect. An absent default amount SHALL open the shared typed cash-event amount-entry step; it SHALL NOT be treated as zero.

#### Scenario: Posting service accepts the preset

- **GIVEN** a complete preset and accepted posting service support for its account, category, direction, tax, and amount basis
- **WHEN** the user activates the preset for a business date
- **THEN** the service SHALL receive those exact values
- **AND** the workspace SHALL show the returned committed posting identity
- **AND** no second journal writer or quick-booking ledger SHALL be used.

#### Scenario: Posting contract is unavailable

- **GIVEN** the direct cash-event posting contract is absent or cannot resolve a required preset field
- **WHEN** the user activates a preset
- **THEN** the workspace SHALL show the unsupported/missing inputs
- **AND** no journal row, posting group, or success state SHALL be created.

#### Scenario: Preset has no default amount

- **GIVEN** a valid preset has no default amount
- **WHEN** the user activates it
- **THEN** the shared typed composer SHALL request the required amount and basis
- **AND** activation SHALL not submit zero or any fabricated amount.

### Requirement: Quick Bookings compose within Banking without changing other views

The application SHALL expose Quick Bookings as `/banking?view=quick-bookings` and SHALL preserve independent route state for imports, history, cashbook, and daily close. The view SHALL use the registered service through `AppScope`/`AppServices`, show localized loading/populated/empty/unavailable/error states, and use a primary “new preset” action. It SHALL NOT construct repositories or query the database from widgets.

#### Scenario: Open Quick Bookings and return to import state

- **GIVEN** the user opens Quick Bookings from a Banking view with query state
- **WHEN** they return to that view
- **THEN** the prior Banking view and its query filters SHALL be preserved.

#### Scenario: Execution is unavailable

- **GIVEN** the preset repository is available but its posting use case is not accepted or registered
- **WHEN** the user opens Quick Bookings
- **THEN** preset review and management SHALL remain available when safe
- **AND** execution SHALL be clearly unavailable without presenting a fake success state.

### Requirement: Quick Bookings follow the desktop design schema

Preset forms and actions SHALL provide localized German and English labels, validation, empty/unavailable/error/success states, keyboard operation, visible focus, semantic names and states, active-locale date/amount formatting, and narrow-window/text-scale reachability as specified by `DESIGN.md`. A status SHALL NOT be conveyed by color alone.

#### Scenario: Preset management is keyboard accessible

- **GIVEN** the user navigates the Quick Bookings view by keyboard
- **WHEN** they create or edit a preset
- **THEN** every field and Save/Cancel action SHALL be reachable in logical order with visible focus
- **AND** validation and execution outcomes SHALL be announced in the active locale.
