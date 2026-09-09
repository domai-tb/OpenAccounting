# Design: Make receivable statements and Kontokorrent balances mathematically correct

## Context

The Kontokorrent statement adds the remaining receivable and then adds only the latest payment, while opening balances include prior receivables but not prior payments. Partial and full payments can therefore be omitted or double-counted. In addition, Forderungen schema setup is fixture-only and not guaranteed by production database startup.

## Goals

Customer statements and dashboard balances agree with the underlying financial events.

## Non-Goals

Changing the legal payment principle or designing the receivable UI.

## Decisions

Represent invoice/correction and payment events as separate signed entries and calculate the balance from the event sum; do not mix a pre-reduced remaining amount with payment rows.

## Risks / Trade-offs

Existing data may have stored only a reduced remaining amount; migration must preserve history or explicitly mark unrecoverable legacy balances.

## Migration Plan

Add a failing partial/full/opening-balance fixture, migrate schema bootstrap into startup, then replace the statement query and add invariant checks.

## Open Questions

How should historical databases with no payment journal linkage be reconciled during migration?
