# Proposal: Make finalized document artifacts durable and usable

## Why

Finalization writes a relative original_pdf_pfad value but no production caller invokes PdfGenerator or writes bytes. The PDF viewer's print and save methods are empty, and dunning PDF generation is also a filename stub. This leaves legally relevant document artifacts non-existent or unusable.

Evidence: lib/pages/rechnungen/rechnungen_datasource.dart:380-398 stores a path without generation; lib/features/pdf/pdf_generator.dart:7-21 returns bytes only; lib/features/desktop/pdf_viewer_service.dart:40-43 has empty print/save; lib/features/mahnwesen/mahnungen_repository.dart:479 is a filename stub.

## What Changes

- Generate and atomically store finalized invoice and dunning PDF files in the profile-local document store.
- Record an artifact path only after a successful write and support reopening it.
- Implement desktop preview, print, save-as, and copy/watermark behavior with actionable error states.

## Capabilities

- Make finalized document artifacts durable and usable
- Priority: High
- Dependencies: runtime-composition-and-database-lifecycle; invoice-accounting-posting-lifecycle; primary-workspace-exposure.

## Impact

lib/features/pdf, lib/features/desktop/pdf_viewer_service.dart, invoice/dunning finalization flows, storage paths, and end-to-end filesystem tests.
