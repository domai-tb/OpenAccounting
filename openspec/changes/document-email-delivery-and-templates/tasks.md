# Implementation Tasks

Complete the cross-change and platform prerequisites before starting the scenario work. These gates are not evidence that the dependent changes or platform integrations already exist.

## 1. Resolve implementation prerequisites

- [ ] 1.1 Update and accept settings-setup-workspace-completion so its SMTP controls consume this shared capability and remove the competing file-backed SmtpSecretStore design.
- [ ] 1.2 Update and accept dunning-workflow-integrity so reminder sending uses the registered transport and atomic idempotent owner-state transaction.
- [ ] 1.3 Select and verify maintained SMTP/MIME and OS-vault adapters on Linux, Windows, and macOS; do not weaken the TLS or secret-storage contract.
- [ ] 1.4 Establish stable profile metadata IDs and startup migration ordering before AppDatabase schema cleanup can clear a legacy credential.

## 2. Unternehmen — SMTP-Konfiguration

- [ ] 2.1 Write failing test: test_smtp_test_connection_with_invalid_host in test/pages/stammdaten/smtp_configuration_test.dart for "SMTP test connection with invalid host" (assert it fails for the right reason).
- [ ] 2.2 Implement the required application behavior for "SMTP test connection with invalid host" from specs/stammdaten/spec.md to pass the named test.
- [ ] 2.3 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 2.4 Write failing test: test_smtp_test_connection_succeeds in test/pages/stammdaten/smtp_configuration_test.dart for "SMTP test connection succeeds" (assert it fails for the right reason).
- [ ] 2.5 Implement the required application behavior for "SMTP test connection succeeds" from specs/stammdaten/spec.md to pass the named test.
- [ ] 2.6 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 2.7 Write failing test: test_tls_or_credential_failure_is_reported_without_downgrade in test/pages/stammdaten/smtp_configuration_test.dart for "TLS or credential failure is reported without downgrade" (assert it fails for the right reason).
- [ ] 2.8 Implement the required application behavior for "TLS or credential failure is reported without downgrade" from specs/stammdaten/spec.md to pass the named test.
- [ ] 2.9 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 2.10 Write failing test: test_legacy_smtp_settings_migrate_securely in test/pages/stammdaten/smtp_configuration_test.dart for "Legacy SMTP settings migrate securely" (assert it fails for the right reason).
- [ ] 2.11 Implement the required application behavior for "Legacy SMTP settings migrate securely" from specs/stammdaten/spec.md to pass the named test.
- [ ] 2.12 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 2.13 Write failing test: test_legacy_secret_file_migrates_only_after_vault_verification in test/pages/stammdaten/smtp_configuration_test.dart for "Legacy secret file migrates only after vault verification" (assert it fails for the right reason).
- [ ] 2.14 Implement the required application behavior for "Legacy secret file migrates only after vault verification" from specs/stammdaten/spec.md to pass the named test.
- [ ] 2.15 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 2.16 Write failing test: test_vault_unavailable_during_migration in test/pages/stammdaten/smtp_configuration_test.dart for "Vault unavailable during migration" (assert it fails for the right reason).
- [ ] 2.17 Implement the required application behavior for "Vault unavailable during migration" from specs/stammdaten/spec.md to pass the named test.
- [ ] 2.18 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 2.19 Write failing test: test_legacy_password_was_already_cleared in test/pages/stammdaten/smtp_configuration_test.dart for "Legacy password was already cleared" (assert it fails for the right reason).
- [ ] 2.20 Implement the required application behavior for "Legacy password was already cleared" from specs/stammdaten/spec.md to pass the named test.
- [ ] 2.21 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 2.22 Write failing test: test_profile_rename_preserves_the_vault_credential in test/pages/stammdaten/smtp_configuration_test.dart for "Profile rename preserves the vault credential" (assert it fails for the right reason).
- [ ] 2.23 Implement the required application behavior for "Profile rename preserves the vault credential" from specs/stammdaten/spec.md to pass the named test.
- [ ] 2.24 Refactor the related implementation; focused tests and the full suite stay green.

## 3. Per-document-type message templates

