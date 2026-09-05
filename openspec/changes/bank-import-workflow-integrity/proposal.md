# Proposal: Expose and harden the bank-import workflow

## Why

The parser/import service is implemented and tested, but Banking is a static route. During persistence, row insert failures are swallowed while import history can still report success; auto-categorized counts are incremented before insertion and no failure diagnostics are recorded.

Evidence: lib/features/bank_import/bank_import_service.dart:209-412 imports data; :336-358 swallows row insert failures and :361-403 records imported counts without failure status; lib/core/router/app_router.dart:184-193 is static; bank-import/spec.md:7, :199, and :205 require review/history behavior.

## What Changes

- Expose Upload → Review → Import and import-history UI through the banking route.
- Make row persistence transactional or explicitly partial with truthful error/status counts.
- Preserve duplicate detection, selected template, source file, and manual-review decisions in the audit trail.

## Capabilities

- Expose and harden the bank-import workflow
- Priority: High
- Dependencies: runtime-composition-and-database-lifecycle; schema-evolution-safety; seed-master-data-contract; primary-workspace-exposure.

## Impact

lib/features/bank_import/bank_import_service.dart, banking route/page, import history schema, error result entities, and parser/import tests.
