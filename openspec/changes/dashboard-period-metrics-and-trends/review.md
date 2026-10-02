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
