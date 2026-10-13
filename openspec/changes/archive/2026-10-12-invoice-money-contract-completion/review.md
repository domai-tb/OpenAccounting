## Review Metadata

- **Review round**: 2
- **Prior round**: APPROVE_WITH_CHANGES; four required corrections were requested.
- **Reviewer context**: fresh-context local subagent; focused re-check of the four required changes
- **Tool restrictions**: read-only inspection of reviewed artifacts; only this `review.md` was authored; no tests run
- **Artifacts reviewed**: proposal.md, design.md, specs/invoice-money-contract/spec.md, specs/documents/spec.md, specs/db/spec.md; comparison limited to the four Required Changes from round 1
- **Validation**: strict change validation is reported as passing; not rerun in this focused re-check; no tests run

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

None open. All four Moderate findings from round 1 are resolved, as recorded under Rebuttals.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts

**Detected:** none detected.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes (if APPROVE WITH CHANGES)

1. **Fixed and accepted by reviewer:** The duplicate validation-code paragraphs were replaced by one closed list containing `valueOutOfRange` and the scenario error codes.
2. **Fixed and accepted by reviewer:** The spec and design bound rounded line, bucket, tax, discount, subtotal, and header amounts; require overflow-safe arithmetic and `valueOutOfRange`; and add a derived-gross overflow boundary scenario.
3. **Fixed and accepted by reviewer:** Scenarios now assert discount-before-single-rounding, a mismatched line amount rejected before insertion, a mixed-rate percentage rounded once and allocated by tie rule, and discounted headers after save/reload.
4. **Fixed and accepted by reviewer:** The modified requirements restore the current-date Storno rule, `GS-YY####` Gutschrift format, and the `NUMERIC(12,2)` currency / `NUMERIC(12,4)` article-price declarations while expressly stating SQLite does not enforce precision or scale.

CHANGES_APPLIED: yes


## Rebuttals

1. **Round 1 finding: contradictory validation error code set — fixed and accepted by reviewer.** `invoice-money-contract/spec.md` has one canonical closed list at line 115, including `valueOutOfRange`.
2. **Round 1 finding: undefined maximum for calculated amounts — fixed and accepted by reviewer.** `design.md` and the invoice-money requirement cap every rounded currency result at `9,999,999,999.99`, require overflow-safe exact arithmetic, and the derived-amount scenario checks rejection before persistence.
3. **Round 1 finding: missing rounding, mismatch, and persistence scenarios — fixed and accepted by reviewer.** The four requested mechanically assertable scenarios are present in the invoice-money spec, including expected amounts and the pre-insert failure point.
4. **Round 1 finding: dropped maintained behavior — fixed and accepted by reviewer.** The documents delta retains `storno_datum` as the current date and `GS-YY####`; the db delta retains the declared NUMERIC conventions and disclaims database-enforced scale/precision.

---

## Round 3 Review Metadata

- **Review round**: 3
- **Prior round**: Round 2 was `APPROVE_WITH_CHANGES`; the four accepted corrections remain present.
- **Review date**: 2026-10-11 16:19 UTC
- **Reviewer context**: Fresh independent local subagent; full semantic pass over the amended contract, scenario map, task ordering, prior review, and relevant maintained specs.
- **Artifacts reviewed**: `proposal.md`, `design.md`, all three change specs, `test-plan.md`, `tasks.md`, the Round 2 review above, and maintained `accounting`, `documents`, and `db` specs. Working-tree versions were reviewed; `documents` and `db` are modified in the worktree.
- **Validation**: `openspec validate invoice-money-contract-completion --type change --strict --json` passed (1/1). No tests were run, as requested.
- **Tool restrictions**: No source, test, or spec files were edited; only this review entry was authored.

### Findings

#### 🔴 Critical (blocking)

1. **Invoice VAT rounding conflicts with the maintained accounting contract** (`openspec/changes/invoice-money-contract-completion/specs/invoice-money-contract/spec.md:34`, `openspec/specs/accounting/spec.md:466-476`)
   - **Problem**: The change calculates VAT once per tax bucket, while the maintained accounting scenarios say to calculate and round it per position. Three net lines of `0.03` at 19% produce VAT `0.03` under per-position rounding (`0.01` each) and `0.02` under bucket rounding (`0.09 × 19%`). The proposal says no tax-rate or posting-policy change, but these rules produce different invoice totals.
   - **Required change**: Choose one rounding rule and make the invoice contract and maintained accounting requirement agree. If bucket rounding is intended, include the accounting capability in this change, state the tax-rounding change in the proposal, and add a multi-line regression for the boundary case.

#### 🟡 Moderate

