## MODIFIED Requirements

### Requirement: Auto-Update

The application SHALL check GitHub Releases for updates on startup and periodically (every 4 hours). Updater installation SHALL remain unavailable until a separate approved policy defines trusted root, package format, provenance, replay/downgrade protection, rollback, and key rotation. This change SHALL expose availability and rejection states only.

#### Scenario: Update Available Notification

GIVEN a new release exists on GitHub Releases with a version higher than the current version
WHEN the app checks for updates
THEN a notification SHALL appear: "Update verfügbar: vX.Y.Z"
AND the notification SHALL include "Herunterladen" and "Später" buttons

#### Scenario: Update Download and Install

GIVEN an update notification is visible AND an approved signing policy exists
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

#### Scenario: Updater Unavailable

GIVEN no approved signing policy exists
WHEN updater status is shown
THEN the UI SHALL explain that installation is unavailable
AND SHALL not claim an update was installed

#### Scenario: No Update Available

GIVEN the current version is the latest release on GitHub
WHEN the app checks for updates
THEN no notification SHALL appear
AND the check SHALL complete silently

### Requirement: Window Management

The application SHALL remember window size, position, and maximized state across sessions. The minimum window size SHALL be 960x640. The window SHALL support minimization to the system tray.

#### Scenario: Window State Persistence

GIVEN the user resizes the window to 1400x900 and moves it to position (200, 100)
WHEN the user closes and reopens the app
THEN the next launch SHALL restore the window to 1400x900 at (200, 100)

#### Scenario: Minimum Size Enforcement

GIVEN the app window is open
WHEN the user attempts to resize the window below 960x640
THEN the window SHALL not shrink below 960x640
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

### Requirement: Platform Workarounds

The application SHALL apply platform-specific workarounds: disable GPU acceleration on Linux (Wayland compatibility), hide the console window on Windows in release builds, and handle macOS-specific file path differences for profile storage and Linux display server compatibility.

#### Scenario: Linux GPU Workaround

GIVEN the app launches on Linux
WHEN the webview initializes
THEN GPU acceleration SHALL be disabled via the appropriate Tauri/webview flag
AND the app SHALL render correctly on Wayland and X11

#### Scenario: Windows Console Hide

GIVEN the app launches on Windows in release mode
WHEN the application window appears
THEN no console window SHALL appear alongside the application window

#### Scenario: macOS Profile Path

GIVEN the app launches on macOS
WHEN the profile directory is resolved
THEN the profile directory SHALL be at `~/Library/Application Support/OpenAccounting/profile/<Name>/`
AND NOT at `~/.local/share/OpenInvoices/` (the Linux convention)

#### Scenario: Linux Profile Path

GIVEN the app launches on Linux
WHEN the profile directory is resolved
THEN the profile directory SHALL be at `~/.local/share/OpenInvoices/profile/<Name>/`
AND NOT at `~/Library/Application Support/` (the macOS convention)

#### Scenario: Windows Profile Path

GIVEN the app launches on Windows
WHEN the profile directory is resolved
THEN the profile directory SHALL be at `%APPDATA%/OpenAccounting/profile/<Name>/`

## REMOVED Requirements

### Requirement: Backend Process Management (Sidecar)

The application SHALL manage a Python backend process as a Tauri sidecar. The backend SHALL start automatically when the app launches and terminate when the app quits. The sidecar SHALL be bundled as a standalone executable via PyInstaller.

#### Scenario: Backend Auto-Start

GIVEN the app has launched
WHEN the frontend initializes
THEN the backend sidecar SHALL start automatically
AND the frontend SHALL poll until the backend responds on a health endpoint
AND the UI SHALL display "Backend wird gestartet..." during this period

#### Scenario: Backend Crash Recovery

GIVEN the backend process is running
WHEN the backend process crashes
THEN the app SHALL detect the crash within 5 seconds
AND automatically restart the backend sidecar
AND display a notification: "Backend wurde neu gestartet"

#### Scenario: Backend Shutdown on App Quit

GIVEN the app is running with an active backend sidecar
WHEN the user quits the application
THEN the backend sidecar process SHALL be terminated gracefully
AND any in-progress requests SHALL be allowed to complete (up to 5 second timeout)

#### Scenario: Backend Port Conflict

GIVEN another process is already using the backend port
WHEN the backend sidecar starts
THEN the sidecar SHALL log the port conflict error
AND the app SHALL display "Backend nicht erreichbar" with retry option
