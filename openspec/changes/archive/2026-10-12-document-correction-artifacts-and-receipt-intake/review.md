## Review Metadata

- **Review round**: 3
- **Prior round**: Round 2 returned `REVISE`; its findings were supplied in the review task summary. No prior review artifact exists in this change directory.
- **Reviewer context**: Fresh-context independent subagent
- **Tool restrictions**: Read-only artifact/source review; no implementation edits or tests. This file persists the already-issued verdict.
- **Artifacts reviewed**: `proposal.md`, `design.md`, all six delta specs; maintained `documents`, `accounting`, `desktop-drag-drop`, `document-artifact-transaction`, `receipts-and-payment-reconciliation`, and `stammdaten` specs; `docs/06-dokumente.md`, `docs/03-kunden-stammdaten.md`, `DESIGN.md`; relevant invoice lifecycle, database, routing, file-drop, and PDF source; related invoice-workspace proposal and review.
- **Validation**: `openspec validate document-correction-artifacts-and-receipt-intake --type change --strict --json` passed (1/1); `openspec validate --specs --strict` passed (54/54). Structural validation does not establish semantic correctness. No tests were run, as requested.

<!-- STALENESS: this verdict applies to the artifact contents reviewed for round 3. -->

## Findings

### 🔴 Critical (blocking)

1. **Customer Beleg ownership still describes the wrong schema.** `specs/stammdaten/spec.md:5-10` says each Beleg has a `kunde_id FK`, while the repository models customer links in the `kunden_belege(kunde_id, beleg_id)` join table (`lib/core/db/database.dart:669-674`). The Belege table itself has no `kunde_id` column (`lib/core/db/database.dart:578-591`). This conflicts with the delta's later instructions to unlink `kunden_belege` and can make deletion checks miss existing customer associations. Make the join table the explicit canonical customer-link model and require deletion checks to use it.

### 🟡 Moderate

2. **ZIP verification does not explicitly bound actual streamed content or require an exact manifest match.** `specs/accounting/spec.md:5` caps *declared* uncompressed size and verifies hashes for included files. Specify that verification counts bytes actually emitted while streaming and aborts at the content limit, and that the archive's normalized file-entry set must exactly match the manifest. Otherwise malformed size metadata or unmanifested entries may escape the stated bounds or completeness check.

3. **The export period's record-selection rule is open, but the plan does not gate export work on resolving it.** The design says date-selection semantics require decisions before implementation (`design.md:60`) and asks whether document date or accounting date controls inclusion (`design.md:102`). The migration plan proceeds to implement the period export without explicitly placing that decision before the work (`design.md:85-93`). Add this as a prerequisite to the export step so a complete period snapshot has a defined membership rule, including cross-period corrections.

4. **The documentation alignment is promised but missing from the migration plan.** The proposal promises documentation alignment (`proposal.md:12`), but the current `docs/06-dokumente.md:5` claims all finalized documents are GoBD-compliant, describes bundles for mailing (`:246-267`), and says expired receipts are automatically cleaned up (`:293-300`). The latter two conflict with the new deferred batch-email and no-auto-purge contracts; the compliance claim conflicts with the design's no-certification boundary. Add an explicit documentation-update step and reconcile those statements.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable.

CHANGES_APPLIED: n/a

## Review Metadata — Round 6

- **Review round**: 6
- **Prior round**: Round 5 returned `REVISE` only because the verification record was stale; the classification mapping was confirmed correct.
- **Reviewer context**: Fresh-context independent subagent
- **Tool restrictions**: Read-only artifact review; no edits, tests, or archive operation. Append-only to this file.
- **Artifacts reviewed**: Corrected `specs/documents/spec.md` ADDED/MODIFIED mapping, matching maintained `openspec/specs/documents/spec.md`, `tasks.md`, and `verify.md`.
- **Validation**: Reviewer did not independently run tests or validators. The current change validation passed 1/1 and maintained-spec validation passed 63/63 before this review.

<!-- STALENESS: this verdict applies to the artifact contents reviewed for round 6. -->

## Findings

1. **Requirement classification and maintained spec — CLOSED.** The customer shared-evidence requirement is correctly classified as ADDED and matches the maintained requirement. Other MODIFIED requirements exist in the baseline spec.
2. **Verification record — CLOSED.** `verify.md` reflects the corrected mapping and records this review as pending until its verdict is entered.

No unresolved findings.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable.

CHANGES_APPLIED: n/a

## Review Metadata — Round 5

