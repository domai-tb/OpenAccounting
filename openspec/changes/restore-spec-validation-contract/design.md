# Design: Restore the maintained OpenSpec validation contract

## Context

Strict Anvil validation currently rejects 15 of 23 maintained specifications because they lack the required Purpose and Requirements structure. This leaves the repository's planning source of truth non-parseable even though several feature specs are treated as authoritative.

## Goals

A parseable, internally consistent spec baseline that can be used by subsequent implementation changes.

## Non-Goals

Implementing any product behavior; rewriting historical archive records; adding a new validation tool.

## Decisions

Use the configured Anvil schema as the contract. Keep capability-specific changes in active proposals and use mechanical validation for this documentation-only boundary.

## Risks / Trade-offs

Normalizing specs may expose additional inconsistencies; resolving them in one baseline change can create a large review surface.

## Migration Plan

Inventory all main specs, repair structure and duplicates, run strict validation, then use the repaired baseline as the dependency for future changes.

## Open Questions

Are any archived documents intentionally exempt from strict validation? If so, the exemption must be explicit rather than implicit.
