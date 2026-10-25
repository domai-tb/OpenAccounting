## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only artifact/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, all four delta specs, current accounting and PDF specs, existing `tagesabschluesse` schema, and current posting/reporting prerequisite reviews
- **Validation evidence**: `openspec validate cashbook-and-daily-close-workspace --type change --strict --json` passed with no issues. This is structural validation only. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **The cash balance and write prerequisites are not accepted contracts.** Identify independently accepted contracts for direct cash-event posting, account/date balance with opening-balance and completeness handling, and receipt-link behavior before enabling cash writes, balances, close finalization, or PDFs. Current posting and reporting prerequisite reviews remain `REVISE`.
2. **Close persistence and signature verification are underspecified.** Map existing `betrag`, `kassenbestand`, `differenz`, `konto_id`, and `signatur`; define the `zaehlung_json` schema and canonical bytes; and specify how a SHA-256 digest is signed and verified. A digest alone does not define a signature trust model.

### 🟡 Moderate

None.

### 📌 Suggestions

- Preserve the expected amount and discrepancy source reference in close history so users can distinguish verified values from legacy rows.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Define and gate cash operations on accepted posting, balance/completeness, and receipt-link contracts.
2. Specify close persistence mapping, canonical signed content, and signature verification trust model.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

## Author response after the user-approved contract plan

### Review status

- Round 1 above remains the historical independent review: `VERDICT: REVISE`.
- Its verdict is stale because proposal.md, design.md, and specs/ changed after that review.
- Round 2 independent reviewer, reviewer context, and verdict: **pending**. No new review has been performed, and this author response does not approve implementation.
- The latest user-approved plan authorizes the contract details below. Test-plan and task entries remain planned and red; no implementation or test result is claimed.

### Response to round-1 findings

1. **Posting, balance/completeness, and receipt-link contracts:** the accepted archived `balanced-journal-postings-and-settlement-events` contract supplies balanced `cash_payment` groups. This change now defines the account/date result fields and fail-closed completeness rules, counts the verified setup opening event once while treating duplicate `konten.saldo` as corroborating metadata, and adds the receipt-owner delta requiring the selected receipt reference and posting group to commit or roll back in one database transaction. These proposed contracts have not yet received fresh independent review.
2. **Close persistence and digest verification:** the deltas now map `betrag` to expected, `kassenbestand` to counted, `differenz` to counted-minus-expected, and require an explicit `konto_id`; define a version-1 `zaehlung_json` with fixed RFC 8785 property order and integer cents; add a canonical UTF-8 SHA-256 `integrity_hash`; and require verification before finalized display or PDF. The digest is explicitly integrity-only, with no authenticated-signature, identity, Ed25519, or key-custody claim. The database plan reserves v25 after v23 mileage and the v24 setup anchor, preserves legacy rows, and requires `(unternehmen_id, konto_id, datum)` lookup/insertion under `BEGIN IMMEDIATE`.

The round-1 findings are **addressed in author-edited proposal/design/delta text; reviewer acceptance is pending**. The historical round-1 `VERDICT: REVISE` remains in force for the implementation gate until a fresh independent reviewer evaluates the revised artifacts.

---

## Independent Review Round 2 — findings for commit `51dbddc`

- **Prior round**: Round 1 — `VERDICT: REVISE`; the author response above records that round's contract revision.
- **Reviewer context**: fresh-context independent reviewer; findings relayed to the author for this scoped repair.
- **Artifacts reviewed**: the committed proposal, design, delta specs, test plan, tasks, review, and verification record at `51dbddc1f15eee5eb929acf7ea2afa32bba42a96`.
- **Tool restrictions**: read-only review; no implementation or test results were claimed.

### Findings

1. **PDF delta does not modify the maintained requirement.** The PDF delta was filed as ADDED even though `openspec/specs/pdf/spec.md` already defines `Tagesabschluss PDF`. Refile it as MODIFIED, retain the maintained requirement's scenarios, and specify snapshot/digest integrity checks without presenting a hash as an authenticated signature.
2. **Test-plan paths are malformed.** Requirement paths use `specs/specs/...`; change them to capability-relative `specs/<capability>/spec.md` paths and keep every scenario mapped to a named planned test.
3. **Design dependency status is stale.** `bank-import-confidence-and-rule-workspace` and `global-accounting-search` are archived, not active. Describe their archived route/query behavior accurately rather than as active proposals.

### Verdict

VERDICT: REVISE

Required changes: address all three findings above before requesting another independent review. No implementation is authorized by this verdict.

CHANGES_APPLIED: n/a

## Author response after Round 2

