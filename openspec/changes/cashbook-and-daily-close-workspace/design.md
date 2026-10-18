## Context

Feature-map §§36 and 39 require a dedicated cashbook, running cash balance, source documents, category/VAT/description fields, daily reconciliation, protected history, and formal daily closing (`pasted-text-1.txt:712-727,763-776`). The current `/banking` route is only `BankImportPage` (`lib/core/router/app_router.dart:133`), and `AppServices` registers no cashbook, journal, or daily-close use case (`lib/core/app_services.dart:21-45`). The `journal` schema has category, VAT, cash-account, receipt, debit/credit, and group columns, but the generic `JournalRepository.create` writes one row with `immutable = 0` and does not set debit/credit legs (`lib/core/db/database.dart:595-624`; `lib/features/accounting/journal_repository.dart:21-39,175-222`). It cannot be treated as a balanced cash event source.

The setup flow creates an opening Kasse journal row and separately assigns the opening amount to `konten.saldo` (`lib/features/setup/setup_repository.dart:96-176`). The cash-balance contract therefore treats the verified setup event as the one opening amount and uses `konten.saldo` only to corroborate it; it never adds both representations. The existing `tagesabschluesse` table has `datum`, `betrag`, `kassenbestand`, `differenz`, `konto_id`, and legacy `signatur`, but lacks `zaehlung_json` and a distinct integrity-digest column (`lib/core/db/database.dart:894-905`). The schema is v22 at this HEAD (`lib/core/db/migrations.dart:18`); this change reserves v25 after the v23 mileage migration and v24 setup anchor. No production cashbook or daily-close workflow exists in `lib`, and `PdfGenerator` exposes only generic snapshot rendering (`lib/features/pdf/pdf_generator.dart:9-12`).

The accepted `balanced-journal-postings-and-settlement-events` change is archived with round-2 approval and defines balanced `cash_payment` groups; this feature consumes that posting boundary for new cash events. It does not consume aggregate period summaries as an account balance. Instead, this change defines the typed account/date result, its source coverage, opening-cash treatment, and fail-closed behavior. The active `bank-import-confidence-and-rule-workspace` owns the `/banking` host and import/rule/history views, while `global-accounting-search` adds typed banking filters. This change adds separate `view=cashbook` and `view=close` states to the existing route and preserves import views. The maintained receipt-intake contract owns receipt bytes and intake; this change adds only the posting-reference transaction contract and creates no second file store. Receipt intake's existing crash recovery remains responsible for filesystem/database reconciliation and is not included in the cash posting transaction.

`DESIGN.md` requires a shallow desktop navigation and page-level tabs (`184-227,232-255`), structured labeled forms (`1224-1255`), keyboard operation and visible focus (`1187-1203,1448-1463`), and localized strings and active-locale date/amount formatting (`1108-1144,2004-2011`).

## Goals / Non-Goals

**Goals:**

- Add Cashbook and Daily Close views without adding another top-level Banking route or changing existing import history semantics.
- Present cash movements, categories, tax treatment, descriptions, and linked evidence from typed committed posting groups.
- Provide a running balance and close expected balance only when a complete typed result identifies company, cash account, as-of date, integer cents, currency, source reference, and completeness.
- Preserve daily close history as an immutable snapshot with a verifiable SHA-256 integrity digest and generate the existing PDF from that verified stored snapshot.
- Keep every financial write behind the approved application service; fail closed on missing contracts, mappings, or source completeness.

**Non-Goals:**

- Replacing the accepted posting service's gross/net, tax, category/account, or correction rules.
- Defining a general-purpose multi-currency conversion or a non-two-decimal cash balance representation.
- Counting imported bank rows, generic journal rows, `konten.saldo`, or free-text descriptions as cash movements without an approved typed source.
- Automatically posting a discrepancy, cash adjustment, or tax entry when a close is recorded.
- Building the separate quick-booking templates in feature-map §37 or implementing bank import/reconciliation changes owned by other proposals.

## Decisions

### Add views to the existing Banking route

Keep `/banking` as the canonical route. Add `view=cashbook` and `view=close` page states alongside the import/rules/history views owned by `bank-import-confidence-and-rule-workspace`; preserve its existing `view=history` filters and selected row. The Banking host resolves a cashbook use case through `AppScope`/`AppServices`; page widgets do not construct `JournalRepository`, issue SQL, or own posting rules. Use the existing shell, dense table, one primary action, explicit loading/empty/error/unavailable states, and query-backed list state.

This composes with the active Banking proposal without adding a competing route or another bank-import/rule store. Cashbook filtering operates on the typed cash projection and does not change bank-import matching or history.

### Delegate balanced cash events and atomically attach receipts

The form carries date, integer-cent amount and basis, income/expense intent, category, configured tax input, description, and optional existing receipt ID. The UI does not derive tax, choose a fallback account/category, or insert a journal row. It calls the accepted typed writer for a balanced `cash_payment` group and displays the event only after that service returns its posting-group identity and typed projection. When a receipt is selected, the posting group and receipt-to-posting relation commit in the same SQLite transaction. A failure at either write rolls back both; the receipt row and original file remain unchanged. Receipt intake and source-file writes retain their own crash-recovery contract and are not claimed to share a database transaction.

Until the accepted posting writer and required account/category/tax mappings are available, the view displays a localized setup/unavailable state and commits nothing. Existing generic journal rows, unmatched bank imports, and legacy opening rows are not treated as committed cash events merely because they contain `konto_id` or a cash-like description.

### Return one typed, complete account/date cash-balance result

