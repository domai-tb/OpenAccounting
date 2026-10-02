## Context

`/settings` is registered in `lib/core/router/app_router.dart:163`, but `_SettingsContentState.build` currently renders one flat list with language, theme, privacy masking, profile create/select, and a local-storage note (`app_router.dart:754-865`). It has no Settings section navigation, backup workflow, restore UI, company/tax controls, SMTP form, export surface, rename, or profile removal controls. Theme, locale, and privacy state already have Riverpod-backed persistence; these must be retained rather than reimplemented.

`BackupService` already creates WAL-safe local backups, encrypted external backups, SMB backups, validated atomic restores, and a last-backup marker (`lib/core/db/backup_service.dart:22-203`). It is constructed for migration backup in `lib/core/db/migrations.dart:78`; no Settings provider or user-facing workflow composes it. The backup specification itself has a path conflict: its local-backup and target-boundary requirements use the active profile, while its platform-path requirement names a global sibling directory. Runtime `ProfileManager` and `BackupService` use `<base>/profiles/<name>/backups` (`lib/core/db/profile_manager.dart:9-42`; `backup_service.dart:43-54`).

`ProfileManager` can list, create, rename, and switch profiles. Its `deleteProfile` recursively removes the profile directory (`lib/core/db/profile_manager.dart:144-159`), contrary to the `profiles` contract that profile removal retain the database and directory. The manager scans directories for profile discovery, while `profile.json` stores only an active pointer; the specification also describes a profile entry in that file. Profile switching is specified to require restart in `profiles` and `setup`, but `profile-workspace-lifecycle` currently implies that the application graph switches in the same session. This change reconciles the latter contract to the former.

The setup page has four steps in the canonical order but shows only company name/address, one IBAN/BIC pair, six generated `Kategorien 1..6` labels, and raw category IDs in its final summary (`lib/features/setup/wizard_page.dart:258-395`). The maintained `setup` spec requires company/tax/legal-form and bank-account fields and seeded categories. The setup service and repository already own validation, transactional persistence, and category IDs (`wizard_service.dart:174-215`; `setup_repository.dart:183-199`).

`DESIGN.md` §19 requires a constrained Settings page with section navigation; §§20-22 describe privacy masking, backup status, and truthful integration status. The `docs/08-einstellungen.md` feature map is not a runtime contract: it assigns number ranges to wizard step 3, describes global backup paths and Python/SMB details, and advertises printer/export, feature toggles, and CSV import that have no corresponding maintained OpenSpec capabilities here. Preserve the canonical setup order and do not infer those extra features.

## Goals / Non-Goals

**Goals:**

- Make the documented Settings architecture a reachable, localized, responsive workspace whose controls use existing provider/use-case/repository boundaries.
- Expose supported theme, language/region, privacy, profile, backup, and integration actions with truthful outcome and failure states.
- Complete the current four-step setup presentation against its maintained OpenSpec fields and persisted category records.
- Preserve profile-local backup paths, non-destructive profile removal, and explicit restart behavior.
- Keep unsupported export and erasure claims out of the UI until their contracts are settled.

**Non-Goals:**

- Implement company/account/tax-rate/number-range CRUD already owned by `master-data-workspaces-and-crud`.
- Implement EÜR, EKS, UStVA, DATEV, or another reporting/export calculator owned by `accounting-reporting-workspaces` and its accounting dependencies.
- Add number sequences as setup step 3, general CSV/JSON/ZIP import/export, printer settings, unspecced feature flags, cloud storage, or a bank API integration.
- Permanently erase profile/accounting data or select a retention duration.

## Decisions

1. **Keep `/settings` as the owner of the section index.** Build a full-page Settings workspace with a constrained content width and persistent section navigation following `DESIGN.md` §19. Section selection stays inside `/settings`; actual company, account, number-range, tax, banking, and report actions navigate to the owning production route. Do not create a second set of forms or direct database reads in the settings widgets. Show only supported actions; `Erweitert` and `Über` may be informational, not hosts for invented feature toggles.

2. **Reuse the live preference providers.** Keep `appLocaleProvider`, `themeModeProvider`, and `privacyModeProvider` as the source of truth for existing preferences. Add any supported region/formatting/sidebar values through their existing settings boundary, persist before showing success, and keep the current route and section after updates. Accounting currency remains governed by its current EUR data contract; the Settings UI must not imply arbitrary-currency accounting support.

3. **Compose profile actions through the injected `ProfileManager`.** Keep profile I/O out of widgets. Extend the catalog represented in `profile.json` to store `active` and the registered profile names. For a legacy pointer-only file, populate the names from validated profile directories without moving or deleting files. Registration removal affects only that list; the profile directory, database, uploads, and backups remain on disk, with no automatic purge. Preserve active/last-profile guards. This satisfies the existing non-destructive `profiles` contract while making discovery after removal deterministic. A permanent erase remains a separate unresolved policy decision.

4. **Honor the established profile restart contract.** Selecting a different profile persists the pointer and shows a localized restart-required state. Do not switch the database, invalidate providers, or relabel the current session before restart. The same-profile selection is a no-op. Update the contradictory lifecycle requirement to match `profiles` and `setup`.

