# OpenAccounting accounting and persistence audit

Audit date: 2026-09-29  
Checkout: `dev`, `70ec70c`, FVM Flutter `3.47.2`  
Scope owner: A (accounting and persistence); the architecture coverage manifest at `test/integration/audit/architecture-delivery-coverage.tsv` is owned by C and was not edited.

This is an evidence register, not a repair. No production files were changed. The rows below trace the actual page/provider/service/repository/Drift path where one was available, then compare the observed behavior with the maintained OpenSpec/docs contract and the current official sources in the companion source matrix.

## Review boundary and evidence

The pass covered the accounting, invoices, corrections, payments, receivables, bank import, inventory, recurring postings, dunning, setup/opening balance, tax reports, DATEV/EÜR/EKS, database schema/migrations/triggers, backup/restore, profile lifecycle, and their audit tests. Representative reviewed paths include:

- `lib/pages/rechnungen/**`, `lib/features/accounting/**`, `lib/features/einkommen/**`, `lib/features/bank_import/**`, `lib/features/recurring/**`, `lib/features/mahnwesen/**`, `lib/pages/stammdaten/**`;
- `lib/core/db/{database,migrations,gobd_triggers,backup_service,profile_manager,seed}.dart`, `lib/core/{app_services,injection}.dart`;
- `openspec/specs/{accounting,document-artifact-transaction,correction-document-accounting-integrity,bank-import,receipts-and-payment-reconciliation,recurring-accounting-postings,backup,profiles,pdf,pdf-rendering-completeness}/**`;
- the focused integration tests under `test/integration/audit/`, plus `test/db/{backup,profile}_test.dart` and accounting feature tests.

The repository baseline in `test/integration/audit/_baseline.md` records four pre-existing failing checks and seven analyzer infos from the earlier 2026-09-12 run. Those baseline failures are verification caveats, not silently reclassified as findings here. One coordinated FVM test run was completed after the pinned SDK cache became writable: 55 tests passed across invoice lifecycle, corrections, bank import, receipts, recurring postings, inventory, tax reports, profile lifecycle, backup, and GoBD trigger tests. This verifies the existing scenarios; it does not close findings whose missing scenarios are named below.

## Finding register

Each entry is one actionable row. “Owner/status” identifies the next review owner; it does not authorize implementation.

### A-001 — Document finalization posts effects without a type policy

- **Exact location:** `lib/pages/rechnungen/rechnungen_datasource.dart:124-214,217-580,583-832,835-986`; `openspec/specs/document-artifact-transaction/spec.md:8-10`; `openspec/specs/accounting/spec.md:329-355`; `docs/01-rechnungen.md:42-64`.
- **Source/expected:** The maintained document matrix says Rechnung can create receivable/journal/inventory, Storno reverses, Gutschrift records a credit/reversal, and Angebot/Auftrag/Proforma/Lieferschein are document-only. The accounting spec limits an input-tax claim to a finalized `Eingangsrechnung` and its Storno.
- **Actual:** `finalizeRechnung` accepts any stored `typ`, decreases stock, writes a journal, creates a receivable, and inserts `vorsteuer_ansprueche` whenever VAT is non-zero. `createGutschrift` writes a finalized negative document without the corresponding effects; `stornoRechnung` accepts any finalized document and uses `correctionSign` without a complete source-effect policy.
- **Reproduce/evidence:** `test/integration/audit/invoice-accounting-posting-lifecycle_test.dart:77-82` currently expects an outgoing invoice to create a Vorsteuer row, directly contradicting the maintained input-tax contract. `test/features/rechnungen/gutschrift_test.dart:80-98` fixes a positive linked Gutschrift/Storno total but does not settle the posting semantics.
- **Severity/impact:** High; accounting, correction, PDF, inventory, and receivable results can disagree by document type. The Gutschrift-to-Storno sign and standalone credit-note policy are product decisions still blocking a final legal interpretation.
- **Affected paths/platforms:** All persisted profiles and Linux runtime behavior; macOS/Windows static behavior shares the same Dart/Drift code.
- **Minimal proposed fix:** Freeze one typed posting matrix, make the finalizer dispatch by document type, permit input-tax claims only for incoming invoices, and reject unsupported finalization types. Record the chosen Gutschrift/Storno sign and effect policy in the spec before changing code.
- **Regression scenario:** Finalize outgoing/incoming Rechnung, Gutschrift, Storno, Angebot, Auftrag, Proforma, and Lieferschein; assert exact journal, receivable, inventory, tax-claim, PDF, and idempotency effects for each.
- **Owner/status:** A plus product owner; **OPEN / contract decision required**.

### A-002 — Journal rows are not a complete double-entry or immutable posting

