## ADDED Requirements

### Requirement: Outgoing invoice drafts are editable in the workspace

The invoice workspace SHALL let a user create and reopen an outgoing invoice draft, edit its supported header fields,
and add, edit, remove, and reorder multiple positions. Saving a valid edit SHALL persist the whole draft update and keep
the document in Entwurf until the user explicitly finalizes it. Draft editing SHALL use the invoice use-case boundary;
widgets MUST NOT write directly to a repository or data source. If a save is rejected, the last persisted draft SHALL
remain unchanged and the user's in-progress values SHALL remain available for correction.

#### Scenario: Multiple positions round-trip through a draft
- **GIVEN** an outgoing invoice draft has one position and is still in Entwurf
- **WHEN** the user adds a second position, edits the first, reorders them, and saves
- **THEN** reopening the draft shows both updated positions in the saved order and the document remains in Entwurf

#### Scenario: Rejected draft edit preserves the saved draft
- **GIVEN** a saved draft exists and the current form contains a position rejected by domain validation
- **WHEN** the user saves the edit
- **THEN** the persisted draft remains byte-for-byte unchanged, the form retains the attempted values, and the rejected field is identified for correction

### Requirement: Preview totals come from the authoritative domain result

The invoice workspace SHALL show net, VAT, and gross totals for the current valid draft in both the editor summary and
document preview. Those displayed values SHALL be copied from one authoritative domain preview result; widgets MUST NOT
sum position aggregates or independently calculate, round, allocate, or sign invoice money. The result's gross amount
SHALL be the value shown as the document total. This UI requirement defines only presentation and data flow. It does not
define or change calculation formulas, accepted input scales, persistence representation, rounding/allocation, error
codes, or correction signs. Implementation is blocked until a separately reviewed and accepted OpenSpec change resolves
or supersedes the archived `invoice-money-invariants` contract.

#### Scenario: Current preview result is shown without widget recalculation
- **GIVEN** a valid outgoing draft and the domain preview returns net 100.00, VAT 19.00, and gross 119.00
- **WHEN** the editor and document preview are rendered
- **THEN** both show net 100.00 and VAT 19.00, and each document-total label shows gross 119.00 from that same result

#### Scenario: Invalid preview does not leave stale totals presented as current
- **GIVEN** the previous form state had a valid preview and the current form values fail domain validation
- **WHEN** preview recalculation returns a validation failure
- **THEN** the previous amounts are marked unavailable or stale, no amount is presented as the current total, and localized field and summary validation states identify the rejected input

### Requirement: Eligible document lifecycle actions are accessible and guarded

The invoice workspace SHALL expose supported finalization, Storno, Gutschrift, replacement-invoice, and document-
conversion operations in the context of the selected document, using invoice use cases for all mutations. The UI SHALL
enable only operations permitted by `openspec/specs/documents/spec.md`, and each use case SHALL revalidate type, state,
and existing lifecycle relationships inside the write transaction before creating a document or side effect. Storno is
permitted only for a finalized outgoing Rechnung or Gutschrift that is not already storniert; an invoice-derived
Gutschrift requires a finalized outgoing Rechnung; Ersatzrechnung requires a storniert outgoing Rechnung with no
existing replacement; conversion requires a finalized source and a supported conversion-chain pair; finalization
requires a valid Entwurf type. Finalization and conversion SHALL require user confirmation. Storno SHALL collect a
non-empty reason. A completed operation SHALL refresh the source detail and document list and expose the resulting
document. This change implements the existing eligibility contract; it MUST NOT redefine correction semantics,
numbering, or accounting side effects.

#### Scenario: User invokes an eligible correction or conversion
- **GIVEN** a finalized outgoing invoice for which Gutschrift is permitted
- **WHEN** the user selects Gutschrift and confirms the displayed operation
- **THEN** `createGutschrift(vonRechnungId: id, grund: optionalReason ?? '')` is invoked once with `datum` and `positionen` omitted
- **AND** the linked correction appears in the workspace and the source detail shows the correction relationship

#### Scenario: Storno collects its required reason
- **GIVEN** a finalized outgoing invoice for which Storno is permitted
- **WHEN** the user selects Storno, enters a non-empty reason, and confirms
- **THEN** `stornoRechnung(rechnungId: id, grund: trimmedReason)` is invoked once
- **AND** the source detail shows the resulting Storno relationship and status

#### Scenario: Replacement invoice is offered for a storniert source
- **GIVEN** a storniert outgoing invoice that is eligible for an Ersatzrechnung
- **WHEN** the user selects Ersatzrechnung and confirms
- **THEN** `createErsatzRechnung(vonRechnungId: id)` is invoked once
- **AND** both source and replacement details show their linked relationship

