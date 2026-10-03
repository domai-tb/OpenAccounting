## Why

The product feature map requires optional modules to be individually activatable and says disabling one must preserve its records. `docs/03-kunden-stammdaten.md` and `docs/08-einstellungen.md` describe these controls, but the company schema currently exposes only the profile-manager flag and Settings has no module controls. The current Settings proposal explicitly excludes feature toggles, so this separate contract closes the documented gap without duplicating its workspace work.

## What Changes

- Define a stable, per-business module catalog with explicit availability and enabled state.
- Expose supported module controls in the Settings section navigation described by `DESIGN.md` §19.
- Apply module state consistently to navigation, dashboard widgets, shortcuts, and actions while retaining all existing records.
- Keep unavailable or dependency-blocked modules disabled with a clear reason; do not infer enablement from revenue thresholds or other undocumented rules.

## Capabilities

### New Capabilities

- `feature-modules`: Defines the module catalog, durable state, availability/dependency rules, Settings controls, and non-destructive visibility behavior.

### Modified Capabilities

- None.

## Impact

Settings, application navigation and route guards, dashboard widgets/shortcuts, company-scoped settings persistence, and German/English localization. The existing Settings workspace proposal may host the new section when implemented; this change owns module-state behavior and the section's acceptance contract. No module-specific accounting behavior is introduced.
