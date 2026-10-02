## Context

The current `/invoices/new` form calls `RechnungenUseCases.createDraftRechnung` with the default outgoing type and accepts a customer, but not a supplier or source invoice number. `/receipts` is a generic `belege` record list. `BuchungsvorlagenRepository` can create a template-prefilled `rechnung_eingang` draft in backend code, but it is not exposed as a routed capture/review surface and does not consume an invoice source. The product-vision matrix maps the invoice editor/lifecycle to M19–M20 (partial) and the receipt inbox to M22 (missing); `DESIGN.md` §§15–16 describe those user-facing workflows.

Incoming invoice classification, draft persistence primitives, and later finalization effects already exist in `documents`. The outgoing editor change explicitly excludes incoming invoices. The receipt-intake change owns Beleg ingestion, immutable source storage, generic recognition review, and source preview. Its document contract names `rechnungen.beleg_id`, but the current `rechnungen` table has no such column; that artifact owner must deliver the association before this capture flow is implemented. This proposal adds invoice-specific review and draft creation on top of those contracts; it does not replace either workflow.

## Goals / Non-Goals

**Goals:**

- Let a user manually capture an incoming supplier invoice from a reviewed PDF Beleg.
- Populate reviewable suggestions from standalone XRechnung XML or structured XML in a ZUGFeRD/Factur-X PDF.
- Persist the supplier's source invoice number independently from the application's assigned invoice number.
- Keep the source Beleg available and linked while creating an editable incoming draft.

**Non-Goals:**

- Create or alter generic Beleg import, artifact storage, source validation, or viewer behavior.
- Implement OCR, supplier-master-data CRUD, supplier payments, journal posting, settlement, tax reporting, or invoice finalization policy.
- Generate outbound ZUGFeRD/XRechnung files, certify PDF/A, or claim legal conformance.
- Choose money precision, rounding, tax treatment, or correction signs.

## Decisions

### Reuse the Beleg workflow as the source boundary

The capture page accepts an already imported Beleg and calls the existing receipt preview/association capability. It SHALL not copy source bytes, build paths in a widget, or introduce a second artifact record. Source import errors and unavailable previews stay with the Beleg workflow. If the source is a PDF, keep that preview visible while the user reviews fields; use the review layout in DESIGN.md §16 and the invoice form behavior in §§15 and 25.

Expose the action from the reviewed Beleg detail so capture preserves source context. A second invoice-page file importer was considered and rejected because it would create a competing ingestion path and obscure which workspace owns the source.

### Create the canonical incoming draft through the invoice use-case path

Use `rechnung_eingang` for new capture. Extend the existing `RechnungenUseCases` → repository → data source path to accept the chosen supplier, source invoice number, and the source Beleg association. Keep the supplier's number in a nullable field separate from `rechnungsnummer`, which remains the application's finalized document number. Do not put it in free-text `notiz` or a journal description.

Manual entry and structured import share one draft editor. The user explicitly selects an existing supplier; extracted supplier identity may help the user find a match but never creates or selects a supplier automatically. If no supplier can be selected, the Beleg remains available for review and no invoice draft is created.

Creating a journal row directly was considered and rejected because it bypasses the existing incoming-invoice lifecycle and source relationship.

### Treat structured fields as suggestions

Read supported XRechnung XML and the structured invoice payload embedded in a supported ZUGFeRD/Factur-X PDF from the Beleg. Map only fields the incoming draft model already represents. Show which values came from the source and let the user correct them before explicitly creating the draft. Preserve the source unchanged. Do not OCR PDFs or images, infer unsupported values, or parse by making network requests. Reuse the receipt-intake source validation and safe XML parsing contract.

If a field cannot be represented, surface that field and keep the manual path available; do not silently coerce it. The source-invoice formats and profile versions supported for import must be named before implementation. The maintained PDF capability describes generation and is not evidence that an imported source is legally certified.

Automatic draft creation and OCR were considered and rejected because neither gives the user a review point for supplier identity and imported values.

### Keep draft creation separate from accounting effects

Saving capture creates only an editable incoming draft using the modified `documents` lifecycle requirement. Number allocation, finalization, payables, journal postings, tax claims, payment, and reporting continue to use their existing capability owners. Do not add capture-time accounting writes or alternative money calculations.

**Implementation preconditions:** `document-correction-artifacts-and-receipt-intake` must be reviewed and accepted with a working Beleg-to-invoice relationship and source preview. The archived `invoice-money-invariants` review remains `REVISE`; a separately reviewed and accepted replacement contract must settle the shared invoice model/calculator path before this feature is implemented.

## Risks / Trade-offs

- [A structured invoice version or field is unsupported] → Keep the original Beleg, name the unsupported field, and let the user continue manually.
- [Supplier identity is ambiguous] → Require explicit selection from existing supplier records; never auto-create or silently match a supplier.
- [The source invoice number is confused with the app's invoice number] → Store the two values separately and allocate the app number only through existing finalization.
- [The shared money contract remains unsettled] → Treat acceptance of the replacement money contract as a hard implementation gate.
- [Preview support differs by file type] → Reuse the Beleg preview capability and expose its explicit unavailable/unsupported state; do not add a second viewer here.

## Migration Plan

1. Complete and accept the Beleg source/preview/association contract and resolve the invoice money-contract prerequisite.
2. Add a nullable supplier-source-number column through the repository's additive schema migration; existing documents retain their current number and values.
3. Wire manual and structured review to the existing invoice use-case path. Capture creates only drafts; finalization effects remain in their current owner.
4. If the capture route is disabled or rolled back, retain imported Belege and existing invoice rows. The new nullable source-number field can remain unused without rewriting old data.

## Open Questions

- Which exact XRechnung versions and ZUGFeRD/Factur-X profiles and embedded XML variants will the importer support?
- Which source fields beyond supplier identity, source number, dates, and representable invoice positions belong in the first mapping?
- Which library or existing parser can read those formats locally without adding a second validation or artifact pipeline?
