## Why

The shared finalizer applies accounting and sales-stock effects without a document-type boundary, records outgoing VAT as input tax, and cannot finalize incoming aliases. Its PDF filename is based only on a range-local number, so same-number documents can overwrite or delete one another. A separate invoice-derived receivable API also accepts finalized non-invoice records.

## What Changes

- Limit generic journal and receivable postings to supported outgoing and incoming invoices; restrict the public invoice-derived receivable operation to the same types.
- Create generic input-tax claims only for incoming invoices; preserve dedicated correction reversal behavior.
- Deduct sales stock only for outgoing invoices, aggregate repeated article lines before validation and deduction, and restore only recorded negative source movements.
- Route incoming aliases and legacy supplier-linked `rechnung` records through the incoming number range; reject unsupported types and missing or malformed ranges without fallback.
- Store new PDFs under document-row identity and clean up only files created by the failed operation, preserving existing stored paths.
- Keep document-only finalization and its own number/PDF lifecycle without financial or stock effects.

Financial correction signs, balanced debit/credit mappings, and historical record repair remain separate work.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `documents`: define finalization effects by document type and preserve each PDF artifact independently of its display number.
- `accounting`: create generic input-tax claims only for incoming invoices and restrict invoice-derived receivables to supported incoming or outgoing invoices.
- `inventory`: validate combined outgoing quantities and restore only stock movements recorded for the source.

## Impact

The shared invoice finalizer, Storno stock reversal, `RechnungTyp` classification, `ForderungenRepository.createForRechnung`, PDF persistence and cleanup, and focused lifecycle tests are affected. No new dependency or schema migration is required.
