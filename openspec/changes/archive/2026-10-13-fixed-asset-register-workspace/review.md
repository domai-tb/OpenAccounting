## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only proposal/spec/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, all four delta specs, fixed-asset/database/accounting contracts, current asset schema, EÜR implementation, and profile table-inventory proposal
- **Validation evidence**: `openspec validate fixed-asset-register-workspace --type change --strict --json` passed with no issues; `openspec validate --specs --strict` passed 55/55. Structural validation does not establish semantic completeness. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **New asset writes do not satisfy the legacy required column.** `anlageverzeichnis.anschaffungskosten NUMERIC(12,2) NOT NULL` remains required, while new records are described using `kaufpreis_netto`. Specify the compatibility write or table rebuild so canonical inserts do not fail.
2. **Depreciation bounds and rounding are missing.** Define the final depreciation year/useful-life boundary and cent-rounding rule; current examples imply rounded amounts without a normative rounding method.
3. **The new schedule table is absent from the shared inventory.** Declare its owner, schema-version/presence rule, and database/profile-export inventory update before release. It adds a table beyond the active portability proposal's proposed 42-table inventory.
4. **EÜR integration depends on an unaccepted report contract.** Keep asset EÜR integration gated until the report contract is independently accepted; current EÜR reads legacy columns directly and the reporting-workspaces proposal remains under review.

### 🟡 Moderate

None.

### 📌 Suggestions

- None.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Define compatibility persistence for the existing required acquisition-cost column.
2. Specify schedule duration and deterministic cent rounding.
3. Reconcile the schedule table with the accepted database and profile-export inventories.
4. Gate EÜR integration on an independently accepted reporting contract.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

<!-- STALENESS: this Round 2 verdict applies only to the artifact contents reviewed in -->
<!-- Round 2. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Review Metadata — Round 2

- **Review round**: 2
- **Prior round**: 1 (VERDICT: REVISE with 4 Required Changes)
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only spec/proposal inspection; no shell, no edits, no tests
- **Artifacts reviewed**: repaired proposal.md, design.md, all four delta specs (db, fixed-asset-register-workspace, accounting, typed-route-workspaces), maintained specs (accounting Anlagenverzeichnis, db Table Definitions, profile-data-portability export inventory)
- **Validation evidence**: none run this round per instructions (no shell/tests); semantic re-review of repaired normative language and maintained-spec conflicts only

## Findings — Round 2

### Required Change 1 (compat write anschaffungskosten/kaufpreis_netto): CONFIRMED

Every canonical write that sets `kaufpreis_netto` SHALL also write `anschaffungskosten` with the same amount (delta db spec; design Decision 2; proposal Impact). Reads SHALL treat `kaufpreis_netto` as canonical and SHALL NOT reinterpret `anschaffungskosten`. New scenario `Canonical writes satisfy the legacy required column` asserts the insert SHALL NOT fail the legacy `NOT NULL` constraint. Legacy columns are preserved without copying or reinterpreting values.

### Required Change 2 (final-year bound + cent rounding): CONFIRMED

Each full-year amount SHALL be `kaufpreis_netto / nutzungsdauer_jahre` rounded half-up to the cent for `NUMERIC(12,2)` storage, computed independently per year with no final-year remainder adjustment (delta accounting spec; delta fixed-asset-register-workspace spec; design Decision 3). The schedule SHALL contain at most `nutzungsdauer_jahre` full-year rows; later years SHALL be unavailable with the useful-life bound identified. Examples (`1000/3 → 333.33`; KFZ 30% → `233.33`) are consistent with the maintained accounting `333.33` example and the stated per-year rule.

### Required Change 3 (schedule table owner/version + export inventory): CONFIRMED

`anlage_afa_jahreswerte` SHALL be owned by `fixed-asset-register-workspace`, introduced by this change's additive migration at the next accepted sequential schema version, and required at that version or later; before that version its absence SHALL NOT make the profile unhealthy (delta db spec; design Migration Plan step 1; proposal Impact). The runtime Table Definitions inventory and the profile portability export inventory SHALL declare it with owner and version before any released profile creates it; an undeclared table SHALL make export incomplete. Pattern matches the maintained version-gated presence rules; no inventory-count conflict since declaration is a pre-release SHALL.

