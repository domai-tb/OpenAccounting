# Review: OpenInvoices

## Review Metadata
- Review round: 2
- Author: independent reconciliation review
- Date: 2026-08-30

## Attack Surface

### Unstated Assumptions

- OpenInvoices is a brownfield change to OpenAccounting, not a new project.
- Local-first accounting must work without Riverpod, Tauri, a Python sidecar, a webview, a backend, or backend authentication.
- External backup destinations are deliberate user-approved exceptions to profile-local storage.
- The current 38 tables are the base schema; feature migrations need explicit table contracts.

### Missing Edge/Failure Scenarios

- Unsafe profile names, canonical-path escapes, symlink escapes, and local writes outside `APP_DATA_DIR` are rejected.
- External backup targets are validated separately; SMB credentials use OS secret storage and encrypted backups authenticate ciphertext.
- Invalid or unconfigured tax rates are rejected while configured custom rates remain valid.
- Negative §25a margins contribute zero taxable base while their raw margin remains auditable.
- Repeated transactional requests require idempotency keys and cannot duplicate finalization, payment, journal, PDF, or stock effects.

### Scope Creep vs. Proposal

- Removed greenfield/project-recreation assumptions and made Flutter-native desktop behavior authoritative.
- Kept optional integrations, external backups, and updater enablement bounded rather than required for core accounting.

### Cheaper Alternatives Not Considered

- Reuse existing GetIt/AppScope/AppServices and data-source boundaries instead of adding a required state container.
- Keep local backups under active-profile `APP_DATA_DIR` instead of adding a second local storage root.
- Name one inventory movement table instead of leaving a generic log contract.

### Contradictions Between Design and Specs

- Resolved architecture mismatch: design and app spec retain GetIt/AppScope/AppServices and Flutter-native state.
- Resolved platform mismatch: desktop and PDF specs no longer require Tauri, webview, or Python sidecar behavior.
- Resolved path mismatch: profiles, database, and backups use `profiles/<name>` and active-profile `APP_DATA_DIR` consistently.
- Resolved schema mismatch: 38 tables are the base; `inventarbewegungen` is an explicitly named feature addition; setup uses a `Kasse` account in `konten`.
- Resolved tax mismatch: UStVA covers referenced statutory KZ, custom configured rates, and one §25a margin-base formula.
- Resolved template mismatch: `pdf_vorlage` is `standard` or `gruen`, with `standard` fallback.
- Resolved integrity terminology: SHA-256 values are tamper-evident integrity hashes, not digital signatures.
- Resolved mutation safety: retries and optimistic state changes are restricted to idempotent operations or keyed transactional mutations.

### Testability

- Each reconciliation is expressed as a requirement/scenario with observable path, schema, tax, backup, integrity, or idempotency outcomes.
- No application tests were run; this repair changes planning prose/configuration only.

### Security

- Profile names reject traversal and separators; canonical containment and symlink-escape checks protect local writes.
- External backup paths require explicit opt-in and separate validation; SMB credentials are kept in OS secret storage.
- Passphrase-based external backups use authenticated encryption metadata and do not persist plaintext passphrases.
- Unkeyed SHA-256 hashes are not represented as signatures.

## Findings

- 🔴 Critical — Greenfield/Riverpod/Tauri/Python/backend assumptions contradicted OpenAccounting. **Resolved** in proposal, design, app, and desktop artifacts.
- 🔴 Critical — Profile and backup path rules allowed unsafe traversal and conflated local and external destinations. **Resolved** in profiles and backup artifacts.
- 🔴 Critical — Schema count and cash/inventory storage contracts conflicted. **Resolved** in db, setup, stammdaten, and inventory artifacts.
- 🔴 Critical — UStVA KZ coverage, custom rates, and §25a margin semantics were incomplete or inconsistent. **Resolved** in accounting and PDF artifacts.
- 🔴 Critical — `pdf_vorlage` representations conflicted. **Resolved** in stammdaten and PDF artifacts.
- 🔴 Critical — SHA-256 was called a digital signature. **Resolved** in accounting and PDF artifacts.
- 🔴 Critical — Transactional retries lacked idempotency constraints. **Resolved** in app, documents, and accounting artifacts.
- 🟡 Moderate — Updater package/signing details remain implementation-specific and are explicitly deferred until the distribution trust model is documented.

## Applied Changes

- Rebased proposal/design/app decisions on existing OpenAccounting Flutter architecture and made Dio/network access optional.
- Replaced Tauri/webview/Python-sidecar requirements with Flutter-native desktop behavior and deferred updater enablement pending package-signing details.
- Added canonical profile-name/path checks, symlink-escape rejection, active-profile backup containment, and separate external-target rules.
- Reconciled 38-table base schema, `Kasse` account setup, and named `inventarbewegungen` storage.
- Reconciled UStVA KZ coverage, custom tax rates, §25a margin calculation, `pdf_vorlage`, integrity-hash terminology, and idempotent mutations.

## Remaining Non-Blocking Limitations

- Target-platform updater packaging, publisher-key distribution, and SMB implementation details still require an implementation decision.
- Exact tax-form field mappings and legal acceptance require domain review before release.
- Protected task/test-plan mappings still use superseded scenario names and must be remapped before implementing those scenarios.

## Rebuttals

- The existing task and test-plan mappings still contain superseded scenario names because those protected files were out of scope; implementation must remap them before tests are authored.
- This limitation does not restore any runtime requirement removed by this reconciliation.

## Verdict

VERDICT: APPROVE
CHANGES_APPLIED: yes
