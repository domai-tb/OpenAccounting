# Proposal: Complete journal reversals, booking groups, and historical snapshots

## Why

Journal Storno does not require a finalized immutable source and writes a mutable reversal. The journal schema/entity omit gruppe_id even though the requirement needs it, and stored account/tax snapshots are optional rather than resolved from the selected category.

Evidence: lib/features/accounting/journal_repository.dart:224-278 permits non-finalized sources and immutable=0 reversals; journal_entity.dart omits required fields; database.dart:550-583 lacks gruppe_id; accounting/spec.md:21 and :671 require the contract.

## What Changes

- Enforce finalized-source and immutable-reversal rules for Storno.
- Add booking-group linkage and expose it through the domain entity.
- Resolve and persist stable account/tax snapshots at booking time.

## Capabilities

- Complete journal reversals, booking groups, and historical snapshots
- Priority: High
- Dependencies: schema-evolution-safety; seed-master-data-contract.

## Impact

lib/features/accounting/journal_repository.dart, journal_entity.dart, database schema/migrations, and accounting tests.