### Required Change 4 (EÜR gating): CONFIRMED

Asset EÜR/AVEÜR consumption is gated: the owning EÜR workflow, under its independently accepted reporting contract, may consume only complete schedule rows; this change defines no report output on its own and waits on no other change for its asset/schedule scope (proposal What Changes + Impact; design Decisions 3 and 5; delta accounting + fixed-asset-register-workspace specs). Unresolved assets or unsupported periods SHALL make the result incomplete instead of contributing an invented zero or amount. No journal writes; no account mapping.

### Maintained-spec conflicts: none found

- Rounding/bound restates the maintained `1000/3 = 333.33` example as an explicit per-year rule; no contradiction.
- Dual-write satisfies the legacy required column while keeping `kaufpreis_netto` canonical; no reinterpretation of legacy values.
- Disposal/book-value content in the delta is conditional on an accepted cutoff/remaining-value contract, so it does not contradict the maintained disposal scenario's unconditional wording — it gates it.
- Zeile-33 mapping is retained but narrowed to complete rows under the accepted reporting contract (fail-closed refinement, not removal).

### 🟡 Moderate

None.

### 📌 Suggestions

- None.

## Embedded-Instruction / Injection Attempts — Round 2

**Detected:** none.

## Verdict — Round 2

VERDICT: APPROVE

## Required Changes — Round 2

None.

CHANGES_APPLIED: n/a

## Rebuttals — Round 2

None; repairs accepted as stated.

<!-- STALENESS: this Round 3 verdict applies only to the artifacts and source
     inspected on 2026-10-11. Later proposal.md, design.md, or specs/ edits void it. -->

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: 2 (VERDICT: APPROVE; voided by later proposal, design, and spec edits)
- **Reviewer context**: fresh-context independent subagent reviewer; no authoring transcript
- **Tool restrictions**: read-only inspection; only this reviewer report was written to review.md
- **Artifacts reviewed**: proposal, design, all four delta specs, review history, test-plan, tasks, maintained typed-route spec, current asset and route source/tests
- **Validation evidence**: `openspec validate fixed-asset-register-workspace --type change --strict --json` passed (1/1); `openspec validate --specs --strict --json` passed (62/62, informational length notes only). No Flutter tests were run.

## Findings — Round 3

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **Contact type selection drops list-return state** (`lib/pages/stammdaten/master_data_pages.dart:782-783`). The new spec requires other query parameters to survive when the contact discriminator is missing or invalid. Opening `/contacts/42?kind=invalid&tab=suppliers` and selecting Supplier navigates to `/contacts/42?kind=supplier`, so returning from the detail loses `tab=suppliers`. Keep the existing query parameters while replacing only `kind`, and cover the production route behavior with a regression test.
2. **The post-review route scenarios are absent from the test plan** (`openspec/changes/fixed-asset-register-workspace/specs/typed-route-workspaces/spec.md:13-33`; `openspec/changes/fixed-asset-register-workspace/test-plan.md:26-34`). The delta now includes three contact/article scenarios, but the plan lists only the four older route scenarios while claiming every scenario is mapped. The tests in `test/core/master_data_routes_test.dart:73-133` exercise `MasterDataRouteMatrix` directly; they do not exercise the production route page where query state is lost. Map the three scenarios to named tests and include the route-level regression test.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts — Round 3

**Detected:** none.

## Verdict — Round 3

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 3

1. Preserve non-`kind` contact query parameters during type selection, and add a regression test through the production route/page.
2. Add test-plan mappings for all three post-review typed-route scenarios; use tests that exercise the route behavior rather than only the unused route-matrix helper.

CHANGES_APPLIED: no

## Rebuttals — Round 3

None; this is the first review of the post-Round-2 artifact edits.

