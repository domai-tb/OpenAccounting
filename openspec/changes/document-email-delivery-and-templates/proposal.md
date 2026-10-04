## Why

The feature map calls for reusable document message templates and user-initiated sending, and Feature 08 documents SMTP setup. The app has no document mail workflow: its SMTP “test” only opens and closes a socket, and `MahnungenRepository.sendMail()` merely marks a reminder sent without sending a message. Dunning already has an OpenSpec proposal that requires truthful SMTP transport acceptance, but no shared transport capability owns that behavior.

## What Changes

- Add user-confirmed direct SMTP sending in the existing `/invoices/:id` detail route for finalized `Rechnung`, `Angebot`, `Auftrag`, and `Proforma` documents, using their stored PDF artifact and linked customer's primary email as the recipient default.
- Add editable plain-text message templates for those first-release document types with a finite placeholder set, per-send overrides, and validation before sending. Defer `Lieferschein` until it has a persisted generated artifact provider, and defer `Mahnung` until its production route and accepted dunning/artifact contracts are ready.
- Add a shared transport service and per-profile send-attempt history with explicit `accepted`, `rejected`, and `unknown` outcomes. Acceptance means the configured SMTP server accepted the message; it does not mean delivered or read.
- Require authenticated TLS submission with certificate and hostname validation. Replace the ambiguous `smtp_ssl` boolean with an explicit secure transport mode; do not offer a certificate-validation bypass or plaintext fallback.
- Make the connection test negotiate the configured TLS mode and authenticate without sending a message. Store credentials in the Windows Credential Manager, macOS Keychain, or Linux Secret Service through a maintained cross-platform adapter; migrate the current profile-local secret file and do not fall back to plaintext storage.
- Allow attachments only from the selected document's validated generated artifact and explicitly selected existing related-document artifacts. Resolve each typed artifact ID through the registered artifact service, verify ownership and physical profile-root containment, and do not accept arbitrary filesystem paths or escaping symlinks.
- Keep sending manual. A draft, missing artifact, invalid address, missing transport configuration, or unresolved send outcome cannot be reported as sent; retries after an ambiguous outcome require explicit user action. Link each attempt to its stable source-document ID so a reminder attempt cannot create a second reminder.
- Update Feature 01/05/08 documentation to separate template editing, transport acceptance, document sending, and actual delivery status.

## Capabilities

### New Capabilities

- `document-email-delivery`: Defines message templates, reviewed attachments, secure direct SMTP transport, send-attempt outcomes, and user-facing sending behavior.

### Modified Capabilities

- `stammdaten`: Define explicit authenticated TLS submission settings, credential use, and an SMTP test that reports actual protocol/authentication results.

## Impact

The settings and document-detail surfaces, registered application services, SMTP transport and MIME construction, OS credential-vault adapter, profile-local send-attempt persistence, generated localization, and `docs/01-rechnungen.md`, `docs/05-mahnwesen.md`, and `docs/08-einstellungen.md`. Dunning and other document workflows call the shared delivery capability only after their own balance and artifact requirements are met. This proposal does not add automatic sending, an external mail-client handoff, arbitrary file attachments, or a claim that SMTP acceptance proves delivery.
