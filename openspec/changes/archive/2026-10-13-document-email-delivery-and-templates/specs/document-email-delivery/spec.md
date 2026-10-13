## ADDED Requirements

### Requirement: Per-document-type message templates

The first release SHALL provide editable profile-local plain-text subject and body templates for finalized outgoing `Rechnung`, `Angebot`, `Auftrag`, and `Proforma` documents available through the production `/invoices/:id` route. A registered application service SHALL assemble a typed delivery context from the route document ID, its `RechnungItem`, and the linked customer record, and SHALL require the stored generated PDF artifact. `Lieferschein` SHALL remain unavailable until its owner supplies a persisted generated artifact; `Mahnung` SHALL remain unavailable until its owner supplies an accepted production route, typed eligibility context, artifact contract, and accepted-outcome integration. A finite allowlist SHALL include `{dokumentnummer}`, `{betrag}`, `{faelligkeit}`, and `{firma}`; each placeholder SHALL resolve only from a typed source value. `{betrag}` SHALL use the persisted canonical total and shared currency formatting. A template with an unknown placeholder or a placeholder unavailable for the selected document SHALL produce a field-level error before sending. Subject values MUST reject carriage-return and line-feed characters. The user SHALL be able to override the rendered subject or body for one send without changing the saved template unless they explicitly save the template.

#### Scenario: Render a document template

- **GIVEN** a saved invoice template uses `{dokumentnummer}`, `{betrag}`, and `{firma}` and those source values are present
- **WHEN** the send preview is prepared for that invoice
- **THEN** the subject and body show the invoice number, canonical total, and company name in place of those tokens

#### Scenario: Supported document types use the production detail route

- **GIVEN** a finalized `Rechnung`, `Angebot`, `Auftrag`, or `Proforma` is open at `/invoices/:id` with its typed document context
- **WHEN** the user prepares its type-specific template
- **THEN** the template receives the correct document type, number, linked customer values, canonical total, and only values available for that type

#### Scenario: Deferred document types have no first-release template action

- **GIVEN** a `Lieferschein` has no persisted generated artifact or a `Mahnung` lacks its accepted route/artifact/lifecycle dependencies
- **WHEN** the user opens the document or reminder surface
- **THEN** no send or template action is offered for that deferred type

#### Scenario: Reject unsupported or unavailable placeholder

- **GIVEN** a saved template contains an unknown token or `{faelligkeit}` but the selected document has no due date
- **WHEN** the user prepares the send preview
- **THEN** the system identifies the unresolved token and does not offer the message for sending

#### Scenario: Per-send edit leaves template unchanged

- **GIVEN** a valid saved template is rendered
- **WHEN** the user edits the subject or body for one send and sends without saving the template
- **THEN** the outgoing message uses the override and the stored template remains byte-for-byte unchanged

#### Scenario: Reject header line breaks

- **GIVEN** a saved or per-send subject contains a carriage return or line feed
- **WHEN** the user prepares the send preview
- **THEN** the field is rejected with a localized error and no MIME header is constructed

### Requirement: Review a safe document message before sending

Sending SHALL be available only when the owning feature supplies an eligible outgoing document, a validated generated artifact, and a valid single default recipient address. The user MAY change that one recipient for the current attempt. Sender and recipient SHALL each parse as exactly one mailbox; CR or LF in either address SHALL be rejected before MIME construction. Before connecting to SMTP, the system SHALL show the actual recipient, expanded subject and body, sender address, and selected attachment names. Attachments SHALL be limited to the selected document's generated artifact and explicitly selected existing artifacts linked to that document. The registered artifact resolver SHALL verify that each typed artifact ID belongs to the selected document and that its canonical physical target remains below the active profile root; an escaping symlink SHALL be rejected. Arbitrary filesystem paths SHALL NOT be accepted. The user MUST explicitly confirm the reviewed message before transmission.

#### Scenario: Confirm a reviewed document message

- **GIVEN** a finalized invoice has a valid recipient, generated PDF, and a rendered template
- **WHEN** the user reviews the preview and confirms sending
- **THEN** the transport receives the displayed recipient, subject, body, sender, and selected linked attachments

#### Scenario: Block draft, invalid recipient, or missing artifact

- **GIVEN** the document is a draft, its recipient is invalid, or its required generated artifact is missing
- **WHEN** the user attempts to prepare or confirm a send
- **THEN** the system presents the specific blocking error and makes no SMTP connection