- **Exact location:** `lib/core/db/database.dart:580-610`; `lib/features/accounting/journal_repository.dart:175-208`; `lib/pages/rechnungen/rechnungen_datasource.dart:464-501`; `lib/features/einkommen/forderungen_repository.dart:333-433`; `lib/core/db/gobd_triggers.dart:30-40`; `lib/core/db/seed.dart:109-123`; `docs/02-buchhaltung.md:3-5,48-63`.
- **Source/expected:** Product docs promise double-entry bookkeeping, SKR03/SKR04 accounts, and immutable posted entries. GoBD Rz 107-111 requires later changes to preserve the original and the fact of change; the source matrix records the official text.
- **Actual:** Production inserts populate only `betrag`/type/snapshots while `soll`, `haben`, `soll_konto_id`, and `haben_konto_id` remain null. Manual/setup/payment/recurring rows leave `immutable=0`. The insert trigger is deliberately disabled, and the seed creates synthetic account numbers `8001..8085`/`4001..4085` rather than a real chart.
- **Reproduce/evidence:** Inspect the insert maps at the locations above and query a newly created journal row; the existing trigger contains `WHEN NEW.immutable = 1 AND 0`, so it cannot enforce the claimed lifecycle.
- **Severity/impact:** High; exports and reports can appear balanced while lacking persisted debit/credit identity, and mutable rows can be edited after posting.
- **Affected paths/platforms:** All journal-producing services and DATEV/EÜR/UStVA consumers; all desktop platforms.
- **Minimal proposed fix:** Require validated debit/credit account mapping before posting, persist both sides and source snapshots, make the posting transition explicit, and fail closed when an account mapping is absent. Keep a correction/storno record rather than overwriting a posted row.
- **Regression scenario:** Post invoice, payment, opening balance, write-off, and recurring booking; assert non-null sides, balanced totals, immutable transition, and correction linkage; export the same rows to DATEV.
- **Owner/status:** A; **OPEN / implementation gap**.

### A-003 — UStVA and EÜR treat outgoing VAT claims as input tax

- **Exact location:** `lib/features/accounting/ustva_service.dart:142-154,268-271`; `lib/features/accounting/euer_service.dart:150-182`; `lib/pages/rechnungen/rechnungen_datasource.dart:557-563`; `test/integration/audit/invoice-accounting-posting-lifecycle_test.dart:77-82`.
- **Source/expected:** UStG §15 (official source in the matrix) limits input-tax deduction to qualifying supplier services and invoices. The product accounting spec requires claims for finalized incoming invoices; UStVA 2026 instructions are a separate official source for the form’s net/negative conventions.
- **Actual:** The report service sums every `vorsteuer_ansprueche` row in the period without filtering invoice direction/status. The invoice finalizer creates that row for any non-zero VAT, including an outgoing `Rechnung`; turnover separately recognizes `BelegTyp.einnahme`.
- **Reproduce/evidence:** Finalize an outgoing invoice with VAT, call UStVA/EÜR generation for that period, and inspect KZ61/66 or the input-tax total. The existing audit test codifies the incorrect outgoing row as expected behavior.
- **Severity/impact:** High; tax reports can classify sales VAT as deductible input tax. This is a runtime classification defect; the audit does not assert a legal filing outcome.
- **Affected paths/platforms:** UStVA/EÜR report services and every profile with finalized outgoing VAT; all desktop platforms.
- **Minimal proposed fix:** Store direction/source document identity on claims, create claims only from incoming invoices, and have reports filter by direction, status, and correction linkage. Decide how reverse-charge and special schemes are represented before adding cases.
- **Regression scenario:** Incoming invoice, outgoing invoice, Gutschrift, Storno, reverse-charge candidate, and zero-VAT rows produce independent turnover/input-tax totals and signed corrections.
- **Owner/status:** A; **OPEN / high priority**.

### A-004 — Bank import rejects a whole batch before its partial-row contract runs

- **Exact location:** `lib/features/bank_import/bank_import_service.dart:210-225,245-340,427-460`; `openspec/changes/archive/2026-09-05-bank-import-workflow-integrity/specs/bank-import-workflow-integrity/spec.md:21-42`; `test/integration/audit/bank-import-workflow-integrity_test.dart:203-293`.
- **Source/expected:** The archived workflow contract says valid rows persist independently, invalid rows receive diagnostics, and failed rows can be retried without duplication.
- **Actual:** `_validateImport` validates every raw row and throws on the first invalid date/amount before the history row and per-row transaction loop. The later loop catches row failures, but it is unreachable for malformed values rejected up front.
- **Reproduce/evidence:** Submit one valid transaction and one row with an invalid date or amount; observe the batch-level validation exception and absence of the valid row. The existing integration test exercises forced insert failures, not malformed upfront values.
- **Severity/impact:** High; one bad bank statement row prevents recoverable valid transactions from entering the ledger.
- **Affected paths/platforms:** Bank import service/page and persisted import history on all desktop platforms.
- **Minimal proposed fix:** Parse each raw row inside the row-level result boundary, record a typed failure for that row, and reserve batch failure for invalid file-level metadata. Preserve deterministic deduplication keys.
- **Regression scenario:** Mixed valid/invalid rows, repeated retry of only failed rows, duplicate file import, and file-level invalid metadata.
- **Owner/status:** A; **OPEN / implementation gap**.