#### Scenario: Permitted conversion requires confirmation
- **GIVEN** a finalized Angebot for which conversion to Auftrag is permitted
- **WHEN** the user selects Auftrag, reviews the target, and confirms
- **THEN** `konvertiereDokument(quelleId: id, zielTyp: 'auftrag')` is invoked once
- **AND** the new Auftrag appears with its source relationship

#### Scenario: Stale or ineligible lifecycle action is rejected at the use-case boundary
- **GIVEN** the source document's type, state, or relationships no longer permit the selected action
- **WHEN** the UI submits the action with its source ID and the use case rechecks persisted state
- **THEN** the use case SHALL reject before numbering, PDF, journal, stock, or relationship writes
- **AND** the UI SHALL show a localized actionable error and retain the source view

#### Scenario: Storno reason is required
- **GIVEN** a finalized outgoing invoice is otherwise eligible for Storno
- **WHEN** the user submits a blank reason
- **THEN** `stornoRechnung(rechnungId, grund)` SHALL NOT be invoked
- **AND** the field SHALL show a localized validation error

#### Scenario: Finalization requires an explicit confirmation
- **GIVEN** the user is viewing a valid outgoing invoice draft
- **WHEN** the user requests finalization and confirms the summary
- **THEN** `finalizeRechnung(rechnungId: id, locale: activeLocale)` is invoked once
- **AND** the detail becomes read-only with finalized-document actions

#### Scenario: Finalization is cancelled
- **GIVEN** the user is viewing a valid outgoing invoice draft
- **WHEN** the user cancels the finalization confirmation
- **THEN** the document remains an editable draft and no document number, artifact, or lifecycle side effect is created

#### Scenario: Finalization is unavailable for an ineligible document
- **GIVEN** the selected document is already finalized or has a type that generic finalization does not support
- **WHEN** the detail view resolves its persisted state
- **THEN** no enabled finalization action is shown, and a stale direct request is rejected before any side effect

#### Scenario: Correction actions wait for the artifact transaction
- **GIVEN** the correction artifact transaction from `document-correction-artifacts-and-receipt-intake` is not available
- **WHEN** a finalized document detail is loaded
- **THEN** Storno, Gutschrift, replacement, and conversion actions are unavailable
- **AND** a stale direct request is rejected before numbering, artifact-path, accounting, or relationship writes

#### Scenario: Invalid preview blocks finalization confirmation
- **GIVEN** the current draft preview fails domain validation
- **WHEN** the user requests finalization
- **THEN** no confirmation is shown, the draft remains editable, and no document number, artifact, or lifecycle side effect is created

### Requirement: Lifecycle relationships are available in the invoice detail model

The invoice detail read path SHALL map persisted source/target relationships for Storno, Gutschrift, Ersatzrechnung,
and supported conversions into typed document references. After a lifecycle action, both the source and resulting
document details SHALL show their reciprocal relationship with a navigable link. A relationship read failure SHALL
show an explicit localized unavailable state and SHALL NOT fabricate an unlinked document.

#### Scenario: Show a newly created correction relationship
- **GIVEN** a finalized invoice has a linked Gutschrift persisted
- **WHEN** the invoice detail and Gutschrift detail are loaded
- **THEN** each typed detail model SHALL contain the reciprocal source/target reference
- **AND** both details SHALL show a navigable relationship link

#### Scenario: Relationship target is missing
- **GIVEN** a persisted source relationship references a missing document row
- **WHEN** the detail view is loaded
- **THEN** the relationship SHALL be shown as unavailable with its stored identifier
- **AND** no unrelated document SHALL be displayed as the target

### Requirement: The invoice workspace follows the design system across window sizes

The outgoing invoice editor SHALL follow `DESIGN.md`'s split editor and live-preview layout on desktop and switch to
separate editor/preview tabs at narrow widths. All user-facing labels, validation messages, actions, tooltips, and
accessibility labels SHALL use generated localization resources. Layout and actions SHALL remain usable with localized
text expansion and keyboard focus.

#### Scenario: Desktop presents editor and preview together
- **GIVEN** the application is rendered at 1280 by 800 logical pixels
- **WHEN** the user opens a draft invoice
- **THEN** the editor and preview are both visible in the same workspace and all controls have localized accessible labels

#### Scenario: Narrow window uses tabs without overflow
- **GIVEN** the application is rendered at 800 by 700 logical pixels with German selected
- **WHEN** the user opens the invoice workspace and switches between editor and preview
- **THEN** each panel is reachable through a localized tab, no horizontal overflow occurs, and all draft and lifecycle actions remain reachable
