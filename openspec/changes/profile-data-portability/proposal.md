## Why

Settings currently has no complete profile export, and its active workspace proposal explicitly leaves the portable profile format unresolved. A DATEV CSV formatter exists without a production UI caller, and SQLite snapshot backup currently serves migrations while its Settings workflow remains proposed. Report, GoBD, and document-package workflows are also not assumed to be available as runtime exports. Users have no reviewed way to obtain one complete, structured copy of the active profile and its profile-local evidence.

## What Changes

- Add a profile-scoped export action under Settings → Daten & Datenschutz that creates a versioned, portable archive from a consistent local snapshot.
- Include the fixed inventory of all 39 current profile database tables, their relationships, and the currently persisted profile-local file references with a manifest that identifies scope and missing files.
- Define this as profile-owner-controlled portability; it does not provide a subject-scoped disclosure for an individual customer or supplier.
- Exclude secrets and unrelated machine configuration; never describe a report, backup, or partial archive as a complete profile export.
- Keep export read-only and non-destructive. Deletion, anonymization, and retention scheduling remain unavailable until their separate policy is approved.
- Follow DESIGN.md settings, export, accessibility, localization, and narrow-window requirements.

## Capabilities

### New Capabilities

- `profile-data-portability`: Defines complete structured export of one active local profile and truthful handling of unsupported or missing data.

### Modified Capabilities

- `db`: Reconcile the maintained database table inventory with the 39 names already registered and created by production runtime, while allowing only explicitly specified feature tables as additive schema.

## Impact

Settings data/privacy section, typed export use case and repository boundary, profile database snapshot/export packaging, profile-local artifact inventory, localized status/history, the maintained DB table inventory, and `docs/08-einstellungen.md`. The export does not replace any separately scoped DATEV, backup, report, GoBD, or document-package workflow, and does not claim those workflows are user-available until wired at runtime. It does not erase or modify source records or fulfill a customer-specific disclosure request.
