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

## Independent Implementation Review — Round 4 (2026-10-13)

### Scope and validation

Reviewed the current invoice-authoring-and-lifecycle-workspace implementation against its proposal, design, delta spec, maintained `documents` rules, and the prior Round 3 review. Focus areas were the correction-artifact capability gate, customer/edit/save validation, lifecycle UI behavior and relationship navigation, and authoritative money preview.

Ran the agreed scoped suite from the repository root:

```bash
fvm flutter test --dart-define=platform=vm \
  test/features/rechnungen/workspace_editor_test.dart \
  test/features/rechnungen/workspace_preview_test.dart \
  test/features/rechnungen/workspace_responsive_test.dart \
  test/features/rechnungen/workspace_lifecycle_actions_test.dart \
  test/features/rechnungen/workspace_lifecycle_ui_test.dart \
  test/features/rechnungen/workspace_relationships_test.dart \
  test/features/rechnungen/correction_artifact_transaction_wiring_test.dart \
  test/features/rechnungen/storno_test.dart \
  test/features/rechnungen/gutschrift_test.dart \
  test/features/documents/document_correction_artifacts_and_receipt_intake_test.dart \
  test/integration/audit/correction-document-accounting-integrity_test.dart
```

Result: exit 0, **76 tests passed**. This review independently ran the test command; no device or platform-runtime validation is claimed.

### Findings

#### Moderate — test-plan result ledger is stale

`test-plan.md` still marks every row `🔴 pending` and says results remain pending until the final scoped result is provided. The final scoped result now exists: the command above passed 76/76. The listed test names correspond to real tests. In particular, `workspace_lifecycle_actions_test.dart` covers use-case/action orchestration, while `workspace_lifecycle_ui_test.dart` contains direct widget tests for Storno, Gutschrift, replacement, conversion, and incoming-invoice Storno. Update the result ledger and its coverage note to record the run and preserve that distinction.

### Implementation review

- The artifact capability is exposed through the use-case/repository boundary and requires a profile directory; the correction writer commits the artifact inside the database transaction path. The scoped tests cover unavailable capability, committed artifact paths, and rollback when the committed file is unreadable.
- New-draft customer selection is required and persists the selected customer. Invalid dates and malformed numeric input are surfaced while preserving the current editor text. Draft edits validate before the atomic update; rejected edits retain the previous stored values.
- The detail actions recheck lifecycle eligibility, collect and trim Storno reasons, and require confirmation for finalization, Gutschrift, replacement, and conversion. The widget suite exercises the confirmation/cancel/write behavior, including incoming-invoice Storno. Reciprocal relationship reads, missing-target state, and navigation are covered.
- The editor and document detail preview use the canonical invoice calculator for net, VAT, and gross totals, including header discounts, and suppress stale totals after invalid input. The embedded detail row label now follows the input mode (`Netto` or `Brutto`) instead of labeling a net line amount as gross.
- Prior findings on discount round-tripping, reordered row identity, lifecycle confirmation coverage, Storno dialog state lifetime, and relationship navigation are resolved in the current snapshot and covered by the passing scoped run.

### Verdict

VERDICT: REVISE

The implementation findings reviewed here are resolved and the scoped suite passes. The change remains unready for approval until its test-plan ledger records the completed results rather than reporting every test as pending.

CHANGES_APPLIED: yes

## Independent Implementation Review — Round 5 (2026-10-13)

### Review update

The Round 4 test-plan finding is resolved: `test-plan.md` now records all 36 planned cases as passed and its coverage note records the final aggregate result. The net-mode document line label also matches the displayed net line amount. The exact 11-file aggregate was rerun against this implementation snapshot and completed with exit 0: **76 tests passed**.

### Findings

None.

### Verdict

VERDICT: APPROVE

The reviewed implementation and test artifacts now agree. The scoped suite covers customer selection and save validation, draft edits and ordering, discount-aware authoritative preview, lifecycle capability and confirmations, reciprocal relationships, correction artifact rollback, and accounting integrity.

CHANGES_APPLIED: yes