### A-005 — Bank import mode and receipt reconciliation are not exposed end to end

- **Exact location:** `lib/features/bank_import/bank_import_page.dart:447-475`; `lib/features/bank_import/bank_import_service.dart:210-225`; `openspec/specs/bank-import/spec.md:137-167`; `openspec/specs/receipts-and-payment-reconciliation/spec.md:8-42`; `test/integration/audit/receipts-and-payment-reconciliation_test.dart`.
- **Source/expected:** The bank-import contract requires automatic/manual mode and a per-import override. The receipt contract requires a confirmed bank match to apply its signed amount to a receivable atomically.
- **Actual:** The page calls `importTransactions` without a mode, so the service default `manuell` is always used. Matching records `bank_transaktionen.journal_id`; no path calls `ForderungenRepository.zahlungBuchen` to apply the amount, and `belege` remains metadata-only.
- **Reproduce/evidence:** Search production callers for `importTransactions(` and `zahlungBuchen(`, then complete a bank match and inspect the Forderung balance; the page caller has no mode argument and the reconciliation spec’s application path is absent.
- **Severity/impact:** High; an apparently confirmed bank match can leave the receivable unchanged, and the user cannot select the documented import mode.
- **Affected paths/platforms:** Bank page/provider/service, Forderungen, `bank_transaktionen`, `belege`; all desktop platforms.
- **Minimal proposed fix:** Add explicit mode state and pass it through the page/provider; implement one atomic match command that verifies signed amount, applies payment, links the bank row, and records an idempotency key.
- **Regression scenario:** Manual and automatic imports, exact/partial/overpayment matches, rejected amount mismatch, replay of a confirmed match, and rollback when payment posting fails.
- **Owner/status:** A; **OPEN / missing capability**.

### A-006 — Payment replay and overpayment handling do not preserve the accounting contract

- **Exact location:** `lib/features/einkommen/forderungen_repository.dart:281-399`; `openspec/specs/accounting/spec.md:481-485`; `test/integration/audit/receivables-ledger-integrity_test.dart`.
- **Source/expected:** A reused idempotency key must identify the same logical request, and an incoming overpayment must create a supplier/customer credit rather than silently becoming a generic overpayment journal.
- **Actual:** A reused key returns the prior Forderung without comparing amount, target, or direction. Overpayment marks the original receivable paid and inserts `BelegTyp.ueberzahlung`, without a separate credit Forderung. The created payment journal also remains mutable by default.
- **Reproduce/evidence:** Call `zahlungBuchen` twice with the same key but a different amount/receivable; the early lookup returns the previous result. Pay more than the balance and inspect the absence of a credit balance record.
- **Severity/impact:** High; conflicting retries can be accepted and excess cash can disappear from the open-items model.
- **Affected paths/platforms:** Payment, receivables, bank reconciliation, journal, and reports.
- **Minimal proposed fix:** Persist a request fingerprint and return a typed conflict on mismatch; model overpayment as a separate signed credit item linked to the original payment.
- **Regression scenario:** Exact replay, conflicting replay, partial payment, exact payment, overpayment, reversal, and concurrent payment attempts.
- **Owner/status:** A; **OPEN / implementation and contract gap**.

### A-007 — Concurrent write-off can post duplicate loss journals

- **Exact location:** `lib/features/einkommen/forderungen_repository.dart:402-441`; `openspec/specs/accounting/spec.md` write-off requirements; `test/integration/audit/receivables-ledger-integrity_test.dart`.
- **Source/expected:** A write-off should transition one open receivable once and create one linked loss posting.
- **Actual:** The method reads the Forderung/status/balance before `BEGIN`, then inserts the loss and writes zero/`ausgebucht` without an in-transaction conditional re-read or compare-and-update. Two callers can observe the same open row and both post loss entries.
- **Reproduce/evidence:** Invoke `ausbuchen` concurrently against one open Forderung with separate repository instances; inspect duplicate loss journals and relations.
- **Severity/impact:** High; duplicate expense and inconsistent open-item totals are possible under retries or two windows.
- **Affected paths/platforms:** Receivables and journal writes on desktop runtimes with concurrent isolates/windows.
- **Minimal proposed fix:** Move the state check into the transaction and make the state transition conditional on the prior open balance; return a typed already-closed result when the update affects zero rows.
- **Regression scenario:** Two simultaneous write-offs, write-off racing with payment, and retry after transaction interruption.
- **Owner/status:** A; **OPEN / concurrency defect**.

### A-008 — Direct inventory edits bypass movement and stock-policy enforcement

