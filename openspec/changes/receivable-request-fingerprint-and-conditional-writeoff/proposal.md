## Why

`ForderungenRepository.zahlungBuchen` returns the earlier result for a reused idempotency key without comparing the requested amount, target, direction, or date. `ausbuchen` validates state before opening its transaction and updates the row without checking the affected-row count, so retries and concurrent windows can create duplicate loss journals or orphan payment effects. The existing `forderung_zahlungen` table is created lazily by `ensureSchema`; schema version 7 does not own its legacy rows.

## What Changes

- Persist a canonical keyed-payment fingerprint in cents with the Forderung target, derived payment direction, date policy, and effective date.
- Return a typed idempotency conflict for any reused key whose fingerprint differs, with no journal, relation, or balance mutation.
- Resolve keyed-payment races through the existing database transaction and unique key, returning one original effect for identical requests.
- Move write-off state validation into the transaction and require a conditional open-to-`ausgebucht` transition; a zero-row transition returns a typed already-closed conflict and rolls back its journal/relation.
- Make payment and write-off races atomic so exactly one closing effect wins when a full payment competes with a write-off.
- Give current schema version 7 profiles an explicit v8 migration for the lazy relation table and nullable fingerprint columns; preserve rows whose fingerprint cannot be reconstructed as `legacy-unknown`.

## Capabilities

### New Capabilities

- `receivable-request-fingerprint-and-conditional-writeoff`: Safe keyed payment replay and race-safe receivable write-off commands.

### Modified Capabilities

- None. Existing overpayment, credit-item, and Gutschrift policy remains outside this change.

## Impact

The implementation will touch `lib/features/einkommen/forderungen_repository.dart`, its use-case forwarding surface only if typed errors require it, `lib/core/db/migrations.dart`/startup schema ownership, and focused Forderungen/database integration tests. It adds no dependency and does not define bank reconciliation, overpayment allocation, credit-item creation, or Gutschrift behavior.
