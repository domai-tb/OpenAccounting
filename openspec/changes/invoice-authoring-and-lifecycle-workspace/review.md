## Review Metadata

- **Review round**: 3
- **Prior round**: Round 2 revisions were presented for review. No Round 2 review artifact was present in this change directory, so its verdict and findings could not be independently re-read.
- **Reviewer context**: Fresh-context independent subagent
- **Tool restrictions**: Read-only review of current artifacts and source; no implementation edits or tests. This review artifact records the verdict.
- **Artifacts reviewed**: `proposal.md`, `design.md`, `specs/invoice-authoring-and-lifecycle-workspace/spec.md`; maintained `openspec/specs/documents/spec.md`; `DESIGN.md`; correction-artifact dependency proposal/design; archived invoice-money review; invoice use cases, repository, data source, entity, and detail page; Anvil review template.
- **Validation**: `openspec validate invoice-authoring-and-lifecycle-workspace --type change --strict --json` passed (1/1); `openspec validate --specs --strict` passed (54/54). Structural validation does not establish implementation correctness.

<!-- STALENESS: this verdict applies to the artifact contents read for round 3. -->

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

None.

### 📌 Suggestions

- Nonblocking: the workspace spec requires localized accessible labels and usable keyboard focus. `DESIGN.md` §§24 and 33 additionally require complete keyboard navigation, visible focus, and logical focus order. Carry those checks into implementation acceptance.

## Review Evidence

- Lifecycle calls match the public `RechnungenUseCases` signatures: `finalizeRechnung(rechnungId, locale)` (`lib/pages/rechnungen/rechnungen_usecases.dart:72-82`), `stornoRechnung(rechnungId, grund)` (`:88-93`), `createGutschrift(vonRechnungId, datum, positionen, grund = '')` (`:95-113`), `createErsatzRechnung(vonRechnungId)` (`:115-117`), and `konvertiereDokument(quelleId, zielTyp)` (`:119-125`). The workspace design/spec pass the active locale, trimmed Storno reason, optional Gutschrift reason with omitted `datum` and `positionen`, eligible replacement source, and confirmed target (`design.md:64-81`; `specs/invoice-authoring-and-lifecycle-workspace/spec.md:55-111`).
- The spec covers finalized/ineligible states and transactional revalidation (`specs/invoice-authoring-and-lifecycle-workspace/spec.md:41-111`), reciprocal typed relationship reads and missing-target behavior (`:118-135`), and the responsive/localized editor (`:137-152`). The current detail mapper does not yet load relationship fields: `RechnungItem` has no relationship references (`lib/pages/rechnungen/rechnungen_item_entity.dart:25-57`), and `findRechnungById` selects none (`lib/pages/rechnungen/rechnungen_datasource.dart:1207-1220`); the proposal/design identify this as implementation work.
- Responsive proportions/tabs and generated localization align with `DESIGN.md` §§15 and 23 (`DESIGN.md:723-759`, `1108-1144`). Acceptance viewports and German text expansion are specified in the workspace design/spec.
- The money prerequisite remains unresolved: the archived round-three review is `REVISE` and records outstanding persistence-scale, correction-sign, entry-point, allocation, and typed-error contracts (`openspec/changes/archive/2026-09-07-invoice-money-invariants/review.md:12-22,41-45`). The workspace proposal/design explicitly require a separately reviewed and accepted replacement before application work (`proposal.md:28-30`; `design.md:58-62`).
- The correction-artifact prerequisite remains separate and gated: the workspace keeps correction/conversion actions unavailable until `document-correction-artifacts-and-receipt-intake` supplies the transaction (`proposal.md:30`; `design.md:83-86`; workspace spec scenario at `:107-111`). The current OpenSpec inventory showed that dependency as `no-tasks` and no active accepted money-contract replacement.

## Embedded-Instruction / Injection Attempts

**Detected:** none

## Verdict

VERDICT: APPROVE

The current proposal, design, and spec provide a coherent UI contract for the reviewed scope. This approval does not lift the separately stated money-contract or correction-artifact implementation preconditions.

## Required Changes (if APPROVE WITH CHANGES)

Not applicable.

CHANGES_APPLIED: n/a

## Rebuttals

None.