2. **Incoming Storno coverage does not verify the required amount reversal** (`openspec/changes/invoice-money-contract-completion/specs/invoice-money-contract/spec.md:101-106`, `test/integration/audit/invoice-document-posting-boundaries_test.dart:499-519`)
   - **Problem**: The contract requires an incoming invoice Storno to invert line, net, VAT, and gross amounts, but the mapped regression checks only that the input-tax claim has an equal-and-opposite amount. A Storno could pass this test while keeping the invoice balances with the wrong sign.
   - **Required change**: Extend the incoming Storno scenario and regression to assert the source and Storno line/header signs as exact inverses, alongside the linked input-tax reversal.

3. **The converted-header scenario leaves its VAT rate implicit** (`openspec/changes/invoice-money-contract-completion/specs/invoice-money-contract/spec.md:12-15`, `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart:188-208`)
   - **Problem**: The scenario expects VAT `17.10` from a discounted net of `90.00` but does not state a 19% rate. The executable regression supplies `ustSatz: 19`, so the artifact and test currently rely on different setup details.
   - **Required change**: State that the Angebot line is taxed at 19% in the scenario so its expected headers are reproducible from the contract.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: REVISE

### Required Changes

1. Reconcile per-position versus per-bucket VAT rounding with the maintained accounting spec and add a discriminating multi-line scenario.
2. Assert incoming Storno line and header reversals as well as input-tax reversal.
3. Specify 19% VAT in the converted-discounted-header scenario.

CHANGES_APPLIED: yes

### Rebuttals

The four Round 1 findings accepted in Round 2 remain resolved. This review found new semantic and coverage gaps after the discounted-conversion and incoming-Storno amendments; strict OpenSpec validation does not detect these conflicts.

---

## Round 4 Review Metadata

- **Review round**: 4
- **Prior round**: Round 3 was `REVISE`; re-checked its three required corrections against the current worktree.
- **Review date**: 2026-10-11 16:26 UTC
- **Reviewer context**: Fresh independent local subagent; reviewed current change artifacts, maintained accounting/documents/db requirements, mapped tests, and task numbering.
- **Artifacts reviewed**: `proposal.md`, `design.md`, all change specs, `test-plan.md`, `tasks.md`, the prior review, maintained `accounting`, `documents`, and `db` specs, and the mapped invoice conversion and incoming-Storno test bodies.
- **Validation**: `openspec validate invoice-money-contract-completion --type change --strict --json` passed (1/1). No tests were run.
- **Tool restrictions**: Only this Round 4 entry was authored; no source, test, or spec files were edited, and nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

1. **The documents discount contract still specifies bucket-level VAT** (`openspec/changes/invoice-money-contract-completion/specs/documents/spec.md:62-64`, `openspec/specs/documents/spec.md:285-287`)
   - **Problem**: The invoice-money contract and design now require VAT to be rounded per discounted position and summed (`specs/invoice-money-contract/spec.md:32-44`, `design.md:31-33`), matching maintained accounting (`openspec/specs/accounting/spec.md:466-476`). The changed documents requirement still says VAT is recalculated from each discounted bucket, and the maintained documents requirement retains the same wording. This change modifies `documents`, so synchronizing its delta would preserve the contradiction. At the discriminating 3 × `0.03` at `19.00%` boundary, per-position rounding yields `0.03` VAT while rounding the `0.09` bucket yields `0.02`.
   - **Required change**: Keep buckets for allocating document-discount cents, but state in both the documents delta and maintained documents requirement that VAT is rounded per discounted position and then summed.

#### 🟡 Moderate

None beyond the blocking finding.

#### Round 3 finding status

- **Incoming Storno regression**: resolved. The mapped test checks the source line and net/VAT/gross headers, asserts the Storno line and all three headers are their exact negatives, and checks the linked input-tax reversal is equal and opposite.
- **Discounted conversion VAT rate**: resolved. The scenario specifies `19.00%`; the mapped test creates its Angebot line with `ustSatz: 19` and checks the discounted net, VAT, and gross headers.
- **Per-position VAT regression**: the invoice-money spec now has the discriminating three-line `0.03` scenario and the mapped test asserts 3 cents VAT. The cross-capability documents conflict above still prevents this correction from being complete.

### Scenario and task mapping

All 45 scenarios defined in the three change specs have a named test-plan row. The plan has 47 rows because it also tracks two additional regression tests (PDF line discount and gross-mode discount) that are not separate spec scenarios. Task numbers are unique and contiguous within groups 1–12; the ledger contains 146 tasks, with no numbering collision.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: REVISE

### Required Changes

1. Align the changed and maintained documents discount requirements with per-position VAT rounding after discount allocation; retain bucket allocation only for distributing discount cents.

