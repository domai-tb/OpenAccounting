# Design: Make schema evolution authoritative, versioned, and fail-loud

## Context

Schema state is split between versioned migrations and runtime ALTER/table creation. Invoice finalization can create inventarbewegungen dynamically, receivable schema setup is fixture-only, and many migration/ALTER failures are swallowed. Rebuild logic also copies only a limited column set, risking silent data loss.

## Goals

The database has one authoritative evolution path and no silent schema corruption.

## Non-Goals

Changing domain table semantics unrelated to migration safety.

## Decisions

Version all schema changes, treat migration errors as startup-visible failures, and use explicit column inventories/compatibility tests for rebuilds.

## Risks / Trade-offs

Existing profiles may rely on lazy columns; migrations must be ordered before removing fallback helpers.

## Migration Plan

Inventory runtime schema writes, add migrations and legacy fixtures, then remove feature-level ensureSchema/table creation after startup coverage passes.

## Open Questions

Which existing profile versions must be supported for in-place migration, and which require an explicit export/import upgrade?