<!-- STALENESS: this Round 4 verdict applies to the planning artifacts and
     source inspected on 2026-10-11. Any later proposal.md, design.md, or
     specs/ edits void it. -->

## Review Metadata — Round 4

- **Review round**: 4
- **Prior round**: 3 (VERDICT: APPROVE_WITH_CHANGES; contact query preservation confirmed, route-test mapping only partly addressed)
- **Reviewer context**: fresh independent subagent re-review; no authoring transcript
- **Tool restrictions**: read-only inspection; only this reviewer report was written to review.md; no tests run
- **Artifacts reviewed**: proposal, design, all four delta specs, review history, current test-plan/tasks, current route implementation and route tests
- **Validation evidence**: `openspec validate fixed-asset-register-workspace --type change --strict --json` passed (1/1); `openspec validate --specs --strict --json` passed (62/62). No Flutter tests were run.

## Findings — Round 4

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **Two typed-route scenarios still map only to a test helper** (`openspec/changes/fixed-asset-register-workspace/test-plan.md:29,31`; `test/core/master_data_routes_test.dart:73-133`). Those tests call `MasterDataRouteMatrix`, which is declared but has no production callers. The new production-page test covers missing/invalid contact selection and repeated query preservation, but it does not prove customer-versus-supplier lookup or the article item/group route and group-list behavior. Add production route/page tests for those cases and map the rows to them.
2. **Green test-plan rows lack traceable run evidence** (`openspec/changes/fixed-asset-register-workspace/test-plan.md:8-40`). All 27 rows are marked green, while the only evidence is a note that a focused run passed; it records no command or result summary. No `verify.md` exists, and this review did not run tests. Keep green status only when the focused test result is recorded; verification still requires the exact full-suite command and result in `verify.md`.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts — Round 4

**Detected:** none.

## Verdict — Round 4

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 4

1. Replace the helper-only mappings for contact discriminator selection and article/item-group routing with executable tests of the production route/page behavior; retain the new query-preservation route test.
2. Record the focused test command and result before treating the test-plan rows as green. Add the required full-suite command and result to verify.md before claiming verification complete.

CHANGES_APPLIED: no

## Rebuttals — Round 4

None; the Round 3 contact query-preservation fix is confirmed. The route-test coverage requirement is only partly met.

<!-- STALENESS: this Round 5 verdict re-checks the Round 4 required changes
     against the test-plan and current route tests inspected on 2026-10-11. -->

## Review Metadata — Round 5

- **Review round**: 5
- **Prior round**: 4 (VERDICT: APPROVE_WITH_CHANGES; production route coverage and recorded test evidence required)
- **Reviewer context**: fresh independent subagent re-review; no authoring transcript
- **Tool restrictions**: read-only inspection; only this reviewer report was written to review.md; no tests run
- **Artifacts reviewed**: Round 4 required items in test-plan.md and the production contact/article route tests; relevant current contact and article route implementations
- **Validation evidence**: `openspec validate fixed-asset-register-workspace --type change --strict --json` passed (1/1); `openspec validate --specs --strict --json` passed (62/62; informational length notes only). No Flutter tests were run.

## Findings — Round 5

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **Article route mapping omits the group-list contract** (`test/core/contact_detail_type_selection_route_test.dart`; `openspec/changes/fixed-asset-register-workspace/specs/typed-route-workspaces/spec.md:28-33`). The new test covers same-ID item/group detail resolution, but its router contains only `/articles/:id`; it never opens `/articles?view=groups` or checks the promised group list and create/update/lifecycle actions. The single test-plan row therefore does not cover the whole named scenario. Extend production-route coverage to assert the group-list surface/actions, or split the scenario and map each independently testable part.
2. **Green rows still lack recorded run evidence** (`openspec/changes/fixed-asset-register-workspace/test-plan.md:8-40`). The three typed-route rows now map to named production-page tests, including same-ID contact and item/group records. However, every row is green while Coverage Notes only claim that tests passed “in the focused run”; no command or result summary is recorded. The Round 4 required change is not complete. Record the focused test command and result before treating rows as green. `verify.md` is absent, so the required full-suite command and result also remain outstanding before verification can be claimed complete.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts — Round 5