- **Exact location:** `lib/pages/stammdaten/artikel_repository.dart:207-268,342-417`; `lib/pages/rechnungen/rechnungen_datasource.dart:374-403,706-740`; `lib/core/db/database.dart:517-519`; `test/integration/audit/inventory-quantity-integrity_test.dart:56-69`.
- **Source/expected:** Stock changes should be represented by movements, obey `lager_aktiv` and `minusbestand_erlaubt`, and retain quantity precision.
- **Actual:** `update` accepts `bestand_aktuell` and updates the article without a movement or policy check. Public `setBestand`/`adjustBestand` create movements but also omit the policy checks enforced in `LagerRepository`. The legacy article column is integer while the newer quantity/movement paths use numeric precision.
- **Reproduce/evidence:** Update an article with a direct `bestand_aktuell` change or call `adjustBestand` on inactive/negative-disallowed stock; inspect the missing movement or accepted negative value.
- **Severity/impact:** High for inventory integrity; invoices can consume stock while master-data edits create no audit trail.
- **Affected paths/platforms:** Article master data, inventory, invoice/storno side effects; all desktop platforms.
- **Minimal proposed fix:** Remove stock from the generic article update payload, expose one policy-checked movement command, and migrate the legacy quantity contract explicitly.
- **Regression scenario:** Inactive stock, allowed/disallowed negative stock, fractional quantity, direct edit attempt, invoice finalization, storno, and repeated movement reference.
- **Owner/status:** A; **OPEN / persistence boundary gap**.

### A-009 — Recurring direct posting can leave an unlinked or orphan tax claim

- **Exact location:** `lib/features/recurring/buchungsvorlagen_repository.dart:357-445`; `lib/core/db/database.dart:856-867`; `openspec/specs/recurring-accounting-postings/spec.md:26-43`; `test/integration/audit/recurring-accounting-postings_test.dart:21-103`.
- **Source/expected:** One occurrence key should produce one journal and one matching, source-linked tax claim, atomically and idempotently.
- **Actual:** The transaction inserts the journal and a tax claim with neither `rechnung_id` nor a journal link, then uses `INSERT OR IGNORE` for the occurrence. A losing concurrent transaction deletes only the journal; its tax claim is left behind. The direct journal also defaults to mutable.
- **Reproduce/evidence:** Run two direct-generation calls for one template/occurrence concurrently, then inspect `vorsteuer_ansprueche.rechnung_id` and the rows after loser cleanup; even the successful path has no source identity.
- **Severity/impact:** High; reports can include tax claims with no source journal.
- **Affected paths/platforms:** Recurring direct postings, tax reports, journal, occurrence tables.
- **Minimal proposed fix:** Make the occurrence reservation the first atomic gate or delete all rows by a shared posting group; add foreign-key/cleanup coverage for every side effect.
- **Regression scenario:** Concurrent same-occurrence generation, failed tax insert, failed occurrence insert, and retry after process interruption.
- **Owner/status:** A; **OPEN / concurrency defect**.

### A-010 — Recurring invoice creation and due-date advancement are split across transactions

- **Exact location:** `lib/features/recurring/rechnungsvorlagen_repository.dart:317-340,343-431`; `openspec/specs/recurring-accounting-postings/spec.md`; recurring persistence tests.
- **Source/expected:** Generating one occurrence and advancing its template should be a retry-safe logical operation.
- **Actual:** `_generateOne` commits the invoice/occurrence, then `generateFaellig` updates `naechste_faelligkeit` outside that transaction. If the update fails, the occurrence exists while the template remains due; a retry can attempt the same logical work and depend on a uniqueness race rather than a deliberate idempotency result.
- **Reproduce/evidence:** Force the post-generation template update to fail and inspect the committed invoice, occurrence, and unchanged next due date.
- **Severity/impact:** Medium/High; scheduled runs can repeatedly report failures and leave ambiguous progress.
- **Affected paths/platforms:** Recurring invoice scheduler and invoice persistence.
- **Minimal proposed fix:** Reserve and advance the occurrence in the same transaction as invoice creation, or persist a durable generation state that makes retries explicit.
- **Regression scenario:** Successful generation, template update failure, process interruption, same-day retry, and concurrent scheduler calls.
- **Owner/status:** A; **OPEN / transaction-boundary gap**.

### A-011 — Dunning interest uses an arbitrary configured rate and stale stage state

