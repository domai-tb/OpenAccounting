## 1. accounting: GoBD Export

- [ ] 1.1 Write failing test `test_gobd_zip_generation` in `test/features/accounting/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "GoBD ZIP generation"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "GoBD ZIP generation" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_gobd_integrity_verification` in `test/features/accounting/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "GoBD integrity verification"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "GoBD integrity verification" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_gobd_export_with_missing_documents` in `test/features/accounting/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "GoBD export with missing documents"; assert it fails for the right reason.
- [ ] 1.8 Implement the specified behavior for "GoBD export with missing documents" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.10 Write failing test `test_gobd_verification_detects_a_changed_file` in `test/features/accounting/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "GoBD verification detects a changed file"; assert it fails for the right reason.
- [ ] 1.11 Implement the specified behavior for "GoBD verification detects a changed file" to pass 1.10.
- [ ] 1.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.13 Write failing test `test_gobd_verification_rejects_unsafe_or_oversized_zip_content` in `test/features/accounting/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "GoBD verification rejects unsafe or oversized ZIP content"; assert it fails for the right reason.
- [ ] 1.14 Implement the specified behavior for "GoBD verification rejects unsafe or oversized ZIP content" to pass 1.13.
- [ ] 1.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.16 Write failing test `test_gobd_verification_rejects_manifest_mismatch_and_streamed_size_overflow` in `test/features/accounting/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "GoBD verification rejects manifest mismatch and streamed-size overflow"; assert it fails for the right reason.
- [ ] 1.17 Implement the specified behavior for "GoBD verification rejects manifest mismatch and streamed-size overflow" to pass 1.16.
- [ ] 1.18 Refactor the affected code; keep the focused and full suites green.

## 2. desktop-drag-drop: Drag-and-Drop File Import

- [ ] 2.1 Write failing test `test_drag_pdf_to_belege` in `test/features/desktop_drag_drop/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Drag PDF to Belege"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Drag PDF to Belege" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_drag_unsupported_file_type` in `test/features/desktop_drag_drop/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Drag Unsupported File Type"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Drag Unsupported File Type" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.7 Write failing test `test_drag_multiple_supported_files` in `test/features/desktop_drag_drop/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Drag Multiple Supported Files"; assert it fails for the right reason.
- [ ] 2.8 Implement the specified behavior for "Drag Multiple Supported Files" to pass 2.7.
- [ ] 2.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.10 Write failing test `test_drag_file_outside_drop_zone` in `test/features/desktop_drag_drop/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Drag File Outside Drop Zone"; assert it fails for the right reason.
- [ ] 2.11 Implement the specified behavior for "Drag File Outside Drop Zone" to pass 2.10.
- [ ] 2.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.13 Write failing test `test_belege_rejects_generic_csv_and_tiff_imports` in `test/features/desktop_drag_drop/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Belege rejects generic CSV and TIFF imports"; assert it fails for the right reason.
- [ ] 2.14 Implement the specified behavior for "Belege rejects generic CSV and TIFF imports" to pass 2.13.
- [ ] 2.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.16 Write failing test `test_supported_e_invoice_xml_is_validated_before_storage` in `test/features/desktop_drag_drop/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Supported e-invoice XML is validated before storage"; assert it fails for the right reason.
- [ ] 2.17 Implement the specified behavior for "Supported e-invoice XML is validated before storage" to pass 2.16.
- [ ] 2.18 Refactor the affected code; keep the focused and full suites green.

## 3. document-artifact-transaction: Atomic artifact and side-effect transaction

- [ ] 3.1 Write failing test `test_finalized_invoice_commits_artifact_and_effects` in `test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Finalized invoice commits artifact and effects"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Finalized invoice commits artifact and effects" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_writer_failure_rolls_back` in `test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Writer failure rolls back"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Writer failure rolls back" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.7 Write failing test `test_process_crash_before_artifact_rename_is_reconciled` in `test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Process crash before artifact rename is reconciled"; assert it fails for the right reason.
- [ ] 3.8 Implement the specified behavior for "Process crash before artifact rename is reconciled" to pass 3.7.
- [ ] 3.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.10 Write failing test `test_process_crash_after_rename_but_before_database_commit_is_reconciled` in `test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Process crash after rename but before database commit is reconciled"; assert it fails for the right reason.
- [ ] 3.11 Implement the specified behavior for "Process crash after rename but before database commit is reconciled" to pass 3.10.
- [ ] 3.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.13 Write failing test `test_missing_committed_artifact_is_reported` in `test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Missing committed artifact is reported"; assert it fails for the right reason.
- [ ] 3.14 Implement the specified behavior for "Missing committed artifact is reported" to pass 3.13.
- [ ] 3.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.16 Write failing test `test_finalized_correction_has_a_readable_artifact` in `test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Finalized correction has a readable artifact"; assert it fails for the right reason.
- [ ] 3.17 Implement the specified behavior for "Finalized correction has a readable artifact" to pass 3.16.
- [ ] 3.18 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.19 Write failing test `test_finalized_conversion_has_a_readable_artifact` in `test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Finalized conversion has a readable artifact"; assert it fails for the right reason.
- [ ] 3.20 Implement the specified behavior for "Finalized conversion has a readable artifact" to pass 3.19.
- [ ] 3.21 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.22 Write failing test `test_correction_artifact_failure_leaves_no_false_finalization` in `test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Correction artifact failure leaves no false finalization"; assert it fails for the right reason.
- [ ] 3.23 Implement the specified behavior for "Correction artifact failure leaves no false finalization" to pass 3.22.
- [ ] 3.24 Refactor the affected code; keep the focused and full suites green.

