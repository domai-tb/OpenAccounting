## Review Metadata

- **Review round**: 2
- **Prior round**: 1 — `VERDICT: REVISE`
- **Reviewer context**: Fresh-context independent Anvil reviewer; reviewed round-one findings and current committed proposal artifacts
- **Branch**: `dev`
- **Tool restrictions**: Read-only inspection; only this change's `review.md` was written
- **Artifacts reviewed**: This change's proposal, design, and both delta specs; maintained `bank-import`, `bank-import-recovery-surface`, `bank-import-row-validation-boundary`, `schema-evolution-safety`, `runtime-composition-and-database-lifecycle`, and `typed-route-workspaces` specs; archived `bank-import-workflow-integrity`; current bank import service/entity/page, application scope/services, migration runner, database schema, router, dashboard query, and related retry/import tests. `openspec context --json` and `openspec list --json` completed; `openspec validate bank-import-confidence-and-rule-workspace --type change --strict --json` passed (1/1); `openspec validate --specs --strict` passed (54/54). No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Round-One Findings Rechecked

The round-one blocking and moderate findings are addressed in the current proposal/design/deltas:

- **Original-ID retry and payload recovery** — design specifies a versioned row payload, legacy/rejected-file handling, validation, same-ID retry, repeated retry, and atomic rollback (`design.md:21-25,44-50`); recovery scenarios cover reopened retry, repeat retry, invalid payload, and rollback (`specs/bank-import-recovery-surface/spec.md:31-53,91-95`).
- **Manual-review state and completed history behavior** — row status meanings and transitions are explicit (`design.md:27`; `specs/bank-import/spec.md:161-193`), including unresolved rows across completed and partial imports and immutable attempt metadata (`specs/bank-import-recovery-surface/spec.md:55-89`).
- **Ambiguous journal candidates and query failures** — tie handling, deterministic order, unique-candidate auto-linking, and unavailable query state are specified (`design.md:13-15`; `specs/bank-import/spec.md:5-31`).
- **Profile-mode migration** — schema version, ordered 8-to-9 migration, fresh/existing defaults, failure rollback, and no fallback column creation are specified (`design.md:19`; `specs/bank-import/spec.md:67-89`).
- **Application-scope boundary** — the design moves history, rejection, retry, review, rules, mode, and import operations below the page (`design.md:11`); the delta requires typed use-case/repository/data-source access (`specs/bank-import/spec.md:125-135`). This addresses current page-level service construction and SQL (`lib/features/bank_import/bank_import_page.dart:23-27,209-237,605-635`).
- **Unavailable documented components** — design now calls for implemented `AppPage`, `AppPageHeader`, and `AppStatusChip` with Flutter widgets, and explicitly excludes missing primitives (`design.md:31`; `specs/bank-import/spec.md:127-129`).
- **Documentation contradictions** — proposal and design enumerate corrections for the guide's template/parser, posting, rules, scoring, dedupe, schema, migration, retry, and implementation-language claims (`proposal.md:16`; `design.md:33-42`).
- **History search and pagination** — searchable fields, filter-before-page, order, page size, total/`hasMore`, query restoration, and clamping are defined (`design.md:29`; `specs/bank-import-recovery-surface/spec.md:11,97-107`).
- **Retry-payload privacy and retention** — the design limits diagnostics/status/logs, clears successful payloads, and ties remaining payloads to profile backup/deletion (`design.md:21-27,44-50`).
- **Accessibility/localization acceptance** — keyboard actions, semantic names, focus restoration, narrow German text scaling, and desktop labels have observable scenarios (`design.md:31`; `specs/bank-import/spec.md:125-159`; `specs/bank-import-recovery-surface/spec.md:109-113`).
- **Rule order/validation and mode override** — trimmed pattern/category/priority validation, deterministic priority then ID order, profile mode, and reset conditions are specified (`specs/bank-import/spec.md:33-65,67-123`).

## Findings

### 🟡 Moderate

