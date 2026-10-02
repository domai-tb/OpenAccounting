## Context

`/banking` is served by `BankImportPage`, which currently talks directly to `BankImportService` and the database executor. Review displays the transaction fields and category but no score or journal candidate (`lib/features/bank_import/bank_import_page.dart`, `_buildReviewTable`). `BankImportService.computeScore` already calculates the maintained 40/30/30 amount/date/partner score, but it is called only inside import persistence. `applyRules` reads `auto_filter_regeln` ordered by priority and performs case-insensitive substring matching on Verwendungszweck. There is no production UI for managing those rules; search found no other rule-management owner.

The database already has `auto_filter_regeln` columns for pattern, category, account, priority, and active state. This change should reuse that table and the existing bank-import workflow. The archived `bank-import-workflow-integrity` contract owns confirmed imports, deduplication, and partial-row retry. The maintained `bank-import-recovery-surface` spec owns history actions. Neither is replaced here.

The detailed scoring and rule language in `docs/04-bank-import.md` conflicts with the maintained `bank-import` spec and service behavior. This proposal keeps the current OpenSpec scoring and substring-rule contracts and includes bringing the documentation into line with them.

## Goals / Non-Goals

**Goals:**

- Show the existing score and best journal candidate in Review before confirmation.
- Let users manage persisted category rules from the Banking workspace.
- Keep score suggestions, category edits, and rule edits separate from journal posting and payment allocation.
- Retain current dedupe, partial-import, and retry semantics.

**Non-Goals:**

- Changing the score formula, match thresholds, automatic/manual mode policy, or rule matching/order semantics.
- Creating journal postings, applying receipts/payments, splitting transactions, or changing receivable balances.
- Replacing the current import workflow or duplicating the history/recovery capability.
- Adding a new rules table, matching package, or separate route.

## Decisions

1. **Compute preview matches before confirmation with the existing scorer.** Load the candidate journal rows through the existing bank-import service boundary and evaluate them using `computeScore`. Keep the score and selected candidate in the review-row projection; do not persist them as accounting facts. The review table adds confidence and candidate columns using the existing design-system table and status treatments. A `0%` score renders an explicit no-match state. Reimplementing the scoring formula in the widget was rejected because it would allow the UI and import service to disagree.
2. **Manage the current rule shape in the existing workspace.** Add a Rules view to `/banking` that lists pattern, category, priority, and active state and supports create/edit/enable-disable/delete. Extend `BankImportService` for the rule reads/writes and keep validation at that boundary. The same `auto_filter_regeln` table and current pattern matcher remain authoritative. A second rules repository/table or a new settings route was rejected as duplicate ownership.
3. **Keep suggested matches separate from settlement.** Review confidence is advisory. Manual review cannot set `journal_id` from a score. This change performs no journal or receivable writes. Any later action that posts or applies a bank transaction must follow `balanced-journal-postings-and-settlement-events` and its accepted money/account contracts. Suggestions are not payment allocations.
4. **Preserve existing recovery ownership.** Continue calling the existing import path for confirmed rows and preserve its duplicate and partial-failure outcomes. Do not introduce a second retry mechanism or change history status policy. The existing `bank-import-recovery-surface` requirement remains the acceptance contract for history details/actions.
5. **Update the conflicting documentation in the same implementation.** Replace the stale score-factor table, rule types/order, and confidence descriptions in `docs/04-bank-import.md` with the maintained `bank-import` OpenSpec contract. An alternative was to introduce regex, partner, amount-range, and combined rules plus a different score formula; that is rejected in this change because it would redefine behavior already represented by the maintained spec and service.

## Risks / Trade-offs

- [The current candidate query scans the journal and may be slow for large ledgers] → Reuse the existing scorer and candidate source for this change; add indexed narrowing only when measured review latency requires it.
- [A database failure can look like an empty rule list] → The rule view SHALL render an unavailable/retry state separately from a successfully loaded empty list, consistent with route-state requirements.
- [Users may expect the richer matcher documented today] → Update `docs/04-bank-import.md` to the maintained contract and identify that correction in release notes; do not silently ship mixed semantics.
- [A score can be mistaken for a confirmed payment] → Label it as a suggestion and keep the no-posting/no-settlement boundary visible in the review state.

## Migration Plan

No schema migration is needed for the current rule fields. Add preview scoring and the rule-management view over the existing service/table, then update `docs/04-bank-import.md`. Existing imports and rules remain readable. A source rollback removes the new UI and service methods without data rollback; rule values continue to use the same table. Implement after the balanced-posting dependency is accepted wherever an action would create accounting or settlement effects.

## Open Questions

- Does the product intend to restore the richer regex/partner/amount/combined matcher and alternate score factors currently written in `docs/04-bank-import.md`? This proposal deliberately follows the maintained OpenSpec/service contract; a different answer needs a separate reviewed scoring/rule contract before implementation.
