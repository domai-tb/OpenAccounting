## Why

Settings currently has no complete profile export, and its active workspace proposal explicitly leaves the portable profile format unresolved. Existing DATEV, report, backup, and document-package exports each have narrower scopes, so users have no reviewed way to obtain one complete, structured copy of the active profile and its evidence.

## What Changes

- Add a profile-scoped export action under Settings → Daten & Datenschutz that creates a versioned, portable archive from a consistent local snapshot.
- Include typed business records, relationships, and profile-local referenced documents/artifacts with a manifest that identifies the export scope and missing files.
- Exclude secrets and unrelated machine configuration; never describe a report, backup, or partial archive as a complete profile export.
- Keep export read-only and non-destructive. Deletion, anonymization, and retention scheduling remain unavailable until their separate policy is approved.
- Follow DESIGN.md settings, export, accessibility, localization, and narrow-window requirements.

## Capabilities

### New Capabilities

- `profile-data-portability`: Defines complete structured export of one active local profile and truthful handling of unsupported or missing data.

### Modified Capabilities

None. Settings may expose the action through the existing Settings capability index after this export contract is accepted.

## Impact

Settings data/privacy section, typed export use case and repository boundary, profile database snapshot/export packaging, profile-local artifact inventory, localized status/history, and `docs/08-einstellungen.md`. The export does not replace GoBD, DATEV, backup, or document-package exports, and does not erase or modify source records.
