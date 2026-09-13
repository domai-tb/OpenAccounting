# document-artifact-transaction Specification

## Purpose
TBD - created by archiving change document-artifact-lifecycle. Update Purpose after archive.

## Requirements

### Requirement: Atomic artifact and side-effect transaction

The lifecycle owner SHALL generate bytes from an immutable snapshot, write a unique profile-local temporary file, verify readability, atomically rename it, and persist its path only after success. The side-effect matrix SHALL be: Rechnung may create receivable/journal/inventory effects; Storno reverses linked effects; Gutschrift records credit/reversal; Angebot/Auftrag/Proforma/Lieferschein are document-only; Mahnung creates dunning state and an artifact.

#### Scenario: Finalized invoice commits artifact and effects
- **GIVEN** a valid invoice and active profile root
- **WHEN** finalization succeeds
- **THEN** the readable PDF path and the invoice’s defined receivable/journal/inventory effects SHALL commit together

#### Scenario: Writer failure rolls back
- **GIVEN** PDF generation, write, or readability verification fails
- **WHEN** finalization handles the failure
- **THEN** no path or temporary file SHALL remain and numbering, document, journal, receivable, and inventory state SHALL remain unchanged

### Requirement: Retry, concurrency, and path safety

Finalization SHALL allocate a number once per idempotency key, return the existing result on an identical retry, reject a conflicting concurrent request, and never overwrite an unrelated artifact. Temporary and final paths SHALL remain below the active profile root.

#### Scenario: Identical retry is idempotent
- **GIVEN** a finalization request has already committed with an idempotency key
- **WHEN** the same request is retried
- **THEN** the original number and artifact path SHALL be returned without duplicate side effects

#### Scenario: Concurrent collision is rejected
- **GIVEN** two different requests finalize the same document or a path collides with an unrelated file
- **WHEN** both requests run
- **THEN** exactly one valid result SHALL commit, the other SHALL return a typed conflict, and the unrelated file SHALL remain unchanged
