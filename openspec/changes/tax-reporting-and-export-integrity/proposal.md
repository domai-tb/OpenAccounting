# Proposal: Align tax calculations and reporting exports with the accounting contract

## Why

UStVA currently treats every non-special journal row as domestic turnover, omits required Kennzahlen, and uses a reverse-charge formula that conflicts with the documented net/additive semantics. EÜR uses line-number ranges instead of booking direction and lacks disposal/cutover policy. DATEV and GoBD outputs remain in memory or are not user-exportable.

Evidence: lib/features/accounting/ustva_service.dart:104-116 has no expense direction filter; :133-146 omits required keys such as 62/67; lib/features/accounting/euer_service.dart:159 uses line-number ranges; lib/features/accounting/datev_service.dart:18-22 returns strings and :250-262 logs memory_export.csv; accounting/spec.md:275-303 requires files.

## What Changes

- Filter UStVA by booking direction and implement the complete required Kennzahlen and reverse-charge base contract.
- Make EÜR profit, fixed-asset disposal, and cutover behavior explicit and period-correct.
- Produce validated DATEV CSV and GoBD ZIP artifacts through user-selected destinations with export history.

## Capabilities

- Align tax calculations and reporting exports with the accounting contract
- Priority: Critical
- Dependencies: journal-integrity-and-snapshots; seed-master-data-contract; primary-workspace-exposure; finalized-document-artifact-lifecycle.

## Impact

lib/features/accounting/ustva_service.dart, euer_service.dart, datev_service.dart, export/storage adapters, and reporting UI; depends on journal and seed contracts.
