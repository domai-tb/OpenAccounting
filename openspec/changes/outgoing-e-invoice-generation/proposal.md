## Why

Feature 01 documents outbound ZUGFeRD and XRechnung generation, and maintained PDF/customer specifications require those outputs. The production PDF generator creates visual PDFs only; there is no structured outbound XML serializer, PDF/A-3 embedding path, standards validator, or user-facing XRechnung export. The incoming-invoice proposal explicitly excludes outbound generation.

The existing contracts distinguish two behaviors: a customer with `zugferd_aktiv` defaults to a hybrid ZUGFeRD PDF when an outgoing invoice is finalized, while XRechnung is a standalone XML export. The current PDF spec incorrectly describes XRechnung as XML embedded in PDF/A-3 and the feature guide names the obsolete ZUGFeRD 2.1.1 release.

## What Changes

- Present an explicit per-invoice output choice for ZUGFeRD, XRechnung, or PDF; use the customer's `zugferd_aktiv` value only to preselect the default.
- Generate a ZUGFeRD 2.5.2 EN 16931 profile invoice as a PDF/A-3b hybrid with its CII XML embedded when that output is selected for finalization.
- Offer a separate XRechnung 3.0 UBL 2.1 XML export from a finalized outgoing invoice, validated against the XRechnung Bundle 3.0.2 Summer 2026 technical artifacts.
- Build finalization outputs from one immutable typed finalization snapshot, materialized inside the transaction after number allocation and canonical invoice calculation but before artifact generation. Its values MUST be the same values persisted on commit. Build standalone exports from committed finalized snapshots. Do not calculate, round, classify tax, or fill missing invoice data during serialization.
- Validate XML against pinned, locally packaged official XSD/Schematron artifacts and validate the hybrid PDF/A-3b packaging before reporting success or writing a user-requested export.
- Reject incomplete or inconsistent source data with localized field-level diagnostics. Failed ZUGFeRD generation rolls back finalization and leaves no numbered invoice or partial file.
- Keep XRechnung export behind the typed application-scope invoice service/repository and a native save-file dialog. It does not change the finalized invoice.
- Persist the selected per-invoice output format atomically with finalization so the detail workspace can restore the choice after the invoice is reopened. Legacy finalized invoices with no saved choice resolve to PDF, independent of current customer defaults.
- Update the maintained PDF/customer requirements and `docs/01-rechnungen.md` to distinguish the hybrid and standalone formats, supported releases, validation behavior, explicit output selection, and XRechnung export. Replace blanket mandatory-field claims with conditions tied to applicable legal or pinned format rules.

## Capabilities

### New Capabilities

- `outgoing-e-invoice-generation`: produce version-pinned outbound structured invoice artifacts from finalized sales invoices.

### Modified Capabilities

- `pdf`: define the distinct ZUGFeRD hybrid and standalone XRechnung outputs instead of describing both as embedded XML.
- `stammdaten`: make the existing customer ZUGFeRD flag's generation and failure behavior explicit.
- `documents`: persist the selected output format as part of ordinary invoice finalization and expose it through finalized-document reads.

## Impact

The typed invoice generation/service boundary, immutable invoice snapshot, `rechnungen.ausgabeformat` persistence/migration, PDF generation pipeline, outgoing invoice detail action, local standards-validation artifacts, customer ZUGFeRD setting, and the invoice guide. Implementation depends on accepted invoice-money and tax-category-mapping contracts and on the master-data workspace exposing the existing `zugferd_aktiv` field. This change covers ordinary finalized outgoing invoices only; correction documents, supplier invoices, e-mail delivery, network submission, accounting postings, and tax policy remain owned by their existing capabilities.