The typed result contains `company_id`, `account_id`, `as_of_date`, nullable `balance_cents`, `currency_code`, `source_reference`, `complete`, and an unavailable reason when incomplete. `as_of_date` is the end of the selected local date. A complete result uses one account and supported two-decimal currency, includes verified setup opening cash exactly once, and accounts for every committed balanced `cash_payment` group through that date. The report consumes the opening setup event as the canonical opening fact; if `konten.saldo` duplicates it, that field is corroborating metadata and is never added. A conflicting, missing, duplicate, or ambiguous opening identity, unsupported currency, uncertain legacy coverage, or unbalanced/unlinked legacy row that could affect the account makes the result incomplete with no usable amount. The view displays the result as returned and never locally sums journal rows, reads `konten.saldo` as an as-of balance, infers zero, or converts currency. Aggregate reporting-period summaries do not satisfy this contract.

### Finalize daily close only from a complete source snapshot

The user selects the explicit company, account, and date and enters the count in integer cents. The close use case returns the complete expected result and source reference; it does not recalculate a balance in the UI. Existing columns map as `betrag = expected`, `kassenbestand = counted`, and `differenz = counted - expected`, all in the selected currency with exact two-decimal conversion from cents, and `konto_id` is the explicit selection. A nonzero difference requires a non-empty explanation. The finalization identity is `(unternehmen_id, konto_id, datum)`. Duplicate lookup, snapshot verification, and insertion run in one SQLite `BEGIN IMMEDIATE` transaction. A sole matching verified v1 snapshot is returned read-only; any matching legacy row, multiple rows, or ambiguous identity blocks new finalization. The transaction stores `zaehlung_json`, mapped columns, and `integrity_hash` together. The close writes no journal event; discrepancy correction remains outside this scope.

Version 1 has exactly these JSON fields: `account_id`, `company_id`, `counted_amount_cents`, `currency_code`, `date`, `difference_cents`, `expected_amount_cents`, `explanation`, `schema_version`, and `source_reference`. RFC 8785 JCS determines the fixed lexicographic property order; bytes are UTF-8 with no extra whitespace. Amounts are integer cents; the date is ISO `YYYY-MM-DD`; explanation is NFC text or null; unknown or absent fields and versions are invalid. `integrity_hash` is `sha256:` plus lowercase SHA-256 hex of the exact canonical UTF-8 bytes. It is a change-detection digest only, not a signature, identity assertion, or proof of key custody. New rows leave legacy `signatur` unchanged. On every load, the reader validates the schema, canonical text, and digest before labeling the record finalized. Legacy or mismatched data remains unverified and is not eligible for PDF.

### Render PDF from the immutable close result

Use the existing PDF abstraction with a typed finalized-close snapshot and active locale. The renderer first verifies the stored canonical snapshot and digest, then presents the expected amount, actual count, returned difference, note, date/account, currency, source reference, and an integrity-check label. It reads the stored snapshot only; it does not query the journal, recalculate balances/tax/differences, or change close state. Missing, legacy, unknown-version, malformed, or hash-mismatched evidence keeps the PDF action unavailable and produces no artifact.

### Follow the desktop and accessibility contract

Use keyboard-accessible tabs, row navigation, and entry fields with visible focus, logical traversal, semantic names containing the cash account/category and amount, and text that does not rely on color. All labels, tax/status/errors, notes, empty/unavailable states, and PDF actions use German and English generated catalogs. Dates and monetary values use the active locale. Layouts must work when the window narrows or text scales, while preserving explicit Save/Finalize actions for accounting operations.

## Risks / Trade-offs

- **[Risk]** A plausible number can still be incomplete because legacy/opening rows or a second cash account are missing. → **Mitigation:** require explicit account scope and a complete typed source result; otherwise hide the balance and block close.
- **[Risk]** A digest can be misrepresented as proof of who finalized a close. → **Mitigation:** call it an integrity hash only, make no signer/key-custody claim, and label it as an integrity check in UI/PDF.
- **[Risk]** The existing close table lacks versioned snapshot and digest fields. → **Mitigation:** reserve v25 to add nullable fields and protect finalized rows while leaving legacy rows untouched.
- **[Risk]** Cashbook scope collides with Banking import views. → **Mitigation:** use isolated `view=cashbook` and `view=close` states on the shared `/banking` host and preserve existing import query values.

## Migration Plan

1. Retain v23 for mileage and v24 for the setup anchor; reserve v25 for this close-evidence migration. Back up the profile database before migration, as required by the forward-only migration runner.
2. In v25, add nullable `zaehlung_json` and `integrity_hash` to the existing table and install immutability triggers for rows with a new digest or legacy `signatur`. Preserve table inventory and all old row values; do not backfill, reinterpret, or rewrite legacy evidence.
3. Wire cash-event writes through the accepted balanced posting service. Persist the selected existing receipt ID with the posting group in the same SQLite transaction. Build account/date results from one verified setup opening event and committed balanced cash groups; fail closed for incomplete or ambiguous history.
4. Wire close finalization through the typed close service and exact column/payload mapping above. Verify the stored snapshot and digest before finalized display or PDF generation; do not post a discrepancy.
5. A failed migration rolls back transactionally. Hiding the views on application rollback must preserve committed cash groups, receipt references, legacy close rows, and finalized snapshots; do not delete or rewrite persisted history.

## Open Questions

Correction of an erroneous finalized close remains out of scope: the existing verified snapshot is immutable, and no correction posting is created. A separate reviewed contract must define any future correction workflow.
