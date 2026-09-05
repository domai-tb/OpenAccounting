## ADDED Requirements

### Requirement: Single Instance Enforcement

Only one instance of the application SHALL run at a time. When a second instance is launched, it SHALL activate the existing instance's window instead of opening a new one.

#### Scenario: Second Instance Launch

- **GIVEN** OpenInvoices is already running
- **WHEN** the user launches OpenInvoices again
- **THEN** the existing instance's window SHALL be brought to the foreground and the new instance SHALL exit immediately

#### Scenario: Deep Link to Running Instance

- **GIVEN** OpenInvoices is already running
- **WHEN** the user double-clicks a `.pdf` file associated with OpenInvoices
- **THEN** the file SHALL be opened in the existing instance's PDF viewer and no new instance SHALL be created

#### Scenario: First Instance Launch

- **GIVEN** no OpenInvoices instance is running
- **WHEN** the user launches OpenInvoices
- **THEN** a new instance SHALL start normally and the main window SHALL appear