CHANGES_APPLIED: no

---

## Round 5 Review Metadata

- **Review round**: 5
- **Prior round**: Round 4 was `REVISE`; re-checked its discount-rounding finding and the stated regression refinements.
- **Review date**: 2026-10-11 16:33 UTC
- **Reviewer context**: Fresh independent local subagent; semantic review of current artifacts and mapped tests.
- **Artifacts reviewed**: proposal, design, all three change specs, test plan, tasks, prior review, maintained accounting and documents specs, and the mapped calculator, conversion, and incoming-Storno tests.
- **Validation**: `openspec validate invoice-money-contract-completion --type change --strict --json` passed (1/1); `openspec validate --specs --strict` passed (62/62). Tests were not rerun by this reviewer.
- **Tool restrictions**: Only this Round 5 entry was authored; no source, test, or spec files were edited, and nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

None.

#### 🟡 Moderate

None.

### Round 4 finding status

- **Discounted VAT rounding**: resolved. The changed and maintained documents requirements allocate discount cents by VAT bucket and persisted position, then round VAT per discounted position and sum it (`specs/documents/spec.md:62-64`, `openspec/specs/documents/spec.md:285-287`). This agrees with the maintained accounting requirement (`openspec/specs/accounting/spec.md:466-476`).
- **Three-line VAT boundary**: the invoice-money requirement and mapped test use three `0.03` net lines at `19.00%` and expect three cents VAT (`specs/invoice-money-contract/spec.md:41-44`, `test/features/rechnungen/invoice_money_contract_test.dart:143-174`).
- **Persisted-position tie**: the `0.03` / `0.15` lines with a `0.03` discount expect position 1 to receive the remainder cent and totals of 15/2/17 cents (`specs/invoice-money-contract/spec.md:46-49`, `test/features/rechnungen/invoice_money_contract_test.dart:176-203`). This also distinguishes per-position VAT after discount from bucket-level VAT.
- **Gross-mode rounding and discount**: the updated scenario and test cover both undiscounted totals of 6/0/6 cents and totals of 4/0/4 cents after a 2-cent discount across two 3-cent gross lines (`specs/invoice-money-contract/spec.md:51-54`, `test/features/rechnungen/invoice_money_contract_test.dart:205-223`).
- **Incoming Storno**: the changed documents scenario and mapped test assert the source line and all three headers, exact negative Storno line/header values, and one equal-and-opposite input-tax claim (`specs/documents/spec.md:17-20`, `test/integration/audit/invoice-document-posting-boundaries_test.dart:729-799`), consistent with maintained accounting (`openspec/specs/accounting/spec.md:888-891`).
- **Discounted conversion**: the scenario now specifies `19.00%`; the mapped test uses that rate and asserts discounted net/VAT/gross values of `90.00`/`17.10`/`107.10` (`specs/invoice-money-contract/spec.md:12-15`, `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart:176-208`).

### Scenario and task mapping

All 47 scenarios across the three change specs have named test-plan rows. The plan has 49 rows, including two supplemental regression rows. Its five pending regression rows are marked red and have executable tests plus test-before-implementation tasks; the mapped order is test, implementation, refactor. The supplied baseline failures identify the expected VAT, tie, gross-mode, and incoming-Storno failures. No test was run during this review.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: APPROVE

### Required Changes

None.

CHANGES_APPLIED: yes

---

## Round 12 Review Metadata

- **Review round**: 12
- **Prior round**: Round 11 checked plan/ledger consistency only; this fresh pass inspects the signed-line source path and generated-PDF assertions.
- **Review date**: 2026-10-12 16:30 UTC
- **Reviewer context**: Independent focused review of `_pdfPositionsFromRows`, its snapshot construction and callers, the correction-PDF regression, and the invoice change's delta specs, task ledger, and test plan.
- **Mapped tests inspected**: `test_finalized_correction_has_a_readable_artifact`, including the extracted Storno, Gutschrift, and Gutschrift-Storno position rows.
- **Validation**: No tests or validators were run by this reviewer. The test plan records the focused PDF regression as green; the full VM suite is still running and is not claimed as passed here.
- **Tool restrictions**: No source or test file was edited. Only this review entry was appended; nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

None in the reviewed signed-line source/test change.

#### 🟡 Moderate

None in the reviewed signed-line source/test change.

### Review evidence

