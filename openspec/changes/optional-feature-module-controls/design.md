## Context

`docs/03-kunden-stammdaten.md:195-210` and `docs/08-einstellungen.md:317-349` describe optional module flags. The attached feature map §74 requires per-module activation and says disabling a module must not delete records. Current production persistence has `profilmanager_aktiv` and adds `lagerfuehrung_aktiv` to the company row; the maintained accounting spec also defines GuV threshold auto-activation. There is no shared module catalog or settings UI, and the active `settings-setup-workspace-completion` proposal excludes generic feature toggles. `DESIGN.md:925-945,1448-1469` defines Settings navigation, localization, keyboard access, focus, and text scaling.

## Goals / Non-Goals

**Goals:**

- Give each recognized optional module a durable, validated enabled state.
- Apply that state consistently to all entry points while preserving records.
- Make unavailable modules and failed setting writes truthful and accessible.

**Non-Goals:**

- Implement the accounting or document behavior of any optional module.
- Add automatic activation rules beyond the maintained GuV threshold rule.
- Delete or migrate business records when a module is disabled.

## Decisions

1. **Use a closed, versioned catalog.** Version 1 contains `profile_manager`, `inventory`, and `guv`. Each entry declares localized labels, owning provider, dependencies, availability rule, default, and automatic activation rule. `profile_manager` requires the profile workspace provider. `inventory` requires the article catalog and invoice stock providers. `guv` requires the accounting journal and GuV calculator providers. Each has no optional-module dependency. A missing provider or dependency makes the module unavailable. Other legacy documentation flags remain outside this catalog until their owning capability contract is accepted.
2. **Persist one canonical company-scoped state.** Add `unternehmen.feature_modules_json`, a versioned JSON object with an `enabled` map keyed by catalog IDs. Fresh profiles default all three preferences to false. Existing profiles backfill `profile_manager` from `profilmanager_aktiv`, `inventory` from `lagerfuehrung_aktiv`, and `guv` from `guv_aktiv` only when the legacy column exists; absent or invalid values default to false. The settings UI reads and writes through the module application service, not SQL. Legacy columns are migration inputs only and are not written after backfill.
3. **Coordinate an additive migration.** On the current schema-version-8 baseline, add the JSON column and backfill in the next sequential schema migration (version 9 if no accepted migration lands first). Merge with any other accepted migration at that version instead of creating a second version bump. Backfill only when the canonical value is absent; preserve a valid existing canonical value and every legacy value. Keep the migration transactional and do not alter module-owned records.
4. **Resolve effective state centrally.** A module is effectively enabled only when its provider and dependencies are available and its saved preference is enabled. The catalog also applies the maintained GuV threshold auto-activation: when the accounting threshold condition is met, it persists `guv=true` through the same canonical state writer and reports the threshold reason. The Profile Manager remains visible whenever more than one profile exists, regardless of its saved preference. Inventory disablement hides inventory navigation, widgets, shortcuts, and inventory-specific mutation controls but does not suppress stock effects required by invoice finalization or storno.
5. **Contribute a focused Settings section.** Place module controls under `Einstellungen → Funktionen` within the constrained Settings workspace. Reuse the design-system controls, de/en ARB localization, visible focus, semantic state labels, and responsive layout. The current Settings proposal may compose this section, but does not own module-state rules.

## Risks / Trade-offs

- [An active or disabled state can drift between navigation and direct actions] → Resolve module state through one catalog-backed service at route, dashboard, and mutation boundaries.
- [Legacy records may become hidden after disabling] → Explain that data is retained and make the re-enable action available from the same section.
- [Some modules depend on unfinished capabilities] → Mark them unavailable until all declared dependencies are available; do not present a nonfunctional toggle.
- [Settings workspace implementation is separately proposal-gated] → Keep this change's capability provider independent and add its section when that workspace is composed.

## Migration Plan

1. Add `feature_modules_json` through the coordinated next sequential schema migration and backfill the three catalog preferences from legacy flags when present.
2. Add the versioned catalog and settings provider; route every module entry point through its effective-state resolver.
3. Apply GuV threshold auto-activation and the Profile Manager multi-profile override through that resolver.
4. Add the focused Settings section and keep disabling non-destructive; rollback disables new controls without changing module-owned records or the saved JSON state.

## Catalog Extension Boundary

Additional flags in legacy documentation are outside catalog version 1. Each requires an accepted owning capability contract before it can be added.
