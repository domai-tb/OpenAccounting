## Why

The standard invoice finalization path can generate a PDF, but other finalized document types persist paths without writing files. Dunning generation is minimal, routed invoice pages expose no artifact actions, and PDF snapshots omit configured content. Users therefore cannot trust or use the document output.

## What Changes

- Establish one authoritative atomic artifact lifecycle for all supported document types and dunning.
- Separate byte rendering from artifact persistence and document/accounting side effects.
- Expose preview, open, save, print, missing-file, and retry states from routed UI.
- Complete document metadata, optional content, Unicode font handling, and page numbering.
- Add production-path failure, idempotency, concurrency, and artifact-byte tests.

## Capabilities

### New Capabilities

- `pdf-rendering-completeness`: Type-specific PDF bytes, metadata, optional content, Unicode, and layout.
- `document-artifact-transaction`: Atomic storage, persistence ordering, side-effect matrix, rollback, idempotency, and concurrency.
- `document-artifact-actions`: Routed artifact state and viewer actions for invoice and dunning pages.

### Modified Capabilities

None. Existing `pdf` and `finalized-document-artifact-lifecycle` specs remain the baseline; these capabilities resolve their missing ownership and UI contracts.

## Impact

- `lib/features/pdf/`, invoice and dunning data sources/repositories, `lib/features/desktop/pdf_viewer_service.dart`, router pages, and artifact tests.
- Existing persisted paths remain readable; migration must never delete documents or silently rewrite unrelated files.
- No new dependency is required; use the existing PDF and desktop adapter abstractions.
