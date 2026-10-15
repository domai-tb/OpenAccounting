## Review Metadata

- **Review round**: 2
- **Prior round**: REVISE; round 1 called for period-scoped metrics, historical as-of balances, explicit margin/year-over-year behavior including a zero baseline, trend error/empty states, and complete quick-link scenarios. These edits are present and were re-checked.
- **Reviewer context**: Fresh-context independent subagent review.
- **Tool restrictions**: Read-only artifact/source/spec inspection; no tests or implementation run; only this review file was written.
- **Artifacts reviewed**: This change's proposal, design, and dashboard delta spec; maintained dashboard, accounting, receivables, payments, documents, income, localization/accessibility, runtime-composition, and typed-route specs; the active accounting-reporting, balanced-posting/settlement, and receivable-write-off proposals; `DESIGN.md` §11; `docs/07-dashboard.md`; dashboard, router, bank-import, localization, and service-composition sources.

Strict validation was run: the named change passed with 0 issues, and all 54 maintained specs passed. This is structural validation only. No test plan or task file exists for this change, and no executable tests were run.

## Findings

### 🔴 Critical (blocking)

1. **Historical balance source contract is incomplete for receivables and payables.** The dashboard requires balances as of a selected period end and says to subtract settlement, write-off, and correction events (`design.md:28,36,48`; delta spec `:57-61`). The maintained `receivables-ledger-integrity` contract covers a receivable statement built from signed invoice/correction entries and dated payments, but does not define a payable history source (`openspec/specs/receivables-ledger-integrity/spec.md:8-30`). The active balanced-posting design adds settlement dates (`openspec/changes/balanced-journal-postings-and-settlement-events/design.md:27`), while the active write-off requirement creates a linked `ausbuchen` relation without specifying an effective date (`openspec/changes/receivable-request-fingerprint-and-conditional-writeoff/specs/receivable-request-fingerprint-and-conditional-writeoff/spec.md:228-236`). The dashboard design itself leaves the event-date contract as an open question (`design.md:48`). Therefore a correct receivable/payable snapshot cannot yet be derived from the cited accepted contracts, and current status is explicitly insufficient. Define or identify an accepted typed as-of open-item source for both directions, including issue, correction, settlement, and write-off effective dates plus an incomplete-history result; add boundary scenarios for each event and legacy history. Otherwise narrow this KPI until that source is accepted. Do not implement a current-status fallback.

### 🟡 Moderate

1. **Unmatched-transaction attention items have no filtered banking destination in the current route graph.** The delta requires an action item to open the relevant filtered workspace (`specs/dashboard/spec.md:119-137`). `/banking` currently builds `BankImportPage` without reading route/query state (`lib/core/router/app_router.dart:133`); the page has no filter argument (`lib/features/bank_import/bank_import_page.dart:40-65`). The dashboard change's impact does not include the bank route or page. Define the filter state and include its route/page support in the change, or target an existing actionable route, then add an acceptance scenario proving the unmatched filter is applied.

### 📌 Suggestions

- The design says persisted unsupported quick links will be filtered on load and shown as removable (`design.md:38`), but the delta only tests rejection of a newly entered route (`specs/dashboard/spec.md:32-37`). Add a legacy-config scenario to keep this behavior testable.
- The change names Riverpod providers but not their service source (`design.md:25`). The maintained runtime contract forbids page-level repository/executor construction (`openspec/specs/runtime-composition-and-database-lifecycle/spec.md:28-36`), and the current provider constructs `DashboardRepository` from the database executor (`lib/features/dashboard/dashboard_widgets.dart:173-181`). Route the future provider through the composed dashboard use case/application service.

The period selector, period-bound flow/balance distinction, margin and comparison formulas, unavailable/empty trend states, accessible chart summaries, active-locale behavior, and add/edit/reorder/remove/reject quick-link scenarios are now explicit. The round-1 corrections address those findings.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable.

CHANGES_APPLIED: n/a

## Rebuttals

No author rebuttals were included in this review round. Round-1 findings were rechecked as resolved. The critical and moderate round-2 findings remain open. This is the second consecutive REVISE round; the Anvil template requires human escalation before another apply cycle.

---

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: REVISE (round-2 Critical: as-of receivables/payables source missing; Moderate: bank filter route; plus legacy quick-link and provider-routing suggestions)
- **Reviewer context**: Fresh-context independent subagent review.
- **Tool restrictions**: Read-only artifact/spec inspection; no shell, no tests; append-only to this review file.
- **Artifacts reviewed**: `proposal.md`, `design.md`, `specs/dashboard/spec.md`, `test-plan.md`, `tasks.md` in this change.

### Round-2 closure check (normative language)

1. **Critical — as-of receivables/payables source: CLOSED.** `design.md:5` + Decision 4 cite the `receivables-ledger-integrity` statement plus approved balanced settlement allocations/keyed `zahlung` effective dates (authoritative date: bank booking/value or manual cash date, verbatim) for receivables, and `einkommen` `rechnung_eingang` items plus approved supplier allocations for payables, with the invoice-money remainder rule noted as approved/archived. Delta spec covers it normatively: Historical open balance snapshot (`:69-73`), Historical payable snapshot (`:75-79`), Settlement split and reversal (`:81-85`), and Write-off/legacy without effective date (`:87-91`) all use SHALL/SHALL NOT, ending in incomplete-history unavailable with an explicit ban on silent exclusion or current-status inference.
2. **Moderate — bank filter route: CLOSED, no new route.** Actionable-attention-item requirement (`:147-149`) targets the existing canonical `/banking` route with typed `transactionId=<id>` selection coexisting with supported banking query state. Scenarios Open an attention item (`:151-154`) and Unmatched filter applied (`:156-160`) use SHALL, including the missing/malformed/unavailable-ID typed not-found case without changing other query state.
3. **Suggestions: CLOSED.** Legacy persisted quick link filtered on load (`:39-43`) uses SHALL filtered/removable without navigation. Provider routing is fixed in `design.md` Decision 1: providers composed from the dashboard use case/application service, never page-constructed repository/executor.
4. **Period scope: CLOSED and narrowed.** Annual calendar-year summary only; month/quarter explicitly unavailable until the reporting workspace accepts them (`design.md:11,26`; proposal `:7`; delta `:47-49`; Unsupported month/quarter/year scenario `:57-61` with SHALL NOT substitution ban).

### Hard gates honestly stated: YES

- **Reporting-workspace acceptance** (`accounting-reporting-workspaces` annual `AccountingPeriodSummary`, 2025 EÜR form) is gated in proposal Impact, design Risks/Migration/Open Questions, and delta `:49` (unavailable state naming the prerequisite, SHALL NOT substitute invoice/journal/bank totals).
- **Write-off/correction effective-date contract** (`ausbuchen` relation) is gated in proposal Impact, design Migration/Open Questions, and delta `:87-91` (incomplete-history unavailable, SHALL NOT silently exclude or infer).

### Non-blocking observation (not a gate)

`test-plan.md`/`tasks.md` do not yet list the six newest scenarios (legacy quick-link filter; unsupported month/quarter/year; payable snapshot; split/reversal; write-off/legacy unavailable; unmatched filter applied). Normative closure above is complete; test-plan sync can happen at implementation without changing meaning.

## Embedded-Instruction / Injection Attempts (Round 3)

**Detected:** none.

## Verdict (Round 3)

VERDICT: APPROVE

CHANGES_APPLIED: n/a