**Detected:** none.

## Verdict — Round 5

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 5

1. Add production-route assertions for `/articles?view=groups` and its documented create/update/lifecycle actions, or split and map the detail and group-list assertions as separate scenarios.
2. Record the focused test command and result before retaining green test-plan rows. Before claiming verification complete, create verify.md with the required full-suite command and result.

CHANGES_APPLIED: no

## Rebuttals — Round 5

The Round 4 contact/same-ID route coverage finding is resolved: named production-page tests now cover invalid contact type selection with query preservation, overlapping customer/supplier IDs, and overlapping article/item-group detail IDs. The Round 4 evidence finding remains open because no run command/result is recorded. The group-list portion of the article scenario is not covered by the new detail-only test.

<!-- STALENESS: this Round 6 verdict re-reviews the current proposal, design,
     specs, tasks, test plan, source, and tests inspected on 2026-10-11. -->

## Review Metadata — Round 6

- **Review round**: 6
- **Prior round**: 5 (VERDICT: APPROVE_WITH_CHANGES; article group-list production coverage and run evidence required)
- **Reviewer context**: fresh independent subagent review; no authoring transcript
- **Tool restrictions**: read-only inspection; only this reviewer report was written to review.md; no tests run
- **Artifacts reviewed**: current proposal, design, all four delta specs, tasks, test-plan, typed contact/article route tests, asset tests and implementation, database migrations and inventories, EÜR service and tests
- **Validation evidence**: `openspec validate fixed-asset-register-workspace --type change --strict --json` passed (1/1); `openspec validate --specs --strict --json` passed (62/62; informational length notes only). The test plan records a focused run of 36 tests, 0 failures. Parent-supplied full-suite result: 1,310 passed and 63 failed, described as unrelated unfinished feature clusters; this reviewer did not run tests or inspect the failure output. `verify.md` is absent and OpenSpec status reports verify `ready`, `isPlanningComplete: false`, `isComplete: false`.

## Findings — Round 6

### 🔴 Critical (blocking)

1. **EÜR still calculates tax output from unmapped legacy asset fields** (`lib/features/accounting/euer_service.dart:172-174,212-266`; delta accounting spec `Unresolved AfA or disposal inputs`, lines 37-41). When no canonical fields are populated, `EuerService.generate` falls through to the historical calculation using `anschaffungskosten`, `nutzungsdauer`, and `privatanteil`; it can add that guessed amount to EÜR line 33 without marking the report incomplete. The existing ambiguous-source test only checks `AssetRegisterUseCases.consumeCompleteAfa`, not the production EÜR reader. This contradicts the spec's requirement to identify the asset and mark the report incomplete when those legacy values have no confirmed mapping.

### 🟡 Moderate

1. **The disposal scenario and its mapped test assert different contracts** (`openspec/changes/fixed-asset-register-workspace/specs/accounting/spec.md:25-29`; `test/features/accounting/fixed_asset_register_workspace_test.dart:85-107`; test-plan row 11). The spec scenario assumes an accepted cutoff and remaining-book-value contract, then requires AfA to stop and the remaining value to be shown. No such contract exists in the design or implementation; the mapped test instead verifies the disposal year is unavailable and EÜR generation throws. Rewrite the scenario to assert the current unavailable state, or provide the accepted formula/rule and implement/test the scenario it currently describes.
2. **TDD task entries omit the newly added route scenarios and tests** (`openspec/changes/fixed-asset-register-workspace/tasks.md:70-83`; `test-plan.md:29-31`). The test plan now maps the contact discriminator, contact type-selection, article/item-group detail, and group create/update/archive/restore tests, but the typed-route task group lists only the older four route tests. Add accurate red-green-refactor tasks for the added scenarios before treating the completed task list as complete.
3. **Verification is still incomplete** (`openspec/changes/fixed-asset-register-workspace/verify.md` absent; `openspec/schemas/anvil/schema.yaml` verify gate). The focused 36-test command/result is now recorded, resolving the focused-evidence part of Round 5. The full suite is reported as 1,310 passed and 63 failed; even if those failures are outside this change, the Anvil verify gate requires a passing full suite with no failures. Record the run and blockers in verify.md, and do not claim completion until a fresh full-suite run passes.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts — Round 6

