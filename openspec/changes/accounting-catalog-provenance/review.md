## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, all delta specs, current category/accounting specs, and relevant category, EÜR, DATEV, and master-data workspace paths
- **Validation evidence**: `openspec validate accounting-catalog-provenance --type change --strict --json` passed with no issues; `openspec validate --specs --strict` passed 55/55. Structural validation does not establish semantic completeness. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **Provenance persistence is not specified.** The accounting delta defines five statuses, catalog entry/source fields, and edit/review transitions, but the `db` delta changes only seed behavior. The current `kategorien` table has no provenance columns. Specify the schema migration and persistence contract.
2. **Confirmed provenance is not represented in every supported output.** Current `datev_export_log` and `euer_exporte` do not store mapping provenance. Define the GuV owner/output contract or remove GuV from scope, and specify provenance persistence for every supported output.
3. **Missing-mapping failure behavior is incomplete.** EÜR currently filters categories without `euer_zeile`, and DATEV uses `1200`/`8400` fallbacks. Specify period/category detection and fail closed instead of omitting rows or inventing mappings.
4. **The category review path is not reachable.** Existing category repository methods have no reachable category workspace, and the referenced master-data workspace proposal is not active. Include a reachable review action or gate this capability on an accepted workspace.

### 🟡 Moderate

None.

### 📌 Suggestions

- Reconcile recurring-booking inactive-category behavior: inactivity may warn, while `legacy_unverified` or `review_required` must still block posting.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Define and persist provenance schema and state transitions.
2. Define provenance ownership and recorded output mapping, or remove unsupported GuV scope.
3. Specify missing-mapping detection and fail-closed behavior for EÜR and DATEV.
4. Include a reachable review action or gate on an accepted category workspace.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

---

## Review Round 2

### Review Metadata

- **Review round**: 2
- **Prior round**: 1 (`REVISE`)
- **Reviewer context**: fresh-context independent reviewer; did not author the current repairs
- **Tool restrictions**: inspected proposal artifacts and relevant runtime contracts; appended this review only; no tests or commits
- **Artifacts reviewed**: proposal, design, accounting and database deltas, round-1 findings, DATEV/EÜR source behavior, maintained accounting spec, and category workspace proposal
- **Validation evidence**: `openspec validate accounting-catalog-provenance --type change --strict --json` passed with no issues. `git diff --check` passed. Structural validation does not establish semantic completeness. No tests were run.

<!-- STALENESS: this verdict applies to proposal.md, design.md, and specs/ as
reviewed in round 2. Any later edit to those artifacts voids this verdict. -->

### Findings

#### 🔴 Critical (blocking)

1. **DATEV provenance does not identify both emitted account slots.** The DATEV EXTF row contains both `Konto` and `Gegenkonto`; the current resolver can source these from different inputs. The proposed snapshot example has `datev_accounts` entries containing only `journal_id`, `account_number`, and `source`, with no `Konto`/`Gegenkonto` slot or explicit category/history link. The new precedence scenario also does not define how the two sides are resolved independently. Specify one snapshot record per emitted account slot, its source and account number, and category/history linkage when applicable; require generation to fail if either required side cannot be resolved without a synthetic fallback. Otherwise the persisted snapshot cannot prove which mapping produced each emitted account, and fail-closed behavior remains ambiguous for the category contra-account.

2. **Adding the required status column to existing SQLite rows is not an executable migration contract yet.** The delta requires adding `mapping_status TEXT NOT NULL` to `kategorien` while preserving and classifying existing categories, but it gives no default or table-rebuild/copy procedure. On the populated legacy table described by the proposal, a direct SQLite `ALTER TABLE ... ADD COLUMN ... TEXT NOT NULL` without a default fails. Specify how the migration assigns `legacy_unverified` before enforcing the non-null constraint, while preserving IDs, values, and journal references transactionally.

#### 🟡 Moderate

1. **`unmapped` posting eligibility conflicts across the design.** The design says unmapped user categories remain valid for entry when no accounting mapping is needed, but later says `unmapped` is a posting blocker; the inactive-recurring scenario blocks every `unmapped` category as well. Define whether the block applies only when the posting/output contract requires an accounting mapping or to every journal posting, then align the category and recurring scenarios.

### Round-1 Required-Change Status

- Provenance columns/history and EÜR/DATEV output metadata are now specified; DATEV account-slot provenance remains incomplete as described above.
- EÜR missing-category/line detection and DATEV fail-closed fallback behavior are specified.
- Category review is gated on the accepted and available `/categories` workspace, with untrusted status remaining read-only and blocked until then.
- Inactive-category warnings are separated from mapping trust; unresolved statuses block recurring posting. The `unmapped` eligibility conflict above still needs reconciliation.

## Verdict

VERDICT: REVISE

## Required Changes

1. Define DATEV resolution and persisted provenance for both emitted account slots, including fail-closed behavior and links to the exact category-history row when used.
2. Specify a valid transactional SQLite migration strategy for setting `mapping_status` on existing rows and enforcing `NOT NULL`.
3. Reconcile whether `unmapped` blocks all postings or only operations requiring an accounting mapping, and make the design/spec scenarios consistent.

CHANGES_APPLIED: n/a

---

## Review Round 3

### Review Metadata

- **Review round**: 3
- **Prior round**: 2 (`REVISE`)
- **Reviewer context**: fresh independent reviewer; did not author the round-2 repairs
- **Tool restrictions**: read proposal/spec/design/source context and append this review only; no tests or commits
- **Artifacts reviewed**: current proposal, design, accounting and database deltas, rounds 1–2, DATEV account-slot behavior, and relevant journal/accounting contracts
- **Validation evidence**: `openspec validate accounting-catalog-provenance --type change --strict --json` passed with no issues. `git diff --check` passed. No tests were run.

<!-- STALENESS: this verdict applies to proposal.md, design.md, and specs/ as
reviewed in round 3. Any later edit to those artifacts voids this verdict. -->

### Findings

None. All blocking round-2 findings are resolved:

- DATEV now resolves `Konto` and `Gegenkonto` independently and persists one account-slot record per emitted value, including the slot, exact number, source, journal ID, and category/history reference when applicable. It fails when either slot lacks an eligible source and prohibits an implicit company default.
- The transactional SQLite migration adds `mapping_status` with a constrained `legacy_unverified` literal default, verifies existing-row classification, records prior values in history, and rolls schema/data changes back together on failure.
- `unmapped` categories may label a posting only when required account and tax data are supplied independently. Category values are blocked only for operations that require them; recurring and output scenarios now follow that policy while preserving inactive-category warnings.

## Verdict

VERDICT: APPROVE

CHANGES_APPLIED: n/a