- `_pdfPositionsFromRows` derives `lineSign` from the persisted line amount, computes unsigned net/VAT/gross cents, and applies the sign to all three values. Its fallback also takes the absolute stored amount before applying the persisted sign.
- `_buildPdfSnapshot` uses this mapping for `finalizeRechnung`, `stornoRechnung`, and `createGutschrift`, covering the source invoice and both correction directions.
- The regression parses the generated PDF text and asserts the full `Beratung` row with negative net/VAT/gross for Rechnung Storno and Gutschrift, and positive amounts for a Gutschrift Storno. The `100.00` position values differ from the document totals, so the row assertions verify line amounts rather than merely matching headers.
- The current test plan maps this regression to row 21 and records that an unsigned-line mutation failed while the Storno header stayed negative, then passed after restoring persisted-sign mapping. All 52 mapped rows are green.
- Tasks 8.22 and 8.23 are checked. Task 8.24 remains open for refactoring and the focused plus full-suite rerun; tasks 12.2–12.4 remain open for verification, archive, and commit. The ledger is 154/158 checked, with exactly those four tasks open.
- Review.md contains two Round 8 entries with conflicting verdicts. This newer Round 12 supersedes both Round 8 entries and the stale signed-line follow-up in Round 10 for the correction-PDF issue. Full-suite and archive gates remain separate and open.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: APPROVE

### Required Changes

None for the signed-line source/test change. Keep task 8.24 and task 12.2 open until their required focused and full-suite evidence is complete.

CHANGES_APPLIED: yes

## Round 6 Review Metadata

- **Review round**: 6
- **Prior round**: Round 5 was `APPROVE`; re-checked the current Storno, Gutschrift, allocator, task, and test-plan changes.
- **Review date**: 2026-10-12 15:42 UTC
- **Reviewer context**: Fresh independent semantic review of the current proposal/design, all three delta specs, maintained db/accounting/documents requirements, task ledger, test plan, and relevant mapped test bodies.
- **Mapped tests inspected**: Storno 500/501 boundary, standalone Gutschrift source field, incoming Storno balance and input-tax reversal, invoice discount allocation/tie cases, shared allocator tie and zero-weight cases, and Storno PDF artifact.
- **Validation**: No tests or validators were run by this reviewer. The implementation owner reports 1,428 VM tests passed, analyzer clean, strict change validation 1/1, and maintained specs validation 62/62; those results were not independently rerun here.
- **Tool restrictions**: Only this review entry was authored. No implementation, spec, task, or test-plan files were edited; nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

1. **The task ledger and prescribed completion trailer contradict each other** (`tasks.md:1, 191-194`; `test-plan.md:62`)
   - **Problem**: The change has 155 task items, but only 47 are checked and 108 remain open. The test-plan says all 51 mapped tests are green, which does not close the unchecked red/implementation/refactor tasks or verification, synchronization, archive, and commit tasks. In particular, task 12.2 is still open, and tasks 12.3–12.4 are open, while task 12.4 already prescribes `OpenSpec-Tasks: 155/155`.
   - **Required change**: Reconcile task checkboxes against recorded evidence and keep the final trailer count accurate. Do not claim 155/155 until all 155 tasks, including verify/sync/archive/commit, are actually complete.

#### 🟡 Moderate

2. **The maintained Gutschrift requirement still names the obsolete source column** (`openspec/specs/documents/spec.md:124-127`; delta `specs/documents/spec.md:62-65`)
   - **Problem**: The maintained scenario says `gutschrift_zu_rechnung_id`, while the corrected delta and mapped standalone-Gutschrift test use the actual `gutschrift_von` field. Strict validation does not detect this maintained-contract mismatch.
   - **Required change**: During task 12.3 synchronization, replace the stale maintained field name with `gutschrift_von` and validate the synchronized specs.

3. **Largest-remainder precedence lacks a discriminating regression** (`specs/invoice-money-contract/spec.md:86-98`; `test-plan.md:50-51`)
   - **Problem**: The shared allocator contract requires distributing leftover cents by descending fractional remainder, but its mapped tests cover only an equal-remainder key tie and a zero-total error. The mapped invoice cases also use exact or tied shares. A regression that sorts only by stable key instead of largest remainder would pass the current mapped cases.
   - **Required change**: Add one non-tied case and map it to a test, for example allocate 3 cents across weights `{a: 1, b: 2, c: 4}` and expect `{a: 0, b: 1, c: 2}`. Record its red/green evidence and task mapping.

### Round 5 finding status

- **VAT rounding conflict**: remains resolved. The invoice and documents deltas round VAT per discounted position; this matches the maintained accounting and documents requirements.
- **Incoming Storno**: remains resolved. The mapped test checks source and Storno line/header signs and the equal-and-opposite input-tax claim.
- **Discounted conversion VAT rate**: remains resolved; the scenario and test use 19% and assert the discounted headers.
- **New Storno reason boundary**: the mapped test rejects 501 characters before creating a Storno and accepts/persists exactly 500.
- **Storno PDF mapping**: the mapped artifact regression checks the title, current and original dates, signed header totals, and absence of payment details. Its cross-feature test location is a valid shared integration test for this scenario.
- **Gutschrift source field**: corrected in the delta and test (`gutschrift_von`); the maintained-spec mismatch above remains open until synchronization.

