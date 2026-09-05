## ADDED Requirements

### Requirement: Drag-and-Drop File Import

The application SHALL accept dragged files onto the main window and specific drop zones (e.g., the Belege section). Supported file types for import: PDF, CSV, image formats (JPG, PNG, TIFF).

#### Scenario: Drag PDF to Belege

- **GIVEN** the user has a PDF file on their system
- **WHEN** the user drags the PDF file onto the Belege drop zone
- **THEN** the file SHALL be stored through the local data source below the active profile `APP_DATA_DIR` and a new Beleg record SHALL be created and the file SHALL be visible in the Belege list

#### Scenario: Drag Unsupported File Type

- **GIVEN** the user has a `.docx` file on their system
- **WHEN** the user drags the `.docx` file onto any drop zone
- **THEN** the drop zone SHALL show a rejection indicator and no upload SHALL occur and a tooltip SHALL display: "Nicht unterstütztes Dateiformat"

#### Scenario: Drag Multiple Supported Files

- **GIVEN** the user has multiple PDF files on their system
- **WHEN** the user drags all files onto the Belege drop zone
- **THEN** each file SHALL be uploaded and a Beleg record SHALL be created for each and all files SHALL be visible in the Belege list

#### Scenario: Drag File Outside Drop Zone

- **GIVEN** the user is dragging a file over the main window
- **WHEN** the cursor is not over a drop zone
- **THEN** no drop indicator SHALL appear and releasing the file SHALL have no effect

