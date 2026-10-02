## Context

The current `/invoices/new` route implements a separate one-line draft form. It creates a `RechnungItem` through
`AppServices.rechnungen`, but there is no edit-draft use case. The invoice detail route offers finalization, PDF save,
and PDF preview; it does not expose the Storno, Gutschrift, replacement, or conversion use cases already present in
`RechnungenUseCases`. Its displayed total is derived by summing `RechnungPositionItem.gesamt`, rather than consuming
the net/VAT/gross result returned by `VorschauService`.

`openspec/specs/documents/spec.md` already specifies editable drafts, finalization confirmation, correction workflows,
and supported conversion chains. This change specifies their missing user-facing invoice workspace. The layout follows
`DESIGN.md` §15 (desktop split editor and preview, narrow-window tabs), while the localization rules in §23 apply to
all affected labels, messages, and semantics.

The archived `invoice-money-invariants` change is not a settled dependency: its round-three review is `REVISE` and
documents critical unresolved storage-scale and correction-sign decisions. The UI design must not interpret that
archive as an approved calculation contract.

## Goals / Non-Goals

**Goals:**

- Provide one workspace for creating and editing multi-position outgoing invoice drafts.
- Display validation and a live document preview using a single authoritative domain preview result.
- Show the preview result's net, VAT, and gross values consistently in the editor and document preview.
- Expose eligible lifecycle operations through the invoice use-case layer, with confirmation for finalization and
  conversion and a required reason for Storno.
- Follow the established application services boundary, DESIGN.md layouts, and generated localization.

**Non-Goals:**

- Define or change invoice arithmetic, accepted numeric scales, serialization, persistence precision, rounding,
  discount allocation, validation error codes, or correction signs.
- Implement incoming/supplier invoices, source-document import, e-invoice formats, payment handling, journal postings,
  inventory policy, or tax/accounting reports.
- Change document type eligibility, numbering, or side effects owned by existing invoice lifecycle use cases.

## Decisions

### Use a shared outgoing-invoice editor state

Create and edit routes SHALL use the same editor model and presentation components. The state owns the current header
fields, ordered editable position rows, validation state, and latest domain preview result. Creating a position, editing
one, removing one, reordering, switching input mode, or changing a discount invalidates the prior preview until a new
domain result is returned. This avoids a create-only form diverging from the edit experience.

### Keep mutation and preview behind the use-case boundary

Widgets SHALL resolve `RechnungenUseCases` through `AppServices`; they SHALL NOT construct repositories, call a data
source, or contain persistence SQL. Add an `updateDraftRechnung` use case and matching repository/data-source operation
for full draft updates if no equivalent exists. Validate the draft before persistence and persist the header and ordered
positions atomically. A rejected update leaves the saved draft untouched and keeps the user's unsaved form state.

Expose preview through an application-level use-case method that delegates to the canonical domain calculator. The
workspace SHALL display only fields from that result. In particular, the document-total label binds to the result's
gross value; it MUST NOT derive a total by summing line aggregates. A failed preview clears or marks the previous result
stale and reports localized validation next to the affected controls and in the summary.

**Hard implementation precondition:** before any application work begins, a separately authored, fresh-reviewed, and
accepted OpenSpec change MUST resolve or supersede `openspec/changes/archive/2026-09-07-invoice-money-invariants/`.
That change must settle the relevant calculator result, persistence representation, and correction-sign contract. If
the prerequisite is absent or not approved, stop before editing source. This proposal deliberately defines no new
formula, scale, rounding, allocation, error-code, persistence, or correction-sign behavior.

### Put lifecycle commands in contextual detail actions