#### Scenario: Reject arbitrary filesystem attachment

- **GIVEN** the user attempts to attach a file path that is not an existing artifact linked to the selected document
- **WHEN** the message is prepared
- **THEN** the attachment is rejected and the preview contains only allowed linked artifacts

#### Scenario: Reject attachment owned by another document

- **GIVEN** the user selects an existing artifact ID that belongs to a different document
- **WHEN** the message is prepared
- **THEN** the artifact is rejected and no bytes from it are read or attached

#### Scenario: Reject artifact symlink escaping the profile root

- **GIVEN** a linked artifact path resolves through a symlink to a file outside the active profile root
- **WHEN** the message is prepared
- **THEN** the artifact resolver rejects it and the preview contains no attachment from that path

#### Scenario: Reject invalid sender or recipient mailbox headers

- **GIVEN** the configured sender or per-send recipient contains CR/LF or parses as more than one mailbox
- **WHEN** the user prepares the message
- **THEN** the invalid field is identified before MIME headers are constructed and no SMTP connection occurs

#### Scenario: Send supported document from its detail route

- **GIVEN** an eligible finalized document of type `Rechnung`, `Angebot`, `Auftrag`, or `Proforma` is open on `/invoices/:id`
- **WHEN** the user reviews and confirms the type-specific message
- **THEN** the registered service receives the typed source document ID and approved artifact references for that exact route record

### Requirement: Secure authenticated SMTP transport

The transport SHALL support explicit implicit-TLS and required-STARTTLS modes with TLS 1.2 or later, normal certificate-chain and hostname validation, and authenticated SMTP submission. It MUST NOT use plaintext, downgrade from required TLS, disable certificate validation, or transmit credentials before TLS and server identity have been verified. An optional configured SHA-256 certificate fingerprint MAY further restrict an otherwise valid certificate and MUST NOT override chain or hostname validation. Credentials SHALL be read from the profile-scoped operating-system credential vault and MUST NOT be written to logs, send history, database fields, or ordinary files. SMTP/MIME protocol handling SHALL use a maintained library rather than a bespoke protocol implementation.

#### Scenario: Submit only after secure authentication

- **GIVEN** SMTP is configured with a supported secure mode, valid certificate, hostname, and credentials
- **WHEN** the user confirms a reviewed message
- **THEN** the transport negotiates the configured TLS mode, authenticates over TLS, and submits the MIME message

#### Scenario: TLS or authentication failure prevents submission

- **GIVEN** certificate validation, hostname validation, TLS negotiation, or SMTP authentication fails
- **WHEN** a send is attempted
- **THEN** no message body is submitted, credentials are not sent before verified TLS, and the failure is recorded without a plaintext retry

#### Scenario: Configured certificate pin does not bypass normal validation

- **GIVEN** a configured certificate fingerprint matches but the presented certificate has an invalid chain or hostname
- **WHEN** the transport connects
- **THEN** the connection is rejected and no credentials or message data are sent

#### Scenario: STARTTLS repeats EHLO before selecting authentication

- **GIVEN** required STARTTLS succeeds and the server advertises authentication mechanisms only after TLS
- **WHEN** the client proceeds to SMTP authentication
- **THEN** the client issues EHLO after TLS and uses only the post-TLS advertised AUTH capabilities

### Requirement: Record truthful SMTP send outcomes

Each user-confirmed send attempt SHALL be durably recorded with a profile-local source-document reference, recipient, timestamp, selected artifact identifiers, and final outcome: `accepted`, `rejected`, or `unknown`. Future dunning attempts SHALL additionally reference the stable `mahnung_id` and idempotency key; first-release Mahnung sending remains unavailable. The record SHALL be created in `submitting` state before network transmission; recovery SHALL convert any abandoned `submitting` attempt to `unknown`. `accepted` SHALL mean only that the SMTP server returned a successful final response accepting the message; it MUST NOT be presented as delivered or read. An explicit SMTP rejection or a transport failure proven to occur before message submission SHALL be `rejected`. A connection or persistence failure after message data may have reached the server SHALL be `unknown`. After a final SMTP success response, persistence of the `accepted` attempt, setting invoice `ausgegeben_am` if it is still null, and any dunning-owned reminder-status/invoice-stage projection SHALL commit in one local database transaction. The dunning projection SHALL be idempotent by stable reminder and attempt identifiers. Rejected and unknown attempts SHALL NOT set invoice output time or mark a reminder sent. A recovered unknown reminder attempt SHALL remain attached to the same reminder; it MUST NOT create another reminder, advance its stage, or be resubmitted automatically. Retrying that same reminder SHALL require an explicit duplicate-risk confirmation. Send history MUST NOT store credentials, full message bodies, or attachment bytes. The system SHALL NOT retry automatically or send a second copy for a duplicate call while an attempt is in progress.

