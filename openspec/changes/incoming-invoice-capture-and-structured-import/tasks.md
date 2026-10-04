## 1. documents: Document Lifecycle — Entwurf

- [ ] 1.1 Write failing test `test_draft_not_in_euer` in `test/features/documents/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Draft not in EÜR"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Draft not in EÜR" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_draft_editable` in `test/features/documents/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Draft editable"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "Draft editable" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_incoming_invoice_supports_draft_state` in `test/features/documents/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Incoming invoice supports draft state"; assert it fails for the right reason.
- [ ] 1.8 Implement the specified behavior for "Incoming invoice supports draft state" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.10 Write failing test `test_lieferschein_created_without_draft_state` in `test/features/documents/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Lieferschein created without draft state"; assert it fails for the right reason.
- [ ] 1.11 Implement the specified behavior for "Lieferschein created without draft state" to pass 1.10.
- [ ] 1.12 Refactor the affected code; keep the focused and full suites green.

## 2. incoming-invoice-capture: Manual supplier invoice capture reuses a reviewed Beleg

- [ ] 2.1 Write failing test `test_save_a_manually_reviewed_pdf_as_an_incoming_draft` in `test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Save a manually reviewed PDF as an incoming draft"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Save a manually reviewed PDF as an incoming draft" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_missing_supplier_prevents_draft_creation` in `test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Missing supplier prevents draft creation"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Missing supplier prevents draft creation" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.

## 3. incoming-invoice-capture: Structured supplier invoice data is reviewed before draft creation

- [ ] 3.1 Write failing test `test_confirm_structured_fields_into_an_incoming_draft` in `test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Confirm structured fields into an incoming draft"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Confirm structured fields into an incoming draft" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_unconfirmed_suggestions_do_not_create_a_draft` in `test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Unconfirmed suggestions do not create a draft"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Unconfirmed suggestions do not create a draft" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.

## 4. incoming-invoice-capture: Unsupported source data remains reviewable without inferred invoice values

- [ ] 4.1 Write failing test `test_unreadable_structured_data_falls_back_to_manual_entry` in `test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Unreadable structured data falls back to manual entry"; assert it fails for the right reason.
- [ ] 4.2 Implement the specified behavior for "Unreadable structured data falls back to manual entry" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_unrepresentable_value_is_not_silently_mapped` in `test/features/incoming_invoices/incoming_invoice_capture_and_structured_import_test.dart` for scenario "Unrepresentable value is not silently mapped"; assert it fails for the right reason.
- [ ] 4.5 Implement the specified behavior for "Unrepresentable value is not silently mapped" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
