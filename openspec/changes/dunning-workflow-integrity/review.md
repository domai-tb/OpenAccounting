## Review Metadata

- **Review round**: 1
- **Prior round**: none; no prior review artifact exists for this change
- **Reviewer context**: fresh-context independent subagent
- **Tool restrictions**: read-only inspection; only this `review.md` was written; no tests run
- **Artifacts reviewed**: this change's `proposal.md`, `design.md`, both delta specs, `AGENTS.md`, `.fvmrc`, `openspec/config.yaml`, `DESIGN.md`, maintained `mahnwesen`, `typed-route-workspaces`, `finalized-document-artifact-lifecycle`, and settlement/accounting specs; active `balanced-journal-postings-and-settlement-events` review; archived `invoice-money-invariants` review; dunning repository, stage repository, entity, schema, migrations, app service composition, router, and `docs/05-mahnwesen.md`
- **Validation**: `openspec context --json` and `openspec list --json` captured current state; `openspec validate dunning-workflow-integrity --type change --strict --json` passed structurally; `openspec validate --specs --strict` passed 54/54 maintained specs. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

1. **The dunning monetary path is gated in the design but not in the normative contract.** The proposal/design correctly defer dunning calculations until `invoice-money-invariants` is accepted and a balanced posting/settlement source exists (`proposal.md:16`, `design.md:27-30,47-49`). The archived money review still ends in `VERDICT: REVISE` (`openspec/changes/archive/2026-09-07-invoice-money-invariants/review.md:12-22,43-45`), and the active balanced-posting review is also `REVISE` with those same unresolved inputs (`openspec/changes/balanced-journal-postings-and-settlement-events/review.md:16-26,48`). However, the delta still normatively says the system SHALL calculate interest and evaluate settled balances (`specs/mahnwesen/spec.md:53,75-77`) without specifying a fail-closed unavailable result when the accepted source is absent or inconsistent. The only unavailable scenario covers database read failure (`specs/mahnwesen/spec.md:103-106`). Production `MahnungenRepository.create` currently uses invoice gross/net totals and stage days as interest days (`lib/features/mahnwesen/mahnungen_repository.dart:131-169`), so implementation needs an explicit prohibition on this fallback. **Required:** state in the dunning requirements that preview/calculation/create/send/package operations requiring balance or interest return an actionable unavailable result and perform no write when the accepted settlement/money source is unavailable or invalid; name that authoritative source and preserve the implementation gate until both upstream contracts pass independent review.

2. **The per-stage interest rate has no defined daily application across stage changes.** The contract selects annual percentage rates per level and says to calculate interest for each elapsed overdue day on unpaid principal using a 365-day year (`specs/mahnwesen/spec.md:5,75-82`). It does not say which level's rate applies to days before the current stage, whether the next-level rate is retroactive or starts on that stage's date, the exact interest start/end day, how same-day settlements affect principal, or when rounding occurs. The example holds one 8% rate constant for all 20 days and therefore does not settle the configured 0%/5%/8% stage transitions. A resulting rate or interval choice changes the amount presented to customers. **Required:** define the per-day rate timeline, accrual interval and settlement-date boundary, and deterministic rounding point in the normative requirement; add an example spanning two configured stages with a partial payment and observable expected cents. Keep the configured rates explicitly non-statutory as already intended.

### 🟡 Moderate

