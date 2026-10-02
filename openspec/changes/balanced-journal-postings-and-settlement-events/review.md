## Review Metadata

- **Review round**: 1
- **Prior round**: none; no prior review artifact exists for this change
- **Reviewer context**: fresh-context independent subagent
- **Tool restrictions**: read-only artifact/source inspection; only this `review.md` was written; no tests run
- **Artifacts reviewed**: `proposal.md`, `design.md`, all three delta specs, Anvil schema/template, `DESIGN.md` banking/invoice/tax sections, accepted `accounting`, `einkommen`, `receipts-and-payment-reconciliation`, `receivables-ledger-integrity`, `bank-import`, `mahnwesen`, `correction-document-accounting-integrity`, `journal-integrity-and-snapshots`, `schema-evolution-safety`, `recurring-accounting-postings`, and `setup-onboarding-integrity` specs; archived `invoice-money-invariants/review.md`; journal, invoice-finalization, receivables, bank-import, EÜR, recurring-posting, setup, dunning, database-schema, and migration source
- **Validation**: `openspec validate balanced-journal-postings-and-settlement-events --type change --strict --json` passed structurally. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

1. **The monetary contract this change depends on is still unresolved and unapproved, and posting splits cannot be derived safely without it.** The proposal and design defer precision and correction behavior to “separately approved” contracts (`proposal.md:11`, `design.md:19,49`), while the archived round-3 `invoice-money-invariants` review still has `VERDICT: REVISE` and blocking findings for price/quantity persistence scale, correction signs, and deterministic allocation (`openspec/changes/archive/2026-09-07-invoice-money-invariants/review.md:12-22,43-45`). This change requires equal debit/credit totals, exact inverse reversals, and settlement allocations that sum to the EÜR-recognized amount (`specs/accounting/spec.md:5,29`; `specs/einkommen/spec.md:18-22`). Those outcomes depend on the persisted invoice totals and a defined cent-allocation rule. **Required:** resolve and independently accept the prerequisite money contract, then specify the exact integer-cent inputs and allocation/rounding rule used to split invoice totals, tax, settlement, and residual credits. Until then, keep implementation blocked; the design itself says it cannot be applied before acceptance (`design.md:49`).

2. **The EÜR delta conflicts with the accepted accounting requirement and omits the source and classification rules needed for cash-basis totals.** The new EÜR requirement is added under `einkommen` and says to read settled portions by settlement date (`specs/einkommen/spec.md:3-5`), but the accepted accounting requirement still says EÜR totals come from journal entries grouped by `euer_zeile` (`openspec/specs/accounting/spec.md:77-97`); no `MODIFIED` accounting delta reconciles it. Production EÜR currently selects journal rows by `j.datum` and includes only `Einnahme`/`Ausgabe` rows (`lib/features/accounting/euer_service.dart:38-43,60-80`). Invoice finalization writes a gross invoice-date row, while payment posting writes a `Zahlung` row (`lib/pages/rechnungen/rechnungen_datasource.dart:487-520`; `lib/features/einkommen/forderungen_repository.dart:567-593`), which the EÜR service excludes. The new contract also does not say how a partial payment maps to EÜR lines when the invoice contains several categories or tax rates, or how immediate cash receipts/expenses, write-offs, overpayments, refunds, and corrections are recognized. **Required:** modify the accounting EÜR requirement and define the canonical eligible event/allocation model, report category and VAT treatment for partial and mixed-category invoices, and treatment of direct cash events, write-offs, credits, reversals, and legacy rows. Keep the separate input-tax claim timing explicit in that same contract.