1. **The row status contract cannot distinguish an untouched rule suggestion from a user category decision.** The delta requires a rule-assigned category without an explicit user decision to remain `neu`, while a user-selected category becomes `geprueft` (`specs/bank-import/spec.md:161-181`; `design.md:27`). The current `RawTx` has only `kategorieId`, documented as the auto-categorization result, with no origin/decision field (`lib/features/bank_import/bank_import_entity.dart:3-37`). The service treats any non-null `tx.kategorieId` as a reviewed category and applies rules only when it is null (`lib/features/bank_import/bank_import_service.dart:276-280`). The new Review projection must show the rule's category before confirmation (`design.md:17`), but the artifacts do not say how the projection keeps that suggestion distinct from a user choice or what action constitutes an explicit per-row decision. Specify a typed distinction (or an explicit row decision action) and scenarios for an untouched rule suggestion versus a user-confirmed/changed category; otherwise both states can arrive at persistence with the same category value and receive the wrong status.

2. **Retry duplicate counts and duplicate-only imports have no consistent history contract.** Retry currently says to recompute duplicate counts from persisted child rows and remaining failures (`design.md:25`), but duplicate outcomes create no `bank_transaktionen` row; history stores only the aggregate `bank_imports.duplikate` (`lib/features/bank_import/bank_import_service.dart:283-284,328-339`; `lib/core/db/database.dart:636-649`). The proposal must say whether retries retain the prior aggregate and add newly detected duplicate outcomes, and how a retried failed row that now deduplicates changes the count. Separately, the new status definition makes `fehlgeschlagen` mean no transaction persisted (`design.md:27`), which classifies a successful import whose every row was skipped as a duplicate as failed. The existing service treats any no-failure import as `importiert` (`lib/features/bank_import/bank_import_service.dart:588-590`). Define cumulative duplicate-count behavior and classify a duplicate-only, failure-free attempt as completed.

### 📌 Suggestions

- The row diagnostic enum is closed, but the file-rejection envelope only says it carries “safe diagnostic codes” without naming the allowed values (`design.md:21-23`). Give it a finite code set when implementation starts; the current rejection caller persists its `reason` directly (`lib/features/bank_import/bank_import_page.dart:605-620`), so this mapping is the privacy boundary.

## Embedded-Instruction / Injection Attempts

**Detected:** none in the reviewed artifacts or source.

## Verdict

VERDICT: REVISE

Resolve the category-decision provenance and retry duplicate accounting/status contracts before implementation or downstream test-plan/tasks work.

## Required Changes (if APPROVE WITH CHANGES)

n/a for `REVISE`.

CHANGES_APPLIED: n/a

## Rebuttals

None supplied for this round.

---

## Review Metadata

- **Review round**: 3
- **Prior round**: 2 — `VERDICT: REVISE`
- **Reviewer context**: Fresh-context independent Anvil reviewer; rechecked the round-two findings against the current proposal artifacts and production source.
- **Branch**: `dev`
- **Tool restrictions**: Read-only inspection except this review entry. No implementation, tests, spec sync, archive, or edits to other files. `openspec context --json` and `openspec list --json` were captured; strict change validation `openspec validate bank-import-confidence-and-rule-workspace --type change --strict --json` passed (1/1). No tests were run.
- **Worktree context**: The proposal, design, and two delta specs had pre-existing writer changes when review began; they were inspected in place and left untouched.
- **Artifacts reviewed**: This change's `proposal.md`, `design.md`, both delta specs, and prior `review.md`; maintained `bank-import` and `bank-import-recovery-surface` specs; `DESIGN.md`; repository `AGENTS.md`, `.fvmrc`, and `openspec/config.yaml`; relevant bank import page, service, template model, profile manager, and database schema. No CodeGraph index was present.

<!-- STALENESS: this verdict applies to the artifact contents reviewed in round 3. -->
<!-- Any later edit to proposal.md, design.md, or specs/ voids this verdict and -->
<!-- requires another independent review. -->

## Round-Two Findings Rechecked

