## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/desktop-file-associations/spec.md → File Associations | PDF File Association | test/features/desktop/file_assoc_test.dart | test_pdf_file_association | 🔴 red |
| specs/desktop-file-associations/spec.md → File Associations | CSV File Association | test/features/desktop/file_assoc_test.dart | test_csv_file_association | 🔴 red |
| specs/desktop-file-associations/spec.md → File Associations | File Association With No App Running | test/features/desktop/file_assoc_test.dart | test_file_assoc_no_app_running | 🔴 red |
| specs/desktop-file-associations/spec.md → File Associations | Unsupported File Type Double-Click | test/features/desktop/file_assoc_test.dart | test_unsupported_file_double_click | 🔴 red |
| specs/desktop-pdf-viewer/spec.md → PDF Viewer Window | PDF Inline Display | test/features/desktop/pdf_viewer_test.dart | test_pdf_inline_display | 🔴 red |
| specs/desktop-pdf-viewer/spec.md → PDF Viewer Window | PDF Print | test/features/desktop/pdf_viewer_test.dart | test_pdf_print | 🔴 red |
| specs/desktop-pdf-viewer/spec.md → PDF Viewer Window | PDF Save As | test/features/desktop/pdf_viewer_test.dart | test_pdf_save_as | 🔴 red |
| specs/desktop-pdf-viewer/spec.md → PDF Viewer Window | PDF Viewer Closed by User | test/features/desktop/pdf_viewer_test.dart | test_pdf_viewer_closed | 🔴 red |
| specs/desktop-drag-drop/spec.md → Drag-and-Drop File Import | Drag PDF to Belege | test/features/desktop/drag_drop_test.dart | test_drag_pdf_to_belege | 🔴 red |
| specs/desktop-drag-drop/spec.md → Drag-and-Drop File Import | Drag Unsupported File Type | test/features/desktop/drag_drop_test.dart | test_drag_unsupported_file | 🔴 red |
| specs/desktop-drag-drop/spec.md → Drag-and-Drop File Import | Drag Multiple Supported Files | test/features/desktop/drag_drop_test.dart | test_drag_multiple_supported | 🔴 red |
| specs/desktop-drag-drop/spec.md → Drag-and-Drop File Import | Drag File Outside Drop Zone | test/features/desktop/drag_drop_test.dart | test_drag_outside_drop_zone | 🔴 red |
| specs/desktop-single-instance/spec.md → Single Instance Enforcement | Second Instance Launch | test/features/desktop/single_instance_test.dart | test_second_instance_launch | 🔴 red |
| specs/desktop-single-instance/spec.md → Single Instance Enforcement | Deep Link to Running Instance | test/features/desktop/single_instance_test.dart | test_deep_link_running_instance | 🔴 red |
| specs/desktop-single-instance/spec.md → Single Instance Enforcement | First Instance Launch | test/features/desktop/single_instance_test.dart | test_first_instance_launch | 🔴 red |
| specs/desktop-platform-workarounds/spec.md → Platform Workarounds | Linux GPU Workaround | test/features/desktop/platform_test.dart | test_linux_gpu_workaround | 🔴 red |
| specs/desktop-platform-workarounds/spec.md → Platform Workarounds | Windows Console Hide | test/features/desktop/platform_test.dart | test_windows_console_hide | 🔴 red |
| specs/desktop-platform-workarounds/spec.md → Platform Workarounds | macOS Profile Path | test/features/desktop/platform_test.dart | test_macos_profile_path | 🔴 red |
| specs/desktop-platform-workarounds/spec.md → Platform Workarounds | Linux Profile Path | test/features/desktop/platform_test.dart | test_linux_profile_path | 🔴 red |

## Coverage Notes

All tests VM-compatible via fakes for OS APIs (file assoc, window_manager, drag-drop, lock). OS harness on Windows/macOS/Linux validates native registration.