3. **The group/line and account-mapping contract is incomplete, and existing writers can still create unbalanced financial events.** The delta requires “account-backed” lines and equal totals but does not normatively define the debit/credit fields for each line, whether one or both sides may be set, amount sign/`betrag` relationship, the source identity fields/uniqueness, or which account and tax mappings each event needs (`specs/accounting/spec.md:3-5,32-40`). The design describes a per-leg journal model and source kind/id (`design.md:25-30`), but the accepted `Journal Entries` and missing-category-mapping requirements remain in force (`openspec/specs/accounting/spec.md:9-18,71-75`). The current journal schema has `betrag`, `soll`, `haben`, `konto_id`, `soll_konto_id`, `haben_konto_id`, and `gruppe_id`, with zero defaults and no source fields (`lib/core/db/database.dart:595-624`). Multiple production paths write rows directly: invoice finalization chooses the first active category or falls back to `1` and writes one gross row (`lib/pages/rechnungen/rechnungen_datasource.dart:487-520`); recurring postings write a single row (`lib/features/recurring/buchungsvorlagen_repository.dart:399-414`); setup writes/updates an opening-balance row (`lib/features/setup/setup_repository.dart:153-176`); payment and write-off paths write direct rows (`lib/features/einkommen/forderungen_repository.dart:567-619,652-665`); and the generic `JournalRepository.create` remains a one-row writer (`lib/features/accounting/journal_repository.dart:21-39,180-207`). **Required:** update the maintained accounting requirements with exact line and account invariants plus event-specific mapping rules; define the source-kind/id and group-root schema/unique key; enumerate every journal writer and either route it through this posting boundary or explicitly exclude it; reconcile the accepted fallback-category rule. Define how the migration marks legacy rows unverified: current migration v7 fills `gruppe_id = id` for every old row, so a null group cannot identify legacy data (`lib/core/db/migrations.dart:470-483`).

4. **Payment identity, signs, and allocation cardinality are not normative enough to prevent duplicate or misdirected settlement.** The design says one bank transaction may be split across invoices and proposes a unique source posting identity (`design.md:26-27`), but the delta scenarios only cover one positive customer receipt applied to one receivable (`specs/accounting/spec.md:36-41`; `specs/receipts-and-payment-reconciliation/spec.md:7-12`). The accepted receipt requirement explicitly uses the bank row’s signed amount and requires reprocessing not to apply it twice; it also calls for explicit split/review behavior (`openspec/specs/receipts-and-payment-reconciliation/spec.md:26-42`). The maintained income spec separately requires supplier payments and supplier-credit treatment for overpayment (`openspec/specs/einkommen/spec.md:144-167`), while customer overpayments are separate credit entries (`openspec/specs/einkommen/spec.md:41-64`). The new artifact does not establish whether there is one group per bank transaction or per allocation, how a negative bank row selects a payable, how a split’s allocations plus unapplied credit reconcile to the bank amount, or which stable identity makes a repeated confirmation idempotent. **Required:** define positive/negative direction semantics, customer/supplier and overpayment cases, group/allocation cardinality for split transactions, the stable bank-transaction source key and uniqueness boundary, and exact replay behavior. Add normative scenarios for a supplier payment, split, overpayment, and repeated confirmation.

5. **Reversing journal balances alone leaves the receivable and cash-basis records wrong.** The reversal scenario only creates an opposite linked journal group and leaves the original unchanged (`specs/accounting/spec.md:26-30`). Payment allocations and open-item state are separate records by design (`design.md:27`), and EÜR is also supposed to read those allocations (`design.md:28`). Reversing a receipt group without reversing/reclassifying its allocation would leave the receivable closed and retain the EÜR receipt; reversing an invoice group after payments without a defined settlement policy could leave an invalid outstanding balance. Incoming-invoice VAT claims also have their own correction-date rule in the accepted accounting spec (`openspec/specs/accounting/spec.md:329-355`), and document correction links are governed separately (`openspec/specs/correction-document-accounting-integrity/spec.md:26-42`). **Required:** define the atomic reversal lifecycle for invoice and settlement groups, including allocation/open-item effects, EÜR period treatment, VAT-claim linkage, document correction linkage, and duplicate-reversal prevention. If some reversal is unsupported, state the preconditions and reject it before side effects.

