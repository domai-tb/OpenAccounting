## ADDED Requirements

### Requirement: File Associations

The application SHALL register as a handler for `.pdf` and `.csv` files on the operating system. Double-clicking a file with these extensions SHALL open it in the appropriate viewer within the app.

#### Scenario: PDF File Association

- **GIVEN** OpenInvoices is registered as a handler for `.pdf` files
- **WHEN** the user double-clicks a `.pdf` file
- **THEN** the app SHALL open (or activate if already running) and display the PDF in the internal PDF viewer

#### Scenario: CSV File Association

- **GIVEN** OpenInvoices is registered as a handler for `.csv` files
- **WHEN** the user double-clicks a `.csv` file
- **THEN** the app SHALL open the import wizard and pre-fill the file path in the import source field

#### Scenario: File Association With No App Running

- **GIVEN** OpenInvoices is not currently running
- **WHEN** the user double-clicks a `.pdf` file associated with OpenInvoices
- **THEN** a new app instance SHALL launch and open the PDF in the internal PDF viewer

#### Scenario: Unsupported File Type Double-Click

- **GIVEN** OpenInvoices is not registered as a handler for `.docx` files
- **WHEN** the user double-clicks a `.docx` file
- **THEN** OpenInvoices SHALL NOT launch and the OS default handler for `.docx` SHALL be used

