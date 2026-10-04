## Test Plan

<!-- Every scenario from specs/ is mapped to a concrete failing test. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/document-email-delivery/spec.md → Per-document-type message templates | Render a document template | test/pages/document_delivery/email_template_test.dart | test_render_a_document_template | 🔴 red |
| specs/document-email-delivery/spec.md → Per-document-type message templates | Supported document types use the production detail route | test/pages/document_delivery/email_template_test.dart | test_supported_document_types_use_the_production_detail_route | 🔴 red |
| specs/document-email-delivery/spec.md → Per-document-type message templates | Deferred document types have no first-release template action | test/pages/document_delivery/email_template_test.dart | test_deferred_document_types_have_no_first_release_template_action | 🔴 red |
| specs/document-email-delivery/spec.md → Per-document-type message templates | Reject unsupported or unavailable placeholder | test/pages/document_delivery/email_template_test.dart | test_reject_unsupported_or_unavailable_placeholder | 🔴 red |
| specs/document-email-delivery/spec.md → Per-document-type message templates | Per-send edit leaves template unchanged | test/pages/document_delivery/email_template_test.dart | test_per_send_edit_leaves_template_unchanged | 🔴 red |
| specs/document-email-delivery/spec.md → Per-document-type message templates | Reject header line breaks | test/pages/document_delivery/email_template_test.dart | test_reject_header_line_breaks | 🔴 red |
| specs/document-email-delivery/spec.md → Review a safe document message before sending | Confirm a reviewed document message | test/pages/document_delivery/email_message_review_test.dart | test_confirm_a_reviewed_document_message | 🔴 red |
| specs/document-email-delivery/spec.md → Review a safe document message before sending | Block draft, invalid recipient, or missing artifact | test/pages/document_delivery/email_message_review_test.dart | test_block_draft_invalid_recipient_or_missing_artifact | 🔴 red |
| specs/document-email-delivery/spec.md → Review a safe document message before sending | Reject arbitrary filesystem attachment | test/pages/document_delivery/email_message_review_test.dart | test_reject_arbitrary_filesystem_attachment | 🔴 red |
| specs/document-email-delivery/spec.md → Review a safe document message before sending | Reject attachment owned by another document | test/pages/document_delivery/email_message_review_test.dart | test_reject_attachment_owned_by_another_document | 🔴 red |
| specs/document-email-delivery/spec.md → Review a safe document message before sending | Reject artifact symlink escaping the profile root | test/pages/document_delivery/email_message_review_test.dart | test_reject_artifact_symlink_escaping_the_profile_root | 🔴 red |
| specs/document-email-delivery/spec.md → Review a safe document message before sending | Reject invalid sender or recipient mailbox headers | test/pages/document_delivery/email_message_review_test.dart | test_reject_invalid_sender_or_recipient_mailbox_headers | 🔴 red |
| specs/document-email-delivery/spec.md → Review a safe document message before sending | Send supported document from its detail route | test/pages/document_delivery/email_message_review_test.dart | test_send_supported_document_from_its_detail_route | 🔴 red |
| specs/document-email-delivery/spec.md → Secure authenticated SMTP transport | Submit only after secure authentication | test/pages/document_delivery/smtp_transport_test.dart | test_submit_only_after_secure_authentication | 🔴 red |
| specs/document-email-delivery/spec.md → Secure authenticated SMTP transport | TLS or authentication failure prevents submission | test/pages/document_delivery/smtp_transport_test.dart | test_tls_or_authentication_failure_prevents_submission | 🔴 red |
| specs/document-email-delivery/spec.md → Secure authenticated SMTP transport | Configured certificate pin does not bypass normal validation | test/pages/document_delivery/smtp_transport_test.dart | test_configured_certificate_pin_does_not_bypass_normal_validation | 🔴 red |
| specs/document-email-delivery/spec.md → Secure authenticated SMTP transport | STARTTLS repeats EHLO before selecting authentication | test/pages/document_delivery/smtp_transport_test.dart | test_starttls_repeats_ehlo_before_selecting_authentication | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | SMTP acceptance is recorded without delivery claim | test/pages/document_delivery/email_attempt_repository_test.dart | test_smtp_acceptance_is_recorded_without_delivery_claim | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | Explicit server rejection is recorded | test/pages/document_delivery/email_attempt_repository_test.dart | test_explicit_server_rejection_is_recorded | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | Unknown attempt does not claim invoice output | test/pages/document_delivery/email_attempt_repository_test.dart | test_unknown_attempt_does_not_claim_invoice_output | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | Lost response after submission is ambiguous | test/pages/document_delivery/email_attempt_repository_test.dart | test_lost_response_after_submission_is_ambiguous | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | No automatic retry follows a temporary failure | test/pages/document_delivery/email_attempt_repository_test.dart | test_no_automatic_retry_follows_a_temporary_failure | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | Incomplete attempt recovers as unknown | test/pages/document_delivery/email_attempt_repository_test.dart | test_incomplete_attempt_recovers_as_unknown | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | Duplicate UI submission does not send twice | test/pages/document_delivery/email_attempt_repository_test.dart | test_duplicate_ui_submission_does_not_send_twice | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | Accepted dunning outcome and owner projection commit atomically | test/pages/document_delivery/email_attempt_repository_test.dart | test_accepted_dunning_outcome_and_owner_projection_commit_atomically | 🔴 red |
| specs/document-email-delivery/spec.md → Record truthful SMTP send outcomes | Crash after SMTP acceptance does not retry or duplicate a reminder | test/pages/document_delivery/email_attempt_repository_test.dart | test_crash_after_smtp_acceptance_does_not_retry_or_duplicate_a_reminder | 🔴 red |
| specs/document-email-delivery/spec.md → Keep email delivery within application and design boundaries | User sends from an accessible document surface | test/pages/rechnungen/invoice_email_actions_widget_test.dart | test_user_sends_from_an_accessible_document_surface | 🔴 red |
| specs/document-email-delivery/spec.md → Keep email delivery within application and design boundaries | Background workflow does not send | test/pages/rechnungen/invoice_email_actions_widget_test.dart | test_background_workflow_does_not_send | 🔴 red |
| specs/document-email-delivery/spec.md → Keep email delivery within application and design boundaries | Deferred document type shows no send control | test/pages/rechnungen/invoice_email_actions_widget_test.dart | test_deferred_document_type_shows_no_send_control | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | SMTP test connection with invalid host | test/pages/stammdaten/smtp_configuration_test.dart | test_smtp_test_connection_with_invalid_host | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | SMTP test connection succeeds | test/pages/stammdaten/smtp_configuration_test.dart | test_smtp_test_connection_succeeds | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | TLS or credential failure is reported without downgrade | test/pages/stammdaten/smtp_configuration_test.dart | test_tls_or_credential_failure_is_reported_without_downgrade | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | Legacy SMTP settings migrate securely | test/pages/stammdaten/smtp_configuration_test.dart | test_legacy_smtp_settings_migrate_securely | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | Legacy secret file migrates only after vault verification | test/pages/stammdaten/smtp_configuration_test.dart | test_legacy_secret_file_migrates_only_after_vault_verification | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | Vault unavailable during migration | test/pages/stammdaten/smtp_configuration_test.dart | test_vault_unavailable_during_migration | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | Legacy password was already cleared | test/pages/stammdaten/smtp_configuration_test.dart | test_legacy_password_was_already_cleared | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | Profile rename preserves the vault credential | test/pages/stammdaten/smtp_configuration_test.dart | test_profile_rename_preserves_the_vault_credential | 🔴 red |

## Coverage Notes

- All 37 specification scenarios have one named test. Every test must first fail for the expected reason before implementation.
- SMTP behavior tests should use a controlled local SMTP server or protocol fake that can simulate implicit TLS, STARTTLS capability changes, AUTH failure, DATA acceptance/rejection, and connection loss without contacting a real mail provider.
- Credential migration tests should inject a fake OS-vault adapter and verify startup ordering before database schema cleanup; platform integration checks remain required on Linux, Windows, and macOS.
- Attachment tests need isolated profile roots, linked artifact fixtures, cross-document artifact IDs, and a symlink that resolves outside the root.
- No tests were run during proposal planning.
