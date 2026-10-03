## Context

Feature-map §§36 and 39 require a dedicated cashbook, running cash balance, source documents, category/VAT/description fields, daily reconciliation, protected history, and formal daily closing (`pasted-text-1.txt:712-727,763-776`). The current `/banking` route is only `BankImportPage` (`lib/core/router/app_router.dart:133`), and `AppServices` registers no cashbook, journal, or daily-close use case (`lib/core/app_services.dart:21-45`). The `journal` schema has category, VAT, cash-account, receipt, debit/credit, and group columns, but the generic `JournalRepository.create` writes one row with `immutable = 0` and does not set debit/credit legs (`lib/core/db/database.dart:595-624`; `lib/features/accounting/journal_repository.dart:21-39,175-222`). It cannot be treated as a balanced cash event source.

The setup flow creates an opening Kasse journal row and separately assigns the opening amount to `konten.saldo` (`lib/features/setup/setup_repository.dart:96-176`); an authoritative report must reconcile that duplicated representation under its approved source contract. `tagesabschluesse` already exists with `datum`, `betrag`, `kassenbestand`, `differenz`, `konto_id`, and `signatur`, but has no `zaehlung_json` column (`lib/core/db/database.dart:807-819`). The accounting spec refers to `zaehlung_json` and currently says expected cash is the sum of all journal entries for that day (`openspec/specs/accounting/spec.md:487-513`); the PDF spec expects a finalized `zaehlung_json` snapshot (`openspec/specs/pdf/spec.md:442-456`). No production Tagesabschluss or cashbook workflow was found in `lib`, and `PdfGenerator` currently exposes only generic snapshot rendering (`lib/features/pdf/pdf_generator.dart:9-12`).

At this HEAD, both `balanced-journal-postings-and-settlement-events` and `accounting-reporting-workspaces` have `VERDICT: REVISE`. The former review identifies unresolved monetary/source/mapping rules, including direct cash events; the latter defines aggregate reporting periods, not an account-scoped as-of cash balance. This change therefore also requires a separately approved typed cash-balance source contract covering account/date scope and completeness; approving the current reporting-workspace proposal alone does not satisfy that prerequisite. The active `bank-import-confidence-and-rule-workspace` owns the `/banking` host and import/rule/history views, while `global-accounting-search` adds typed banking filters. This change adds separate `view=cashbook` and `view=close` states to the existing route and preserves the import views. The active receipt-intake proposal owns evidence storage/intake; this change links selected receipt IDs through that owner and does not create a second file store.

`DESIGN.md` requires a shallow desktop navigation and page-level tabs (`184-227,232-255`), structured labeled forms (`1224-1255`), keyboard operation and visible focus (`1187-1203,1448-1463`), and localized strings and active-locale date/amount formatting (`1108-1144,2004-2011`).

## Goals / Non-Goals

**Goals:**

- Add Cashbook and Daily Close views without adding another top-level Banking route or changing existing import history semantics.
- Present cash movements, categories, tax treatment, descriptions, and linked evidence from typed committed posting groups.
- Provide a running balance and close expected balance only when an approved report result identifies its cash account, date scope, currency, and completeness.
- Preserve daily close history as a signed, immutable snapshot and generate the existing PDF from that snapshot.
- Keep every financial write behind the approved application service; fail closed on missing contracts, mappings, or source completeness.

**Non-Goals:**

- Defining gross/net input rules, tax calculation/timing, category-to-account mappings, account defaults, cash opening/balance math, the close difference sign/date cutoff, or correction-posting behavior.
- Counting imported bank rows, generic journal rows, `konten.saldo`, or free-text descriptions as cash movements without an approved typed source.
- Automatically posting a discrepancy, cash adjustment, or tax entry when a close is recorded.
- Building the separate quick-booking templates in feature-map §37 or implementing bank import/reconciliation changes owned by other proposals.

## Decisions

### Add views to the existing Banking route

Keep `/banking` as the canonical route. Add `view=cashbook` and `view=close` page states alongside the import/rules/history views owned by `bank-import-confidence-and-rule-workspace`; preserve its existing `view=history` filters and selected row. The Banking host resolves a cashbook use case through `AppScope`/`AppServices`; page widgets do not construct `JournalRepository`, issue SQL, or own posting rules. Use the existing shell, dense table, one primary action, explicit loading/empty/error/unavailable states, and query-backed list state.

This composes with the active Banking proposal without adding a competing route or another bank-import/rule store. Cashbook filtering operates on the typed cash projection and does not change bank-import matching or history.

### Delegate cash events to approved posting and receipt owners

The form carries date, user-entered amount with the basis declared by the approved owner contract, income/expense intent, category, configured VAT/tax input, description, and optional selected receipt ID. The UI does not derive tax, choose a fallback account/category, or insert a journal row. It calls one typed cash-event writer and displays a committed event only after that service returns its posting-group identity and typed projection. Receipt IDs resolve through the existing receipt/evidence owner; files are not copied into a cashbook-specific store.

Until the accepted posting contract explicitly covers direct cash income/expense events, account and category mappings, amount basis, and receipt linkage, the view displays a localized setup/unavailable state and commits nothing. Existing generic journal rows, unmatched bank imports, and legacy opening rows are not treated as complete cashbook history merely because they contain `konto_id` or a cash-like description.

### Use one authoritative complete cash-balance result

