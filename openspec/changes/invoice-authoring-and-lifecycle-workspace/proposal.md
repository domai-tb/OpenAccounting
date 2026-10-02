## Why

The invoice route can create only a one-position draft and does not let users edit saved drafts or invoke the existing correction and conversion use cases. Its summary also treats the sum of position totals as the document total, which can display net as gross.

## What Changes

- Provide an editable, multi-position outgoing-invoice draft workspace with add, edit, remove, and reorder controls.
- Provide a live document preview with field-level and summary validation; show calculated net, VAT, and gross values from the authoritative domain preview result.
- Expose eligible existing finalization, Storno, Gutschrift, replacement, and document-conversion actions with contextual eligibility, confirmation, and localized feedback.
- Make the existing invoice use cases revalidate lifecycle eligibility at the transactional boundary against the maintained `documents` rules; expose contextual actions and typed source/target links in the workspace.
- Keep draft editing, corrections, conversions, and finalization routed through the invoice use-case boundary; add a draft update use case where the current API has none.
- Respect the invoice editor layout and responsive behavior in `DESIGN.md`, and localize every new or touched user-facing string.

## Capabilities

### New Capabilities

- `invoice-authoring-and-lifecycle-workspace`: User-facing invoice drafting, preview, validation, and access to supported document lifecycle operations.

### Modified Capabilities

- None. The existing `documents` requirements already define editable drafts, finalization, corrections, and conversions; this change adds their missing invoice-workspace interaction contract without changing those domain rules.

## Impact

Affected surfaces include the invoice routes and detail page, invoice entity/read mapper and relationship fields, invoice use cases/repository/data source for draft updates and lifecycle guards, preview presentation, localization resources, and invoice workspace specifications. The implementation must consume one authoritative domain preview result for the displayed totals and must not calculate totals in widgets.

**Dependency and boundary:** The archived `invoice-money-invariants` change ends in `VERDICT: REVISE` with unresolved arithmetic persistence and correction-sign contracts. Before implementation, a separately reviewed and accepted OpenSpec change MUST resolve or supersede that contract. This proposal neither amends nor restates its formulas, accepted scales, rounding/allocation rules, persistence representation, error codes, or correction sign matrix. This change excludes incoming invoices, payment/accounting postings, and accounting or tax reporting.

Correction and conversion actions also depend on the real artifact transaction in `document-correction-artifacts-and-receipt-intake`. Keep those actions unavailable until that capability is implemented; the editor and ordinary draft flow can proceed independently after the money-contract prerequisite is accepted.