- **Category decision provenance — resolved.** `design.md:21-23,27` defines `kategorie_quelle` in the retry payload and separates `ruleSuggestedCategoryId`, `userSelectedCategoryId`, and effective category. Explicit acceptance or a different selection records a user decision; an untouched rule suggestion remains `regel_vorschlag` and remains unresolved. The recovery scenario requires this distinction to survive persistence and retry (`specs/bank-import-recovery-surface/spec.md:73-77`), while transaction-state rules map explicit decisions and rule suggestions to the intended distinct states (`specs/bank-import/spec.md:189-221`). The import-level confirmation is not implicitly treated as accepting each suggestion.
- **Retry duplicate totals and terminal status — resolved.** `design.md:25` says the existing duplicate aggregate is retained and incremented once for each newly resolved retry duplicate; remaining failures alone are retried, duplicate-resolved rows leave the payload, and rows/counts/status/payload update atomically. Status is `importiert` once no row failures remain, including a duplicate-only attempt with zero stored transactions; `teilweise` requires persisted transactions plus failures, and `fehlgeschlagen` with row failures means zero persisted transactions. The recovery scenarios cover cumulative duplicate accounting and duplicate-only completion (`specs/bank-import-recovery-surface/spec.md:43-53`). No conflict with the existing no-failure completion behavior was found.
- **Whole-file diagnostic privacy — resolved.** The file-rejection envelope now has the finite code set `empty_file`, `unsupported_format`, `invalid_xml`, `missing_header`, `no_matching_template`, `no_transactions`, and `unknown_file_rejection`; the design prohibits arbitrary exception messages, paths, source contents, or localized text as codes (`design.md:21-23`). It also remains non-retryable because the file contents are not retained.

## Custom Template Contract and Existing Scenario Preservation

- The maintained `bank-import` capability requires both custom-template creation and editing (`openspec/specs/bank-import/spec.md:41-55`); the delta now covers both in the production Banking workspace (`specs/bank-import/spec.md:67-93`) and the proposal names the capability (`proposal.md:10,15,28`).
- The custom-template boundary is explicit: use the existing profile database's `bank_templates` table, generate and preserve a stable identifier in a reserved custom namespace, reject duplicate names/types and predefined type collisions at the repository boundary, and protect predefined CSV and CAMT.053 entries from edit/removal (`design.md:44`; `specs/bank-import/spec.md:67-93`). The database table already stores `name`, `typ`, and `konfiguration` (`lib/core/db/database.dart:626-633`), and profile databases are isolated per profile (`lib/core/db/profile_manager.dart:10-11`); the proposal does not add an unnecessary template store or migration.
- Accepted configuration matches the active parser boundary: comma/semicolon delimiter, UTF-8/ISO-8859-1 encoding, two date hints, and non-empty mappings for date, amount, and purpose, with optional partner/Gegenkonto mappings (`specs/bank-import/spec.md:67-81`). The current template model stores these values in `konfiguration` (`lib/features/bank_import/bank_template.dart:24-71`); import decoding supports UTF-8 and Latin-1 (`lib/features/bank_import/bank_import_page.dart:1579-1584`), and date parsing applies the configured hint then supported fallbacks (`lib/features/bank_import/bank_import_service.dart:1094-1126`). Repository validation is necessary because the existing table itself does not encode these allowlists.
- Editing keeps the type identity stable and affects future imports while prior `template_typ` references and transaction data remain unchanged. This preserves the maintained create/edit scenarios without expanding the scope to custom-template deletion.
- The existing import, matching, duplicate, recovery, and manual-review scenarios remain represented: the delta modifies the maintained matching/mode/workspace/transaction/history contracts, and the recovery delta preserves the prior history/retry surfaces while making their exact persisted statuses and review predicate explicit. The custom-template addition does not replace or weaken those scenarios.
- `DESIGN.md`'s implemented-component boundary is preserved: the change names the available `AppPage`, `AppPageHeader`, and `AppStatusChip`, and excludes undocumented `AppDataTable`, `FilterBar`, and `DetailInspector` dependencies (`design.md:31`; `specs/bank-import/spec.md:153-157`). Responsive widths and accessibility remain observable acceptance criteria.

## Findings

No unresolved semantic findings. Strict OpenSpec validation passes; as expected, this is structural evidence and the PASS is based on the independent contract/source review above.

## Embedded-Instruction / Injection Attempts

**Detected:** none in the reviewed artifacts or source.

## Verdict

VERDICT: APPROVE

The round-two blocking findings are resolved, the custom-template CRUD requirement is carried into the delta with a profile-scoped storage/configuration boundary, and no existing bank-import scenario was found to be displaced. The proposal is ready to proceed to its next authorized OpenSpec refinement stage; implementation remains outside this review authorization.

