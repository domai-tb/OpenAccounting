# Design: Make finalized document artifacts durable and usable

## Context

Finalization writes a relative original_pdf_pfad value but no production caller invokes PdfGenerator or writes bytes. The PDF viewer's print and save methods are empty, and dunning PDF generation is also a filename stub. This leaves legally relevant document artifacts non-existent or unusable.

## Goals

Every finalized document has a durable artifact and a usable desktop lifecycle.

## Non-Goals

Changing PDF visual design or tax content; those can be separate design/content changes.

## Decisions

Keep artifacts under the active profile, use a temporary file plus atomic rename, and separate artifact generation from platform-specific print/save adapters.

## Risks / Trade-offs

Filesystem and OS integrations are harder to exercise in VM tests; use injectable storage/desktop adapters and a small platform smoke suite.

## Migration Plan

Introduce storage and adapters, add file-existence regression tests, then connect invoice and dunning finalization and replace empty viewer callbacks.

## Open Questions

Which platform-specific print/save capabilities are required for the first desktop release and which should be reported as unsupported?
