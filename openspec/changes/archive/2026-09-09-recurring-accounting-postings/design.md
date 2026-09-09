# Design: Make recurring invoice and booking-template postings tax-aware

## Context

Recurring invoice generation forces every position to 19 percent and computes gross as net times 1.19, ignoring 7 percent, zero-rate, or mixed-rate templates. Direct recurring bookings write the full gross expense as Vorsteuer, overstating tax claims.

## Goals

Automation preserves the same tax and posting semantics as manual documents.

## Non-Goals

Changing schedule frequency or template UX beyond the tax/posting contract.

## Decisions

Persist tax rate and gross/net basis explicitly on generated rows, reuse the invoice/journal calculators, and key idempotence by template occurrence.

## Risks / Trade-offs

Existing templates lack rate metadata; migration/default policy must be explicit and reviewable.

## Migration Plan

Add mixed-rate and gross-expense failing tests, extend template data, then update generators and reporting fixtures.

## Open Questions

Should legacy templates without a tax rate default to profile tax policy or require manual review?
