# Proposal: Complete contact credit controls and dunning workflows

## Why

Customer CRUD exists but Contacts is a static route. Credit-limit checking reports auditLogged true without persisting an audit record or completing an invoice action, and dunning generation validates input without producing or persisting a letter artifact.

Evidence: Customer CRUD is present at lib/pages/stammdaten/kunden_repository.dart:220-389 but /contacts is static at lib/core/router/app_router.dart:195-216. Credit methods at :391-425 return auditLogged without a persistence path; dunning validation/generation at :427-463 does not create a letter artifact.

## What Changes

- Expose customer/supplier list, detail, CRUD, credit, and invoice-linked operations.
- Persist credit-limit decisions and their audit context.
- Generate, store, and link dunning letters with due/amount/level context.

## Capabilities

- Complete contact credit controls and dunning workflows
- Priority: High
- Dependencies: primary-workspace-exposure; finalized-document-artifact-lifecycle; receivables-ledger-integrity; localization-settings-and-data-protection.

## Impact

lib/pages/stammdaten/kunden_repository.dart, contacts/dunning routes and pages, dunning/PDF storage, credit audit schema, and integration tests.
