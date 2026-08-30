# OpenInvoices planning-artifact reconciliation report

## Files changed

Primary reconciliation commit `64aa2d7b8b1f265002c1cb383c41303e6ecaf6ba` changed:

- `openspec/changes/openinvoices/proposal.md`
- `openspec/changes/openinvoices/design.md`
- `openspec/changes/openinvoices/review.md`
- `openspec/changes/openinvoices/specs/accounting/spec.md`
- `openspec/changes/openinvoices/specs/app/spec.md`
- `openspec/changes/openinvoices/specs/backup/spec.md`
- `openspec/changes/openinvoices/specs/db/spec.md`
- `openspec/changes/openinvoices/specs/desktop/spec.md`
- `openspec/changes/openinvoices/specs/documents/spec.md`
- `openspec/changes/openinvoices/specs/inventory/spec.md`
- `openspec/changes/openinvoices/specs/pdf/spec.md`
- `openspec/changes/openinvoices/specs/profiles/spec.md`
- `openspec/changes/openinvoices/specs/setup/spec.md`
- `openspec/changes/openinvoices/specs/stammdaten/spec.md`

This report is an additional planning artifact requested by the brief. Source code, tests, `tasks.md`, and `test-plan.md` were not modified.

## Decisions applied

1. Treated OpenInvoices as a brownfield extension of OpenAccounting. Retained GetIt, AppScope, AppServices, Page → UseCase → Repository → DataSource, and Flutter-native state. Riverpod, Tauri, Python sidecar, webview runtime behavior, and backend authentication are not required for local-first workflows. Dio is optional behind data-source boundaries.
2. Replaced desktop Tauri/webview/sidecar requirements with Flutter-native platform integrations. Optional updater enablement is deferred until package and signing trust details are documented.
3. Added profile-name validation for traversal/separators, canonical path containment, symlink-escape rejection, and a clear boundary between local profile content and approved external backup targets.
4. Made local backups use `${APP_DATA_DIR}/backups/`. USB, NAS, SMB, and user-selected local folders require explicit opt-in and separate validation. SMB credentials use OS secret storage; passphrase backups use KDF metadata and AES-256-GCM authentication without plaintext passphrase storage.
5. Defined 38 tables as the base schema. Feature migrations may add only named tables; inventory adds `inventarbewegungen` with explicit columns and document references. Setup creates a `Kasse` account in `konten` and records its opening balance through the opening journal mechanism; no `kassenbestand` table is required.
6. Expanded UStVA semantics to cover referenced statutory KZ, including 12, 61, 66, 81, 83, 89, and 93. Configured custom rates are valid; only invalid or unconfigured rates are rejected. Standardized §25a as `marge_25a_brutto = VK_brutto - (EK_netto × menge)` with taxable base `max(marge_25a_brutto, 0)`.
7. Standardized `pdf_vorlage` to `standard` or `gruen`, with unknown-value fallback to `standard`.
8. Reworded unkeyed SHA-256 document/Tagesabschluss values as tamper-evident integrity hashes, not digital signatures.
9. Restricted optimistic/retry behavior to idempotent operations or mutations carrying unique idempotency keys. Finalization, payment, journal, PDF, and stock effects are specified as atomic/deduplicated where retried.
10. Filled `review.md` with independent findings, applied changes, remaining non-blocking limitations, and `VERDICT: APPROVE` only after blocker reconciliation.

## Validation commands and output

- `openspec status --change "openinvoices" --json` — schema `anvil`; change root resolved; 30/120 tasks complete before this prose-only repair.
- Initial `openspec validate --change "openinvoices" --json` — rejected by CLI because `--change` is unsupported. Corrected after checking `openspec validate --help`.
- `openspec validate --changes "openinvoices" --json` — `valid: true`, 1 passed, 0 failed. Two non-blocking warnings remain in pre-existing `stammdaten` requirements (`Artikelgruppen` and `Kategorien — eks_kategorie`) for missing RFC 2119 wording.
- `git diff --check` — no output.
- Custom artifact scan — required terms for `APP_DATA_DIR`, `inventarbewegungen`, KZ 61/66/81/83/89/93, `pdf_vorlage`, integrity hashes, and idempotency keys all present; no integer `pdf_vorlage` contract, singular `profile/` path, or review TODO remains in editable artifacts.
- `git show --format=fuller --stat --name-only 64aa2d7` — commit contains only the 14 OpenInvoices planning artifacts listed above; subject is `docs(openinvoices): reconcile planning artifacts`.
- No Flutter tests, analyzer, or application build ran. Changes are planning prose/configuration only.

## Commit

- Reconciliation commit: `64aa2d7b8b1f265002c1cb383c41303e6ecaf6ba`
- Subject: `docs(openinvoices): reconcile planning artifacts`
- Report commit: created after this report was written; recorded in repository history separately.

## Concerns

- `lib/core/db/database.dart.dsl-backup` was already untracked at baseline and remains untouched.
- `test/db/backup_test.dart` appeared as a new untracked file after the baseline check and primary commit; it remains untouched and unstaged.
- Protected `tasks.md` and `test-plan.md` still contain superseded scenario names (sidecar, webview, `kassenbestand`, and old review headings). They were explicitly out of scope and need remapping before implementation/tests are authored.
- Updater package selection, publisher-key distribution, SMB implementation details, and exact tax-form/legal acceptance remain implementation/domain-review work.
