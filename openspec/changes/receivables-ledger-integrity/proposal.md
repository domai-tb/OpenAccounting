# Proposal: Make receivable statements and Kontokorrent balances mathematically correct

## Why

The Kontokorrent statement adds the remaining receivable and then adds only the latest payment, while opening balances include prior receivables but not prior payments. Partial and full payments can therefore be omitted or double-counted. In addition, Forderungen schema setup is fixture-only and not guaranteed by production database startup.

Evidence: lib/features/einkommen/forderungen_repository.dart:309-360 mixes remaining amount with only latest payment; database.dart:144 omits Forderungen schema; Forderungen tests explicitly call ensureSchema.

## What Changes

- Define one signed-ledger model for invoice, payment, credit-note, and opening-balance entries.
- Include every qualifying payment exactly once and handle partial, full, overpayment, and date-boundary cases.
- Bootstrap the receivables schema through the production database lifecycle rather than test-only setup.

## Capabilities

- Make receivable statements and Kontokorrent balances mathematically correct
- Priority: Critical
- Dependencies: schema-evolution-safety; journal-integrity-and-snapshots.

## Impact

lib/features/einkommen/forderungen_repository.dart, database startup, statement entities, and integration tests; depends on schema, journal, and invoice posting changes.