**Detected:** none.

## Verdict — Round 6

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 6

1. Prevent EÜR line 33 from calculating an amount from unmapped legacy asset fields. Mark the report incomplete with the asset ID and reason, and add a production `EuerService.generate` regression test for a legacy-only row.
2. Align the asset disposal scenario with the currently unsupported cutoff/book-value rule and its unavailable-result test, or define and implement the accepted rule the current scenario assumes.
3. Add accurate red-green-refactor task entries for the added typed-route scenarios and mapped tests.
4. Record the full-suite command/result and remaining unrelated failures in verify.md. Keep verification incomplete until a fresh full-suite run passes with zero failures.

CHANGES_APPLIED: no

## Rebuttals — Round 6

The Round 5 article group-list coverage finding is resolved: the production widget test now opens `/articles?view=groups` and exercises create, update, archive, and restore; the test-plan row names both the typed-detail test and the widget test. The focused-evidence finding is also resolved by the recorded command and `36 passed, 0 failed` result. The full-suite verification gate remains open. New findings are the EÜR legacy fallback, the disposal scenario/test mismatch, and missing TDD tasks for the added route scenarios.

<!-- STALENESS: this Round 7 verdict rechecks the Round 6 fixes against the
     current proposal, design, specs, test-plan, tasks, production source,
     migrations, and tests inspected on 2026-10-11. -->

## Review Metadata — Round 7

- **Review round**: 7
- **Prior round**: 6 (VERDICT: APPROVE_WITH_CHANGES; EÜR legacy inputs, disposal contract, route TDD tasks, and verification gate required)
- **Reviewer context**: fresh independent subagent review; no authoring transcript
- **Tool restrictions**: read-only inspection except this appended verdict; no tests run
- **Artifacts reviewed**: current proposal, design, all four delta specs, tasks, test-plan, asset/EÜR implementation, migration and schema inventories, asset and route tests, and prior review findings
- **Validation evidence**: `openspec validate fixed-asset-register-workspace --type change --strict --json` passed (1/1); `openspec validate --specs --strict --json` passed (62/62; informational length notes only). The test-plan records 36 focused tests passed, but its six command files currently contain 37 `test`/`testWidgets` declarations. No tests were run in this review. The prior parent-supplied full-suite result was 1,310 passed and 63 failed; no new full-suite result was supplied. `verify.md` is absent; OpenSpec status reports verify `ready`, `isPlanningComplete: false`, and `isComplete: false`.

## Findings — Round 7

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **The added typed-route scenarios still lack auditable per-scenario TDD tasks** (`openspec/changes/fixed-asset-register-workspace/tasks.md:87-92`; `test-plan.md:30-32`). Tasks 6.13-6.15 combine contact query preservation, same-ID record selection, and group actions into one generic test/implementation/refactor sequence without naming the mapped tests. The group widget test has a later sequence, but those tasks also omit its exact test name. Anvil requires a red-green-refactor triple for every scenario. Split the remaining route cases into named, scenario-specific triples; retain the existing group lifecycle sequence only if it explicitly names `test_article_group_workspace_supports_create_update_archive_and_restore`.
2. **The green test-plan evidence does not match the current focused test surface** (`openspec/changes/fixed-asset-register-workspace/test-plan.md:37-42`). The recorded command reports 36 passing tests, while its six files currently declare 37 executable tests, including the new legacy-only EÜR regression. No newer result is recorded, so the green row for that regression is not yet backed by the stated run. Record a focused result that includes all current tests before treating every row as green.
3. **The required verification gate remains incomplete** (`openspec/changes/fixed-asset-register-workspace/verify.md` absent; `openspec/schemas/anvil/schema.yaml` verify instructions). The previously supplied full-suite result has 63 failures, and there is no `verify.md` recording the exact command, failure disposition, or a passing full-suite run. Per the Anvil gate, the change cannot be complete until a fresh full-suite run has zero failures and its evidence is recorded.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts — Round 7

