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
