## Context

`docs/03-kunden-stammdaten.md:195-210` and `docs/08-einstellungen.md:317-349` describe optional module flags. The attached feature map §74 requires per-module activation and says disabling a module must not delete records. Current production persistence has `profilmanager_aktiv`, but no shared module catalog or settings UI; the active `settings-setup-workspace-completion` proposal excludes generic feature toggles. `DESIGN.md:925-945,1448-1469` defines Settings navigation, localization, keyboard access, focus, and text scaling.

## Goals / Non-Goals

**Goals:**

- Give each recognized optional module a durable, validated enabled state.
- Apply that state consistently to all entry points while preserving records.
- Make unavailable modules and failed setting writes truthful and accessible.

**Non-Goals:**

- Implement the accounting or document behavior of any optional module.
- Infer tax thresholds, automatic activation, or feature defaults from stale examples in `docs/08-einstellungen.md`.
- Delete or migrate business records when a module is disabled.

## Decisions

1. **Use a catalog as the sole availability source.** A stable module identifier resolves to its user-facing label, availability, default for a new profile, and dependencies. Only registered modules can be enabled. An unavailable module is not advertised as active just because a legacy flag exists.
2. **Persist profile-scoped state through the existing settings boundary.** The settings UI reads and writes through an application service/provider, never directly through SQL. The persistence implementation can reuse the current company-settings store after the owning master-data contract is resolved; it must not add a parallel flag source.
3. **Make disabling non-destructive.** The state controls discoverability and write entry points. It does not delete records or files. Existing records remain intact so re-enabling restores access. A stale deep link is stopped at the route boundary and receives a localized unavailable page.
4. **Do not invent automatic activation.** The old document's revenue thresholds have no current maintained contract. Defaults and dependency graph must be explicit in the catalog; enablement changes only through a declared default migration or user action.
5. **Contribute a focused Settings section.** Place module controls under `Einstellungen → Funktionen` within the constrained Settings workspace. Reuse the design-system controls, de/en ARB localization, visible focus, semantic state labels, and responsive layout. The current Settings proposal may compose this section, but does not own module-state rules.

## Risks / Trade-offs

- [An active or disabled state can drift between navigation and direct actions] → Resolve module state through one catalog-backed service at route, dashboard, and mutation boundaries.
- [Legacy records may become hidden after disabling] → Explain that data is retained and make the re-enable action available from the same section.
- [Some modules depend on unfinished capabilities] → Mark them unavailable until all declared dependencies are available; do not present a nonfunctional toggle.
- [Settings workspace implementation is separately proposal-gated] → Keep this change's capability provider independent and add its section when that workspace is composed.

## Migration Plan

1. Add the module catalog and a settings provider with safe defaults for known profile versions.
2. Read the existing `profilmanager_aktiv` value only as a legacy input for the profile module; never create a second conflicting setting.
3. Gate all registered module entry points and add the focused Settings section.
4. Verify disabling preserves profile database and files; rollback disables new controls without changing module-owned records.

## Open Questions

- Which currently unavailable modules should appear in the catalog, and what dependencies make each one available?
- What explicit default should each module use when upgrading an existing profile with no saved state?
- Which persistence owner should eventually hold all module flags after the master-data workspace is approved?