- [ ] 3.1 Write failing test: test_render_a_document_template in test/pages/document_delivery/email_template_test.dart for "Render a document template" (assert it fails for the right reason).
- [ ] 3.2 Implement the required application behavior for "Render a document template" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 3.3 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 3.4 Write failing test: test_supported_document_types_use_the_production_detail_route in test/pages/document_delivery/email_template_test.dart for "Supported document types use the production detail route" (assert it fails for the right reason).
- [ ] 3.5 Implement the required application behavior for "Supported document types use the production detail route" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 3.6 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 3.7 Write failing test: test_deferred_document_types_have_no_first_release_template_action in test/pages/document_delivery/email_template_test.dart for "Deferred document types have no first-release template action" (assert it fails for the right reason).
- [ ] 3.8 Implement the required application behavior for "Deferred document types have no first-release template action" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 3.9 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 3.10 Write failing test: test_reject_unsupported_or_unavailable_placeholder in test/pages/document_delivery/email_template_test.dart for "Reject unsupported or unavailable placeholder" (assert it fails for the right reason).
- [ ] 3.11 Implement the required application behavior for "Reject unsupported or unavailable placeholder" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 3.12 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 3.13 Write failing test: test_per_send_edit_leaves_template_unchanged in test/pages/document_delivery/email_template_test.dart for "Per-send edit leaves template unchanged" (assert it fails for the right reason).
- [ ] 3.14 Implement the required application behavior for "Per-send edit leaves template unchanged" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 3.15 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 3.16 Write failing test: test_reject_header_line_breaks in test/pages/document_delivery/email_template_test.dart for "Reject header line breaks" (assert it fails for the right reason).
- [ ] 3.17 Implement the required application behavior for "Reject header line breaks" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 3.18 Refactor the related implementation; focused tests and the full suite stay green.

## 4. Review a safe document message before sending

- [ ] 4.1 Write failing test: test_confirm_a_reviewed_document_message in test/pages/document_delivery/email_message_review_test.dart for "Confirm a reviewed document message" (assert it fails for the right reason).
- [ ] 4.2 Implement the required application behavior for "Confirm a reviewed document message" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 4.3 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 4.4 Write failing test: test_block_draft_invalid_recipient_or_missing_artifact in test/pages/document_delivery/email_message_review_test.dart for "Block draft, invalid recipient, or missing artifact" (assert it fails for the right reason).
- [ ] 4.5 Implement the required application behavior for "Block draft, invalid recipient, or missing artifact" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 4.6 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 4.7 Write failing test: test_reject_arbitrary_filesystem_attachment in test/pages/document_delivery/email_message_review_test.dart for "Reject arbitrary filesystem attachment" (assert it fails for the right reason).
- [ ] 4.8 Implement the required application behavior for "Reject arbitrary filesystem attachment" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 4.9 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 4.10 Write failing test: test_reject_attachment_owned_by_another_document in test/pages/document_delivery/email_message_review_test.dart for "Reject attachment owned by another document" (assert it fails for the right reason).
- [ ] 4.11 Implement the required application behavior for "Reject attachment owned by another document" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 4.12 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 4.13 Write failing test: test_reject_artifact_symlink_escaping_the_profile_root in test/pages/document_delivery/email_message_review_test.dart for "Reject artifact symlink escaping the profile root" (assert it fails for the right reason).
- [ ] 4.14 Implement the required application behavior for "Reject artifact symlink escaping the profile root" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 4.15 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 4.16 Write failing test: test_reject_invalid_sender_or_recipient_mailbox_headers in test/pages/document_delivery/email_message_review_test.dart for "Reject invalid sender or recipient mailbox headers" (assert it fails for the right reason).
- [ ] 4.17 Implement the required application behavior for "Reject invalid sender or recipient mailbox headers" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 4.18 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 4.19 Write failing test: test_send_supported_document_from_its_detail_route in test/pages/document_delivery/email_message_review_test.dart for "Send supported document from its detail route" (assert it fails for the right reason).
- [ ] 4.20 Implement the required application behavior for "Send supported document from its detail route" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 4.21 Refactor the related implementation; focused tests and the full suite stay green.

## 5. Secure authenticated SMTP transport

- [ ] 5.1 Write failing test: test_submit_only_after_secure_authentication in test/pages/document_delivery/smtp_transport_test.dart for "Submit only after secure authentication" (assert it fails for the right reason).
- [ ] 5.2 Implement the required application behavior for "Submit only after secure authentication" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 5.3 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 5.4 Write failing test: test_tls_or_authentication_failure_prevents_submission in test/pages/document_delivery/smtp_transport_test.dart for "TLS or authentication failure prevents submission" (assert it fails for the right reason).
- [ ] 5.5 Implement the required application behavior for "TLS or authentication failure prevents submission" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 5.6 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 5.7 Write failing test: test_configured_certificate_pin_does_not_bypass_normal_validation in test/pages/document_delivery/smtp_transport_test.dart for "Configured certificate pin does not bypass normal validation" (assert it fails for the right reason).
- [ ] 5.8 Implement the required application behavior for "Configured certificate pin does not bypass normal validation" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 5.9 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 5.10 Write failing test: test_starttls_repeats_ehlo_before_selecting_authentication in test/pages/document_delivery/smtp_transport_test.dart for "STARTTLS repeats EHLO before selecting authentication" (assert it fails for the right reason).
- [ ] 5.11 Implement the required application behavior for "STARTTLS repeats EHLO before selecting authentication" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 5.12 Refactor the related implementation; focused tests and the full suite stay green.