## 4. documents: Correction and conversion drafts preserve source context

- [ ] 4.1 Write failing test `test_replacement_draft_retains_source_fields_and_links` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Replacement draft retains source fields and links"; assert it fails for the right reason.
- [ ] 4.2 Implement the specified behavior for "Replacement draft retains source fields and links" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_ineligible_source_creates_no_partial_target` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Ineligible source creates no partial target"; assert it fails for the right reason.
- [ ] 4.5 Implement the specified behavior for "Ineligible source creates no partial target" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.7 Write failing test `test_supported_conversion_preserves_source_context` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Supported conversion preserves source context"; assert it fails for the right reason.
- [ ] 4.8 Implement the specified behavior for "Supported conversion preserves source context" to pass 4.7.
- [ ] 4.9 Refactor the affected code; keep the focused and full suites green.

## 5. documents: Dokumentenpakete

- [ ] 5.1 Write failing test `test_package_groups_documents_and_receipt_evidence` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Package groups documents and receipt evidence"; assert it fails for the right reason.
- [ ] 5.2 Implement the specified behavior for "Package groups documents and receipt evidence" to pass 5.1.
- [ ] 5.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.4 Write failing test `test_package_export_preserves_member_snapshot` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Package export preserves member snapshot"; assert it fails for the right reason.
- [ ] 5.5 Implement the specified behavior for "Package export preserves member snapshot" to pass 5.4.
- [ ] 5.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.7 Write failing test `test_missing_member_cannot_be_added` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Missing member cannot be added"; assert it fails for the right reason.
- [ ] 5.8 Implement the specified behavior for "Missing member cannot be added" to pass 5.7.
- [ ] 5.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.10 Write failing test `test_create_package_from_multiple_documents` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Create package from multiple documents"; assert it fails for the right reason.
- [ ] 5.11 Implement the specified behavior for "Create package from multiple documents" to pass 5.10.
- [ ] 5.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 5.13 Write failing test `test_empty_package_creation_blocked` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Empty package creation blocked"; assert it fails for the right reason.
- [ ] 5.14 Implement the specified behavior for "Empty package creation blocked" to pass 5.13.
- [ ] 5.15 Refactor the affected code; keep the focused and full suites green.

## 6. documents: Belege — Upload and Attach

- [ ] 6.1 Write failing test `test_attach_receipt_to_invoice` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Attach receipt to invoice"; assert it fails for the right reason.
- [ ] 6.2 Implement the specified behavior for "Attach receipt to invoice" to pass 6.1.
- [ ] 6.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.4 Write failing test `test_unsupported_file_type_rejected` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Unsupported file type rejected"; assert it fails for the right reason.
- [ ] 6.5 Implement the specified behavior for "Unsupported file type rejected" to pass 6.4.
- [ ] 6.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.7 Write failing test `test_oversized_or_mislabeled_source_is_rejected` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Oversized or mislabeled source is rejected"; assert it fails for the right reason.
- [ ] 6.8 Implement the specified behavior for "Oversized or mislabeled source is rejected" to pass 6.7.
- [ ] 6.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.10 Write failing test `test_linked_evidence_cannot_be_deleted` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Linked evidence cannot be deleted"; assert it fails for the right reason.
- [ ] 6.11 Implement the specified behavior for "Linked evidence cannot be deleted" to pass 6.10.
- [ ] 6.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.13 Write failing test `test_customer_association_must_be_removed_before_evidence_deletion` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Customer association must be removed before evidence deletion"; assert it fails for the right reason.
- [ ] 6.14 Implement the specified behavior for "Customer association must be removed before evidence deletion" to pass 6.13.
- [ ] 6.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.16 Write failing test `test_unlinked_evidence_can_be_deleted` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Unlinked evidence can be deleted"; assert it fails for the right reason.
- [ ] 6.17 Implement the specified behavior for "Unlinked evidence can be deleted" to pass 6.16.
- [ ] 6.18 Refactor the affected code; keep the focused and full suites green.
- [ ] 6.19 Write failing test `test_scheduled_deletion_date_does_not_silently_purge_evidence` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Scheduled deletion date does not silently purge evidence"; assert it fails for the right reason.
- [ ] 6.20 Implement the specified behavior for "Scheduled deletion date does not silently purge evidence" to pass 6.19.
- [ ] 6.21 Refactor the affected code; keep the focused and full suites green.

## 7. documents: Customer document links preserve shared evidence

- [ ] 7.1 Write failing test `test_remove_customer_association_without_deleting_shared_evidence` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Remove customer association without deleting shared evidence"; assert it fails for the right reason.
- [ ] 7.2 Implement the specified behavior for "Remove customer association without deleting shared evidence" to pass 7.1.
- [ ] 7.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 7.4 Write failing test `test_customer_document_deletion_date_does_not_purge_shared_evidence` in `test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Customer document deletion date does not purge shared evidence"; assert it fails for the right reason.
- [ ] 7.5 Implement the specified behavior for "Customer document deletion date does not purge shared evidence" to pass 7.4.
- [ ] 7.6 Refactor the affected code; keep the focused and full suites green.

