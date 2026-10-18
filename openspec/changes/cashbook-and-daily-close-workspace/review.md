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
