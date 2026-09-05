# desktop-pdf-viewer

## Purpose

Dedicated desktop PDF viewing with zoom, print, save-as, and isolated window lifecycle.

## Requirements

### Requirement: PDF Viewer Window

PDFs SHALL be displayed in a dedicated viewer window separate from the main application window. The viewer SHALL support zoom, print, and save-as actions.

#### Scenario: PDF Inline Display

- **GIVEN** a finalized invoice exists with a generated PDF
- **WHEN** the user requests to view the PDF
- **THEN** a PDF viewer window SHALL open and the document SHALL render inline (Content-Disposition: inline) and the viewer SHALL provide zoom controls (50%-200%)

#### Scenario: PDF Print

- **GIVEN** the PDF viewer is open with a document
- **WHEN** the user clicks "Drucken"
- **THEN** the native print dialog SHALL open and the PDF content SHALL be sent to the selected printer

#### Scenario: PDF Save As

- **GIVEN** the PDF viewer is open with a document
- **WHEN** the user clicks "Speichern unter"
- **THEN** a native save dialog SHALL open and the default filename SHALL match the document number

#### Scenario: PDF Viewer Closed by User

- **GIVEN** the PDF viewer window is open
- **WHEN** the user closes the viewer window
- **THEN** the viewer window SHALL close and the main app window SHALL remain unaffected