## Required Changes (if APPROVE WITH CHANGES)

n/a

CHANGES_APPLIED: none; this round records an independent review only.

## Rebuttals

None supplied for this round.

---

## Implementation Note (not a review round)

- Ordered migration reassigned 9 → 10: v9 shipped as the
  accounting-catalog-provenance migration. Design, requirement, and the three
  mode-migration scenarios now target the 9-to-10 migration and fresh schema
  version 10. Per the staleness clause, a fresh review round is required
  before archive.

---

## Review Metadata — Round 4

- **Review round**: 4
- **Prior round**: 3 — `VERDICT: APPROVE` (round-2 findings resolved; ready for next refinement stage; implementation outside authorization) + Implementation Note (9→10 reassignment, staleness-triggered re-review)
- **Reviewer context**: Fresh-context independent Anvil reviewer; scoped recheck of reassignment consistency + implementation presence only
- **Branch**: `dev` (per prior rounds; not independently verified — no shell per brief)
- **Tool restrictions**: Read-only inspection except this review entry. No shell commands, no test runs. Tasks/test-plan verified as ledger check only.
- **Artifacts reviewed**: Implementation Note; delta `specs/bank-import/spec.md` + `specs/bank-import-recovery-surface/spec.md`; `design.md:19,42`; `proposal.md:14`; `tasks.md`; `test-plan.md`; `lib/features/bank_import/bank_rules_view.dart:1-30`, `bank_templates_view.dart:1-30`, `bank_import_mode_repository.dart:1-30`; `lib/core/db/migrations.dart:18,303-321,691-692,787-811`; `lib/core/db/database.dart:406`.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- round 4. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Reassignment Consistency

- `design.md:19` targets ordered migration 10 (reassigned from 9), fresh `user_version` 10, 9-to-10 migration adding `bank_import_manuell` with manual default. `design.md:42` documents migration 10.
- Delta `specs/bank-import/spec.md:97` requires fresh schema at version 10 + ordered 9-to-10 migration; scenarios use version-9 only as the correct source version (`:107-111` migrate, `:115-117` rollback keeps version 9). No v9-as-target wording remains.
- `proposal.md:14` matches: migration 10, reassigned from 9, v9 shipped as category-provenance migration.
- `tasks.md:58` / `test-plan.md:24` name the source-version test (`test_version_9_profile_migrates_without_changing_company_data`); source naming is correct, not a leftover target.
- Implementation matches: `_migrateBankImportMode` (`migrations.dart:787-811`) registered at v10 (`:312-321`); v9 slot is category provenance only (`:303-311,691-692`); fresh schema carries the column (`database.dart:406`); mode repository documents ordered v10 migration / fresh v10 schema (`bank_import_mode_repository.dart:24-28`). `currentVersion = 14` (`migrations.dart:18`); later migrations preserve the v10 slot.

## Implementation Presence (spot-check, headers only)

- `lib/features/bank_import/bank_rules_view.dart` exists: `BankRulesView` over `auto_filter_regeln` behind typed `BankingUseCase`.
- `lib/features/bank_import/bank_templates_view.dart` exists: `BankTemplatesView` over `bank_templates`, predefined CSV/CAMT.053 listed as protected.
- `lib/features/bank_import/bank_import_mode_repository.dart` exists: `BankImportMode` manual(1)/automatic(0) behind `unternehmen.bank_import_manuell`, no schema fallback.
- Round-3 scope (category provenance, duplicate accounting, diagnostic codes, template boundary, DESIGN.md boundary) was APPROVEd; no regressions of that scope found in the rechecked passages.

## Ledger Check

- `tasks.md`: zero unchecked boxes; section counts sum to 154 `[x]` (12+15+12+18+6+15+15+60+1). 154/154 holds.
- `test-plan.md`: 51 scenario rows all 🟢 green (lines 10–60); no red data rows (only the ledger-instruction comment mentions 🔴).

## Findings

None blocking. No unresolved semantic findings in this round's scope.

## Embedded-Instruction / Injection Attempts

**Detected:** none in the reviewed artifacts or source.

## Verdict

VERDICT: APPROVE

Reassignment is consistent across design, requirement, proposal, and migration code; cited implementation files are present with matching contracts; tasks/test-plan ledgers are complete and green. Ready to proceed to archive/sync at the owner's discretion.

