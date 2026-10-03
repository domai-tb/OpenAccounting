## Why

The banking page lets users edit categories before import, but it does not show the confidence score or candidate journal match promised by `docs/04-bank-import.md`. The scorer runs only while importing, and the active categorization rules have no user-facing management surface.

## What Changes

- Show each row's score and best journal candidate in Review using the existing `bank-import` scoring contract; manual-mode suggestions remain non-mutating.
- Expose the profile's automatic/manual import mode and a one-import override; automatic matching may link to an existing journal entry, but this change creates no journal entry or payment.
- Add a Banking rule-management view for listing, creating, editing, enabling, prioritizing, and deleting the existing category rules.
- Add profile-scoped custom CSV template creation and editing for delimiter, encoding, date format, and required field mappings; keep predefined template identities protected.
- Make import history actionable with detail, failed-row retry under the original import identity, and a filtered view of transactions awaiting review.
- Persist a versioned, validated retry payload containing every field needed to restore a failed reviewed row; treat legacy diagnostics and rejected whole-file attempts as non-retryable.
- Define row review state using the existing `bank_transaktionen.status` values `neu`, `geprueft`, and `gebucht`, and derive unresolved counts from `status = 'neu'`.
- Add the profile mode through ordered migration 9 with a manual default for fresh and existing profiles.
- Put score, rule, custom-template, mode, history, retry, and row-review operations behind the typed application-scope Banking use case and repository.
- Preserve deduplication and partial-failure boundaries; new posting or payment allocation remains governed by the balanced-posting capability.
- Align all of `docs/04-bank-import.md` with maintained OpenSpec and Dart behavior: template/parser claims, no-posting behavior, rule fields/order, 40/30/30 score, dedup hash inputs and schema, ordered mode migration, retry/review semantics, and history query behavior.
- Apply `DESIGN.md` components, responsive behavior, generated localization, keyboard access, and non-color status cues to the added Banking views.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bank-import`: expose match confidence, category rules, persisted mode, and per-import override behavior in the production import workspace.
- `bank-import-recovery-surface`: expose the specified history detail, retry, filtering, pagination, and manual-review actions.

## Impact

The Banking review/rule/template UI, mode setting, import service/history access, migration for the missing profile mode field, and `docs/04-bank-import.md`. Reuse `bank-import-workflow-integrity`, `bank-import`, and `bank-import-recovery-surface` as the import and recovery contracts. A matched transaction may reference an existing journal entry; creating a new posting or applying receipts/payments depends on `balanced-journal-postings-and-settlement-events` and is outside this proposal.
