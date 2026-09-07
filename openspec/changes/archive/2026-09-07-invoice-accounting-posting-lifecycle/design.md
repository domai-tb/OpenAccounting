# Design: Complete the accounting side effects of invoice finalization

## Context

Invoice finalization commits the document and inventory but does not create the required journal, receivable, or input-tax postings. A separate Forderungen method exists but is never called, so the document can look finalized while the accounting ledger remains incomplete.

## Goals

A finalized invoice is financially complete, atomic, and safe to retry.

## Non-Goals

Designing the invoice editor UI; those routes depend on this contract but are scoped separately.

## Decisions

Use one transaction boundary around document status, inventory, journal, and receivable effects. Define outgoing/incoming direction from document type and store the original document reference on every posting.

## Risks / Trade-offs

Existing fixtures may encode finalization as only a status change; they must be upgraded to assert ledger side effects.

## Migration Plan

Add schema/link fields and posting services, add failing integration tests, then route the production finalizer through the atomic orchestration.

## Open Questions

Which account mapping should be the default for customer receivables and supplier liabilities when a profile has incomplete chart-of-accounts data?
