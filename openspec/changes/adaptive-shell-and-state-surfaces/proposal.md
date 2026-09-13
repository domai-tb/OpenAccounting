## Why

The shell currently jumps between fixed widths, the compact rail is misaligned, and persisted state can flash after launch. Async pages mostly show spinners or generic messages, while visible strings and interactive controls are not consistently localized or keyboard accessible.

## What Changes

- Stabilize drawer, compact rail, and expanded sidebar geometry with reduced-motion-aware transitions.
- Hydrate persisted shell preferences before the first frame and close the drawer after navigation.
- Replace spinner-only loading with content-shaped previews that preserve layout.
- Define useful empty/error/retry states and rollback feedback for asynchronous mutations.
- Localize visible UI and add semantic names, visible focus, and keyboard activation.

## Capabilities

### New Capabilities

- `adaptive-shell-motion`: Width breakpoints, animation, persistence, drawer lifecycle, and compact rail semantics.
- `loading-state-previews`: Stable skeleton previews and state transitions for dashboard and routed async content.
- `localized-accessible-surface`: Locale parity, semantic interaction, focus treatment, and narrow-layout action access.

### Modified Capabilities

No existing capability is modified. These additive capabilities own shell, async-state, and visible-surface behavior; existing `app-shell`, `dashboard`, and `localization-settings-and-data-protection` requirements remain authoritative for domain semantics. Where wording overlaps, this change supplies the concrete presentation contract and must not weaken the existing behavior.

## Impact

- `lib/app/`, `lib/design_system/`, `lib/features/dashboard/`, `lib/core/router/`, and generated localization ARB files.
- Widget and integration tests for breakpoints, skeletons, semantics, locale formatting, and mutation rollback. Tests use injected preference/bootstrap, animation, and clock seams under `test/features/shell/`, `test/features/state_surfaces/`, and `test/features/localized_accessible_surface/`.
- No new dependency; use Flutter layout, animation, semantics, and localization primitives already in the project.
