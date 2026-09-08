# Design: Make reversals and replacement documents financially consistent

## Context

Credit-note persistence forces ust_betrag to zero and sets gross equal to net even when positions carry VAT rates. Replacement duplicate protection checks a field that is not selected, so a second replacement can bypass the intended guard.

## Goals

Corrections reverse financial meaning without losing VAT or auditability.

## Non-Goals

Building the correction editor UI; the route exposure proposal owns reachability.

## Decisions

Calculate correction headers from signed positions in one shared money routine and validate source links before allocating a new number.

## Risks / Trade-offs

Changing existing zero-tax expectations will invalidate current happy-path tests that assert only negative totals; those tests must become accounting assertions.

## Migration Plan

Add failing mixed-rate and duplicate-replacement tests, centralize signed total calculation, then update source/link and posting transactions.

## Open Questions

Should Storno and Gutschrift share the same correction document type and VAT policy for incoming as well as outgoing documents?