The cashbook balance and a daily close's expected amount come from the separately approved typed `account-cash-balance-source` contract for an explicit cash account and date. Its result carries amount, currency, requested account/date, source reference, and completeness/legacy status. The active aggregate reporting-workspace change is not this contract and cannot independently enable the balance. The view displays the approved result as returned and never derives it by summing the selected day's journal rows or reading `konten.saldo`. If the contract is absent, account identity is ambiguous, history is incomplete, or a legacy source cannot be verified, the balance/expected amount is unavailable—not zero—and close finalization and PDF export are disabled.

The running-balance and date-cutoff formulas remain with the approved report owner. This is necessary because setup currently represents opening cash in both the opening journal and the account's `saldo`; choosing one independently here risks double-counting or losing history.

### Finalize daily close only from a complete source snapshot

The user selects the date/account and enters the actual count. The accepted close use case returns the expected amount, difference/discrepancy state, and source snapshot; the UI does not recompute them. A nonzero/discrepancy outcome requires a non-empty explanation before finalization. The finalization identity is `(unternehmen_id, konto_id, datum)`. The writer performs its existing-record check and signed close insert inside one SQLite `BEGIN IMMEDIATE` transaction, so concurrent finalizers cannot create duplicates. If exactly one signed close is the only matching row, return it read-only; any matching unsigned legacy row, multiple rows, or ambiguous legacy close identity blocks finalization and requires a separately approved history-correction workflow. Finalization atomically stores close evidence and signature. The close itself writes no journal event; correction postings remain governed by a future approved correction contract.

The existing `tagesabschluesse` table is retained. Add the `zaehlung_json` column already required by the accounting/PDF specs, leave legacy rows untouched and unverified, and reject UPDATE/DELETE on signed close rows. The exact persisted mapping and canonical signature input must be approved before the writer is enabled; if they cannot be verified, no finalized close row is written.

### Render PDF from the immutable close result

Use the existing PDF abstraction with a typed finalized-close snapshot and active locale. The renderer only presents the approved expected amount, actual count, returned difference, note, date/account, and signature; it does not query the journal, recalculate balances/tax/differences, or change close state. Missing or unverified fields keep the PDF action unavailable and produce no artifact.

### Follow the desktop and accessibility contract

Use keyboard-accessible tabs, row navigation, and entry fields with visible focus, logical traversal, semantic names containing the cash account/category and amount, and text that does not rely on color. All labels, tax/status/errors, notes, empty/unavailable states, and PDF actions use German and English generated catalogs. Dates and monetary values use the active locale. Layouts must work when the window narrows or text scales, while preserving explicit Save/Finalize actions for accounting operations.

## Risks / Trade-offs

- **[Risk]** A plausible number can still be incomplete because legacy/opening rows or a second cash account are missing. → **Mitigation:** require explicit account scope and a complete typed source result; otherwise hide the balance and block close.
- **[Risk]** The active posting/reporting prerequisites remain unapproved. → **Mitigation:** keep writes, expected balances, finalization, and PDF unavailable until their required contracts are accepted and the direct cash-event case is covered.
- **[Risk]** The existing close table/spec do not match (`zaehlung_json` is specified but absent from production schema). → **Mitigation:** add only the declared nullable field, preserve existing rows, and block finalization until field mapping and signature input are reviewed.
- **[Risk]** Cashbook scope collides with Banking import views. → **Mitigation:** use isolated `view=cashbook` and `view=close` states on the shared `/banking` host and preserve existing import query values.

## Migration Plan

1. First resolve and independently approve the balanced-posting contract for direct cash events and the separate `account-cash-balance-source` contract for opening cash, account/date scope, legacy completeness, and balance result. These contracts must also settle tax inputs, difference output, and correction behavior before writes/finalization are enabled. Approval of the current aggregate reporting-workspace change alone is insufficient.
2. Add a backed-up, ordered migration that adds nullable `zaehlung_json` to `tagesabschluesse` and installs triggers protecting rows with a signature. Preserve every existing table and all existing rows; do not backfill derived values.
3. Wire typed cashbook, balance, and close use cases through the Banking application service and repository. Use the approved posting group projection for new/committed cash events and the approved reporting result for current/historical balances.
4. Add finalized close snapshot persistence and PDF rendering only after the field mapping and canonical signature input are accepted. Keep export unavailable if any source or snapshot field is incomplete.
5. Rollback may hide the cashbook views but must preserve committed journal groups and signed closes. Do not remove persisted history or rewrite legacy rows.

## Open Questions

1. **Posting prerequisite:** Does the approved balanced-posting contract include direct cash income/expense events as well as invoice settlements? What amount basis, debit/credit mapping, category/VAT mapping, evidence linkage, idempotency, and correction behavior apply? The active proposal is `REVISE`; no cash event writes are enabled until these are decided.
2. **Balance prerequisite:** Which separately owned `account-cash-balance-source` service is authoritative for the selected cash account/date, including the opening cash row created by setup, cash posting groups, profile boundaries, legacy/unbalanced rows, period cutoffs, and completeness status? The active reporting proposal supplies aggregate metrics only and is `REVISE`; no current or expected balance is displayed until the account/date source contract is independently specified and accepted.
3. **Daily close persistence:** How do the current `betrag`, `kassenbestand`, and `differenz` columns map to the approved expected/count/difference result, what exactly is serialized in `zaehlung_json`, and which canonical bytes are SHA-256 signed? The close writer remains disabled until the mapping is reviewed.
4. **Corrected closes:** How should an erroneous finalized close be corrected without rewriting its signed history? This proposal opens the existing close read-only and creates no correction posting; correction behavior remains a separate approved contract.
5. **Supporting evidence:** Which receipt/document use case owns cashbook attachment links, and what must be atomic if evidence linking fails? Reuse an existing stable receipt reference; do not add an independent file path or infer a receipt from text.
