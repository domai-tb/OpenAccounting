# OpenInvoices — Desktop Platform Specification

## ADDED Requirements

### Requirement: System Tray

The application SHALL display a system tray icon with a context menu providing: Show/Hide window, Refresh data, Check for Updates, Quit. The tray icon SHALL remain visible when the window is minimized (not closed).

#### Scenario: Tray Context Menu Actions

GIVEN the app is running and the tray icon is visible
WHEN the user right-clicks the system tray icon
THEN a context menu SHALL appear with "Fenster anzeigen", "Daten aktualisieren", "Nach Updates suchen", and "Beenden"
AND clicking "Fenster anzeigen" SHALL restore the window to its last position and size

#### Scenario: Close to Tray

GIVEN "Minimieren in Tray" is enabled in settings
WHEN the user clicks the window close button
THEN the window SHALL hide to the system tray
AND the app SHALL NOT quit

#### Scenario: Close to Tray Disabled

GIVEN "Minimieren in Tray" is disabled in settings
WHEN the user clicks the window close button
THEN the application SHALL quit completely

#### Scenario: Tray Icon Not Shown

GIVEN the system does not support system tray (e.g., certain Linux WMs)
WHEN the app launches
THEN the app SHALL function normally without a tray icon
AND no error SHALL be displayed

### Requirement: Global Keyboard Shortcuts

The application SHALL register global keyboard shortcuts that function even when the window is not focused. The default shortcuts SHALL be: Ctrl+Shift+I (show/hide window), Ctrl+Shift+N (new invoice).

#### Scenario: Global Show/Hide

GIVEN the app window is hidden or minimized
WHEN the user presses Ctrl+Shift+I
THEN the window SHALL appear at its last position
AND the window SHALL receive focus

#### Scenario: Global Show/Hide Toggles

GIVEN the app window is visible and focused
WHEN the user presses Ctrl+Shift+I
THEN the window SHALL hide to the system tray

#### Scenario: Global New Invoice

GIVEN the app is running (window may be hidden)
WHEN the user presses Ctrl+Shift+N
THEN the app SHALL show the window
AND navigate to the invoice creation form

#### Scenario: Shortcut Conflict Detection

GIVEN another application is already using Ctrl+Shift+I
WHEN the app attempts to register the global shortcut
THEN the app SHALL display a warning: "Tastenkombination wird bereits von einer anderen Anwendung verwendet"
AND the shortcut SHALL not be registered
AND the app SHALL function normally without that shortcut

### Requirement: Auto-Update

The application MAY check GitHub Releases for updates on startup and periodically (every 4 hours). If enabled, updates SHALL be downloaded and installed with user confirmation through a Flutter-native or target-OS updater. Package signatures SHALL be verified. Automatic update enablement is deferred until the distribution package and signing trust model are documented; Tauri is not part of this Flutter application.

The following update scenarios apply only when the optional updater is enabled.

#### Scenario: Update Available Notification

GIVEN a new release exists on GitHub Releases with a version higher than the current version
WHEN the app checks for updates
THEN a notification SHALL appear: "Update verfügbar: vX.Y.Z"
AND the notification SHALL include "Herunterladen" and "Später" buttons

#### Scenario: Update Download and Install

GIVEN an update notification is visible
WHEN the user clicks "Herunterladen"
THEN the update SHALL download with a progress indicator
AND upon completion, the app SHALL prompt: "Update installieren und neu starten?"
AND clicking "Ja" SHALL install and restart the app

#### Scenario: Update Download Cancelled

GIVEN an update notification is visible
WHEN the user clicks "Später"
THEN the notification SHALL dismiss
AND the update SHALL NOT be downloaded
AND the app SHALL check again after 4 hours

#### Scenario: Signing Verification Failure

GIVEN a downloaded update fails Ed25519 signature verification
WHEN the verification check runs
THEN the update SHALL be rejected
AND an error message SHALL display: "Update-Signatur ungültig"
AND the current version SHALL remain active

#### Scenario: No Update Available

GIVEN the current version is the latest release on GitHub
WHEN the app checks for updates
THEN no notification SHALL appear
AND the check SHALL complete silently

### Requirement: Window Management

The application SHALL remember window size, position, and maximized state across sessions. The minimum window size SHALL be 1024x768. The window SHALL support minimization to the system tray.

#### Scenario: Window State Persistence

GIVEN the user resizes the window to 1400x900 and moves it to position (200, 100)
WHEN the user closes and reopens the app
THEN the next launch SHALL restore the window to 1400x900 at (200, 100)

#### Scenario: Minimum Size Enforcement

GIVEN the app window is open
WHEN the user attempts to resize the window below 1024x768
THEN the window SHALL not shrink below 1024x768
AND the resize handle SHALL stop at the minimum dimensions

#### Scenario: Maximize State Persistence

GIVEN the user maximizes the window
WHEN the user closes and reopens the app
THEN the next launch SHALL open the window maximized

#### Scenario: Window State Corruption Recovery

GIVEN the saved window position references a disconnected monitor
WHEN the app launches
THEN the window SHALL appear centered on the primary monitor
AND SHALL use default dimensions (1200x800)

### Requirement: File Associations

The application SHALL register as a handler for `.pdf` and `.csv` files on the operating system. Double-clicking a file with these extensions SHALL open it in the appropriate viewer within the app.

#### Scenario: PDF File Association

