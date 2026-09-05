## Context

Deferred from openinvoices 120-task monolith; split for <30min agent handling.

## Goals / Non-Goals

**Goals:** implement pdf-template-polish specs
**Non-Goals:** no breaking changes

## Decisions

- VM-safe adapters, fakes for OS deps
- Rejected: monolith single change

## Risks / Trade-offs

- [Split drift] → map via test-plan ledger
- [VM vs OS] → fake + OS harness

## Migration Plan

Additive, no migration

## Open Questions

none
