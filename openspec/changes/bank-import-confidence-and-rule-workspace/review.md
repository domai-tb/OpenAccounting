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
- **Tool restrictions**: Read-only inspection except this review entry. No implementation, tests, spec sync, archive, or edits to other files. Strict change validation only: `openspec validate bank-import-confidence-and-rule-workspace --type change --strict --json` passed (1/1). No tests were run.
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