- **Exact location:** `lib/features/mahnwesen/mahnungen_repository.dart:87-97,177-261,416-456`; `lib/features/mahnwesen/mahnstufen_repository.dart:41-65`; `lib/features/mahnwesen/sperrung_service.dart:118-176,180-215,311-316`; `docs/05-mahnwesen.md:3-5,9-64,126-132`; official BGB §288 source in the matrix.
- **Source/expected:** The docs promise German-law-aware dunning, automatic block release after payment, and fee/rate values that differ from the repository defaults. BGB §288 currently expresses business/consumer late-interest and the business €40 surcharge; the audit records the source without deciding how the product should apply it.
- **Actual:** Interest is `betrag * z * tage / 36500` from an arbitrary configured `z`; no statutory base-rate history or party-type branch is present. Defaults in `mahnstufen_repository.dart` conflict with docs. Payment does not call `removeMahnsperre`, and the dunning transaction can commit a Mahnung after the invoice-stage update was caught and logged.
- **Reproduce/evidence:** Create a business/consumer overdue invoice, generate a stage, pay it, and inspect interest, stage/block state, and journal; compare defaults with `docs/05-mahnwesen.md`.
- **Severity/impact:** High/blocked; financial outputs and automatic blocking depend on unresolved product/legal interpretation and incomplete state transitions.
- **Affected paths/platforms:** Dunning, payments, customer status, PDF/email; all desktop platforms.
- **Minimal proposed fix:** Obtain a dated product decision for rate source, customer type, surcharge, fee defaults, and block-clear policy; then store the applied rate/snapshot and make stage/payment transitions atomic.
- **Regression scenario:** Business/consumer, historical rate date, paid-before-stage, paid-after-stage, repeated generation, and stage-update failure.
- **Owner/status:** A plus product/tax owner; **BLOCKED / policy decision required**.

### A-012 — Dunning entrypoints, send, and PDF paths do not implement the documented artifact behavior

- **Exact location:** `lib/pages/stammdaten/kunden_repository.dart:427-468`; `lib/features/mahnwesen/mahnungen_repository.dart:459-479,481-816`; `docs/05-mahnwesen.md:204-234`; `openspec/specs/mahnwesen/spec.md:121-151,255-269`; `openspec/specs/pdf-rendering-completeness/spec.md:8-34`; `openspec/specs/pdf/spec.md:19-23,31-55`.
- **Source/expected:** The docs/specs require a type-specific dunning PDF with dynamic data and an SMTP send path with attachment.
- **Actual:** `KundenRepository.runDunning` only enumerates overdue customers and reports skips; `generateDunningLetter` only validates the block. `sendMail` only marks the record sent; no SMTP call is present. `generatePdf` returns a name in one branch and writes `_minimalPdf()` in the profile branch without the required dunning content.
- **Reproduce/evidence:** Call the customer entrypoints and inspect that no Mahnung is created; call the repository send/PDF methods with a profile directory and inspect the generated bytes and side effects; search for an SMTP client/call site.
- **Severity/impact:** High; a visible “sent” or downloadable artifact can be false or incomplete.
- **Affected paths/platforms:** Dunning UI/repository, local PDF persistence, mail integration; all desktop platforms.
- **Minimal proposed fix:** Make send status conditional on a real delivery result, persist the artifact before marking sent, and render the required dunning fields/type label.
- **Regression scenario:** PDF content assertions for each Mahnstufe, missing-profile path, send failure/retry, and attachment persistence.
- **Owner/status:** A/B; **OPEN / missing runtime capability**.

### A-013 — Backup scheduling is implemented as a helper but not wired into startup/services

- **Exact location:** `lib/core/db/backup_service.dart:56-203`; `lib/core/db/database.dart:362-363`; `lib/core/db/migrations.dart:67-113`; `lib/main.dart:56-100`; `lib/core/app_services.dart:21-45`; `openspec/specs/backup/spec.md:137-151`; `test/db/backup_test.dart`.
- **Source/expected:** The backup spec requires automatic scheduling at startup, while the helper provides `isScheduledDue`, WAL-safe backup, encrypted external backup, and restore primitives.
- **Actual:** Production startup creates the database and services but no `BackupService` scheduler/decision is invoked; search finds the service in migration/test paths only. Configuration columns exist, but due checks do not cause a backup.
- **Reproduce/evidence:** Launch the app with a due backup configuration, inspect backup directory/history, and trace startup callers; only test/migration references reach the helper.
- **Severity/impact:** High; users can believe scheduled backups are active while no backup is produced.
- **Affected paths/platforms:** Startup, profile database, backup directory, restore lifecycle; all desktop platforms.
- **Minimal proposed fix:** Wire one startup scheduler after DB readiness, record success/failure atomically, and surface the last result; preserve current WAL-safe helper and restore maintenance gate.
- **Regression scenario:** Due/not-due startup, backup failure, rotation, encrypted backup, restore with readiness callback, and concurrent startup.
- **Owner/status:** A; **OPEN / missing wiring**.

### A-014 — Profile deletion removes the database despite the profile safety contract

- **Exact location:** `lib/core/db/profile_manager.dart:126-158`; `openspec/specs/profiles/spec.md:159-168`; `test/integration/audit/profile-workspace-lifecycle_test.dart:27-44`.
- **Source/expected:** The maintained profile contract says deleting a profile entry retains its directory/database for data safety and recovery.
- **Actual:** `deleteProfile` recursively deletes the inactive profile directory and database. The current audit test expects physical deletion, so the test and spec disagree.
- **Reproduce/evidence:** Create a second profile, close it, call `deleteProfile`, and inspect the profile path; it is removed recursively.
- **Severity/impact:** High; an irreversible local data loss path is exposed by a contract conflict.
- **Affected paths/platforms:** Profile manager, database files, backup/restore; all desktop platforms.
- **Minimal proposed fix:** Resolve the product decision before implementation. If retention is intended, tombstone/remove the pointer only and make physical purge a separate explicit command with backup confirmation.
- **Regression scenario:** Delete inactive/active profile, restart with stale pointer, recover retained DB, and explicit purge path.
- **Owner/status:** A plus product owner; **BLOCKED / spec-test contradiction**.

