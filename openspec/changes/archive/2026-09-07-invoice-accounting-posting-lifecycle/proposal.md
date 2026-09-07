# Proposal: Complete the accounting side effects of invoice finalization

## Why

Invoice finalization commits the document and inventory but does not create the required journal, receivable, or input-tax postings. A separate Forderungen method exists but is never called, so the document can look finalized while the accounting ledger remains incomplete.

Evidence: lib/pages/rechnungen/rechnungen_datasource.dart:381-405 commits without accounting postings; lib/features/einkommen/forderungen_repository.dart:145-166 is separate and not called; openspec/specs/einkommen/spec.md:7 and accounting/spec.md:329 require the side effects.

## What Changes

- Define outgoing and incoming finalization postings, including receivables and input-tax claims.
- Perform document, stock, journal, and receivable side effects atomically.
- Make repeated finalization idempotent and make correction paths use the same posting contract.

## Capabilities

- Complete the accounting side effects of invoice finalization
- Priority: Critical
- Dependencies: schema-evolution-safety; journal-integrity-and-snapshots; receivables-ledger-integrity; invoice-money-invariants.

## Impact

lib/pages/rechnungen/rechnungen_datasource.dart, accounting/einkommen repositories, journal schema, and integration tests; depends on schema, journal, and receivables boundaries.
