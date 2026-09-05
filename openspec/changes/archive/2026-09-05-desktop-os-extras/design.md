## Context

OpenInvoices added tray/shortcuts/updater/window-state but left OS-integration deferred as N/A. This change hardens remaining desktop OS specs that require native APIs. Current app uses `window_manager` and `system_tray` via VM-safe adapters; file handling and drag-drop are not yet implemented; single-instance not enforced; profile paths already differentiate Linux vs macOS but window console and GPU workarounds not hardened.

## Goals / Non-Goals

**Goals:**
- File association registration for PDF/CSV with routing to viewer/import
- Dedicated PDF viewer window (second window_manager window) with zoom/print/save
- Drag-and-drop import with type validation and drop-zone UI per DESIGN §16
- Single-instance lock with argument forwarding
- Platform workarounds documented and tested for profile paths, console, GPU

**Non-Goals:**
- No Tauri/webview/Python sidecar — Flutter desktop only per spec
- No cloud sync or auto-open for unsupported types
- No custom PDF rendering engine — reuse existing `pdf` feature

## Decisions

- **File associations**: Use OS registration via `flutter` platform channel + `window_manager` `setAsDefaultProtocolClient` equivalent where available; fallback to manual `mimeapps.list`/`Info.plist` association documentation when plugin unavailable. Rejected: separate `file_assoc` native plugin per OS (duplication).
- **PDF viewer window**: Second `window_manager` window (`pdf_viewer` route) with `ZoomableWidget` 50-200% and `printing` package for print. Isolated lifecycle so closing viewer does not close main. Rejected: in-app dialog (violates spec separate window) and embedded webview (requires Tauri).
- **Drag-and-drop**: `desktop_drop` (or `super_drag_and_drop`) with VM-safe adapter `DropBackend`; supported types PDF/CSV/JPG/PNG/TIFF, others show "Nicht unterstütztes Dateiformat". Rejected: `drop_zone` web-only package.
- **Single instance**: `window_manager` `isPreventClose` + lock file `~/.cache/OpenAccounting/lock` with `FileLock`; second instance sends args via socket and exits. Rejected: custom daemon.
- **Platform workarounds**: Profile paths already in `profile_manager.dart` (XDG vs Application Support); add `console hide` via `windows` runner `WIN32` subsystem flag and `Wayland` check via `Platform.environment['XDG_SESSION_TYPE']`.

## Risks / Trade-offs

- [OS registration fails silently] → VM-safe try/catch, no error toast, feature degrades to manual open
- [Second window manager not available in LXC] → guard with `kIsWeb`/`MissingPluginException`, tests use fake backend
- [Drag-drop unsupported on Linux WM] → drop zone shows disabled state, no crash
- [Lock file stale after crash] → check PID alive, remove if dead

## Migration Plan

1. Add `desktop_drop` dependency, evaluate on Windows/macOS/Linux
2. Implement adapters behind `DesktopFileAssocService`, `PdfViewerService`, `DropService`, `SingleInstanceService`
3. Add routes `/pdf-viewer/:id` and overlay viewer window
4. Test on each OS with file double-click and drag-drop harness
5. Rollback: remove registration, viewer and drop zone become no-ops

## Open Questions

- Which file association plugin covers all three OS without fork?
- Should PDF viewer reuse existing PDF generation or call separate `pdf` renderer?