**Detected:** none.

## Verdict — Round 7

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 7

1. Make the added typed-route TDD tasks name each mapped test and preserve red-green-refactor ordering per scenario.
2. Update the focused test result to cover the current 37 test declarations before keeping all test-plan rows green.
3. Add `verify.md` with the exact full-suite command and result. Keep verification incomplete until a fresh full-suite run passes with zero failures.

CHANGES_APPLIED: no

## Rebuttals — Round 7

- Round 6 finding 1 is fixed and accepted: `EuerService.generate` throws with the asset ID for active rows without canonical inputs (`lib/features/accounting/euer_service.dart:206-212`), and the production EÜR regression covers a legacy-only row (`test/features/accounting/fixed_asset_register_workspace_test.dart:137-147`).
- Round 6 finding 2 is fixed and accepted: the disposal scenario now specifies an unavailable row without an accepted cutoff/book-value contract (`specs/accounting/spec.md:25-29`), matching `test_asset_disposal` (`test/features/accounting/fixed_asset_register_workspace_test.dart:85-107`).
- Round 6 finding 3 is only partly addressed: the group lifecycle flow has task entries, but contact/type-selection and typed article-owner tests remain grouped under generic tasks without per-scenario named triples, so this finding is not accepted as fully resolved.
- Round 6 finding 4 remains open: no `verify.md` exists, and no passing full-suite result was supplied for this round.
- The prior group-list coverage issue remains resolved: the production widget test covers `/articles?view=groups` create/update/archive/restore and the test-plan maps it to that named test.

<!-- STALENESS: this Round 8 verdict checks the Round 7 findings against the
     current implementation, specs, design, tasks, test-plan, and tests
     inspected on 2026-10-11. -->

## Review Metadata — Round 8

- **Review round**: 8
- **Prior round**: 7 (VERDICT: APPROVE_WITH_CHANGES; typed-route TDD task granularity, focused-run evidence, and full-suite verification required)
- **Reviewer context**: fresh independent review; no new authoring transcript
- **Tool restrictions**: read-only inspection except this appended report; no tests run
- **Artifacts reviewed**: current design, all four delta specs, tasks, test-plan, `EuerService`, contact/article route owners, fixed-asset implementations, and mapped asset/EÜR/route tests
- **Validation evidence**: strict OpenSpec change validation passed (1/1); strict spec validation passed (62/62). Parent-supplied focused run passed 83/83. Parent-supplied full-suite run completed with 1,313 passed and 63 failed. Parent-supplied `fvm flutter analyze` exited 1 with 58 info diagnostics and no warning/error severities; `git diff --check` passed. No tests were run in this review.

## Findings — Round 8

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **The missing-kind test does not prove that neither entity lookup runs** (`test/core/contact_detail_type_selection_route_test.dart:119-147`; `specs/typed-route-workspaces/spec.md:21-26`). The test seeds customer and supplier rows, then checks that neither name is rendered. It has no query/service spy or other lookup counter, so it would still pass if a future implementation queried both records and kept the type-selection screen. The current production guard correctly returns before either detail body is built (`lib/pages/stammdaten/master_data_pages.dart:775-791`), but the green regression test does not protect the spec's explicit no-query requirement. Add an assertion that observes the lookup boundary, or narrow the requirement and test to the user-visible no-guess behavior.
2. **The full-suite verification gate remains unmet** (parent-supplied run: 1,313 passed, 63 failed). The Round 7 verification finding is not resolved by the new focused 83/83 run. Anvil requires a passing full suite with zero failures before completion; the current full-suite result cannot satisfy that gate. The analyzer command also exits 1, although only info diagnostics were reported; no warning/error-level analyzer finding is established by the supplied summary.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts — Round 8

