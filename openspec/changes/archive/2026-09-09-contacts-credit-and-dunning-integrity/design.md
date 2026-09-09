# Design: Complete contact credit controls and dunning workflows

## Context

Customer CRUD exists but Contacts is a static route. Credit-limit checking reports auditLogged true without persisting an audit record or completing an invoice action, and dunning generation validates input without producing or persisting a letter artifact.

## Goals

Contacts, credit, and dunning support the customer lifecycle with auditable outcomes.

## Non-Goals

Sending email or postal mail automatically; delivery integrations remain explicit settings work.

## Decisions

Persist credit decisions separately from computed checks, reuse the durable document artifact store, and derive dunning eligibility from the receivable ledger.

## Risks / Trade-offs

Credit and dunning actions can affect customer communications; require confirmation and immutable history.

## Migration Plan

Add contacts and dunning integration tests, introduce audit/artifact records, then replace placeholder route and stubs.

## Open Questions

What approval and delivery status model is required before a dunning letter may be marked sent?
