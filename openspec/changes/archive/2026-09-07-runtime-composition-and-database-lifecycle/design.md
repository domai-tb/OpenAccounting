# Design: Unify runtime composition and database lifecycle

## Context

The documented GetIt/AppScope architecture is not implemented: configureDependencies is a no-op, AppScope and AppServices are absent, setup constructs services inside a route, and dashboard providers can query the unopened default database. The full test suite can remain green while logging LazyDatabase initialization errors.

## Goals

One deterministic runtime graph, no unopened database access, and a composition contract that feature pages can rely on.

## Non-Goals

Implementing the business behavior of every feature route; changing the selected-profile storage format.

## Decisions

Keep the application scope as the only UI-facing dependency boundary. Retain Riverpod only if it is the documented mechanism inside that scope; otherwise remove the unused GetIt shim rather than maintaining two authorities.

## Risks / Trade-offs

A graph-wide refactor touches many providers and tests; staged adapters may be needed while feature pages migrate.

## Migration Plan

Introduce the composition root and readiness test first, migrate dashboard/setup, then migrate each exposed workspace and remove route-local construction.

## Open Questions

Should the project standardize on GetIt plus AppScope as AGENTS.md describes, or formally update the architecture to a scoped Riverpod composition?
