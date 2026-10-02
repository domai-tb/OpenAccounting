## Why

The banking page lets users edit categories before import, but it does not show the confidence score or candidate journal match promised by `docs/04-bank-import.md`. The scorer runs only while importing, and the active categorization rules have no user-facing management surface.

## What Changes

- Show each row's score and best journal candidate in Review using the existing `bank-import` scoring contract; keep manual-mode suggestions non-mutating.
- Add a Banking rule-management view for listing, creating, editing, enabling, prioritizing, and deleting the existing category rules.
- Preserve the existing import, deduplication, partial-failure, and recovery boundaries. Do not implement posting or payment allocation in this change.
- Align `docs/04-bank-import.md` scoring and rule details with the maintained OpenSpec contract.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bank-import`: expose match confidence and supported category rules in the production import workspace.

## Impact

The Banking review and rule-management UI, its import service/data access, and `docs/04-bank-import.md`. Reuse `bank-import-workflow-integrity`, `bank-import`, and `bank-import-recovery-surface` as the existing import and recovery contracts. Any action that creates postings or applies receipts/payments depends on `balanced-journal-postings-and-settlement-events`; this proposal does not define or perform those accounting effects.
