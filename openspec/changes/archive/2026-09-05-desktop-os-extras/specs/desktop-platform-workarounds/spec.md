## ADDED Requirements

### Requirement: Platform Workarounds

The application SHALL use Flutter desktop APIs and target-platform integrations for windowing, file associations, tray behavior, shortcuts, and profile paths. It SHALL NOT require Tauri, a webview, or a Python sidecar. Any engine-specific workaround SHALL be used only when supported by the Flutter target and documented for that target.

#### Scenario: Linux GPU Workaround

- **GIVEN** the app launches on Linux
- **WHEN** the Flutter desktop engine initializes
- **THEN** the app SHALL use its supported Wayland/X11 configuration and the app SHALL render correctly on the supported Linux display sessions

#### Scenario: Windows Console Hide

- **GIVEN** the app launches on Windows in release mode
- **WHEN** the application window appears
- **THEN** no console window SHALL appear alongside the application window

#### Scenario: macOS Profile Path

- **GIVEN** the app launches on macOS
- **WHEN** the profile directory is resolved
- **THEN** the profile directory SHALL be at `~/Library/Application Support/OpenInvoices/profiles/<Name>/` and NOT at `~/.local/share/OpenInvoices/` (the Linux convention)

#### Scenario: Linux Profile Path

- **GIVEN** the app launches on Linux
- **WHEN** the profile directory is resolved
- **THEN** the profile directory SHALL be at `~/.local/share/OpenInvoices/profiles/<Name>/` and NOT at `~/Library/Application Support/` (the macOS convention)

