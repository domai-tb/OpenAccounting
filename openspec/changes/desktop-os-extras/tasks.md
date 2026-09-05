## 1. File Associations

- [x] 1.1 Write failing test: `test/features/desktop/file_assoc_test.dart` — PDF/CSV handler registration and routing (assert fails for right reason)
- [x] 1.2 Implement: `DesktopFileAssocService` with VM-safe `FileAssocBackend` (register, route double-click to viewer/import, unsupported no-op)
- [x] 1.3 Refactor; full suite stays green

## 2. PDF Viewer Window

- [x] 2.1 Write failing test: `test/features/desktop/pdf_viewer_test.dart` — dedicated viewer window zoom/print/save (assert fails for right reason)
- [x] 2.2 Implement: `PdfViewerService` second window via `window_manager`, 50-200% zoom, print/save dialogs, isolated lifecycle
- [x] 2.3 Refactor; full suite stays green

## 3. Drag-and-Drop Import

- [x] 3.1 Write failing test: `test/features/desktop/drag_drop_test.dart` — drag PDF/CSV/image to drop zones, reject unsupported (assert fails)
- [x] 3.2 Implement: `DropService` with `desktop_drop` adapter, type validation, drop-zone UI, APP_DATA_DIR storage
- [x] 3.3 Refactor; full suite stays green

## 4. Single Instance

- [x] 4.1 Write failing test: `test/features/desktop/single_instance_test.dart` — lock, second instance foreground, deep-link forwarding (assert fails)
- [x] 4.2 Implement: `SingleInstanceService` lock file + socket forwarding, exit second instance
- [x] 4.3 Refactor; full suite stays green

## 5. Platform Workarounds

- [x] 5.1 Write failing test: `test/features/desktop/platform_test.dart` — profile paths, console hide, GPU config (assert fails)
- [x] 5.2 Implement: harden `profile_manager.dart` paths, Windows console flag, Linux Wayland detection
- [x] 5.3 Refactor; full suite stays green
