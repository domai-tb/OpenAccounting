## Context

PDF rendering exists, but routed invoice pages do not expose artifact actions and several finalized document types persist paths without generating files. Dunning generation is separate and minimal. The project already has immutable PDF snapshot models, profile-local storage, Drift transactions, and a viewer abstraction.

## Goals / Non-Goals

**Goals:**

- Make rendering, artifact storage, and document side effects separate, testable responsibilities.
- Generate and verify profile-local artifacts for all supported types with explicit transaction and retry behavior.
- Expose preview/open/save/print/missing-file states through routed UI.
- Render configured metadata, optional assets, Unicode text, and page numbers.

**Non-Goals:**

- Changing monetary calculations, numbering formats, or document legal policy beyond specifying transactional behavior.
- Implementing a new PDF engine or external document service.
- Enabling updater installation.

## Decisions

- `pdf-rendering-completeness` returns bytes only; it never writes paths or mutates the database.
- `document-artifact-transaction` owns the side-effect matrix, numbering allocation, idempotency key, unique temporary paths, readability verification, atomic rename, and database persistence ordering.
- `document-artifact-actions` consumes lifecycle states and calls injected viewer adapters; it never reconstructs paths or generation logic.
- Finalization uses an immutable snapshot and one transaction boundary. A retry with the same idempotency key returns the committed number/path; a competing request receives a typed conflict. Paths are canonicalized and constrained below the active profile root.
- Use the existing PDF generator with a bundled Unicode font and footer callback; optional content is rendered only when present.

Alternatives rejected: writing directly to the final path (partial files), persisting a path before generation (false success), and separate writers per document type (contract drift).

## Risks / Trade-offs

- [PDF generation is slow] → Show progress and generate outside the UI build; verify bytes before commit.
- [Side effects span DB and filesystem] → Use temp-file/transaction ordering with cleanup and explicit rollback tests.
- [Platform print support differs] → Return an unsupported result and offer Save As.

## Migration Plan

1. Add renderer and lifecycle ports with failing production-path tests.
2. Migrate standard invoice, then Storno/Gutschrift/Lieferschein/other types and dunning.
3. Add route actions and viewer state handling.
4. Migrate snapshot fields/font/footer and run artifact failure/idempotency/concurrency tests.
5. Roll back UI actions without deleting existing artifacts; retain readable legacy files.

## Open Questions

- Which footer text and font license are approved for production?
- Should an existing artifact be immutable forever, or may an explicit regeneration replace it under a new versioned path?
