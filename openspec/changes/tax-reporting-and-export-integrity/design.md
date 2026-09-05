# Design: Align tax calculations and reporting exports with the accounting contract

## Context

UStVA currently treats every non-special journal row as domestic turnover, omits required Kennzahlen, and uses a reverse-charge formula that conflicts with the documented net/additive semantics. EÜR uses line-number ranges instead of booking direction and lacks disposal/cutover policy. DATEV and GoBD outputs remain in memory or are not user-exportable.

## Goals

Tax reports and exports can be trusted for accounting review and handoff.

## Non-Goals

Selecting legal filing values beyond the documented project contract; legal interpretation questions remain explicit open questions.

## Decisions

Use booking art/direction as the first classifier, retain an explicit mapping table for required Kennzahlen, adopt the documented net/additive reverse-charge semantics unless a product/legal decision changes it, and make all artifacts profile-local or user-selected.

## Risks / Trade-offs

Tax semantics are high stakes and existing tests encode at least one conflicting formula; implementation must record the chosen contract and update dependent tests together.

## Migration Plan

Correct direction/key/period tests first, then expose report export adapters and UI, and finally add a release fixture with mixed booking types and export re-open checks.

## Open Questions

Which legal reporting period rules and DATEV account mappings should be confirmed by an accountant before implementation?
