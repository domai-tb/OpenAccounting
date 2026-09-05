# Design: Enforce invoice money and discount invariants

## Context

Invoice discount validation skips total consistency when a line discount exists, persists caller-supplied totals, normalizes negative values with abs, and does not reject invalid discount bounds. Preview and persisted totals can therefore disagree.

## Goals

Invoice arithmetic has one auditable source of truth across preview, draft, finalization, and corrections.

## Non-Goals

Selecting legal rounding rules outside the existing project precision contract.

## Decisions

Centralize calculation and validation, round only at the documented money boundary, and treat invalid input as an error rather than repairing it with abs.

## Risks / Trade-offs

Some existing tests may rely on permissive input; those tests should become explicit negative cases.

## Migration Plan

Add failing discount/negative-value tests, route preview and persistence through one calculator, then remove duplicate arithmetic.

## Open Questions

What exact rounding mode and line/header reconciliation policy should be signed off for mixed-rate invoices?