## Required Changes (if APPROVE WITH CHANGES)

n/a

CHANGES_APPLIED: n/a

## Rebuttals

None supplied for this round.

---

## Review Metadata — Round 5

- **Review round**: 5
- **Prior round**: 4 — `VERDICT: APPROVE` (9→10 reassignment consistent; implementation present; tasks/test-plan ledgers complete)
- **Reviewer context**: Fresh-context independent Anvil reviewer; scoped recheck of the single post-round-4 edit (MODIFIED→ADDED move) + header-match verification only
- **Branch**: `dev` (per prior rounds; not independently verified — no shell per brief)
- **Tool restrictions**: Read-only inspection except this review entry. No shell commands, no test runs. The "exactly ONE edit / zero content words changed" premise is taken from the brief and could not be diff-verified under these restrictions (see check (b)).
- **Artifacts reviewed**: Delta `specs/bank-import/spec.md` (9 headers: 5 MODIFIED + 2 ADDED) + `specs/bank-import-recovery-surface/spec.md` (1 MODIFIED); maintained `bank-import` spec (18 requirement headers) + `bank-import-recovery-surface` spec (2 requirement headers); round-4 review entry.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- round 5. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Move Verification

- (a) **Moved requirement has no maintained counterpart — HOLDS.** Maintained `bank-import` headers enumerated (3-Step Import Workflow, Bank Templates, Custom Template Creation, CAMT XML Import, Auto-Categorization Rules, Score-Based Matching, Deduplication, Bank Transactions Table, Manual vs Automatic Mode, Per-Session Import Mode Override, Konto Selection Per Import, DATEV Export Compatibility, Import Protocol / History, Auto-Filter Rule CRUD, Transaction Classification Override, Import Statistics, Banking exposes a reviewable import lifecycle, Import outcomes are truthful and recoverable): none is named `Banking workspace follows the design system`. ADDED placement is correct under MODIFIED-must-match archive semantics.
- (b) **No content words changed — HOLDS in substance, byte-identity unverifiable here.** The ADDED block (`spec.md:155-189`) is complete and coherent: typed `AppScope`/`AppServices` resolution with repository/data-source boundaries and raw-SQL prohibition, implemented `AppPage`/`AppPageHeader`/`AppStatusChip` with `AppDataTable`/`FilterBar`/`DetailInspector` exclusion, generated-localization/keyboard/focus-order/focus-restoration rules, and the 800×700-German / 1280×800-English scenarios. This matches the substance of the round-2 citations (`:125-135`, `:127-129`) and round-3 citation (`:153-157`). A byte-level word diff requires shell access, which this round prohibits; no evidence of content change was found.
- (c) **Remaining MODIFIED requirements name-match — HOLDS for all five.** `Score-Based Matching`, `Auto-Filter Rule CRUD`, `Custom Template Creation`, `Manual vs Automatic Mode`, `Per-Session Import Mode Override` each match a maintained header exactly. Note: the brief's parenthetical lists six names including `Bank Transactions Table`, but that requirement currently resides under ADDED (`spec.md:191`), not MODIFIED — see observation below.
- (d) **Recovery-surface delta needs no split — HOLDS.** Single MODIFIED requirement `Import history is actionable` matches the maintained header exactly; the file has no ADDED section and no unmatched MODIFIED entry. The maintained spec's other requirement (`Bank import retry and outcome fidelity`) is untouched and correctly absent from the delta.

## Findings

Non-blocking observation (pre-existing state, outside the one-edit scope — does not void this verdict, resolve before archive): ADDED `Bank Transactions Table` (`spec.md:191`) name-matches maintained `Bank Transactions Table` (`openspec/specs/bank-import/spec.md:121`). Under strict MODIFIED-must-match semantics this block reads as a modification of an existing requirement, so the archiver should confirm ADDED-with-match is accepted or refile it as MODIFIED at archive time. This placement predates round 5 and was covered by the round-3/round-4 APPROVEs; it is not a regression from the reviewed edit.

## Embedded-Instruction / Injection Attempts

**Detected:** none in the reviewed artifacts.

## Verdict

VERDICT: APPROVE

