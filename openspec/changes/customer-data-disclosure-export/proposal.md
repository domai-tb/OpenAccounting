## Why

Feature-map item 72 asks customer information to support data disclosure/export as a privacy workflow. The accepted `profile-data-portability` capability covers whole-profile owner export. The current customer detail workflow has no scoped export. Reusing a whole-profile archive for one customer's request would expose unrelated customers' and suppliers' records.

## What Changes

- Add a user-initiated data disclosure export from one customer detail view, limited to that customer and records reached through explicit typed relationships.
- Package a versioned ZIP containing `manifest.json`, typed UTF-8 JSON Lines record projections, and profile-local files explicitly linked to the selected customer, including migration-owned tables through v19 in the schema-health inventory; only records reached through approved customer relationships enter the payload.
- Use versioned per-table field allowlists; omit third-party references and mark any non-empty unclassified field as unsupported and the archive incomplete.
- Follow invoice correction/conversion lineage, recurring-template source-invoice links, and saved delivery-address links while rejecting conflicting customer identities.
- Identify included record types, relationship paths, excluded or ambiguous data, and missing files; never call an incomplete package complete.
- Keep this operation read-only and separate from whole-profile export, customer deletion, anonymization, and retention controls.
- Follow `DESIGN.md` accessibility, localization, form, status, and responsive workspace requirements.

## Capabilities

### New Capabilities

- `customer-data-disclosure-export`: Defines scoped customer-linked record/evidence export and truthful incomplete/unsupported results.

### Modified Capabilities

- `stammdaten`: Add an export action to the typed customer detail contract.
- `receivable-request-fingerprint-and-conditional-writeoff`: Preserve normal v7-to-v8 table creation and stop unsafe v8+ repair when the payment table is missing.
- `db`: Require a stable relationship inventory and consistent profile snapshot, and replace the stale table-count requirement with the shared 39-base + marker + 6-feature inventory, versioned table-presence rules, durable lazy-table markers, and the shared pre-repair payment-table health contract.

## Impact

The customer detail action, typed customer relationship projection, snapshot/export packaging, and `docs/03-stammdaten.md` privacy coverage. The exporter must include only data reached through approved customer relationships. It makes no claim of legal compliance and does not decide third-party disclosure or retention policy. Whole-profile portability remains owned by `profile-data-portability`.
