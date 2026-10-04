## MODIFIED Requirements

### Requirement: Unternehmen — SMTP-Konfiguration

The Unternehmen record SHALL store SMTP activation, host, port, an explicit secure transport mode (`implicit_tls` or `starttls_required`), username, sender address, and an optional SHA-256 certificate fingerprint. Before database opening, startup SHALL ensure each profile has an immutable profile ID in profile metadata; existing profiles SHALL receive and persist this ID before credential migration. Vault keys SHALL use this ID rather than a mutable name or path. Passwords SHALL be stored through a maintained, profile-scoped platform credential adapter backed by macOS Keychain, Windows Credential Manager/DPAPI, or Linux Secret Service. Passwords MUST NOT be newly written to ordinary database fields or plaintext files; any encrypted adapter storage file MUST be protected by an OS-managed secret key. TLS SHALL use version 1.2 or later and SHALL validate the certificate chain and hostname; an optional fingerprint SHALL add a constraint, never bypass validation. Plaintext transport, `smtp_zertifikat_ignorieren`, and silent fallback/downgrade SHALL NOT be supported. Migration SHALL map legacy `smtp_ssl = true` to `implicit_tls` and `smtp_ssl = false` to `starttls_required`. The vault migration SHALL run before `AppDatabase.ensureOpen()` invokes `UnternehmenRepository._ensureSchema()` cleanup of `smtp_passwort`: write each legacy value, read it back and verify it, then remove the old copy. If the credential adapter is unavailable or verification fails, SMTP SHALL remain disabled and the only existing legacy source SHALL remain in place and readable only by the migration recovery path; the system MUST NOT make a new plaintext copy or clear that source. The migration SHALL preserve access across profile rename by retaining the immutable profile ID. The test-connection operation SHALL perform SMTP greeting and EHLO, the selected TLS negotiation, a second EHLO after successful STARTTLS, and authentication without issuing a message-sending command, and SHALL return a typed result that names the operations actually completed.

#### Scenario: SMTP test connection with invalid host

- **GIVEN** SMTP is configured with `smtp_host = "invalid.local"`
- **WHEN** a user triggers the SMTP test connection
- **THEN** the system returns a typed host-unreachable error within 10 seconds and sends no message

#### Scenario: SMTP test connection succeeds

- **GIVEN** SMTP is configured with a reachable host, supported secure mode, valid TLS certificate and hostname, and valid credentials in the OS vault
- **WHEN** a user triggers the SMTP test connection
- **THEN** the system completes greeting and EHLO, negotiates TLS, repeats EHLO after STARTTLS, authenticates using the post-TLS capabilities, returns a typed success result naming those completed steps, and sends no message

#### Scenario: TLS or credential failure is reported without downgrade

- **GIVEN** the TLS certificate is invalid or the SMTP server rejects authentication
- **WHEN** a user triggers the SMTP test connection
- **THEN** the system returns a typed TLS or authentication failure and makes no plaintext connection or message submission

#### Scenario: Legacy SMTP settings migrate securely

- **GIVEN** a profile contains legacy SMTP fields and a vault that is available
- **WHEN** the SMTP settings migration runs
- **THEN** `smtp_ssl = true` becomes `implicit_tls`, `smtp_ssl = false` becomes `starttls_required`, a legacy password is transferred and read-back verified in the profile-ID-scoped OS vault before schema cleanup can remove its old copy, and the certificate bypass is removed

#### Scenario: Legacy secret file migrates only after vault verification

- **GIVEN** a profile has a legacy `.smtp_secret` and its OS vault is available
- **WHEN** the pre-database SMTP migration runs
- **THEN** the secret is written to and read back from the vault before the legacy file is removed

#### Scenario: Vault unavailable during migration

- **GIVEN** a profile contains a legacy SMTP password and the OS vault is unavailable
- **WHEN** the SMTP settings migration runs
- **THEN** SMTP remains disabled, the only legacy source remains available for a later migration retry, no new plaintext location is written, and the UI requests retry or credential re-entry after vault access becomes available

#### Scenario: Legacy password was already cleared

- **GIVEN** a profile has no password in the database or legacy secret file after a previous migration
- **WHEN** SMTP configuration is opened
- **THEN** SMTP remains unavailable until the user enters a password into the OS vault and the UI does not report an authenticated connection

#### Scenario: Profile rename preserves the vault credential

- **GIVEN** SMTP credentials are stored under an immutable profile ID and the user renames the profile
- **WHEN** the renamed profile opens SMTP settings
- **THEN** the same vault credential is available under the unchanged profile ID without copying it to a name- or path-based key
