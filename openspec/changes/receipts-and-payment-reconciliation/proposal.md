# Proposal: Implement receipt inbox, bank reconciliation, and invoice payment application

## Why

The database contains a Belege table but the Receipts route has no repository, ingestion, review state, or linking workflow. Bank import can link transactions to journal rows but not apply payments to invoices/Forderungen, leaving imported money disconnected from receivable balances.

Evidence: The belege table exists at lib/core/db/database.dart:535-548, while /receipts is static at lib/core/router/app_router.dart:173-181. Bank matching persists only journal_id at lib/features/bank_import/bank_import_service.dart:312-353; payment application exists separately at lib/features/einkommen/forderungen_repository.dart:211-259.

## What Changes

- Expose a receipt inbox with file ingestion, review, assignment, and posting states.
- Add bank transaction matching to invoices/receivables with partial/full payment allocation.
- Make reconciliation and payment application atomic, auditable, and reversible.

## Capabilities

- Implement receipt inbox, bank reconciliation, and invoice payment application
- Priority: High
- Dependencies: bank-import-workflow-integrity; receivables-ledger-integrity; primary-workspace-exposure; runtime-composition-and-database-lifecycle.

## Impact

lib/features/bank_import, receipt/document data sources, lib/features/einkommen/forderungen_repository.dart, database schema/migrations, banking/receipts routes, and integration tests.
