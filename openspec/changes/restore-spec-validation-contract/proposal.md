# Proposal: Restore the maintained OpenSpec validation contract

## Why

Strict Anvil validation currently rejects 15 of 23 maintained specifications because they lack the required Purpose and Requirements structure. This leaves the repository's planning source of truth non-parseable even though several feature specs are treated as authoritative.

Evidence: openspec validation reported 15 failures; the invalid files include openspec/specs/accounting/spec.md, setup/spec.md, and profiles/spec.md.

## What Changes

- Normalize every maintained main specification to the configured Anvil structure.
- Reconcile duplicate or conflicting requirements instead of preserving parallel normative text.
- Make strict OpenSpec validation a mechanical acceptance gate for the maintained spec set.

## Capabilities

- Restore the maintained OpenSpec validation contract
- Priority: Medium
- Dependencies: None.

## Impact

Documentation and planning artifacts only; no production runtime behavior is changed by this proposal.