## 6. Record truthful SMTP send outcomes

- [ ] 6.1 Write failing test: test_smtp_acceptance_is_recorded_without_delivery_claim in test/pages/document_delivery/email_attempt_repository_test.dart for "SMTP acceptance is recorded without delivery claim" (assert it fails for the right reason).
- [ ] 6.2 Implement the required application behavior for "SMTP acceptance is recorded without delivery claim" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.3 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 6.4 Write failing test: test_explicit_server_rejection_is_recorded in test/pages/document_delivery/email_attempt_repository_test.dart for "Explicit server rejection is recorded" (assert it fails for the right reason).
- [ ] 6.5 Implement the required application behavior for "Explicit server rejection is recorded" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.6 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 6.7 Write failing test: test_unknown_attempt_does_not_claim_invoice_output in test/pages/document_delivery/email_attempt_repository_test.dart for "Unknown attempt does not claim invoice output" (assert it fails for the right reason).
- [ ] 6.8 Implement the required application behavior for "Unknown attempt does not claim invoice output" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.9 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 6.10 Write failing test: test_lost_response_after_submission_is_ambiguous in test/pages/document_delivery/email_attempt_repository_test.dart for "Lost response after submission is ambiguous" (assert it fails for the right reason).
- [ ] 6.11 Implement the required application behavior for "Lost response after submission is ambiguous" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.12 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 6.13 Write failing test: test_no_automatic_retry_follows_a_temporary_failure in test/pages/document_delivery/email_attempt_repository_test.dart for "No automatic retry follows a temporary failure" (assert it fails for the right reason).
- [ ] 6.14 Implement the required application behavior for "No automatic retry follows a temporary failure" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.15 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 6.16 Write failing test: test_incomplete_attempt_recovers_as_unknown in test/pages/document_delivery/email_attempt_repository_test.dart for "Incomplete attempt recovers as unknown" (assert it fails for the right reason).
- [ ] 6.17 Implement the required application behavior for "Incomplete attempt recovers as unknown" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.18 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 6.19 Write failing test: test_duplicate_ui_submission_does_not_send_twice in test/pages/document_delivery/email_attempt_repository_test.dart for "Duplicate UI submission does not send twice" (assert it fails for the right reason).
- [ ] 6.20 Implement the required application behavior for "Duplicate UI submission does not send twice" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.21 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 6.22 Write failing test: test_accepted_dunning_outcome_and_owner_projection_commit_atomically in test/pages/document_delivery/email_attempt_repository_test.dart for "Accepted dunning outcome and owner projection commit atomically" (assert it fails for the right reason).
- [ ] 6.23 Implement the required application behavior for "Accepted dunning outcome and owner projection commit atomically" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.24 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 6.25 Write failing test: test_crash_after_smtp_acceptance_does_not_retry_or_duplicate_a_reminder in test/pages/document_delivery/email_attempt_repository_test.dart for "Crash after SMTP acceptance does not retry or duplicate a reminder" (assert it fails for the right reason).
- [ ] 6.26 Implement the required application behavior for "Crash after SMTP acceptance does not retry or duplicate a reminder" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 6.27 Refactor the related implementation; focused tests and the full suite stay green.

## 7. Keep email delivery within application and design boundaries

- [ ] 7.1 Write failing test: test_user_sends_from_an_accessible_document_surface in test/pages/rechnungen/invoice_email_actions_widget_test.dart for "User sends from an accessible document surface" (assert it fails for the right reason).
- [ ] 7.2 Implement the required application behavior for "User sends from an accessible document surface" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 7.3 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 7.4 Write failing test: test_background_workflow_does_not_send in test/pages/rechnungen/invoice_email_actions_widget_test.dart for "Background workflow does not send" (assert it fails for the right reason).
- [ ] 7.5 Implement the required application behavior for "Background workflow does not send" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 7.6 Refactor the related implementation; focused tests and the full suite stay green.
- [ ] 7.7 Write failing test: test_deferred_document_type_shows_no_send_control in test/pages/rechnungen/invoice_email_actions_widget_test.dart for "Deferred document type shows no send control" (assert it fails for the right reason).
- [ ] 7.8 Implement the required application behavior for "Deferred document type shows no send control" from specs/document-email-delivery/spec.md to pass the named test.
- [ ] 7.9 Refactor the related implementation; focused tests and the full suite stay green.