### A-015 — Schema evolution mutates columns outside the versioned migration transaction

- **Exact location:** `lib/core/db/migrations.dart:67-113`; `lib/core/db/database.dart:130-231`.
- **Source/expected:** A migration should either complete atomically or leave the previous schema/version recoverable.
- **Actual:** MigrationRunner performs a versioned transaction, but many additive `_addColumnIfMissing` calls run afterward in database initialization. A later additive failure can leave a partially mutated schema while `user_version` reflects the earlier migration state.
- **Reproduce/evidence:** Inject a failure after one additive column and before the next, reopen the DB, and inspect `PRAGMA user_version` and column set.
- **Severity/impact:** Medium/High; interrupted upgrades can create a schema that neither old nor new code fully understands.
- **Affected paths/platforms:** Profile startup and every persisted database upgrade.
- **Minimal proposed fix:** Move all schema changes into versioned, transactional migrations with a tested recovery marker; do not advance the version until every required column/index/trigger exists.
- **Regression scenario:** Fresh DB, each historical version upgrade, failure at every additive step, reopen/retry, and backup restore.
- **Owner/status:** A; **OPEN / migration durability gap**.

### A-016 — DATEV export invents account mappings and can leave artifacts without export history

- **Exact location:** `lib/features/accounting/datev_service.dart:218-269,294-343,564-574`; `openspec/specs/accounting/spec.md:301-305`; `test/features/accounting/datev_test.dart:192-200`; official DATEV interface sources in the matrix.
- **Source/expected:** DATEV requires account/contra-account, amount/direction, date, Belegfeld, and text fields; the product spec says missing configuration should reject export.
- **Actual:** The service falls back through synthetic per-account/global/category values and finally `'1200'`/`'8400'`, derives Soll/Haben from type/sign instead of persisted sides, writes the CSV before inserting export history, and validates Belegfeld1 length but not the current allowed-character set.
- **Reproduce/evidence:** Export with no mapping and force the history insert to fail; observe a CSV artifact with no log. The existing test explicitly expects the category fallback, which records the current behavior rather than the fail-closed contract.
- **Severity/impact:** High; an export can contain plausible but wrong account assignments and an untracked artifact.
- **Affected paths/platforms:** DATEV export, journal mapping, export log, user download directory; all desktop platforms.
- **Minimal proposed fix:** Require explicit validated mappings, use persisted debit/credit sides, validate the DATEV field grammar, and commit/export-log state through one durable result protocol with cleanup or a visible pending artifact.
- **Regression scenario:** Complete/missing mappings, invalid Belegfeld characters, signed correction, duplicate export request, artifact write failure, and log failure.
- **Owner/status:** A; **OPEN / export integrity gap**.

### A-017 — Persisted monetary scale and caller precision disagree with the schema contract

- **Exact location:** `lib/core/db/database.dart:550-560`; `lib/pages/rechnungen/rechnungen_datasource.dart:99-108`; `lib/features/accounting/money.dart`; `test/integration/audit/invoice-money-invariants_test.dart`; `test/integration/audit/_baseline.md:34-37`.
- **Source/expected:** The schema declares `NUMERIC(12,2)` for quantity, unit price, total, and VAT rate, while exact money helpers and persistence callers must agree on a documented scale and sign policy.
- **Actual:** Invoice persistence formats quantity to three decimals and unit price to four before inserting into columns declared with scale two. SQLite affinity does not itself enforce the declared scale, so runtime and future database portability can diverge. The stale 2026-09-12 baseline records a negative-caller money invariant failure; the current test source expects that input to be rejected and the current baseline comparison says the historical failure no longer reproduces.
- **Reproduce/evidence:** Persist values with three-decimal quantity/four-decimal price, reopen and compare exact stored text/number, then run the money invariant test for negative caller input.
- **Severity/impact:** Medium/High; rounding can occur at different layers and correction signs remain ambiguous.
- **Affected paths/platforms:** Invoice lines, inventory quantities, tax calculations, migrations, exports; all platforms.
- **Minimal proposed fix:** Choose and document per-field scales, validate at the boundary, use integer cents/declared quantity units consistently, and add a migration for any scale change.
- **Regression scenario:** Fractional quantity, fractional price, tax rounding, negative correction, round-trip persistence, and DATEV/report export.
- **Owner/status:** A plus product owner; **OPEN / numeric contract decision**.

### A-018 — Synthetic chart seed and km/EKS precision leave reporting semantics implicit

