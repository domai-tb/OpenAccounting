## Context

Desktop adapters for shortcuts, file associations, drag/drop, PDF viewing, tray behavior, and updating exist in isolation. Production bootstrap does not consistently construct them. Documentation and active desktop specs still contain obsolete React/Tauri/Python assumptions.

## Goals / Non-Goals

**Goals:**

- Register supported Flutter desktop adapters idempotently from production bootstrap.
- Route supported events to the active profile and expose unavailable fallbacks truthfully.
- Make updater availability explicit without claiming installation.
- Align docs and specs with Flutter/Dart/Riverpod/Drift/local-first architecture.

**Non-Goals:**

- Implementing a trusted updater signing policy in this change.
- Adding cloud/backend services or resurrecting Tauri/Python sidecars.
- Changing target-specific native code unless wiring requires it.

## Decisions

- Build a `DesktopCapabilityRegistry` with `register<T>(DesktopCapability<T>)` and `isAvailable<T>()` methods. The registry is constructed during bootstrap and injected into `AppServices`. Registration is idempotent (registering the same capability type twice is a no-op). Each adapter is a `DesktopCapability<T>` wrapping an optional implementation (`supported`) or an `Unavailable(reason)` marker.
- Use target adapters with typed results (`supported`, `unavailable`, `failed`) instead of empty callbacks.
- Keep updater installation unavailable until a separate policy defines trust root, package format, provenance, replay/downgrade protection, rollback, and key rotation.
- Treat project source, current `AGENTS.md`, and current Flutter dependencies as documentation authority; add a mechanical contradiction check for forbidden architecture names in active desktop specs.

Alternatives rejected: silently swallowing unsupported platform calls, implementing updater verification speculatively, and keeping obsolete architecture docs for historical convenience in active guidance.

## Risks / Trade-offs

- [Native adapters differ by target] → Keep platform-specific code behind small interfaces and test unavailable paths.
- [Documentation check can over-match historical text] → Scope the check to active docs/specs and allow an explicit historical marker.
- [Bootstrap wiring changes startup order] → Register after profile resolution and before `runApp`, with idempotent guards.

## Migration Plan

1. Add adapter availability/result tests in red state.
2. Wire supported adapters into bootstrap and route events to active services.
3. Add updater unavailable UI and remove any implied install success.
4. Rewrite stale docs/specs and run contradiction plus strict validation checks.
5. Roll back by disabling individual adapters; local core workflows remain available.

## Open Questions

- Which desktop targets are release-supported?
- Where should support/about/version information live in the shell?
