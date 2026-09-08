# Design: Complete journal reversals, booking groups, and historical snapshots

## Context

Journal Storno does not require a finalized immutable source and writes a mutable reversal. The journal schema/entity omit gruppe_id even though the requirement needs it, and stored account/tax snapshots are optional rather than resolved from the selected category.

## Goals

Journal history is immutable, linkable, and interpretable without today’s master-data state.

## Non-Goals

Implementing full double-entry balancing beyond the existing project contract.

## Decisions

Put gruppe_id on the journal row and entity, make source/reversal flags explicit, and resolve snapshots inside the transaction before insertion.

## Risks / Trade-offs

Changing Storno mutability conflicts with an existing test expectation; update the contract and dependent tests together.

## Migration Plan

Migrate the journal column/entity, add failing Storno and snapshot round-trip tests, then enforce transaction checks.

## Open Questions

Should booking groups be generated per source document, per user action, or per multi-line journal batch?
