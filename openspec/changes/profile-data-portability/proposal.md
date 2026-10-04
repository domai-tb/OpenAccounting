## Why

Settings currently has no complete profile export, and its active workspace proposal explicitly leaves the portable profile format unresolved. A DATEV CSV formatter exists without a production UI caller, and SQLite snapshot backup currently serves migrations while its Settings workflow remains proposed. Report, GoBD, and document-package workflows are also not assumed to be available as runtime exports. Users have no reviewed way to obtain one complete, structured copy of the active profile and its profile-local evidence.

## What Changes

- Add a profile-scoped export action under Settings → Daten & Datenschutz that creates a versioned, portable archive from a consistent local snapshot.
- Define one shared inventory of 46 known application tables: 39 pre-existing AppDatabase base tables, the separate shared feature_table_state health table, and six feature-owned tables (forderung_zahlungen, both recurring occurrence tables, both mileage tables, and category_mapping_history). Track migration-required and not-yet-required versions plus lazy marker states; include every supported present table with its relationships and currently persisted profile-local files.
- Define this as profile-owner-controlled portability; it does not provide a subject-scoped disclosure for an individual customer or supplier.
- Exclude secrets and unrelated machine configuration; never describe a report, backup, or partial archive as a complete profile export.
- Keep export read-only and non-destructive. Deletion, anonymization, and retention scheduling remain unavailable until their separate policy is approved.
- Follow DESIGN.md settings, export, accessibility, localization, and narrow-window requirements.

## Capabilities

### New Capabilities

- `profile-data-portability`: Defines complete structured export of one active local profile and truthful handling of unsupported or missing data.

### Modified Capabilities

- `db`: Replace the stale maintained table-count contract with the shared 39-base + marker + 6-feature inventory, including migration-version presence rules, a durable two-row lazy-table marker, pre-repair payment-table health checks, and fail-closed handling of unknown or mismatched tables.
- `receivable-request-fingerprint-and-conditional-writeoff`: Preserve v7-to-v8 payment-table creation while preventing v8+ repair from erasing a missing-table completeness signal.

## Impact

Settings data/privacy section, typed export use case and repository boundary, profile database snapshot/export packaging, profile-local artifact inventory, localized status/history, the maintained DB table inventory shared with mileage and category provenance, and `docs/08-einstellungen.md`. The export does not replace any separately scoped DATEV, backup, report, GoBD, or document-package workflow, and does not claim those workflows are user-available until wired at runtime. It does not erase or modify source records or fulfill a customer-specific disclosure request.