The detail page SHALL derive visible operations from persisted document type, status, and relationships, using the
eligibility matrix in the maintained `documents` specification. Existing repository guards are incomplete, so the
invoice use cases and write transaction must be strengthened to enforce the same matrix before any mutation. In
particular, require an outgoing finalized source for corrections/replacements, require an un-replaced storniert source
for Ersatzrechnung, and require a finalized source plus a supported pair for conversion. Finalization must reject
non-draft or correction-only types before numbering, PDF, stock, or accounting writes. Map each action to the existing
use-case contract: `finalizeRechnung(rechnungId, locale)` receives the current draft ID and active UI locale;
`stornoRechnung(rechnungId, grund)` receives a trimmed non-empty reason; invoice-derived
`createGutschrift(vonRechnungId: id, grund: reason)` leaves `datum` and `positionen` null, and `grund` is optional
with the existing empty-string default; `createErsatzRechnung(vonRechnungId: id)` receives the eligible storniert
source; and `konvertiereDokument(quelleId: id, zielTyp: targetType)` receives the confirmed supported target.
Standalone credit-note creation through `datum` and `positionen` is outside these detail actions. Finalization and
conversion use a localized confirmation; Storno collects a non-empty reason. Extend the typed invoice detail mapper to return persisted
relationship IDs and labels for both source and target details. On success, invalidate both related detail providers and
the document list, then show the created document. On failure, preserve the source view and display an actionable
localized error. The UI change does not redefine accounting effects.

Correction and conversion actions must not become available in production until
`document-correction-artifacts-and-receipt-intake` supplies the real artifact transaction required for finalized
results. The invoice editor and ordinary draft/finalization workspace may be implemented separately once the money
contract prerequisite is accepted.

### Follow the established responsive design

At widths of 960 logical pixels or more, show the editor and live preview together, with proportions close to the
DESIGN.md §15 recommendation (editor 55–60%, preview 40–45%). Below 960 logical pixels, use separate localized editor
and preview tabs instead of squeezing both panes. Acceptance checks use 1280x800 and 800x700 logical-pixel viewports.
Use the app's existing form, card, spacing, button, status, and money-display components. All new or touched
strings, validation feedback, tooltips, and accessibility labels use generated localization resources; date and money
formatting follow the active locale. The implementation must preserve keyboard focus and allow long translated labels
to wrap or scroll without horizontal overflow.

### Keep capability scope local to outgoing authoring

The new capability owns the user-facing workspace contract. Existing `documents` rules continue to own document
eligibility, lifecycle transitions, correction semantics, conversion chains, and side effects. No delta to accounting,
PDF export formats, supplier invoices, or tax/reporting capabilities belongs in this change.

## Risks / Trade-offs

- [The unresolved money contract can block implementation] → Treat the independent accepted contract as a strict
  precondition; do not fill the gap with widget arithmetic or assumptions from the archived review.
- [Finalized corrections can claim PDFs that do not exist] → Keep correction/conversion actions unavailable until the
  separately proposed `document-correction-artifacts-and-receipt-intake` artifact transaction is implemented and
  accepted.
- [Editing adds a write path for invoice headers and positions] → Route it through a single use case and atomically
  save the whole draft; retain the prior persisted draft on validation or write failure.
- [Document actions can become stale while a page is open] → Recheck eligibility in the existing use case, disable
  duplicate submissions while pending, then refresh the source and list after success.
- [Localized copy may expand controls] → Use flexible desktop panes, narrow-window tabs, wrapping, and layout tests
  with the longest supported locale.
- [A large editor may duplicate the PDF renderer] → Reuse invoice position/summary widgets where practical; keep the
  preview a read-only projection of the latest domain preview/document data.

## Migration Plan

No database migration is planned by this proposal. The implementation will first satisfy the arithmetic-contract
precondition, then add or reuse the draft-update application method and wire the shared editor, preview, and contextual
actions. Existing saved drafts remain editable through the new route; finalization and downstream records continue
through their existing use cases. Rollback is a scoped source revert after implementation; persisted records do not
need conversion.

## Open Questions

- Which separate approved change resolves the archived `invoice-money-invariants` blockers? This is a blocking
  prerequisite, not a decision for this workspace change.
- The invoice-derived Gutschrift reason is optional and uses the existing empty-string default; the UI passes it
  through `grund` and does not create a standalone Gutschrift.
