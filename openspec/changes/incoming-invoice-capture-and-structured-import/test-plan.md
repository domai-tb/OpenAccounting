## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/documents/spec.md → Document Lifecycle — Entwurf | Draft not in EÜR | test/features/documents/incoming_invoice_capture_and_structured_import_test.dart | test_draft_not_in_euer | 🔴 red |
| specs/specs/documents/spec.md → Document Lifecycle — Entwurf | Draft editable | test/features/documents/incoming_invoice_capture_and_structured_import_test.dart | test_draft_editable | 🔴 red |
| specs/specs/documents/spec.md → Document Lifecycle — Entwurf | Incoming invoice supports draft state | test/features/documents/incoming_invoice_capture_and_structured_import_test.dart | test_incoming_invoice_supports_draft_state | 🔴 red |
| specs/specs/documents/spec.md → Document Lifecycle — Entwurf | Lieferschein created without draft state | test/features/documents/incoming_invoice_capture_and_structured_import_test.dart | test_lieferschein_created_without_draft_state | 🔴 red |
| specs/specs/incoming-invoice-capture/spec.md → Manual supplier invoice capture reuses a reviewed Beleg | Save a manually reviewed PDF as an incoming draft | test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart | test_save_a_manually_reviewed_pdf_as_an_incoming_draft | 🔴 red |
| specs/specs/incoming-invoice-capture/spec.md → Manual supplier invoice capture reuses a reviewed Beleg | Missing supplier prevents draft creation | test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart | test_missing_supplier_prevents_draft_creation | 🔴 red |
| specs/specs/incoming-invoice-capture/spec.md → Structured supplier invoice data is reviewed before draft creation | Confirm structured fields into an incoming draft | test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart | test_confirm_structured_fields_into_an_incoming_draft | 🔴 red |
| specs/specs/incoming-invoice-capture/spec.md → Structured supplier invoice data is reviewed before draft creation | Unconfirmed suggestions do not create a draft | test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart | test_unconfirmed_suggestions_do_not_create_a_draft | 🔴 red |
| specs/specs/incoming-invoice-capture/spec.md → Unsupported source data remains reviewable without inferred invoice values | Unreadable structured data falls back to manual entry | test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart | test_unreadable_structured_data_falls_back_to_manual_entry | 🔴 red |
| specs/specs/incoming-invoice-capture/spec.md → Unsupported source data remains reviewable without inferred invoice values | Unrepresentable value is not silently mapped | test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart | test_unrepresentable_value_is_not_silently_mapped | 🔴 red |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