GIVEN OpenInvoices is registered as a handler for `.pdf` files
WHEN the user double-clicks a `.pdf` file
THEN the app SHALL open (or activate if already running)
AND display the PDF in the internal PDF viewer

#### Scenario: CSV File Association

GIVEN OpenInvoices is registered as a handler for `.csv` files
WHEN the user double-clicks a `.csv` file
THEN the app SHALL open the import wizard
AND pre-fill the file path in the import source field

#### Scenario: File Association With No App Running

GIVEN OpenInvoices is not currently running
WHEN the user double-clicks a `.pdf` file associated with OpenInvoices
THEN a new app instance SHALL launch
AND open the PDF in the internal PDF viewer

#### Scenario: Unsupported File Type Double-Click

GIVEN OpenInvoices is not registered as a handler for `.docx` files
WHEN the user double-clicks a `.docx` file
THEN OpenInvoices SHALL NOT launch
AND the OS default handler for `.docx` SHALL be used

### Requirement: PDF Viewer Window

PDFs SHALL be displayed in a dedicated viewer window separate from the main application window. The viewer SHALL support zoom, print, and save-as actions.

#### Scenario: PDF Inline Display

GIVEN a finalized invoice exists with a generated PDF
WHEN the user requests to view the PDF
THEN a PDF viewer window SHALL open
AND the document SHALL render inline (Content-Disposition: inline)
AND the viewer SHALL provide zoom controls (50%-200%)

#### Scenario: PDF Print

GIVEN the PDF viewer is open with a document
WHEN the user clicks "Drucken"
THEN the native print dialog SHALL open
AND the PDF content SHALL be sent to the selected printer

#### Scenario: PDF Save As

GIVEN the PDF viewer is open with a document
WHEN the user clicks "Speichern unter"
THEN a native save dialog SHALL open
AND the default filename SHALL match the document number

#### Scenario: PDF Viewer Closed by User

GIVEN the PDF viewer window is open
WHEN the user closes the viewer window
THEN the viewer window SHALL close
AND the main app window SHALL remain unaffected

### Requirement: Drag-and-Drop File Import

The application SHALL accept dragged files onto the main window and specific drop zones (e.g., the Belege section). Supported file types for import: PDF, CSV, image formats (JPG, PNG, TIFF).

#### Scenario: Drag PDF to Belege

GIVEN the user has a PDF file on their system
WHEN the user drags the PDF file onto the Belege drop zone
THEN the file SHALL be stored through the local data source below the active profile `APP_DATA_DIR`
AND a new Beleg record SHALL be created
AND the file SHALL be visible in the Belege list

#### Scenario: Drag Unsupported File Type

GIVEN the user has a `.docx` file on their system
WHEN the user drags the `.docx` file onto any drop zone
THEN the drop zone SHALL show a rejection indicator
AND no upload SHALL occur
AND a tooltip SHALL display: "Nicht unterstütztes Dateiformat"

#### Scenario: Drag Multiple Supported Files

GIVEN the user has multiple PDF files on their system
WHEN the user drags all files onto the Belege drop zone
THEN each file SHALL be uploaded
AND a Beleg record SHALL be created for each
AND all files SHALL be visible in the Belege list

#### Scenario: Drag File Outside Drop Zone

GIVEN the user is dragging a file over the main window
WHEN the cursor is not over a drop zone
THEN no drop indicator SHALL appear
AND releasing the file SHALL have no effect

### Requirement: Single Instance Enforcement

Only one instance of the application SHALL run at a time. When a second instance is launched, it SHALL activate the existing instance's window instead of opening a new one.

#### Scenario: Second Instance Launch

GIVEN OpenInvoices is already running
WHEN the user launches OpenInvoices again
THEN the existing instance's window SHALL be brought to the foreground
AND the new instance SHALL exit immediately

#### Scenario: Deep Link to Running Instance

GIVEN OpenInvoices is already running
WHEN the user double-clicks a `.pdf` file associated with OpenInvoices
THEN the file SHALL be opened in the existing instance's PDF viewer
AND no new instance SHALL be created

#### Scenario: First Instance Launch

GIVEN no OpenInvoices instance is running
WHEN the user launches OpenInvoices
THEN a new instance SHALL start normally
AND the main window SHALL appear

### Requirement: Platform Workarounds

The application SHALL use Flutter desktop APIs and target-platform integrations for windowing, file associations, tray behavior, shortcuts, and profile paths. It SHALL NOT require Tauri, a webview, or a Python sidecar. Any engine-specific workaround SHALL be used only when supported by the Flutter target and documented for that target.

#### Scenario: Linux GPU Workaround

GIVEN the app launches on Linux
WHEN the Flutter desktop engine initializes
THEN the app SHALL use its supported Wayland/X11 configuration
AND the app SHALL render correctly on the supported Linux display sessions

#### Scenario: Windows Console Hide

GIVEN the app launches on Windows in release mode
WHEN the application window appears
THEN no console window SHALL appear alongside the application window

#### Scenario: macOS Profile Path

GIVEN the app launches on macOS
WHEN the profile directory is resolved
THEN the profile directory SHALL be at `~/Library/Application Support/OpenInvoices/profiles/<Name>/`
AND NOT at `~/.local/share/OpenInvoices/` (the Linux convention)

#### Scenario: Linux Profile Path

GIVEN the app launches on Linux
WHEN the profile directory is resolved
THEN the profile directory SHALL be at `~/.local/share/OpenInvoices/profiles/<Name>/`
AND NOT at `~/Library/Application Support/` (the macOS convention)
