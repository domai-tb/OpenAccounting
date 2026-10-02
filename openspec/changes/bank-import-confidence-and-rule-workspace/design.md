## Context

`/banking` is served by `BankImportPage`, which currently talks directly to `BankImportService` and the database executor. Review displays the transaction fields and category but no score or journal candidate (`lib/features/bank_import/bank_import_page.dart`, `_buildReviewTable`). `BankImportService.computeScore` already calculates the maintained 40/30/30 amount/date/partner score, but it is called only inside import persistence. `applyRules` reads `auto_filter_regeln` ordered by priority and performs case-insensitive substring matching on Verwendungszweck. There is no production UI for managing those rules; search found no other rule-management owner. The page calls `importTransactions` without its mode argument, so every import uses the service's manual default. No `unternehmen.bank_import_manuell` column or profile mode control exists. History is a read-only table even though `bank-import-recovery-surface` requires details, conditional retry/review actions, filtering, and pagination.

The database already has `auto_filter_regeln` columns for pattern, category, account, priority, and active state. This change should reuse that table and the existing bank-import workflow. The archived `bank-import-workflow-integrity` contract owns confirmed imports, deduplication, and partial-row retry. The maintained `bank-import-recovery-surface` spec owns history actions. Neither is replaced here.

The detailed scoring and rule language in `docs/04-bank-import.md` conflicts with the maintained `bank-import` spec and service behavior. This proposal keeps the current OpenSpec scoring and substring-rule contracts and includes bringing the documentation into line with them.

## Goals / Non-Goals

**Goals:**

- Show the existing score and best journal candidate in Review before confirmation.
- Expose the active profile's saved import mode and a one-import override.
- Let users manage persisted category rules from the Banking workspace.
- Complete the existing history contract with detail, safe failed-row retry, and a filtered manual-review view.
- Keep score suggestions, category edits, and rule edits separate from journal posting and payment allocation.
- Preserve successful rows and the original import ID when retrying only persisted failed rows.
- Follow `DESIGN.md` for responsive layouts, localization, keyboard/focus behavior, reusable components, and text status cues.

**Non-Goals:**

- Changing the score formula, match thresholds, automatic/manual mode policy, or rule matching/order semantics.
- Creating journal postings, applying receipts/payments, splitting transactions, or changing receivable balances.
- Replacing the current import workflow or duplicating the history/recovery capability.
- Adding a new rules table, matching package, or separate route.

## Decisions

1. **Compute preview matches before confirmation with the existing scorer.** Load the candidate journal rows through the existing bank-import service boundary and evaluate them using `computeScore`. Keep the score and selected candidate in the review-row projection; do not persist them as accounting facts. The review table adds confidence and candidate columns using the existing design-system table and status treatments. A `0%` score renders an explicit no-match state. Reimplementing the scoring formula in the widget was rejected because it would allow the UI and import service to disagree.
2. **Manage the current rule shape in the existing workspace.** Add a Rules view to `/banking` that lists pattern, category, priority, and active state and supports create/edit/enable-disable/delete. Extend `BankImportService` for the rule reads/writes and keep validation at that boundary. The same `auto_filter_regeln` table and current pattern matcher remain authoritative. A second rules repository/table or a new settings route was rejected as duplicate ownership.
3. **Expose mode without adding a posting path.** Add the profile-scoped `unternehmen.bank_import_manuell` setting with a safe manual default and a one-import override. Pass the effective mode to the existing service. Automatic mode may link a high-confidence bank row to an existing journal entry; it SHALL NOT create a journal row or payment. A new posting or settlement remains gated by `balanced-journal-postings-and-settlement-events`.
4. **Use the existing history record for recovery.** Add history detail and actions to the current page. Persisted `fehler_details` already contains failed-row payloads; retry only those rows under the same `bank_imports.id`, leaving successful rows and their transaction IDs unchanged. Manual review opens persisted unresolved rows filtered by import ID. Completed imports stay read-only. Search and pagination operate over typed history projections, not raw SQL columns in the UI.
5. **Update the conflicting documentation in the same implementation.** Replace stale score factors, rule fields/order, mode claims, and history descriptions in `docs/04-bank-import.md` with the maintained OpenSpec contract and actual Dart workflow. Do not restore regex, partner, amount-range, or combined rules without a separate reviewed contract.
6. **Keep Banking views inside the design system.** Reuse `AppPage`, `AppPageHeader`, `AppDataTable`, `FilterBar`, `DetailInspector`, spacing and status tokens. Localize every new label/error/state through generated resources, provide semantic confidence/status text, and preserve logical keyboard order and visible focus. The review table may scroll inside its bounded content region at narrow widths.

## Risks / Trade-offs

- [The current candidate query scans the journal and may be slow for large ledgers] → Reuse the existing scorer and candidate source for this change; add indexed narrowing only when measured review latency requires it.
- [A database failure can look like an empty rule list] → The rule view SHALL render an unavailable/retry state separately from a successfully loaded empty list, consistent with route-state requirements.
- [Users may expect the richer matcher documented today] → Update `docs/04-bank-import.md` to the maintained contract and identify that correction in release notes; do not silently ship mixed semantics.
- [A score can be mistaken for a confirmed payment] → Label it as a suggestion and keep the no-posting/no-settlement boundary visible in the review state.
- [Persisted import mode may be misread as account-wide] → Store it on the active profile's company record and label the one-import override separately.
- [Retry could duplicate already imported rows] → Resume the existing import ID from persisted failed-row payloads only; keep the current deduplication guard as a second boundary.

## Migration Plan

Add the `unternehmen.bank_import_manuell` column through the existing additive migration path with manual mode as the default for existing profiles. Add preview scoring, mode controls, rule management, and history actions over the current tables and service boundaries, then update `docs/04-bank-import.md`. Existing imports and rules remain readable; no transaction or rule backfill is needed. A source rollback removes the new UI and service methods while preserving the mode value and rules. Implement new journal/payment effects only after the balanced-posting dependency is accepted.

## Open Questions

- Does the product intend to restore the richer regex/partner/amount/combined matcher and alternate score factors currently written in `docs/04-bank-import.md`? This proposal deliberately follows the maintained OpenSpec/service contract; a different answer needs a separate reviewed scoring/rule contract before implementation.
- Does retryable failed-row payload data need an explicit retention or erasure policy beyond the active profile database's existing backup and deletion policy?
