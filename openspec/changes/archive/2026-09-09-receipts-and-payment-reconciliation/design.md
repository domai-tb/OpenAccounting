# Design: Implement receipt inbox, bank reconciliation, and invoice payment application

## Context

The database contains a Belege table but the Receipts route has no repository, ingestion, review state, or linking workflow. Bank import can link transactions to journal rows but not apply payments to invoices/Forderungen, leaving imported money disconnected from receivable balances.

## Goals

Imported financial evidence becomes a reviewable, linked, and balance-affecting workflow.

## Non-Goals

Building OCR or bank connectivity beyond the existing import formats.

## Decisions

Keep source artifacts immutable, separate review from confirmed posting, and use an explicit payment-allocation entity rather than overloading journal_id.

## Risks / Trade-offs

Payment allocation affects receivable balances and must coordinate with the ledger integrity proposal; all writes need one transaction.

## Migration Plan

Add receipt/payment schema and red integration tests, connect bank review UI, then wire matching and payment updates.

## Open Questions

Can one bank transaction be split across multiple receivables, and what rounding rule applies?
