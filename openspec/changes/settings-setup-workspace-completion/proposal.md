## Why

Feature 08 describes setup, profile management, backups, integrations, and configuration, but the production `/settings` route exposes only locale, theme, privacy masking, and profile create/select. The setup route also presents placeholder category names and omits fields required by the maintained setup contract. This change makes those existing contracts discoverable and usable without importing stale implementation details from the feature-map document.

## What Changes

- Add a localized, keyboard-accessible Settings workspace with the constrained content width and section navigation described in `DESIGN.md` §19; controls and links must resolve to implemented domain actions and report real outcomes.
- Expose profile management in Settings using the existing `ProfileManager` and profile contracts: create, rename, select, and the specified non-destructive unregister action. Switching continues to require an explicit restart; removing a profile from the registry must not erase its database or files.
- Surface profile-local backup and restore with destination validation, operation history, and clear failure states. Default scheduled backups to manual-only; opt-in daily/weekly backups run after database readiness. Stage restore while the app is live, block writes after confirmation, then apply only after restart and before opening the database.
- Complete setup company/account fields, persist the bank-account holder, and keep the canonical order Stammdaten → Konten → Kategorien → Abschluss. Use category choices only when their catalog version is verified against the maintained accounting seed contract; otherwise show category setup as deferred and incomplete instead of presenting the current synthetic rows as valid bookkeeping categories.
- Route startup profile discovery, recovery, Settings, and profile switching through the validated registered catalog. Preserve unregistered directories and databases without listing or loading them.
- Use the existing SMTP secret store and repository boundary for any surfaced mail configuration; a connection result must describe exactly what was tested. Do not claim SMTP authentication, certificate pinning, or message delivery unless that operation actually occurs.
- Do not add whole-profile/data erasure, configurable retention, generic feature toggles, CSV import, or printer/export behavior without an authoritative OpenSpec contract and the required data-retention decision.

## Capabilities

### New Capabilities

- `settings-workspace`: Defines the Settings navigation and its accessible, truthful presentation of supported settings and management actions.

### Modified Capabilities

- `localization-settings-and-data-protection`: Replace stale evidence and specify reachable, persisted settings, backup, and integration outcomes while keeping erasure policy explicit.
- `backup`: Reconcile the platform-base-path wording with the profile-local backup path already required by the same capability and `profiles`.
- `profiles`: Make the profile catalog/removal behavior coherent and non-destructive, and resolve the conflicting new-profile activation scenario.
- `setup`: Clarify that the existing four steps present real contract-backed fields and category records, rather than placeholders.
- `setup-onboarding-integrity`: Make deferred setup choices discoverable through Settings and preserve non-deceptive first-run state.
- `profile-workspace-lifecycle`: Reconcile profile selection behavior with the established `profiles` and `setup` restart contract.

## Impact

Settings and setup routes, profile catalog services, a nullable `konten.inhaber` migration, category-catalog provenance, backup scheduling and pre-open restore composition, SMTP configuration/status presentation, localization, and the related Flutter providers/repositories. Company, account, tax-rate, and number-range forms must reuse `master-data-workspaces-and-crud`; tax/report/export links must reuse `accounting-reporting-workspaces` (which itself depends on `balanced-journal-postings-and-settlement-events`). The seed catalog must satisfy the existing `seed-master-data-contract` before categories are presented as configured. This change does not implement either workspace or another EKS/report calculator.

The feature-map document says setup step 3 is number ranges, describes global backup/profile paths and `smbprotocol`, and advertises printer/export, feature-toggle, and import contracts. The maintained setup specification instead assigns step 3 to categories; the app is Flutter/Drift and profile-local; no current OpenSpec capability defines those latter controls. Those document claims are constraints to reconcile in a later documentation pass, not requirements to copy into this change. Whole-data erasure and retention duration remain unresolved; no UI or implementation may permanently erase accounting data until an approved policy and its accounting/legal boundary exist. Profile unregister remains non-destructive as already specified.
