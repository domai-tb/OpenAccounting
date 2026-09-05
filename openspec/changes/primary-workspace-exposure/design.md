# Design: Replace primary-route placeholders with real workspaces

## Context

The router explicitly labels invoices, receipts, banking, contacts, taxes, reports, settings, and help as placeholders. Several corresponding backends exist and are tested, but users cannot reach them; current router tests assert placeholder text instead of behavior.

## Goals

Every primary navigation item is an honest entry point into a real workflow.

## Non-Goals

Completing every domain calculation or fixing backend correctness bugs; those remain separate dependent changes.

## Decisions

Treat reachability as a vertical-slice boundary: each route must prove one real read and one real user action, while deep accounting semantics remain owned by domain changes.

## Risks / Trade-offs

A broad route surface can produce inconsistent UX if built piecemeal; shared page/header/state components should be adopted first.

## Migration Plan

Wire invoices and banking first as vertical slices, then master data and accounting/reporting, and finally settings/help; replace placeholder tests as each slice lands.

## Open Questions

Which primary destination should be the first release slice if implementation capacity cannot cover all advertised routes?