- **Stage dates combine grace and waiting periods ambiguously.** The delta says eligibility begins when “due date plus the configured grace period and next-stage waiting period” has elapsed (`specs/mahnwesen/spec.md:53`), while the four configured values are 7/21/35/49 days (`specs/mahnwesen/spec.md:5`) and the maintained singleton separately has `initial_grace_days` (`openspec/specs/mahnwesen/spec.md:239-253`). It is unclear whether each stage value is an absolute days-after-due threshold or an interval added after the previous reminder, and whether the grace period is added once or to every stage. The docs currently describe absolute days-after-due thresholds (`docs/05-mahnwesen.md:247-252`). **Required:** state one date equation and add boundary scenarios for first-stage eligibility and transition from level 1 to level 2.
- **Consolidation has no persisted relationship contract.** The delta requires a customer-level Mahnung linked to every invoice and each balance snapshot (`specs/mahnwesen/spec.md:53,70-73`), but the current schema and entity represent one `rechnung_id` per Mahnung (`lib/core/db/database.dart:771-787`; `lib/features/mahnwesen/mahnungen_entity.dart:3-40`); there is no `mahnungen_rechnungen` relation table in the schema. The design says every included invoice retains its source link but does not define how that mapping, per-invoice stage state, duplicate prevention, and later partial payments are persisted. **Required:** choose and specify the minimum record/link model for a consolidated letter, including idempotency and per-invoice snapshots, or narrow this proposal to separate invoice letters grouped for one send.
- **The corrected dunning documentation would still assert unresolved behavior.** The new documentation parity requirement corrects fee units/defaults and removes a blanket legal-compliance claim (`specs/mahnwesen/spec.md:162-174`), but `docs/05-mahnwesen.md` still says automatic customer blocking clears when all overdue amounts are paid and that evaluation runs on dashboard load and a scheduled check (`docs/05-mahnwesen.md:126-132,247-262`). The design leaves automatic-block release as an open policy question (`design.md:65-70`), and does not define a scheduler contract. **Required:** remove or mark those claims as unsupported until their behavior is specified and wired.
- **Automatic mode lacks an execution and confirmation boundary.** The delta names manual, assisted, and automatic modes, but only says that they share eligibility rules and that assisted mode requires confirmation (`specs/mahnwesen/spec.md:53-58`). It does not define what triggers an automatic run or whether automatic mode creates unsent drafts or sends messages. This matters because sending advances the invoice stage (`specs/mahnwesen/spec.md:108-139`). **Required:** specify the automatic trigger and its permitted side effects, or limit this change to manual/assisted runs.

### 📌 Suggestions

- Add an acceptance scenario for the `/mahnwesen` list/detail workspace at the documented narrow-window breakpoint with keyboard focus/order and localized loading, empty, and failure states. `DESIGN.md` requires responsive desktop layouts and keyboard-visible focus; the current delta names visual guidance in design but has no UI acceptance scenario.
- Use “transport accepted” for persisted delivery state in the UI and history, reserving “delivered” for evidence the SMTP adapter cannot provide. The design already states this boundary, but the normative spec uses the user-facing term “sent” (`specs/mahnwesen/spec.md:108-120`).

## Embedded-Instruction / Injection Attempts

**Detected:** none. Reviewed artifacts and source comments were treated as data and did not attempt to direct or override the review.

## Verdict

<!-- CANONICAL FIELD — machine-readable. Keep this line exactly, on its own line. -->
<!-- Replace <VALUE> with EXACTLY one of: APPROVE | APPROVE_WITH_CHANGES | REVISE -->
<!-- SEVERITY-VERDICT CONSISTENCY: any open 🔴 Critical finding forbids APPROVE. -->

VERDICT: REVISE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: this is a `REVISE` verdict. Blocking contract gaps are listed under Critical findings.

<!-- CANONICAL FIELD — machine-readable completion signal for APPROVE_WITH_CHANGES. -->
<!-- The AUTHOR sets this AFTER applying every required change and the reviewer -->
<!-- has re-checked them. Values: yes (all applied & re-checked) | no (outstanding) -->
<!-- | n/a (verdict is APPROVE or REVISE, no required changes). -->
<!-- Downstream work (test-plan, tasks, apply) MUST NOT proceed on -->
<!-- VERDICT: APPROVE_WITH_CHANGES unless CHANGES_APPLIED: yes. -->

CHANGES_APPLIED: n/a

## Rebuttals

None. This is the first review round.