- **Exact location:** `lib/core/db/seed.dart:109-123`; `lib/features/accounting/eks_service.dart:160-169`; `lib/features/accounting/euer_service.dart:220-226`; `docs/02-buchhaltung.md:48-63`; official EÜR sources in the matrix.
- **Source/expected:** Product docs describe SKR03/SKR04 examples and EÜR/EKS outputs; official EÜR materials define the submission context, while the product still needs an explicit category and km-unit policy.
- **Actual:** Seed data creates numbered placeholder categories rather than real account mappings. EKS parses km through the two-decimal money helper before applying the per-km amount, so finer distance input is rounded/truncated by the money contract. EÜR profit then relies on the synthetic journal/category model.
- **Reproduce/evidence:** Inspect seeded account labels and enter a distance with more than two decimals; compare the stored/used km and EÜR result.
- **Severity/impact:** Medium; reports may be internally consistent but not suitable for the documented accounting/export semantics.
- **Affected paths/platforms:** Setup, category/account selection, EÜR/EKS reports, DATEV export.
- **Minimal proposed fix:** Decide whether the product ships a real chart or requires user mapping, and give km its own quantity parser/scale with a documented rounding rule.
- **Regression scenario:** Fresh seed, mapped/unmapped category, fractional km, period filtering, and EÜR export.
- **Owner/status:** A plus product owner; **OPEN / product/data-model gap**.

## Product and legal interpretation blockers

These questions must be answered before a repair can be assessed as correct:

1. Does a standalone Gutschrift create journal, receivable/credit, inventory, tax, and PDF effects? What exact signed result should Storno-of-Gutschrift produce?
2. Which party/direction rules apply to input VAT, reverse charge, special schemes, and correction documents? The audit uses UStG §15 as a source boundary and does not infer an unverified filing rule.
3. Should dunning rates come from the statutory base rate by date and party type, from a user-entered policy, or from a hybrid snapshot? Which fee defaults and automatic block-clear behavior are intended?
4. Does profile deletion retain data (as the maintained spec says) or purge it (as the current audit test expects)?
5. What exact money/quantity scales, negative-input policy, and largest-remainder/rounding rules are part of the supported product contract?

Until these are answered, rows A-001, A-003, A-011, A-014, and A-017 remain contract-blocked even where the runtime defect is clear.

## Bounded repair candidates for later Anvil work

The smallest coherent repair slices are: freeze the typed document/posting matrix and test it; make tax claims direction-aware; make bank rows individually parseable and reconciliation atomic; add conditional receivable transitions and request fingerprints; unify inventory movement policy; reserve recurring occurrences before side effects; wire startup backup scheduling; resolve profile retention; move additive schema changes into versioned migrations; and make DATEV mappings explicit. These are candidates only. No implementation or OpenSpec change was performed in this audit.

## Independent review state

Initial author pass: **DONE**. The author's prior same-tree reread is retained as peer evidence,
but it is not counted as independent closure.

Independent source closure: **APPROVE for planning evidence only**. Reviewer: Luna, fresh context,
2026-09-29, current checkout `70ec70cc7b0ee4d314565a0782da1ffbdd126ea6`. I independently re-read
the exact source anchors for all 18 rows against the current tree. This was a static source closure;
it did not change production or test files and did not treat the author's reread as reviewer evidence.

