## Why

The product feature map requires optional modules to be individually activatable and says disabling one must preserve its records. `docs/03-kunden-stammdaten.md` and `docs/08-einstellungen.md` describe these controls, but the company schema currently exposes only the profile-manager flag and Settings has no module controls. The current Settings proposal explicitly excludes feature toggles, so this separate contract closes the documented gap without duplicating its workspace work.

## What Changes

- Define catalog version 1 with exactly three maintained modules: `profile_manager`, `inventory`, and `guv`; record each module's provider, dependency rule, default, and activation policy.
- Persist the per-business module state in versioned `unternehmen.feature_modules_json`, with an additive migration that backfills existing profile, inventory, and GuV flags when present.
- Expose supported module controls in the Settings section navigation described by `DESIGN.md` §19.
- Apply effective module state consistently to navigation, dashboard widgets, shortcuts, and module-owned actions while retaining all existing records and required invoice stock effects.
- Preserve the maintained GuV threshold auto-activation through the catalog; no independent `guv_aktiv` runtime setting remains.

## Capabilities

### New Capabilities

- `feature-modules`: Defines the module catalog, durable state, availability/dependency rules, Settings controls, and non-destructive visibility behavior.

### Modified Capabilities

- `db`: Add the durable company-scoped module-state column and coordinated additive migration.
- `accounting`: Resolve GuV activation through the catalog and retain the maintained threshold auto-activation rule.
- `inventory`: Gate inventory entry points, article stock controls, and dashboard and invoice warnings through the catalog without disabling invoice stock movements.
- `profiles`: Resolve Profile Manager visibility through the catalog while retaining the multiple-profile visibility override.
- `stammdaten`: Make versioned company module state the durable source and define legacy-flag migration.

## Impact

Settings, application navigation and route guards, dashboard widgets/shortcuts, company-scoped settings persistence, an additive schema migration, and German/English localization. The existing Settings workspace proposal may host the new section when implemented; this change owns module-state behavior and the section's acceptance contract. GuV auto-activation remains the existing accounting rule; no other module-specific accounting behavior is introduced.
