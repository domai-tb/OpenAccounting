## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/pdf-rendering-completeness/spec.md → Complete supported PDF rendering | Supported type renders bytes | test/features/pdf/pdf_rendering_test.dart | test_supported_type_renders_bytes | 🟢 green |
| specs/pdf-rendering-completeness/spec.md → Complete supported PDF rendering | Unsupported or incomplete snapshot fails | test/features/pdf/pdf_rendering_test.dart | test_unsupported_or_incomplete_snapshot_fails | 🟢 green |
| specs/pdf-rendering-completeness/spec.md → Optional content and readable layout | Configured content appears | test/features/pdf/pdf_rendering_test.dart | test_configured_content_appears | 🟢 green |
| specs/pdf-rendering-completeness/spec.md → Optional content and readable layout | Missing optional content remains readable | test/features/pdf/pdf_rendering_test.dart | test_missing_optional_content_remains_readable | 🟢 green |
| specs/document-artifact-transaction/spec.md → Atomic artifact and side-effect transaction | Finalized invoice commits artifact and effects | test/features/pdf/document_transaction_test.dart | test_finalized_invoice_commits_artifact_and_effects | 🟢 green |
| specs/document-artifact-transaction/spec.md → Atomic artifact and side-effect transaction | Writer failure rolls back | test/features/pdf/document_transaction_test.dart | test_writer_failure_rolls_back | 🟢 green |
| specs/document-artifact-transaction/spec.md → Retry, concurrency, and path safety | Identical retry is idempotent | test/features/pdf/document_transaction_test.dart | test_identical_retry_is_idempotent | 🟢 green |
| specs/document-artifact-transaction/spec.md → Retry, concurrency, and path safety | Concurrent collision is rejected | test/features/pdf/document_transaction_test.dart | test_concurrent_collision_is_rejected | 🟢 green |
| specs/document-artifact-actions/spec.md → Routed artifact actions | User previews and saves an artifact | test/features/pdf/document_actions_test.dart | test_user_previews_and_saves_artifact | 🟢 green |
| specs/document-artifact-actions/spec.md → Routed artifact actions | Viewer reports unsupported print | test/features/pdf/document_actions_test.dart | test_viewer_reports_unsupported_print | 🟢 green |
| specs/document-artifact-actions/spec.md → Missing artifact recovery | Missing file offers regeneration | test/features/pdf/document_actions_test.dart | test_missing_file_offers_regeneration | 🟢 green |
| specs/document-artifact-actions/spec.md → Missing artifact recovery | Unsafe path is rejected | test/features/pdf/document_actions_test.dart | test_unsafe_path_is_rejected | 🟢 green |

## Coverage Notes

Renderer tests use immutable snapshots and verify PDF bytes without DB. Transaction tests use temp profile dir and atomic rename with readability check. Viewer tests inject fake `PdfViewerService`.