**Detected:** none.

## Verdict — Round 8

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 8

1. Make the missing-kind route test observe that no customer or supplier lookup is invoked, while keeping the current type-selection and query-preservation assertions.
2. Keep verification incomplete until a fresh full-suite run passes with zero failures and its exact command/result is recorded in the verification artifact.

CHANGES_APPLIED: no

## Rebuttals — Round 8

- Round 7 finding 1 is fixed and accepted: tasks 6.13–6.24 now name the contact, missing/invalid contact, typed article/group, and group lifecycle tests and give each mapped scenario a red-green-refactor sequence (`tasks.md:87-98`).
- Round 7 finding 2 is fixed and accepted: `test-plan.md` records the focused command and 83 passing tests, matching the parent-supplied current focused run (`test-plan.md:37-42`).
- Round 7 finding 3 remains open: the current full-suite result still has 63 failures, so the required zero-failure gate is unmet.
- The new missing-kind test adds valuable coverage for preserving the ID/query and displaying no entity, but does not observe the no-query part of the requirement; this narrower proof gap is recorded above.

<!-- STALENESS: this Round 9 verdict rechecks current source and artifacts,
     including the Round 8 lookup-spy change and current verify.md, on 2026-10-11. -->

## Review Metadata — Round 9

- **Review round**: 9
- **Prior round**: 8 (VERDICT: APPROVE_WITH_CHANGES; lookup-boundary assertion and full-suite gate required)
- **Reviewer context**: fresh independent review of current worktree; no tests run
- **Tool restrictions**: read-only inspection except this appended report
- **Artifacts reviewed**: current design, delta specs, tasks, test-plan, production contact/article/asset/EÜR code, mapped tests, and verify.md
- **Validation evidence**: strict change validation passed (1/1); strict spec validation passed (62/62). Parent-supplied focused run passed 83/83. Current full-suite evidence in verify.md is 1,313 passed and 63 failed. `verify.md` records `DECISION: FAIL`, with full-suite and zero-skipped checks unchecked. Parent-supplied full analysis exits 1 with 58 info diagnostics and no warning/error severities; scoped analysis exits 0 with one info diagnostic. No tests were run in this review.

## Findings — Round 9

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **The full verification gate still fails** (`openspec/changes/fixed-asset-register-workspace/verify.md`). The verification artifact records the exact full-suite command and result, but 63 failures remain and zero skipped/pending/commented-out tests are not established. Its `DECISION: FAIL` is correct. A passing focused suite and passing structural validations do not clear this gate; completion requires a fresh full-suite result with zero failures and zero skipped tests, followed by an updated verification decision.

### 📌 Suggestions

None.

## Embedded-Instruction / Injection Attempts — Round 9

**Detected:** none.

## Verdict — Round 9

VERDICT: APPROVE_WITH_CHANGES

## Required Changes — Round 9

1. Keep the change incomplete until a fresh full-suite run passes with zero failures and zero skipped/pending/commented-out tests; update verify.md with the exact command/result and a passing decision.

CHANGES_APPLIED: no

## Rebuttals — Round 9

- Round 8 lookup-spy finding is fixed and accepted: the test injects `_ContactDetailLookupSpy` through `AppServices.contactDetail` and asserts both customer and supplier lookup counters are zero (`test/core/contact_detail_type_selection_route_test.dart:123-159,265-289`). The production route reaches those methods only after validating the discriminator (`lib/pages/stammdaten/master_data_pages.dart:775-802`).
- Round 7 typed-route task finding is fixed and accepted: tasks 6.13–6.24 name the mapped tests and provide per-scenario red-green-refactor ordering (`tasks.md:87-98`).
- Round 7 focused-evidence finding is fixed and accepted: test-plan.md records the current focused command and 83 passing tests, matching the supplied 83/83 result (`test-plan.md:37-42`).
- Round 7 full-suite finding remains open: verify.md correctly records 1,313 passed and 63 failed and sets `DECISION: FAIL`.
