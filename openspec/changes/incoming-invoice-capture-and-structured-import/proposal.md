## Why

The production invoice form creates customer invoices only: it offers customer selection, persists no supplier link, and does not turn an imported invoice source into an incoming draft. Incoming invoice types and their later finalization effects already exist in the document contract, but users cannot capture a supplier invoice for review.

## What Changes

- Add an incoming-invoice capture flow that reuses an imported Beleg, previews its original PDF, and lets the user manually prepare a supplier invoice draft.
- Read supported XRechnung XML and structured XML embedded in ZUGFeRD/Factur-X PDF sources into reviewable draft-field suggestions. Require user confirmation before creating the draft.
- Keep imported source values distinct from the application's assigned invoice number and retain the link to the source Beleg.
- Permit canonical incoming invoices to use the existing editable draft lifecycle.
- Leave generic Beleg ingestion, source storage and preview, invoice calculation/finalization effects, payments, and accounting reports to their existing capability owners.

## Capabilities

### New Capabilities

- `incoming-invoice-capture`: Manual and structured-source capture of supplier invoices as editable incoming-invoice drafts.

### Modified Capabilities

- `documents`: Include incoming invoices in the existing editable draft lifecycle; preserve existing finalization rules.

## Impact

Adds a supplier-facing invoice capture workspace and structured invoice-field mapping behind the existing application service boundary. It depends on `document-correction-artifacts-and-receipt-intake` for imported Beleg sources and preview, uses the maintained `documents` finalization contract, and defers all posting and settlement effects to the accepted accounting lifecycle. No new source-artifact store or e-invoice generator is proposed.