#### Scenario: SMTP acceptance is recorded without delivery claim

- **GIVEN** the SMTP server returns its successful final response after message data
- **WHEN** the attempt completes
- **THEN** history records `accepted`, the UI says “accepted by SMTP server” without marking the message delivered or read, and an invoice's first-output timestamp is set if it was null

#### Scenario: Explicit server rejection is recorded

- **GIVEN** the SMTP server returns a final rejection response
- **WHEN** the attempt completes
- **THEN** history records `rejected` with a safe response category and the invoice or reminder is not marked as sent

#### Scenario: Unknown attempt does not claim invoice output

- **GIVEN** an invoice email attempt has an unknown outcome
- **WHEN** the result is saved
- **THEN** `ausgegeben_am` remains unchanged and the UI reports the attempt as unknown

#### Scenario: Lost response after submission is ambiguous

- **GIVEN** the connection is lost after message data may have reached the server and before a final response is received
- **WHEN** the attempt completes
- **THEN** history records `unknown`, the UI does not claim acceptance or delivery, and any retry requires an explicit duplicate-risk confirmation

#### Scenario: No automatic retry follows a temporary failure

- **GIVEN** a send attempt fails or has an unknown outcome
- **WHEN** the application processes background work
- **THEN** no additional SMTP submission is made without a new user-confirmed attempt

#### Scenario: Incomplete attempt recovers as unknown

- **GIVEN** an attempt was durably recorded as `submitting` and the app exits before recording a final result
- **WHEN** the attempt history is loaded after restart
- **THEN** the attempt is changed to `unknown` and is not resubmitted

#### Scenario: Duplicate UI submission does not send twice

- **GIVEN** a user-confirmed attempt is currently `submitting`
- **WHEN** the user activates send again before that attempt completes
- **THEN** the existing attempt is returned and no second SMTP DATA command is issued

#### Scenario: Accepted dunning outcome and owner projection commit atomically

- **GIVEN** a future dunning send for one stable `mahnung_id` receives the SMTP server's successful final response
- **WHEN** the accepted attempt and owner-state transaction commits
- **THEN** the attempt is `accepted` and the reminder status/invoice stage advance exactly once in the same transaction

#### Scenario: Crash after SMTP acceptance does not retry or duplicate a reminder

- **GIVEN** a future dunning send receives the SMTP success response but the local accepted-outcome transaction does not commit before the app exits
- **WHEN** attempt recovery runs after restart
- **THEN** the same attempt becomes `unknown`, remains linked to the same `mahnung_id`, creates no second reminder or stage advancement, and is not resubmitted without explicit duplicate-risk confirmation

### Requirement: Keep email delivery within application and design boundaries

The UI SHALL call the registered document-delivery application service; widgets MUST NOT issue SQL or construct SMTP clients. Templates, preview, confirmation, errors, and history SHALL use generated English and German localization, visible focus, keyboard navigation, responsive layouts, and non-color-only outcome cues as defined by `DESIGN.md`. The initial send surface SHALL be reachable from the production `/invoices/:id` route for the supported first-release types; deferred `Lieferschein` and `Mahnung` types SHALL expose no send control. Sending SHALL remain a user action and SHALL NOT occur automatically on invoice finalization, dunning-stage creation, or application startup.

#### Scenario: User sends from an accessible document surface

- **GIVEN** an eligible finalized document is open in its production detail route
- **WHEN** the user reviews and confirms the localized send form using keyboard controls
- **THEN** the registered application service receives the confirmed message and the UI exposes its recorded outcome with text and an accessible status

#### Scenario: Background workflow does not send

- **GIVEN** an invoice is finalized or a reminder is created while SMTP is configured
- **WHEN** the lifecycle operation completes without a user send confirmation
- **THEN** no SMTP submission occurs and no email attempt is added to history

#### Scenario: Deferred document type shows no send control

- **GIVEN** the open record is a `Lieferschein` without a persisted generated artifact or a `Mahnung` whose owner prerequisites are not accepted
- **WHEN** the detail surface is displayed
- **THEN** the send control is absent and the UI does not imply that delivery is available