- **Review round**: 5
- **Prior round**: Round 4 returned `APPROVE`; only the delta classification was repaired after that approval.
- **Reviewer context**: Fresh-context independent subagent
- **Tool restrictions**: Read-only artifact review; no edits, tests, or archive operation. Append-only to this file.
- **Artifacts reviewed**: `specs/documents/spec.md` classification for `Customer document links preserve shared evidence`, the matching maintained requirement in `openspec/specs/documents/spec.md`, and `verify.md` review/delivery state.
- **Validation**: Reviewer did not independently run validators or tests; current `openspec validate` results are recorded in `verify.md`.

<!-- STALENESS: this verdict applies to the artifact contents reviewed for round 5. -->

## Findings

1. **Requirement classification — CLOSED.** `Customer document links preserve shared evidence` is correctly classified as `ADDED`; the normalized requirement matches the maintained `documents` specification. Other `MODIFIED` requirement headings exist in the baseline.
2. **Verification record — OPEN.** `verify.md` still identifies Round 4 as the latest review and says the delta specs were unchanged after approval. Update the review and delivery record to reflect this round and the archive recovery before completing the change.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable.

CHANGES_APPLIED: n/a

## Rebuttals

Round 2's findings were rechecked: the Beleg drop zone now rejects generic CSV/TIFF; crash recovery covers Storno without assuming the source is a draft; importer recovery removes a renamed but uncommitted source; a successful finalized-conversion scenario is present; and batch print/email are deferred. Customer/supplier unlinking and `kunden_belege` deletion behavior are now specified, but the remaining schema mismatch is finding 1.

Because this round is also `REVISE`, rounds 2 and 3 are consecutive `REVISE` results. The Anvil review gate says to stop and escalate rather than proceed to implementation.

## Review Metadata — Round 4

- **Review round**: 4
- **Prior round**: Round 3 returned `REVISE` with 4 findings (Beleg ownership; ZIP streamed bound + exact manifest; period-rule gating; docs alignment). Repairs applied per task summary.
- **Reviewer context**: Fresh-context independent subagent
- **Tool restrictions**: Read-only artifact/source review; no shell, no tests. Append-only to this file.
- **Artifacts reviewed**: `design.md`, delta specs `stammdaten`, `accounting`, `documents`; `review.md` rounds 1–3 finding text; `lib/core/db/database.dart` `kunden_belege` definition (lines 702–708) for schema cross-check.
- **Validation**: No `openspec validate` and no tests run, as requested. Semantic review only.

<!-- STALENESS: this verdict applies to the artifact contents reviewed for round 4. -->

## Findings verification (Round 3 → Round 4)

1. **Beleg ownership — CLOSED.** `specs/stammdaten/spec.md:5-10` now names `kunden_belege(kunde_id, beleg_id, rolle)` the canonical customer-link model, states a Beleg has no `kunde_id` column, requires deletion checks to query `kunden_belege`, and requires all customer/supplier/invoice/journal/template/package relationships removed first. Normative (`MUST`, `SHALL`, `SHALL NOT`). Consistent with `specs/documents/spec.md:64-67, 91-95, 107-114` (join-table unlink/delete rules) and `design.md:42`. `rolle` column verified present in `database.dart:708`, so no new schema invented.
2. **ZIP streamed bound + exact manifest — CLOSED.** `specs/accounting/spec.md:5` now rejects actual streamed content above 5 GiB, requires counting actual bytes emitted while streaming with abort-and-invalid on breach, and requires the normalized archive file-entry set to exactly match the manifest (no missing, no unmanifested). Normative (`SHALL`, `MUST NOT`). New scenario `:32-35` covers unmanifested/omitted entries and declared-vs-actual size overflow. Mirrored in `design.md:58, 60`.
3. **Period-rule gating — CLOSED.** `design.md:91` (migration step 5) now settles the effective-date period-membership rule as an explicit prerequisite before GoBD export implementation, with the rule restated inline (journal date, reporting period, immutable document date; correction in its own period, source as linked evidence). Consistent with `specs/accounting/spec.md:5` and `design.md:56-58`. Normative (`SHALL`, `SHALL NOT`).
4. **Docs alignment — CLOSED.** `design.md:94` (migration step 8) now adds the explicit `docs/06-dokumente.md` update step and reconciles all three conflicting statements (finalized-documents GoBD-compliance claim, bundle-for-mailing description, expired-receipt automatic-cleanup) by removing the unsupported compliance, batch-send, and automatic-purge claims. Consistent with the deferred batch-email (`design.md:26, 52, 72`) and no-auto-purge (`specs/documents/spec.md:68-69`, `specs/stammdaten/spec.md:12-13`, `design.md:42, 74, 87`) contracts.

New conflicts: none found. No `kunde_id`-column language remains outside the historical finding quote. No new normative contradictions between delta specs and design decisions detected in this pass.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable.

CHANGES_APPLIED: n/a
