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

## Rebuttals

Round 2's findings were rechecked: the Beleg drop zone now rejects generic CSV/TIFF; crash recovery covers Storno without assuming the source is a draft; importer recovery removes a renamed but uncommitted source; a successful finalized-conversion scenario is present; and batch print/email are deferred. Customer/supplier unlinking and `kunden_belege` deletion behavior are now specified, but the remaining schema mismatch is finding 1.

Because this round is also `REVISE`, rounds 2 and 3 are consecutive `REVISE` results. The Anvil review gate says to stop and escalate rather than proceed to implementation.
