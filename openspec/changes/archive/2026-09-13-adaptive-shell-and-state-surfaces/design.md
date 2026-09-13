## Context

The shared shell uses fixed `SizedBox` widths and a persisted sidebar value that loads after the first frame. Dashboard and routed pages use spinner-only loading, generic empty/error copy, and pointer-first controls. The repository already has design tokens, Riverpod, Flutter localization, and Material 3 primitives.

## Goals / Non-Goals

**Goals:**

- Make drawer, rail, and expanded layouts stable at documented width boundaries.
- Animate geometry without losing route or focus and honor reduced motion.
- Replace spinner-only states with content-shaped previews and actionable recovery.
- Make visible copy localized and interactive controls keyboard/semantics complete.

**Non-Goals:**

- Rewriting domain calculations or replacing the existing state-management stack.
- Adding a third-party skeleton or navigation package.
- Changing `AGENTS.md` or the persisted settings schema unless compatibility requires a migration.

## Decisions

- Use `LayoutBuilder`/`MediaQuery` for available-width branches: drawer `<900`, rail `900–1199`, expanded `≥1200`.
- Use fixed centered rail slots and tokenized `AnimatedContainer`/`AnimatedSize` transitions. The maximum transition duration is 250 ms. `MediaQuery.disableAnimations == true` or the persisted reduced-motion preference bypasses motion; either signal wins. Tests inject both signals and use a zero-duration test clock.
- Hydrate sidebar preference during bootstrap and pass an explicit drawer-close callback to navigation.
- Use keyed structural skeleton widgets and `AnimatedSwitcher` for state transitions; keep final dimensions stable.
- Use generated ARB accessors, `FocusTraversalGroup`, `FocusableActionDetector`, and `Semantics` for labels, focus, and keyboard activation.
- Inject a clock/preferences adapter in tests so first-frame hydration, reduced motion, and failed reads/writes are deterministic. A failed preference write leaves the last rendered state active, reports a localized retry action, and never resets navigation.
- Use `AsyncValue`-style state adapters for mutations. A failed mutation restores the last confirmed view model, invalidates the failed optimistic item, and exposes a retry that repeats the original command with the same input.
- Test seams are explicit: `FakeShellPreferences`, `FakeAnimationPolicy`, `FakeAsyncStateAdapter`, and `TestClock` live with focused widget tests. Each scenario has a named test in `test/features/shell/`, `test/features/state_surfaces/`, or `test/features/localized_accessible_surface/`; `fvm flutter test` and `fvm flutter gen-l10n` are release gates.

Alternatives rejected: a global shimmer overlay (does not preserve per-page structure), a new navigation framework (duplicates Flutter routing), and relying on `InkWell` alone (does not define semantic keyboard behavior).

## Risks / Trade-offs

- [Animation causes test flakiness] → Assert settled geometry and reduced-motion behavior; use the 250 ms maximum and injected zero-duration policy.
- [Skeletons duplicate page markup] → Keep skeletons as small reusable primitives with stable keys.
- [ARB changes create churn] → Add keys by capability and regenerate localization once per slice.

## Migration Plan

1. Add shell geometry, hydration, and focus tests in red state.
2. Introduce rail/drawer primitives while retaining current routes and persisted keys.
3. Replace spinner branches with skeleton/state components page by page.
4. Move visible literals into ARB and regenerate output.
5. Run focused widget tests, full FVM analyzer/tests, and strict OpenSpec validation.
6. Roll back by disabling animated/state components while retaining preferences and routes.

## Resolved Scope

- “Material-free” means no new dependency or navigation package; existing Material 3 primitives may remain when they meet the semantic and geometry contract.
- Reduced motion is controlled by either `MediaQuery.disableAnimations` or the persisted app preference, with either signal disabling transitions.