5. **Inject backup work against the active profile.** Provide a Riverpod backup-service boundary assembled with the active profile directory, active database path/executor, and the existing maintenance/restore-readiness gates. Keep local backups at `<active-profile>/backups/`; update the outdated platform-path spec to include the profile subdirectory. Expose the existing create and restore operations and add a public read/list result needed by the UI for actual local backup history. Persist scheduling preferences and run scheduled local backups only at the defined startup/due boundary. Report a completed timestamp/path only after the service returns successfully; a failed restore must keep the active database intact.

6. **Keep integration feedback scoped to the operation.** Reuse the company repository's SMTP fields and `SmtpSecretStore`; never send secrets through ordinary preferences or the company database. The current `testSmtp()` performs a TCP or TLS socket connect and closes it (`lib/pages/stammdaten/unternehmen_repository.dart:330-355`); Settings must label that as connectivity only unless it is upgraded to exercise greeting, STARTTLS/authentication, or message delivery. Do not implement the feature-map's TOFU/certificate-pinning policy without a maintained spec. External backup and SMB controls must similarly report validated destination/write outcomes, not saved configuration as success.

7. **Separate supported export from all-data erasure.** Settings may link to a supported export owned by the reporting/accounting specs and must show its actual scope. The generic all-profile export format and legal/accounting erasure policy are not defined. Until those decisions are accepted and specified, show storage location/privacy information, keep permanent erase unavailable, and do not let profile unregister erase files.

8. **Keep domain workspace ownership explicit.** Company, accounts, tax rates, and number ranges route to `master-data-workspaces-and-crud`. Tax/report/export navigation routes to `accounting-reporting-workspaces`, whose calculation source depends on `balanced-journal-postings-and-settlement-events`. This proposal does not reproduce any of those capabilities or its EKS calculations.

9. **Render setup from real domain records.** Keep the four canonical wizard steps and use the setup use case/repository for validation and persistence. Load category choices from seeded category rows and show stored names, not fabricated labels or raw identifiers. Display a review of the actual values that will be committed. Keep step 3 as categories regardless of the old feature-map diagram.

## Risks / Trade-offs

- [The profile catalog migration could hide or reactivate folders if it guessed incorrectly] → Preserve every validated legacy directory when initializing the registered-name list, do not erase data, and report malformed/ambiguous catalogs for explicit recovery.
- [A profile can be unregistered while its files remain on disk] → State that removal is non-destructive and keep automatic cleanup disabled until retention policy is decided.
- [Settings is a large page with many domains] → Keep sections focused, link to owning routes, retain a constrained width, and avoid duplicate forms or raw-table fallbacks.
- [The existing backup service exposes no public history list or schedule preference model] → Add the narrowest typed service result and preference boundary; derive history from validated local backup files and actual operation results.
- [Secrets have weaker cross-platform guarantees than an OS keychain] → Reuse the existing company secret boundary for SMTP and do not persist new SMB/passphrase secrets in preferences or SQLite; complete secret persistence only after its storage mechanism is accepted.
- [The feature map conflicts with the maintained setup and path contracts] → Keep canonical step order and active-profile paths; do not claim the legacy feature-map surfaces were implemented.
- [Settings strings can appear in English and German in the same workspace] → Add all new labels, statuses, and errors to both supported ARB files and preserve keyboard/focus behavior.

## Migration Plan

1. Add the `profile.json` registered-name list compatibly: if absent, safely enumerate current profile directories, persist them without moving/deleting their contents, and retain the existing active pointer. Keep read compatibility for pointer-only files.
2. Register providers/services for Settings, profile catalog actions, and active-profile backup operations without changing database schema or writing settings directly from widgets.
3. Add section navigation and controls; link company/master-data and tax/report actions only through their owning capability providers/routes.
4. Complete setup fields and category loading using existing setup transaction boundaries. Do not alter the canonical four-step ordering.
5. Keep existing preference defaults. New schedule/region/sidebar preferences use explicit defaults and are written only after user changes. Local backup path remains profile-scoped; no global backup migration is required because the runtime path is already profile-local.
6. Rollback is UI/provider removal. Retain the versioned profile catalog and all profile files; a rollback must never purge unregistered directories. Restore remains atomic and restart-gated.

## Open Questions

- Which accounting/legal retention rules govern permanent erasure, and what data classes can ever be erased? Until accepted, there is no permanent erase control and no retention duration or purge job.
- What is the accepted scope and portable format for a complete profile export? GoBD/DATEV exports are not complete profile exports.
- Should SMTP connectivity testing be extended to SMTP greeting/STARTTLS/authentication, and what wording may it use for each verified stage? The current socket-connect operation must be labeled narrowly.
- What cross-platform credential store should retain SMB credentials and external-backup passphrases? The current file-backed SMTP secret has best-effort POSIX permissions, not an OS-keychain guarantee.
- Which region/date/number formatting options are supported while the accounting contract remains EUR-only?
- The profile selection specs are reconciled here to process restart. The separate `profile-workspace-lifecycle` proposal is archived with unchecked tasks; implementation must not mix its previous same-session switch wording with this contract.