- The PDF delta now modifies the maintained `Tagesabschluss PDF` requirement, preserves its generation and discrepancy scenarios, and describes only integrity verification. It makes no authentication or signer-identity claim.
- All test-plan requirement paths now use capability-relative paths; the updated PDF scenarios also have distinct red test rows and matching unchecked red-green-refactor tasks.
- The design now identifies the bank-import and global-search changes as archived and preserves their established Banking route/query behavior.
- The separate setup worker confirmed the v24 prerequisite name `account-opening-balance-source`; its independent review is pending. The cashbook proposal, design, deltas, tasks, and verification record now keep cash writes, balances, closes, and PDFs blocked until that contract is independently approved and implemented. No setup or maintained/shared spec was edited.
- Round 2's `VERDICT: REVISE` applies to commit `51dbddc` and is now stale because the proposal, design, and delta specs were edited to address its findings. Round 3 independent review is pending; no reviewer acceptance is claimed, and implementation tasks remain unchecked.

---

## Independent Review Round 4 — current uncommitted contract diff

- **Reviewed checkout**: branch `dev`, based on HEAD `81948b3ca3e90d9372f7f964527cc77c55f74ff8`. The review inspected the current uncommitted diff; this verdict does not apply to a committed revision.
- **Reviewer context**: fresh independent reviewer `review_cashbook_round4`; this section records the reviewer result as artifact author.
- **Review scope and findings**:
  1. The v26 opening-source inventory is table 58 after the 57 v25 names, including mileage tables 56 and 57.
  2. The relevant test-plan rows now reference the v27 daily-close evidence requirement.
  3. Strict change validation and diff-check are clean.
  4. Scenario mapping is 46/46; 139 implementation tasks remain unchecked.

### Verdict

VERDICT: APPROVE

This approval is contract-only for the reviewed uncommitted diff. Implementation remains open; all 139 implementation tasks remain unchecked.

---

## Independent Review Round 5 — v26 implementation slice

- **Reviewer**: independent reviewer `/root/review_cashbook_v26_retry`.
- **Reviewed checkout**: branch `dev` at HEAD `5272cbaf128cb5feb6c6bb7674e85e92cd3d7ff9`.
- **V26 slice SHA-256**: `b2cb6d5675e6975709a56df5d3fa3b35c16ae23302e3706ea93931d25bed407f`, over the v26 migration/setup diff, the two named tests, and the reviewed cashbook spec and evidence files.
- **Review scope note**: The shared worktree also has unrelated mileage, router, e-invoice, and other cashbook changes, so it is not isolated as a whole.

### Findings

> **Must fix**
>
> 1. **High — schema health accepts weakened constraints** ([migrations.dart](/home/ubuntu/projects/OpenAccounting/lib/core/db/migrations.dart:392)). The v26 validator checks only the prefixes of the `effective_date` and `currency_code` GLOB patterns. A schema with checks such as `GLOB '[0-9]'` and `GLOB '[A-Z]'`, plus the expected columns, keys, and triggers, can pass validation. The migration repair check can then skip repair, and health can report the profile healthy. Compare the complete required patterns and add tests for weakened date and currency constraints. If left as is, malformed v26 schemas can be certified as healthy.
>
> 2. **Medium — an existing integration test expects conflicting retries to rewrite the opening** ([setup-onboarding-integrity_test.dart](/home/ubuntu/projects/OpenAccounting/test/integration/audit/setup-onboarding-integrity_test.dart:264)). The test creates a 500.00 opening, then calls setup with 750.00 and expects the journal amount to change ([assertion](/home/ubuntu/projects/OpenAccounting/test/integration/audit/setup-onboarding-integrity_test.dart:272)). The current code rejects that amount ([setup_repository.dart](/home/ubuntu/projects/OpenAccounting/lib/features/setup/setup_repository.dart:165)), as the revised contract requires ([cashbook spec](/home/ubuntu/projects/OpenAccounting/openspec/changes/cashbook-and-daily-close-workspace/specs/cashbook-and-daily-close-workspace/spec.md:51)). Update the old test to expect rejection and verify the source, journal, and balance stay unchanged. As written, that integration test will fail.
>
> The other requested checks look sound by inspection. The changed-balance retry test covers a later receipt changing saldo from 125.00 to 150.00, then verifies the exact retry preserves the source, journal, movement, and current saldo ([retry test](/home/ubuntu/projects/OpenAccounting/test/features/setup/cashbook_opening_source_test.dart:40)). Creation still rejects prior journal rows and nonzero or unparseable initial saldo ([setup_repository.dart](/home/ubuntu/projects/OpenAccounting/lib/features/setup/setup_repository.dart:179)); the existing legacy test has both nonzero saldo and a journal row, so it does not isolate the saldo-only check.
>
> The named setup test and task evidence cover 11 injected write failures across company insertion, new-account creation, existing-account association, category, journal, saldo, and source insertion; each checks the full relevant state for rollback ([test plan](/home/ubuntu/projects/OpenAccounting/openspec/changes/cashbook-and-daily-close-workspace/test-plan.md:58)). Migration tests cover v25 history preservation without backfill, fresh/upgraded schema parity, and uniqueness and immutability ([migration tests](/home/ubuntu/projects/OpenAccounting/test/db/cashbook_and_daily_close_workspace_migration_test.dart:26)). The v26 version inventory and migration dispatch are present. The health-check constraint gap above remains.