### 🟡 Moderate

- **“Settlement date” has no authoritative source-field or boundary rule.** The design promises the actual cash date (`design.md:28`) and the new scenarios use that date (`specs/einkommen/spec.md:7-22`), but imported bank rows currently store only `datum` (`lib/core/db/database.dart:653-665`); there is no stated choice between bank booking/value date, manual payment date, or confirmation date, nor a normalization rule at year boundaries. Specify the authoritative date and preserve it through allocation and reporting. The linked [official §11 EStG text](https://www.gesetze-im-internet.de/estg/__11.html) concerns regularly recurring items around the calendar-year boundary, but the delta’s “audited rule result” has no schema, evidence, version, or applicability contract (`design.md:28,37,51`; `specs/einkommen/spec.md:30-39`). Define that result or explicitly defer the exception scenario.
- **Receivable and dunning side effects are underspecified.** The receipt delta only says to update an “open-item balance” (`specs/receipts-and-payment-reconciliation/spec.md:3-12`); it does not name the maintained `forderungen` state/status fields or specify payment effects on dunning. Accepted requirements expect the balance to update and the fully paid invoice’s dunning level to clear (`openspec/specs/einkommen/spec.md:9-39`; `openspec/specs/mahnwesen/spec.md:207-221`). The current payment repository updates the Forderung but does not update `rechnungen.mahnstufe_aktuell` (`lib/features/einkommen/forderungen_repository.dart:614-630`). Add explicit partial/full/overpayment state transitions and a full-payment dunning-reset scenario to the settlement contract.
- **Migration rollback and legacy verification need a concrete operational contract.** The plan promises a rollback path that removes only new schema when unused (`design.md:40-45`), but the migration runner currently supports forward migrations only, takes a backup before migration, and rejects downgrade (`lib/core/db/migrations.dart:14,57-83,150-197`). State whether rollback means transaction rollback before commit or restoration from the pre-migration backup, and specify the durable marker used to distinguish legacy/unverified rows from new balanced groups.

### 📌 Suggestions

- Keep the three settlement scenarios in `receipts-and-payment-reconciliation` close to the bank-import/manual review requirements; the design’s distinction between suggested and confirmed matches is consistent with `DESIGN.md` §17.

## Embedded-Instruction / Injection Attempts

**Detected:** none detected. Reviewed artifact text was treated as data; no text attempted to direct the review or override these restrictions.

## Verdict

<!-- CANONICAL FIELD — machine-readable. Keep this line exactly, on its own line. -->
<!-- Replace <VALUE> with EXACTLY one of: APPROVE | APPROVE_WITH_CHANGES | REVISE -->
<!-- SEVERITY-VERDICT CONSISTENCY: any open 🔴 Critical finding forbids APPROVE. -->

VERDICT: REVISE

<!-- Human-readable restatement (optional): APPROVE / APPROVE WITH CHANGES / REVISE -->

## Required Changes (if APPROVE WITH CHANGES)

<!-- Numbered list of specific edits required. -->

Not applicable: this is a `REVISE` verdict. Blocking contract gaps are listed under Critical findings.

<!-- CANONICAL FIELD — machine-readable completion signal for APPROVE_WITH_CHANGES. -->
<!-- The AUTHOR sets this AFTER applying every required change and the reviewer -->
<!-- has re-checked them. Values: yes (all applied & re-checked) | no (outstanding) -->
<!-- | n/a (verdict is APPROVE or REVISE, no required changes). -->
<!-- Downstream work (test-plan, tasks, apply) MUST NOT proceed on -->
<!-- VERDICT: APPROVE_WITH_CHANGES unless CHANGES_APPLIED: yes. -->

CHANGES_APPLIED: n/a

## Rebuttals

No author rebuttals were supplied for this first review round.