### Mixed-category EÜR scope assessment

Removing the invoice-to-EÜR production regression from this change is a sound boundary: this delta defines the shared cent allocator, while the balanced-journal change owns persisted category/account mapping and contains the blocked mixed-category partial-settlement scenario and test task. The allocator is called by both invoice discount calculation and settlement allocation. Keep that downstream production regression blocked until this contract is accepted and do not count the dependent integration behavior as verified by the two helper tests here.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: REVISE

### Required Changes

1. Reconcile the 155-task ledger and completion trailer to actual evidence.
2. Synchronize the maintained Gutschrift field name to `gutschrift_von`.
3. Add a non-tied largest-remainder regression and map its evidence.

CHANGES_APPLIED: yes

---

## Round 7 Review Metadata

- **Review round**: 7
- **Prior round**: Round 6 was `REVISE`; re-checked its three required changes and the current contract boundaries.
- **Review date**: 2026-10-12 15:50 UTC
- **Reviewer context**: Fresh independent review of the current proposal/design, all three delta specs, maintained db/accounting/documents requirements, tasks, test plan, relevant production allocator callers, and mapped test bodies.
- **Mapped tests inspected**: The new non-tied largest-remainder case, equal-remainder and zero-weight cases, invoice discount callers, the 500/501 Storno boundary, standalone Gutschrift source link, incoming Storno reversal, and Storno PDF artifact.
- **Validation**: No tests or validators were run by this reviewer. The current plan records 52 green rows, including the focused EÜR allocator suite and its mutation evidence; the implementation owner reports focused EÜR and strict validation results are available.
- **Tool restrictions**: Only this review entry was authored. No implementation, spec, task, or test-plan files were edited; nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

None.

#### 🟡 Moderate

None.

### Round 6 finding status

- **Task count and completion trailer**: resolved. Task 12.4 now derives the trailer from the actual completed/total count at commit time. The ledger currently has 53 of 155 tasks checked and 102 open, with verification, synchronization, archive, and commit still open; it therefore records an in-progress change and does not claim completion.
- **Maintained Gutschrift source field**: resolved. The maintained documents scenario, delta scenario, and mapped database assertion now all use `gutschrift_von`.
- **Largest-remainder precedence**: resolved. The new scenario and mapped EÜR allocator test use amount 2 over weights `a=2`, `b=3`, `c=5`, expecting `a=0`, `b=1`, `c=1`. The test distinguishes descending remainder order from stable-key-only ordering, and the test-plan records mutation red/green evidence.

### Round 5 findings and cross-capability boundary

- The per-position VAT rule still agrees with maintained accounting and documents requirements.
- The Storno 500/501 boundary, incoming Storno line/header/input-tax reversal, discounted conversion VAT rate, and Storno PDF date/signed-header/payment-detail assertions remain mapped to executable tests.
- The mixed-category EÜR production regression remains correctly delegated to the balanced-journal change, which owns persisted category/account mapping and keeps its integration test blocked until this money contract is accepted. In this change, the shared allocator is used by both invoice discount calculation and settlement allocation; its helper contract is covered by stable-tie, non-tied-remainder, and zero-weight tests. Those helper tests are not being presented as end-to-end mixed-category EÜR verification.
- Maintained db precision requirements and the maintained accounting/document VAT-rounding requirements remain aligned with the delta specs.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: APPROVE

### Required Changes

None for semantic review. The 102 open tasks still prevent verify/archive/commit completion; task 12.2–12.4 must remain open until their evidence and actions are complete.

CHANGES_APPLIED: yes

---

## Round 8 Review Metadata

- **Review round**: 8
- **Prior round**: Round 7 was `APPROVE`; this fresh review re-checked the later maintained-spec synchronization and current task evidence.
- **Review date**: 2026-10-12 16:20 UTC
- **Reviewer context**: Fresh independent read-only review limited to the prior sync findings, the destination of the added invoice-money capability, and the current task/test-plan counts.
- **Artifacts inspected**: Current maintained db and documents specs, all three change delta specs, task ledger, test plan, and prior review findings.
- **Validation**: No tests or validators were run by this reviewer. The test plan records 52 of 52 mapped rows green; that is focused evidence and does not replace task 12.2's full-suite and analyzer requirements.
- **Tool restrictions**: Only this review entry was authored. No implementation, maintained spec, task, or test-plan files were edited; nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