| ID | Current-tree evidence re-read | Independent verdict and residual |
|---|---|---|
| A-001 | `rechnungen_datasource.dart:464-563` derives posting effects from the stored document type but unconditionally creates the journal/tax path when VAT is present; `:643-679` derives the correction sign from source type. | **CONFIRMED / contract blocked.** Typed document effects and Gutschrift/Storno sign remain owner decisions. |
| A-002 | `database.dart:580-610` declares debit/credit identity and `immutable`; `journal_repository.dart:180-184` inserts `immutable = 0` without debit/credit sides; `gobd_triggers.dart:30-40` has a disabled insert trigger. | **CONFIRMED / open.** Payment, setup, and recurring insert paths also leave the posting lifecycle incomplete. |
| A-003 | `rechnungen_datasource.dart:557-562` inserts `vorsteuer_ansprueche` for any non-zero VAT; `ustva_service.dart:55-64,142-153` filters only by period and sums claims without document direction/status. | **CONFIRMED / high priority.** Direction-aware claim population and report filtering remain unimplemented. |
| A-004 | `bank_import_service.dart:217-225` calls `_validateImport` before the per-row loop at `:245-340`; row failures are caught only after upfront validation. | **CONFIRMED / open.** The malformed-row partial-import case remains unexecuted. |
| A-005 | `bank_import_page.dart:469-475` calls `importTransactions` without `mode`; production search finds no bank-match path that calls `zahlungBuchen` to apply a receivable payment. | **CONFIRMED / open.** Mode propagation and atomic receipt reconciliation remain absent. |
| A-006 | `forderungen_repository.dart:295-305` returns an earlier idempotency-key result without comparing request fields; `:352-371` records excess as a journal/payment row and closes the original Forderung without a separate credit item. | **CONFIRMED / open.** Fingerprinted retries and credit-item semantics remain unresolved. |
| A-007 | `forderungen_repository.dart:406-410` reads status before `beginTransaction` at `:413`; `:416-433` posts and updates without an in-transaction conditional state transition. | **CONFIRMED source risk / concurrency unexecuted.** Duplicate write-off behavior still needs an executable race case. |
| A-008 | `artikel_repository.dart:221-267` allows `bestand_aktuell` through generic `update`; `:342-404` movement commands do not apply the inventory policy checks; `database.dart:517-519` keeps the legacy stock column integer. | **CONFIRMED / open.** One policy-checked movement boundary and an explicit quantity migration remain needed. |
| A-009 | `buchungsvorlagen_repository.dart:399-422` inserts a direct journal and an unlinked tax claim; `:424-437` reserves the occurrence afterward and deletes only the losing journal. | **CONFIRMED source risk / concurrency unexecuted.** Shared posting-group cleanup and race evidence remain open. |
| A-010 | `rechnungsvorlagen_repository.dart:329-335` commits `_generateOne` before updating `naechste_faelligkeit`; `_generateOne` transaction boundaries are `:344-429`. | **CONFIRMED / open.** Post-generation update failure and retry behavior remain unexecuted. |
| A-011 | `mahnungen_repository.dart:87-97` calculates interest from configured `zinssatz`; `mahnstufen_repository.dart:41-65` supplies product defaults; `mahnungen_repository.dart:244-251` catches stage update failure after inserting the Mahnung. | **CONFIRMED / policy blocked.** Statutory-rate/party policy and automatic block-clear behavior remain undecided. |
| A-012 | `kunden_repository.dart:427-463` only enumerates/skips overdue customers; `mahnungen_repository.dart:477-499` marks mail sent and writes `_minimalPdf()` without an SMTP/content path. | **CONFIRMED / open.** Artifact content and delivery success are not production evidence. |
| A-013 | `main.dart:77-100` opens the selected DB and registers desktop capabilities but never constructs a scheduler; `BackupService` references occur in migrations/tests only. | **CONFIRMED / open.** Due-startup behavior remains unexecuted and unwired. |
| A-014 | `profile_manager.dart:144-158` recursively deletes an inactive profile directory; `openspec/specs/profiles/spec.md:159-168` requires retaining it, while the current lifecycle test expects deletion. | **CONFIRMED / contract blocked.** Retention versus purge requires an owner decision. |
| A-015 | `migrations.dart:85-93` wraps versioned migrations in a transaction; `database.dart:154-218` runs many `_addColumnIfMissing` calls after `runner.run`. | **CONFIRMED source risk / fault injection unexecuted.** Recovery at each additive step remains unverified. |
| A-016 | `datev_service.dart:218-238` selects synthetic fallback accounts; `:244-255` derives Soll/Haben from type/sign; `:294-332` writes the artifact before export history. | **CONFIRMED / open.** Explicit mappings, persisted sides, field grammar, and artifact/log protocol remain incomplete. |
| A-017 | `database.dart:550-558` declares invoice quantity/price/total/rate as `NUMERIC(12,2)`; `rechnungen_datasource.dart:175-183` writes quantity at three and unit price at four decimals; the audit test records negative-input rejection. | **CONFIRMED / numeric contract blocked.** Per-field scale, sign, and rounding policy remain to be chosen. |
| A-018 | `seed.dart:109-123` generates synthetic SKR mappings; `eks_service.dart:160-169` formats km through the two-decimal money helper; `euer_service.dart:33-80` aggregates by synthetic category/direction. | **CONFIRMED / data-model decision needed.** Chart mapping and km precision remain product choices. |

The prior author-reported focused command remains useful evidence of 55 selected tests passing:

```text
fvm flutter test --dart-define=platform=vm \
  test/integration/audit/invoice-accounting-posting-lifecycle_test.dart \
  test/integration/audit/correction-document-accounting-integrity_test.dart \
  test/integration/audit/bank-import-workflow-integrity_test.dart \
  test/integration/audit/receipts-and-payment-reconciliation_test.dart \
  test/integration/audit/recurring-accounting-postings_test.dart \
  test/integration/audit/inventory-quantity-integrity_test.dart \
  test/integration/audit/tax-reporting-and-export-integrity_test.dart \
  test/integration/audit/profile-workspace-lifecycle_test.dart \
  test/db/backup_test.dart test/db/gobd_test.dart
```

Those selected tests cover current happy paths and injected row failures; they do not execute the
malformed-row validation case, concurrent write-off/recurring races, missing bank mode, outgoing
input-tax classification, dunning SMTP/PDF content, startup scheduler wiring, or the profile
spec/test contradiction. The current full VM baseline is separately recorded as 748 completed
tests with two `pumpAndSettle` failures; the unsupported 750/750 report remains unreconciled. No
finding is marked resolved merely because an existing test passes.
