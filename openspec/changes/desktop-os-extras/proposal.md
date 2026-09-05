## Why

OpenInvoices tasks 15.x covered tray, shortcuts, updater and window state, but deferred OS-integration specs (file associations, PDF viewer window, drag-and-drop, single-instance, platform workarounds) require native OS APIs that cannot be VM-tested in LXC and were marked N/A with 4.2h period. Splitting them into a focused change makes implementation agent-friendly (<15 tasks) and allows OS-harness testing on Windows/macOS/Linux.

## What Changes

- Add OS file association registration for `.pdf` and `.csv` (handler registration, double-click routing to internal PDF viewer or import wizard, no-op for unsupported types)
- Add dedicated PDF viewer window with zoom 50-200%, print, save-as, and lifecycle isolation from main window
- Add drag-and-drop file import onto main window / Belege drop zones for PDF/CSV/JPG/PNG/TIFF with rejection UI for unsupported types
- Enforce single-instance with second-instance foreground activation and deep-link forwarding
- Harden platform workarounds: Linux Wayland/X11 GPU, Windows console hide in release, macOS vs Linux profile paths
- **BREAKING**: None — additive, behind OS capability checks, falls back silently when not supported

## Capabilities

### New Capabilities
- `desktop-file-associations`: OS handler registration and launch routing for PDF/CSV
- `desktop-pdf-viewer`: dedicated viewer window with zoom/print/save
- `desktop-drag-drop`: OS drag-and-drop import with type validation and drop-zone UI
- `desktop-single-instance`: single-instance lock and deep-link forwarding
- `desktop-platform-workarounds`: platform-specific path and windowing fixes

### Modified Capabilities
- `desktop`: extend window management with viewer window lifecycle

## Impact

- Affected code: `lib/features/desktop/*`, `lib/main.dart`, `lib/core/db/profile_manager.dart`, platform runners (windows/macos/linux)
- Dependencies: `window_manager` (already), `desktop_drop` or `super_drag_and_drop` (new, evaluate), file association plugin (evaluate)
- Systems: OS file associations, window manager, drag-drop, single-instance lock
