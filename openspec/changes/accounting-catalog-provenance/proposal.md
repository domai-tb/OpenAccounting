## Why

The archived `seed-master-data-contract` says curated SKR03/SKR04 and EÜR/EKS mappings were delivered, but production still generates 85 categories with formulaic account numbers and EÜR lines in `lib/core/db/seed.dart`. The database and accounting specs describe those values as standard mappings, and EÜR/DATEV consume them. The repository contains no approved, versioned category source from which those mappings can be verified.

## What Changes

- Remove synthetic category mappings from the seed contract and allow default mapped categories only from an approved, versioned catalog manifest.
- Track whether category mappings are source-verified, explicitly user-confirmed, unresolved legacy data, or unmapped. Preserve source and user-edit history without treating manual edits as official mappings.
- Preserve existing category IDs, values, active state, and journal references during upgrades; require explicit review before legacy mappings affect new postings or mapped reports/exports.
- Prevent EÜR and DATEV from silently consuming unresolved category mappings or inventing fallback account numbers; identify user-configured mappings as such in generated output. GuV is outside this change until its report owner has an accepted mapping-provenance contract.
- Correct the category-seed claims in maintained specifications and user documentation.

No SKR account or tax-line values are proposed here. Adding a bundled catalog is gated on approval of its exact source and edition, redistribution rights, and accounting review of the SKR/EÜR/EKS relationships.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `db`: seed categories only from an approved catalog and preserve current profiles safely.
- `accounting`: category mapping provenance and fail-closed report/export behavior.

## Impact

`lib/core/db/seed.dart`, a versioned database migration, category persistence/edit flows, EÜR/DATEV mapping consumers, `openspec/specs/{db,accounting}`, and `docs/02-buchhaltung.md` / `docs/03-kunden-stammdaten.md`. GuV remains outside scope. The bank-template portion of the archived seed proposal is outside this change.
