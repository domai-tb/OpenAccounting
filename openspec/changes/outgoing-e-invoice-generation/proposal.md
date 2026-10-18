## Why

Feature 01 documents outbound ZUGFeRD and XRechnung generation, and maintained PDF/customer specifications require those outputs. The CII/UBL serializers and pinned offline XML validator are now implemented. The PDF generator now has a local Factur-X hybrid construction path when supplied validated CII, but persisted tax treatment inputs are not yet available to the invoice finalization data source, and app-generated PDF/A-3b conformance is not yet independently verified. The incoming-invoice proposal explicitly excludes outbound generation.

The existing contracts distinguish two behaviors: a customer with `zugferd_aktiv` defaults to a hybrid ZUGFeRD PDF when an outgoing invoice is finalized, while XRechnung is a standalone XML export. The current PDF spec incorrectly describes XRechnung as XML embedded in PDF/A-3 and the feature guide names the obsolete ZUGFeRD 2.1.1 release.

## What Changes

- Present an explicit per-invoice output choice for ZUGFeRD, XRechnung, or PDF; use the customer's `zugferd_aktiv` value only to preselect the default.
- Generate a ZUGFeRD 2.5.2 EN 16931 profile invoice as a PDF/A-3b hybrid with its CII XML embedded when that output is selected for finalization.
- Offer a separate XRechnung 3.0 UBL 2.1 XML export from a finalized outgoing invoice, validated against the XRechnung Bundle 3.0.2 Summer 2026 technical artifacts.
- Build finalization outputs from one immutable typed finalization snapshot, materialized inside the transaction after number allocation and canonical invoice calculation but before artifact generation. Its values MUST be the same values persisted on commit. Build standalone exports from committed finalized snapshots. Do not calculate, round, classify tax, or fill missing invoice data during serialization.
- Persist explicit per-line tax treatment, legal-basis, EN 16931 category, and exemption-reason evidence in additive migration v28. Map only the named supported treatments in this change; rate-only and generic exemption classification are forbidden. Support the pinned §25a margin-scheme mappings only for an explicit subtype and its exact VATEX/statutory-note pair; keep internal margin tax separate from canonical disclosed invoice amounts.
- Persist case-specific §13b eligibility evidence with each reverse-charge line. For §13b(1), record the general §3a(2) recipient/place-of-supply facts and the supplier's other-EU establishment status; for §13b(2)(4)/(5), require a valid USt 1 TG certificate for construction services. VAT IDs and a customer's construction-industry label alone do not establish eligibility; missing or unsupported evidence fails closed.
- Validate XML against pinned, locally packaged official XSD/Schematron artifacts and validate the hybrid PDF/A-3b packaging before reporting success or writing a user-requested export.
- Reject incomplete or inconsistent source data with localized field-level diagnostics. Failed ZUGFeRD generation rolls back finalization and leaves no numbered invoice or partial file.
- Keep XRechnung export behind the typed application-scope invoice service/repository and a native save-file dialog. It does not change the finalized invoice.
- Capture an optional invoice delivery date and emit it as BT-72 (absent fails closed; single-date scope, no period path)
- Emit XRechnung party endpoints from master-data captures plus the export buyer reference (seller VAT/9930, buyer email/EM else buyerReference/0204), failing closed without invention; source BG-16 payment means from the company IBAN (absent IBAN fails closed)
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

The typed invoice generation/service boundary, immutable invoice snapshot, `rechnungen.ausgabeformat` persistence/migration, additive v28 line tax-evidence persistence, PDF generation pipeline, outgoing invoice detail action, local standards-validation artifacts, customer ZUGFeRD setting, and the invoice guide. Implementation depends on the accepted invoice-money contract and independent review of the amended tax-classification contract. §25a is supported only with an explicit subtype and its exact accepted evidence tuple; no subtype is inferred from product or margin data. Migrations v25 are consumed by mileage, v26 is reserved for cashbook prerequisite/account-opening data, and v27 for cashbook close evidence. This change covers ordinary finalized outgoing invoices only; correction documents, supplier invoices, e-mail delivery, network submission, accounting postings, and unsupported tax treatments remain outside its supported behavior.