None.

#### 🟡 Moderate

None.

### Round 7 follow-up

- The maintained db spec retains the unrelated V8-to-v9 migration scenario. Its current diff contains only the invoice precision contract changes.
- The maintained documents Storno requirement now explicitly covers outgoing and incoming invoices, and includes both the incoming input-tax reversal scenario and the Storno PDF date, signed-amount, and no-payment-details scenario from the delta.
- The `invoice-money-contract` delta is explicitly `ADDED`; it is a separate capability with no maintained directory yet and will be created by the archive step. Its lifecycle-validation and stable-error requirements therefore do not need to be duplicated into db or documents.
- The ledger is 152/155, with only tasks 12.2–12.4 open. Task 12.1 is checked, and the test plan has 52 mapped rows, all green. This supports the focused implementation evidence while leaving full verification, sync/archive validation, and commit correctly open.
- This round replaces Round 7's stale 53/155 snapshot for the reviewed ledger state.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: APPROVE

### Required Changes

None for semantic review. Tasks 12.2–12.4 still gate verify, archive, and commit completion.

CHANGES_APPLIED: yes

---

## Round 8 Review Metadata

- **Review round**: 8
- **Prior round**: Round 7 was `APPROVE`; fresh review after test strengthening and ledger/evidence updates.
- **Review date**: 2026-10-12 16:20 UTC
- **Reviewer context**: Read-only semantic/TDD review of the proposal, design, all three delta specs, maintained db/documents/accounting/einkommen requirements, task ledger, all 52 mapped test bodies, relevant invoice/calculator/PDF/database paths, and the current worktree diff for scope contamination.
- **Mapped tests inspected**: All 52 test-plan rows, including the strengthened position-discount case in task 5.4, all three shared-allocation tests, SQLite precision and range tests, invoice lifecycle/correction tests, incoming Storno input-tax reversal, and generated PDF artifact assertions.
- **Validation**: No tests or validators were run by this reviewer. The implementation owner reports 1,429 VM tests passed, analyzer clean, strict change validation 1/1, maintained specs validation 62/62, and `git diff --check` clean; these results were not independently rerun.
- **Tool restrictions**: Only this review entry was authored. No implementation, delta spec, task, or test-plan files were edited; nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

1. **Correction PDF line amounts lose their signs** (`lib/pages/rechnungen/rechnungen_datasource.dart:1822-1871`; `openspec/changes/invoice-money-contract-completion/specs/documents/spec.md:33-36, 43-50`; `specs/invoice-money-contract/spec.md:119-131`)
   - **Problem**: `_pdfPositionsFromRows` recomputes each displayed line from the positive stored quantity and unit price via `VorschauService.lineTotal`, then emits positive net, VAT, and gross amounts. It does not apply the sign from the persisted correction line's `gesamt`. `PdfGenerator` renders these position amounts as supplied. Consequently, a negative Storno or Gutschrift has negative header totals but positive line amounts; a positive Storno of a Gutschrift also displays positive line amounts by coincidence rather than because its sign was derived correctly.
   - **Test gap**: `test_finalized_correction_has_a_readable_artifact` checks the Storno's signed header totals, title, dates, and missing payment block (`test/features/document_artifact_transaction/document_correction_artifacts_and_receipt_intake_test.dart:124-178`), but does not assert signed PDF line net/VAT/gross. Its Gutschrift and Gutschrift-Storno checks only assert persisted net headers and artifact existence.
   - **Required change**: Preserve/apply each persisted correction line's sign when constructing PDF position snapshots. Strengthen the mapped artifact regression to inspect the generated PDF text and assert negative line amounts for Rechnung-to-Storno and Gutschrift, plus positive line amounts for Gutschrift-to-Storno. Keep the existing signed-header, title/date, and no-payment assertions.

#### 🟡 Moderate

1. **Current worktree contains substantial unrelated feature scope** (`git status --short`; `lib/core/db/database.dart`; `lib/core/db/migrations.dart`; shared router, services, localization, docs, and tests)
   - **Problem**: The current status contains 97 changed or untracked paths across invoice money, balanced journal, document correction, receipt intake, recurring, settings, and other capabilities. Shared files such as `database.dart` and `migrations.dart` contain hunks from several changes. A whole-worktree or whole-file commit would include unrelated work.
   - **Required change**: Preserve feature-level staging when committing; do not treat the current mixed diff as the invoice change's commit scope.

### Round 7 finding status and test evidence

