## MODIFIED Requirements

### Requirement: Drag-and-Drop File Import

The application SHALL accept dragged files onto the main window and specific drop zones. Supported generic import
types remain PDF, CSV, JPG, PNG, and TIFF when a destination explicitly accepts them. The Belege drop zone SHALL accept
only verified PDF, PNG, JPEG, and supported XRechnung or ZUGFeRD/Factur-X XML sources up to 50 MiB. A Belege drop
zone SHALL reject CSV and TIFF even though another destination may accept those types.

#### Scenario: Drag PDF to Belege

- **GIVEN** the user has a valid PDF file no larger than 50 MiB
- **WHEN** the user drags the PDF file onto the Belege drop zone
- **THEN** the file SHALL be stored through the local data source below the active profile `APP_DATA_DIR`, a new
  Beleg record SHALL be created, and the file SHALL be visible in the Belege list

#### Scenario: Drag Unsupported File Type

- **GIVEN** the user has a `.docx` file on their system
- **WHEN** the user drags the `.docx` file onto any drop zone
- **THEN** the drop zone SHALL show a rejection indicator, no upload SHALL occur, and a tooltip SHALL display:
  `Nicht unterstütztes Dateiformat`

#### Scenario: Drag Multiple Supported Files

- **GIVEN** the user has multiple PDF files on their system
- **WHEN** the user drags all files onto the Belege drop zone
- **THEN** each file SHALL be uploaded, a Beleg record SHALL be created for each, and all files SHALL be visible in
  the Belege list

#### Scenario: Drag File Outside Drop Zone

- **GIVEN** the user is dragging a file over the main window
- **WHEN** the cursor is not over a drop zone
- **THEN** no drop indicator SHALL appear and releasing the file SHALL have no effect

#### Scenario: Belege rejects generic CSV and TIFF imports

- **GIVEN** the user drags a CSV or TIFF file onto the Belege drop zone
- **WHEN** the drop zone validates the file
- **THEN** it SHALL reject the file before storage and show the unsupported-format state

#### Scenario: Supported e-invoice XML is validated before storage

- **GIVEN** the user drags XRechnung XML or XML associated with ZUGFeRD/Factur-X onto the Belege drop zone
- **WHEN** the importer validates the source
- **THEN** only well-formed supported invoice XML is stored, and XML parsing SHALL not access external entities or
  network resources