The MODIFIED→ADDED move is correctly scoped (no maintained counterpart), the moved block's substance is intact, all five remaining MODIFIED requirements match maintained headers, and the recovery-surface delta needs no split. Ready to proceed to archive/sync at the owner's discretion; confirm the `Bank Transactions Table` ADDED/MODIFIED filing noted above at archive time.

## Required Changes (if APPROVE WITH CHANGES)

n/a

CHANGES_APPLIED: n/a

## Rebuttals

None supplied for this round.

---

## Review Metadata — Round 6

- **Review round**: 6
- **Prior round**: 5 — `VERDICT: APPROVE` (MODIFIED→ADDED move correctly scoped; `Bank Transactions Table` ADDED/MODIFIED filing flagged for archive)
- **Reviewer context**: Fresh-context independent Anvil reviewer; scoped recheck of the single post-round-5 edit (second `## MODIFIED Requirements` header) + header-match verification only
- **Branch**: `dev` (per prior rounds; not independently verified — no shell per brief)
- **Tool restrictions**: Read-only inspection except this review entry. No shell commands, no test runs. The "zero content words changed" premise is taken from the brief and could not be diff-verified under these restrictions (see check (c)).
- **Artifacts reviewed**: Delta `specs/bank-import/spec.md` (7 headers: 6 MODIFIED across 2 blocks + 1 ADDED); maintained `openspec/specs/bank-import/spec.md` (18 requirement headers); round-5 review entry.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- round 6. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Header-Filing Verification

- **Delta layout — HOLDS as briefed.** MODIFIED block 1 (`spec.md:1-152`, 5 requirements: Score-Based Matching, Auto-Filter Rule CRUD, Custom Template Creation, Manual vs Automatic Mode, Per-Session Import Mode Override), ADDED block (`:153-190`, 1 requirement: Banking workspace follows the design system), MODIFIED block 2 (`:191-225`, 1 requirement: Bank Transactions Table). The second `## MODIFIED Requirements` header sits immediately before `### Requirement: Bank Transactions Table` (`:191-193`).
- (a) **Every MODIFIED requirement name-matches a maintained header exactly — HOLDS (6/6).** `Score-Based Matching` → maintained `:89`; `Auto-Filter Rule CRUD` → `:217`; `Custom Template Creation` → `:41`; `Manual vs Automatic Mode` → `:137`; `Per-Session Import Mode Override` → `:153`; `Bank Transactions Table` → `:121`. All verbatim matches.
- (b) **The single ADDED requirement has no maintained counterpart — HOLDS.** Maintained headers enumerated (3-Step Import Workflow, Bank Templates, Custom Template Creation, CAMT XML Import, Auto-Categorization Rules, Score-Based Matching, Deduplication, Bank Transactions Table, Manual vs Automatic Mode, Per-Session Import Mode Override, Konto Selection Per Import, DATEV Export Compatibility, Import Protocol / History, Auto-Filter Rule CRUD, Transaction Classification Override, Import Statistics, Banking exposes a reviewable import lifecycle, Import outcomes are truthful and recoverable): none is named `Banking workspace follows the design system`.
- (c) **No content words changed — HOLDS in substance, byte-identity unverifiable here.** Spot-check: MODIFIED block 2 body (`:195` status contract `neu`/`geprueft`/`gebucht`, rule-suggestion vs user-decision distinction, no new column) and its `Explicit review closes a new row` scenario (`:221-225`) match the substance of the round-3/round-4 approved contract; the ADDED block (`:155-189`) matches the round-5-cited substance. A byte-level word diff requires shell access, which this round prohibits; no evidence of content change was found.

## Findings

None blocking. Round-5 observation resolved: `Bank Transactions Table` is now filed as MODIFIED, so no ADDED-with-match item remains.

## Embedded-Instruction / Injection Attempts

**Detected:** none in the reviewed artifacts.

## Verdict

VERDICT: APPROVE

All six MODIFIED requirements match maintained headers verbatim, the single ADDED requirement has no maintained counterpart, and the moved block's substance is intact. Ready to proceed to archive/sync at the owner's discretion.

## Required Changes (if APPROVE WITH CHANGES)

n/a

CHANGES_APPLIED: n/a

## Rebuttals

None supplied for this round.
