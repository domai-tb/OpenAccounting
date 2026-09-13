## ADDED Requirements

### Requirement: Production desktop action wiring

Supported shortcuts, file associations, drag-and-drop, tray actions, and PDF viewer adapters SHALL be constructed from production bootstrap and registered idempotently in a `DesktopCapabilityRegistry`. Each adapter SHALL be wrapped as a `DesktopCapability<T>` with typed availability state (`supported` / `unavailable(reason)`). An `onEvent` callback injected at bootstrap SHALL receive adapter events; profile-aware routing is the callback's responsibility, not the adapter's.

#### Scenario: Dropped file callback fires
- **GIVEN** the app starts with a registered drop capability and an `onEvent` callback
- **WHEN** the user drops a supported file
- **THEN** the drop adapter SHALL invoke the callback with the file path and the callback SHALL be callable

#### Scenario: Unsupported target reports availability
- **GIVEN** a target does not support one optional desktop action
- **WHEN** the app starts or the user invokes it
- **THEN** the registry SHALL report the action as `unavailable` with a reason and the UI SHALL display the alternative without false success

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