## 8. receipts-and-payment-reconciliation: Receipts follow an actionable inbox lifecycle

- [ ] 8.1 Write failing test `test_receipt_is_reviewed_and_linked` in `test/features/receipts_and_payment_reconciliation/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Receipt is reviewed and linked"; assert it fails for the right reason.
- [ ] 8.2 Implement the specified behavior for "Receipt is reviewed and linked" to pass 8.1.
- [ ] 8.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.4 Write failing test `test_reviewed_receipt_is_posted_only_after_explicit_confirmation` in `test/features/receipts_and_payment_reconciliation/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Reviewed receipt is posted only after explicit confirmation"; assert it fails for the right reason.
- [ ] 8.5 Implement the specified behavior for "Reviewed receipt is posted only after explicit confirmation" to pass 8.4.
- [ ] 8.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.7 Write failing test `test_unreadable_receipt_remains_reviewable` in `test/features/receipts_and_payment_reconciliation/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Unreadable receipt remains reviewable"; assert it fails for the right reason.
- [ ] 8.8 Implement the specified behavior for "Unreadable receipt remains reviewable" to pass 8.7.
- [ ] 8.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.10 Write failing test `test_failed_intake_leaves_no_partial_record_or_file` in `test/features/receipts_and_payment_reconciliation/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Failed intake leaves no partial record or file"; assert it fails for the right reason.
- [ ] 8.11 Implement the specified behavior for "Failed intake leaves no partial record or file" to pass 8.10.
- [ ] 8.12 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.13 Write failing test `test_crash_after_final_source_write_leaves_no_orphan_on_recovery` in `test/features/receipts_and_payment_reconciliation/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Crash after final source write leaves no orphan on recovery"; assert it fails for the right reason.
- [ ] 8.14 Implement the specified behavior for "Crash after final source write leaves no orphan on recovery" to pass 8.13.
- [ ] 8.15 Refactor the affected code; keep the focused and full suites green.
- [ ] 8.16 Write failing test `test_source_preview_failure_preserves_the_record` in `test/features/receipts_and_payment_reconciliation/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Source preview failure preserves the record"; assert it fails for the right reason.
- [ ] 8.17 Implement the specified behavior for "Source preview failure preserves the record" to pass 8.16.
- [ ] 8.18 Refactor the affected code; keep the focused and full suites green.

## 9. receipts-and-payment-reconciliation: Receipt recognition is advisory and reviewable

- [ ] 9.1 Write failing test `test_user_accepts_reviewed_recognition_suggestions` in `test/features/receipts_and_payment_reconciliation/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "User accepts reviewed recognition suggestions"; assert it fails for the right reason.
- [ ] 9.2 Implement the specified behavior for "User accepts reviewed recognition suggestions" to pass 9.1.
- [ ] 9.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 9.4 Write failing test `test_recognition_failure_falls_back_to_manual_review` in `test/features/receipts_and_payment_reconciliation/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Recognition failure falls back to manual review"; assert it fails for the right reason.
- [ ] 9.5 Implement the specified behavior for "Recognition failure falls back to manual review" to pass 9.4.
- [ ] 9.6 Refactor the affected code; keep the focused and full suites green.

## 10. stammdaten: Kunden-Belege

- [ ] 10.1 Write failing test `test_customer_document_is_unlinked_without_deleting_evidence` in `test/features/stammdaten/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Customer document is unlinked without deleting evidence"; assert it fails for the right reason.
- [ ] 10.2 Implement the specified behavior for "Customer document is unlinked without deleting evidence" to pass 10.1.
- [ ] 10.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 10.4 Write failing test `test_customer_document_remains_after_its_due_date` in `test/features/stammdaten/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "Customer document remains after its due date"; assert it fails for the right reason.
- [ ] 10.5 Implement the specified behavior for "Customer document remains after its due date" to pass 10.4.
- [ ] 10.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 10.7 Write failing test `test_dsgvo_expiry_warning` in `test/features/stammdaten/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "DSGVO expiry warning"; assert it fails for the right reason.
- [ ] 10.8 Implement the specified behavior for "DSGVO expiry warning" to pass 10.7.
- [ ] 10.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 10.10 Write failing test `test_dsgvo_overdue_flag` in `test/features/stammdaten/document_correction_artifacts_and_receipt_intake_test.dart` for scenario "DSGVO overdue flag"; assert it fails for the right reason.
- [ ] 10.11 Implement the specified behavior for "DSGVO overdue flag" to pass 10.10.
- [ ] 10.12 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