- The maintained documents source field remains aligned as `gutschrift_von`.
- The shared allocator now has a discriminating non-tied largest-remainder test (`2` cents across weights `a=2`, `b=3`, `c=5`), alongside equal-remainder and positive-amount/zero-weight cases.
- Task 5.4's strengthened position-discount case uses three `0.3350` items at 10% off and expects 90 cents. The test-plan records that rounding before the discount fails with `aggregateMismatch` and restoring discount-before-rounding passes.
- The live plan contains 52 mapped rows, all marked green. The ledger currently has 152 of 155 tasks checked; verify, archive/sync, and commit tasks remain open, so the change is still in progress.
- Per-position VAT, gross-mode rounding, fixed and percentage discount allocation, validation metadata, Storno 500/501 boundary, source-header validation, incoming input-tax reversal, and Storno dates/header PDF evidence remain aligned between specs and their mapped test bodies. The mixed-category EÜR production regression remains correctly owned by the balanced-journal change; the shared helper tests are not presented as that integration proof.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: REVISE

### Required Changes

1. Render correction PDF line amounts with the same signed values persisted for each correction line, and add PDF assertions for negative Rechnung Storno/Gutschrift line amounts and positive Gutschrift-Storno line amounts.
2. Keep commits scoped to the invoice change despite the mixed worktree; stage only invoice-owned paths/hunks and the required maintained-spec synchronization.

CHANGES_APPLIED: yes

---

## Round 9 Review Metadata

- **Review round**: 9
- **Prior round**: Round 8 was `REVISE` on correction-PDF line signs; this artifact-only pass checks the added plan row and tasks 8.22–8.24 against that required change.
- **Review date**: 2026-10-12 16:23 UTC
- **Reviewer context**: Read-only review of the current test-plan row, coverage notes, task sequence, and relevant existing delta scenarios. No source or test-body inspection was performed in this round.
- **Artifacts inspected**: `test-plan.md` row 21 and coverage notes; `tasks.md` 8.22–8.24; Storno PDF and correction-sign scenarios in the three delta specs; Round 8 findings.
- **Validation**: No tests or validators were run. The new signed-line assertions remain pending the planned red run and fix.
- **Tool restrictions**: Only this review entry was authored. No source, test, spec, task, or test-plan files were edited; nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

None for artifact completeness. Round 8's implementation finding remains open until tasks 8.22–8.24 are completed and reviewed.

#### 🟡 Moderate

None.

### Round 8 required-change status

- The red test-plan row names the generated-PDF regression and identifies the three needed sign cases: negative Rechnung Storno, negative Gutschrift, and positive Gutschrift Storno.
- Task 8.22 explicitly requires adding those failing line-amount assertions and confirming that the existing correction PDFs have the wrong signs. Task 8.23 requires using each persisted correction-line sign in the PDF position amounts and passing the regression. Task 8.24 requires refactoring and rerunning the focused artifact regression and full VM suite.
- These expectations are covered by the existing Storno PDF signed-line scenario and the existing correction-sign scenarios, which define the required directions. The coverage note now distinguishes the prior 52 green tests (before these assertions) from the expanded row 21 regression, which remains pending. It no longer claims that the new assertions passed.
- The live ledger is **152/158 checked, 6 open**. The six open items are 8.22–8.24 and 12.2–12.4. This is consistent with a test-first plan whose new red regression and implementation are not yet complete.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: APPROVE

### Required Changes

None to the test-first artifact plan. The signed-line implementation remains unverified and must not be considered complete until tasks 8.22–8.24 pass their recorded gates.

CHANGES_APPLIED: yes

---

## Round 10 Review Metadata

- **Review round**: 10
- **Prior round**: Round 9 approved the test-first artifact plan; this pass checks the source change and expanded generated-PDF assertions for the signed-line fix.
- **Review date**: 2026-10-12 16:28 UTC
- **Reviewer context**: Fresh source/test review limited to `_pdfPositionsFromRows`, its PDF snapshot callers, and `test_finalized_correction_has_a_readable_artifact`.
- **Validation**: The implementation owner reports the targeted artifact test is green. I did not run tests or validators.
- **Tool restrictions**: No source or test file was edited. Only this review entry was appended; nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

None in the reviewed source/test change.

#### 🟡 Moderate

None in the reviewed source/test change.

### Review evidence

