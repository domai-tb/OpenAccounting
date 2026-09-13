## ADDED Requirements

### Requirement: Production desktop action wiring

Supported shortcuts, file associations, drag-and-drop, tray actions, and PDF viewer adapters SHALL be constructed from production bootstrap and registered idempotently. Events SHALL route to the active profile services.

#### Scenario: Dropped file reaches import workflow
- **GIVEN** the app starts with an active profile and a supported file handler
- **WHEN** the user drops a supported file
- **THEN** the registered production adapter SHALL route it to the matching import/document workflow and show its state

#### Scenario: Unsupported target reports availability
- **GIVEN** a target does not support one optional desktop action
- **WHEN** the app starts or the user invokes it
- **THEN** the UI SHALL report the action as unavailable and provide the documented alternative without false success

### Requirement: Updater remains fail-closed

Updater installation SHALL remain unavailable until a separate approved policy defines trusted root, package format, provenance, replay/downgrade protection, rollback, and key rotation. This change SHALL expose availability and rejection states only.

#### Scenario: Unapproved updater is visible as unavailable
- **GIVEN** no approved signing policy exists
- **WHEN** updater status is shown
- **THEN** the UI SHALL explain that installation is unavailable and SHALL not claim an update was installed

#### Scenario: Untrusted update is rejected
- **GIVEN** an update lacks a trusted root or fails verification
- **WHEN** the user checks for updates
- **THEN** the update SHALL not install and the UI SHALL offer safe retry/help