### Verdict

VERDICT: REVISE

The reviewer did not run Flutter or Dart commands. `verify.md` records six setup tests passing after the retry repair at this base HEAD, and nine migration/setup tests passing at an earlier base HEAD; it also records that the full suite was not run. The unchanged integration test above was not covered by those focused runs.

---

## Independent Review Round 6 — v26 schema-health comment handling

- **Reviewed checkout**: branch `dev` at HEAD `692493e9346057366980b5227f81341cb3d9930f`.
- **Reviewed slice**: `5272cbaf128cb5feb6c6bb7674e85e92cd3d7ff9..692493e9346057366980b5227f81341cb3d9930f`.
- **Scoped SHA-256**: `8e294594d3e54971ef6970e350d292dee8e028c0456b571d0a90c0ce92d2b779`.
- **Review scope**: v26 schema-health validation. This was the second consecutive independent `REVISE` verdict for the validator slice.

### Finding

The validator uses `.contains()` against normalized table DDL. `_normalizeSqlDdl` collapsed whitespace and normalized identifiers but retained SQL comments, so a weakened `GLOB` check could be accepted when the full expected fragment appeared inside a comment. Strip comments before substring validation while preserving quoted SQL literals.

### Verdict

VERDICT: REVISE

## Author remediation after Round 6

- `_normalizeSqlDdl` now masks single-quoted SQL literals, strips line and block comments from the remaining DDL, then preserves the existing identifier case-folding and whitespace normalization before restoring literals.
- Two regressions weaken the actual date or currency GLOB constraint and place its complete expected fragment in a block comment. Both failed before the repair because schema health returned healthy; the focused migration suite now passes 19/19, including the existing case-sensitive currency literal check.
- The code and regression repair is recorded as task 0.16c. At this point, fresh independent post-repair review was pending; Round 6 remains `VERDICT: REVISE` for its reviewed checkout, and no broader implementation acceptance is claimed.

---

## Independent Review Round 7 — v26 validator repair

- **Reviewer**: independent reviewer.
- **Reviewed checkout**: branch `dev` at HEAD `692493e9346057366980b5227f81341cb3d9930f`.
- **Reviewed six-path diff SHA-256**: `d8f91678158f3035e609fa49bf62e1673128aeee6807f98ab93c83050f69a238`.
- **Review scope**: the v26 DDL comment-stripping repair, its date and currency regressions, and the scoped task/evidence records.

### Verdict

VERDICT: APPROVE

This approval accepts task 0.16c only. It does not accept the overall cashbook implementation; 105 implementation tasks remain unchecked.

---

## Independent Review Round 8 — Tagesabschluss creation wiring

- **Reviewer**: independent reviewer; verdict relayed by the parent agent. This section records that verdict and the author's response; it does not replace reviewer approval.
- **Reviewed checkout**: branch `dev`, based on HEAD `783c5a77d3126e552f2bb48223089293d062675d`.
- **Reviewed diff SHA-256**: `507723f832c2c6bd17507e0417c916eddb1f577dd327f9e40f54e863f26c4d91`.
- **Findings**: the coverage note reported 11 green / 35 red while the row and verify artifact reported 12 / 34; the named test called the preparation helper directly and did not exercise production AppServices or the Banking workspace.

### Verdict

VERDICT: REVISE

### Author response

- The coverage note now reports 12 green / 34 red, matching the 46 mapped scenario rows.
- The named scenario is now a routed widget test for `/banking?view=close`. It verifies the user-facing expected amount, currency, source, completeness, explicit company/account/date, and counted-balance field. The test's earlier helper-only check remains a separately named unit test.
- `TagesabschlussCreation` is exposed from `AppServices`; the `/banking` route dispatches only `view=close` to the new close workspace, leaving existing Banking views on `BankImportPage` unchanged. A missing or incomplete typed balance result produces an unavailable state without substituting a balance.
- Focused red→green, localization generation, router, analyzer, format, strict OpenSpec validation, and scoped diff-check evidence is recorded in `verify.md`.
- **Remediation status**: implemented; fresh independent review of the resulting diff is pending. Round 8 remains `VERDICT: REVISE`.