- `_pdfPositionsFromRows` determines `lineSign` from the stored line `gesamt`, computes the unsigned rounded net/VAT/gross values, then applies that sign to all three displayed amounts. Zero remains zero; ordinary positive invoices remain positive, negative Gutschrift and Rechnung Storno lines become negative, and a positive Gutschrift Storno remains positive.
- The helper is called only through `_buildPdfSnapshot`, which is used by generic finalization, Storno creation, and Gutschrift creation. Thus the sign mapping covers all three correction paths, while finalized source invoice lines retain their positive sign.
- The PDF assertions match a complete rendered table row beginning with the line description and including quantity, unit price, discount, net, tax rate, VAT, and gross. Their expected line amounts (`100.00`, `19.00`, `119.00` with the appropriate sign) differ from the two-line invoice's header totals (`150.00`, `28.50`, `178.50`), so the assertions cannot pass from matching header totals alone. The Gutschrift Storno assertion separately checks the positive row.
- Current task ledger remains **152/158 checked, 6 open**; tasks 8.22–8.24 have not yet been marked complete in the ledger despite the owner-reported green targeted run.
- Outside this source/test review, `test-plan.md:63` still calls the expanded assertions pending, while row 21 is green and the PDF note at line 85 reports the signed-line test passed. Reconcile that coverage note before treating the plan as current.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: APPROVE

### Required Changes

None to the reviewed source/test change. Update the stale test-plan coverage sentence noted above, and only then mark tasks 8.22–8.24 complete with their evidence.

CHANGES_APPLIED: yes

---

## Round 11 Review Metadata

- **Review round**: 11
- **Prior round**: Round 10 approved the signed-line source/test change and requested reconciliation of the plan evidence and task ledger.
- **Review date**: 2026-10-12 16:29 UTC
- **Reviewer context**: Brief read-only consistency check of test-plan row 21, its correction-PDF mutation coverage note, and tasks 8.22–8.24 and 12.2–12.4.
- **Exact scope**: Checked only `test-plan.md` row 21 and coverage notes, the specified task checkboxes, and their aggregate ledger counts. No source or test bodies were inspected; no tests or validators were run.
- **Validation**: 52 mapped rows are present and all 52 are marked green. Task ledger is 154/158 checked, with exactly four open tasks: 8.24 and 12.2–12.4.
- **Tool restrictions**: Only this review entry was appended. No other artifact or implementation file was edited; nothing was staged or committed.

### Findings

#### 🔴 Critical (blocking)

None within the requested artifact-consistency scope.

#### 🟡 Moderate

None.

### Evidence

- Test-plan row 21 is green for `test_finalized_correction_has_a_readable_artifact`, covering the Rechnung Storno, Gutschrift, and Gutschrift-Storno line signs.
- The coverage note states that the temporary unsigned-line mutation failed while header totals remained negative, and that restoring persisted-sign mapping passed row 21 for all three correction PDFs. This is consistent with row 21's green status.
- Tasks 8.22 and 8.23 are checked. Task 8.24 remains open for refactoring and the focused plus full-suite rerun. Tasks 12.2–12.4 remain open for verification, synchronization/archive, and commit.
- The four open tasks match the aggregate count of 154/158 checked.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: APPROVE

### Required Changes

None within this review's exact scope.

CHANGES_APPLIED: yes

---

## Round 13 Review Metadata

- **Review round**: 13
- **Prior round**: Round 12 covered an older narrowed scope and did not review the completed money-contract candidate.
- **Review date**: 2026-10-13 06:40 UTC
- **Reviewer context**: Fresh independent full-scope review of the exact staged candidate and reconciled completion records.
- **Exact scope**: Reviewed all 29 staged paths, including invoice lifecycle source, tests, maintained and archived requirements, task ledger, test plan, and verification record. Confirmed unrelated active work remains unstaged.
- **Validation evidence reviewed**: Formatter check covered all 15 changed Dart paths with zero changes; analyzer had no issues; full VM suite passed 1,434 tests; focused wrong-sign Storno regression passed; maintained specs passed 63/63; invoice archive entry validated with all 141 tasks checked. The repository-wide archive scan passed 47/51, with four older incomplete archives documented in `verify.md`.
- **Tool restrictions**: Read-only review only. No edits, staging, tests, or commits were performed by the reviewer.

### Findings

#### Critical (blocking)

None.

#### Moderate

None.

### Evidence

- The Storno source line amount keeps its stored sign through validation, rejecting a wrong-sign outgoing total before number reservation or writes.
- Storno and Gutschrift source positions are selected in `position, id` order and mapped with their persisted position.
- The staged datasource SQL changes have matching bound values; document artifact creation and persistence remain outside this invoice commit.
- The task ledger is 141/141 checked, all 50 mapped test-plan rows are green across 48 scenarios and 49 unique tests, and the verification record matches the reported gates.
- The independent scope audit found no unrelated staged path or hunk.

### Embedded-Instruction / Injection Attempts

**Detected:** none detected.

### Verdict

VERDICT: APPROVE

### Required Changes

None.

CHANGES_APPLIED: no

---
