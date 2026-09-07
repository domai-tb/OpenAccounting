# Proposal: Make schema evolution authoritative, versioned, and fail-loud

## Why

Schema state is split between versioned migrations and runtime ALTER/table creation. Invoice finalization can create inventarbewegungen dynamically, receivable schema setup is fixture-only, and many migration/ALTER failures are swallowed. Rebuild logic also copies only a limited column set, risking silent data loss.

Evidence: lib/core/db/database.dart:129-197 and :743; lib/pages/rechnungen/rechnungen_datasource.dart:972-982 create tables during a workflow; lib/core/db/migrations.dart:39-50, :182-203, and :268-287 swallow/limit migration changes.

## What Changes

- Move all production table and column creation into versioned migrations.
- Make migration failures and future-version databases explicit startup errors.
- Preserve every supported column and row while rebuilding legacy tables.

## Capabilities

- Make schema evolution authoritative, versioned, and fail-loud
- Priority: High
- Dependencies: restore-spec-validation-contract.

## Impact

lib/core/db/database.dart, migrations.dart, feature ensureSchema helpers, migration fixtures, and startup error handling.
