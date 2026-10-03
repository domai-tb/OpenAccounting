## Why

Feature-map item 72 asks customer information to support data disclosure/export as a privacy workflow. The new `profile-data-portability` capability exports an entire profile for its owner and explicitly does not provide customer-specific disclosure. The current customer detail workflow has no scoped export. Reusing a whole-profile archive for one customer's request would expose unrelated customers' and suppliers' records.

## What Changes

- Add a user-initiated data disclosure export from one customer detail view, limited to that customer and records reached through explicit typed relationships.
- Package a versioned manifest, typed record projections, and profile-local files explicitly linked to the selected customer, including reviewed dynamic occurrence and receivable-payment tables.
- Use versioned per-table field allowlists; omit third-party references and mark any non-empty unclassified field as unsupported and the archive incomplete.
- Follow invoice correction/conversion lineage, recurring-template source-invoice links, and saved delivery-address links while rejecting conflicting customer identities.
- Identify included record types, relationship paths, excluded or ambiguous data, and missing files; never call an incomplete package complete.
- Keep the operation read-only and separate from whole-profile portability, customer deletion, anonymization, or retention controls.
- Follow `DESIGN.md` accessibility, localization, form, status, and responsive workspace requirements.

## Capabilities

### New Capabilities

- `customer-data-disclosure-export`: Defines scoped customer-linked record/evidence export and truthful incomplete/unsupported results.

### Modified Capabilities

- `stammdaten`: Add an export action to the typed customer detail contract.
- `db`: Require a stable relationship inventory and a consistent profile snapshot for the scoped package.

## Impact

The customer detail action, typed customer relationship projection, snapshot/export packaging, and `docs/03-stammdaten.md` privacy coverage. The exporter must include only data reached through approved customer relationships. It makes no claim of legal compliance and does not decide third-party disclosure or retention policy. Whole-profile portability remains owned by `profile-data-portability`.
