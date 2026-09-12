# Baseline — review-testing-plans

Captured: 2026-09-12T11:50:00Z
Flutter: 3.47.2 (FVM)
Commands:
- `fvm flutter analyze`
- `fvm flutter test --dart-define=platform=vm`

## fvm flutter analyze — 7 infos

```
Analyzing OpenAccounting...
7 issues found. (ran in 1.7s)
```

| # | file:line | rule | hint |
|---|-----------|------|------|
| 1 | `lib/core/theme/app_theme.dart:150:27` | `avoid_positional_boolean_parameters` | `bool` params should be named |
| 2 | `lib/design_system/components/app_sidebar.dart:83:18` | `prefer_const_constructors` | add `const` |
| 3 | `lib/features/inventory/lager_repository.dart:50:15` | `prefer_const_constructors` | add `const` |
| 4 | `lib/features/inventory/lager_repository.dart:56:15` | `prefer_const_constructors` | add `const` |
| 5 | `lib/features/inventory/lager_repository.dart:96:15` | `prefer_const_constructors` | add `const` |
| 6 | `lib/features/inventory/lager_repository.dart:102:15` | `prefer_const_constructors` | add `const` |
| 7 | `lib/main.dart:92:33` | `avoid_positional_boolean_parameters` | `bool` params should be named |

Exit code 1 (infos only, no errors/warnings).

## fvm flutter test — 4 fails (baseline)

Total: ~614 tests, 4 failing (rtk output tail, ~58s).

| # | file:line | test | failure |
|---|-----------|------|---------|
| 1 | `test/integration/audit/analyzer-and-integration-test-gates_test.dart:24:5` | `test_analyzer_and_integration_test_gates_1_1_analyzer_gate_passes` | `Expected: <0> Actual: <1> Pinned flutter analyze must exit zero. 7 infos found.` |
| 2 | `test/integration/audit/analyzer-and-integration-test-gates_test.dart:86:9` | `test_analyzer_and_integration_test_gates_2_1_route_smoke_tests_prove_reachability` | `Expected: exactly one matching candidate Actual: Found 0 widgets with text "Datenbankabfrage abgeschlossen" Route /invoices must query data` |
| 3 | `test/integration/audit/invoice-money-invariants_test.dart:51:38` | `test_invoice_money_invariants_2_2_negative_caller_amount_is_not_normalized` | `Invalid argument(s): einzelpreis darf nicht negativ sein at vorschau_service.dart:194 (_scaledNonNegative → _unitPrice → calculate)` |
| 4 | `test/integration/audit/receivables-ledger-integrity_test.dart:201:7` | `test_receivables_ledger_integrity_2_2_legacy_startup_migrates_safely` | `Expected: contains 'typ' Actual: Set[id, kunde_id, rechnung_id, betrag, status, faelligkeit, beschreibung] ensureSchema must add typ` |

All 4 are pre-existing; no new failures introduced by baseline.

## Inventory — test/integration/audit/* (23 files)

| file | tests | harness pattern |
|------|-------|----------------|
| `analyzer-and-integration-test-gates_test.dart` | 6 | `AppDatabase.forTesting(NativeDatabase.memory())` + `ensureOpen()` + `runInsert` |
| `bank-import-workflow-integrity_test.dart` | 9 | `_openConfiguredDatabase()` helper → `createTestDatabase` + insert unternehmen/konten; `_transactionCount`/`_importHistory` via `runSelect` |
| `contacts-credit-and-dunning-integrity_test.dart` | 4 | `createTestDatabase` + `ensureOpen` |
| `correction-document-accounting-integrity_test.dart` | 4 | `createTestDatabase` + `runCustom`/`runSelect` |
| `dashboard-metrics-and-actions_test.dart` | 7 | `createTestDatabase` + `runCustom` inserts |
| `desktop-lifecycle-and-command-wiring_test.dart` | 5 | `createTestDatabase` + widget pump helpers |
| `desktop-shell-and-design-quality_test.dart` | 10 | widget tests, `createTestDatabase` |
| `finalized-document-artifact-lifecycle_test.dart` | 4 | `createTestDatabase` + `runCustom` DDL + `runSelect` artifact checks |
| `inventory-quantity-integrity_test.dart` | 2 | `createTestDatabase` + `runSelect`/`runCustom` |
| `invoice-accounting-posting-lifecycle_test.dart` | 5 | `createTestDatabase` + `_insertRechnung(db, typ)` helper + `runCustom` UPDATE + `runSelect` |
| `invoice-money-invariants_test.dart` | 6 | `createTestDatabase` via `VorschauService.calculate` |
| `journal-integrity-and-snapshots_test.dart` | 4 | `createTestDatabase` + DELETE + `runCustom` seeds |
| `localization-settings-and-data-protection_test.dart` | 4 | `forTesting(NativeDatabase(File))` file DB + `SharedPreferences` + `runInsert`/`runSelect` |
| `primary-workspace-exposure_test.dart` | 4 | `createTestDatabase` + `runCustom`/`runSelect` COUNT |
| `profile-workspace-lifecycle_test.dart` | 4 | `createTestDatabase` |
| `receipts-and-payment-reconciliation_test.dart` | 4 | `createTestDatabase` |
| `receivables-ledger-integrity_test.dart` | 5 | `createTestDatabase` + `runInsert`/`runSelect`/`PRAGMA table_info` + DROP TABLE legacy |
| `recurring-accounting-postings_test.dart` | 4 | `createTestDatabase` |
| `runtime-composition-and-database-lifecycle_test.dart` | 4 | `createTestDatabase` + `runSelect SELECT 1` |
| `schema-evolution-safety_test.dart` | 4 | `createTestDatabase` + `AppDatabase.allTableNames` + `PRAGMA user_version` + `DROP TABLE` + `ALTER TABLE ADD COLUMN` |
| `seed-master-data-contract_test.dart` | 4 | `createTestDatabase` + `runSelect`/`runCustom` UPDATE kategorien |
| `setup-onboarding-integrity_test.dart` | 6 | `createTestDatabase` + `SetupRepository(db.executor)` + `WizardService(repository, prefs)` + `_MockPrefs implements SharedPreferences` + `hasUnternehmen(db)` |
| `tax-reporting-and-export-integrity_test.dart` | 8 | `createTestDatabase` |

All audit tests follow AAA, `setUp`/`tearDown` with `db.close()`, `TestWidgetsFlutterBinding.ensureInitialized()` where needed.

## In-memory DB helpers — reuse list (no new abstraction)

Ponytail ultra: reuse existing, no new harness abstraction.

**Core helpers (lib/core/db/database.dart):**
- `AppDatabase.createTestDatabase({String? profileDir})` → `AppDatabase.forTesting(NativeDatabase.memory())` wrapped with `_InvoiceErrorMappingExecutor` — preferred for all new tests.
- `AppDatabase.forTesting(QueryExecutor executor, {profileDir})` — lower-level, use only for file-backed tests (e.g. `localization-settings-and-data-protection` with `NativeDatabase(File)`).
- `AppDatabase.allTableNames` — for schema evolution checks.
- `Future<void> ensureOpen()` — must call before any `executor` use; sets `PRAGMA journal_mode=WAL`, `foreign_keys=ON`, installs `GobdTriggers`, `RechnungTriggers`, runs `SeedData`.
- `QueryExecutor get executor` + `runSelect` / `runCustom` / `runInsert` — raw SQL via drift executor, no codegen. All audit tests use this.
- `MigrationRunner.currentVersion` + `PRAGMA user_version` — schema version checks.
- `GobdTriggers.install` / `RechnungTriggers.install` / `SeedData.run` — already called in `ensureOpen`, don't re-call in tests.

**Test-local helpers (copy pattern, don't abstract):**
- `Future<int> _insertRechnung(AppDatabase db, String typ)` — `INSERT INTO rechnungen (...) VALUES (NULL, ?, 'entwurf', ...)` + `SELECT id ORDER BY id DESC LIMIT 1`. Found in `invoice-accounting-posting-lifecycle_test.dart:90`. Reuse by copy for Plan A invoice tests.
- `Future<AppDatabase> _openConfiguredDatabase()` — `createTestDatabase` + `INSERT INTO unternehmen (name)` + `INSERT INTO konten` (see `bank-import-workflow-integrity_test.dart:14`). Reuse for bank/import tests.
- `Future<int> _transactionCount(AppDatabase db)` / `Future<List<...>> _importHistory(AppDatabase db)` — `SELECT COUNT(*) FROM bank_transaktionen` patterns (bank-import).
- `class _MockPrefs implements SharedPreferences` — in-memory map impl (setup-onboarding:11). Reuse for WizardService/Settings tests.
- `SetupRepository(db.executor)` + `WizardService(repository: repo, prefs: prefs)` + `hasUnternehmen(db)` — setup onboarding flow (setup-onboarding-integrity_test.dart:99-101).
- `Future<void> _pumpBankingPage(WidgetTester tester, AppDatabase db)` — widget pump with `AppDatabase` injection (bank-import:61).
- `PRAGMA table_info(forderungen)` + `DROP TABLE IF EXISTS` + `ALTER TABLE ADD COLUMN` — schema evolution pattern (schema-evolution, receivables).

**Reuse rule:** copy-paste local helpers per file; do not create `test/helpers/` or shared harness. One file per plan, quoted helper names above.

**Anti-patterns to avoid:** raw SQL lifecycle tests that bypass real finalizers (replace with service calls in Plan A); `NativeDatabase.memory()` without `AppDatabase.forTesting` wrapper (loses error mapping).

## Decision log — Ponytail ultra ceilings (one file per plan)

| plan | decision | ceiling & upgrade path |
|------|----------|------------------------|
| A: Invoice Posting Lifecycle | Reuse `_insertRechnung` + `createTestDatabase`; invoke real `RechnungenDatasource.finalizeRechnung` instead of raw `UPDATE rechnungen SET ist_entwurf=0` | `ponytail: global in-memory DB per test, serial execution; parallel isolates if suite > 2min` |
| B: Cash & Revenue Classification | Reuse `ensureOpen` + `runSelect` + existing `EuerService`/`RechnungenRepository` queries; fix `beleg_typ` filter in place, no new typed enum abstraction beyond canonical string set | `ponytail: stringly beleg_typ canonical set; Dart enum if >3 call sites diverge` |
| C: Recurring Persistence | Reuse `buchungsvorlagen_repository` + `rechnungsvorlagen_repository` + `runSelect PRAGMA table_info`; fix persistence in repo method, no new DTO layer | `ponytail: O(n) position loop in test verifier; batch verify if >100 positions` |
| D: Accounting Calc & Validation | Reuse `VorschauService.calculate` + `LagerRepository` + `EksService`/`DatevService`/`EuerService` directly; AfA/EKS/DATEV fixes as 1-line filters/throws in service, no new calculator classes | `ponytail: AfA prorate naive month math; 30/360 day-count if tax audit requires` |
| E: Infra Hardening | Reuse `BackupService` + `AppDatabase.forTesting(File)` + `DesktopUpdater` existing; gate with `try/catch` + `File.existsSync` check in place, no new backup abstraction | `ponytail: TOCTOU check is check-then-act; file lock if concurrent backup observed` |

General: no shared `test/helpers` directory, no factories for single impl, no config for constant. Each plan creates `test/integration/audit/<plan>_test.dart` + minimal prod fix in existing file. `// ponytail:` comment on any ceiling that cuts a corner.

## Verification

```bash
fvm flutter analyze   # 7 infos listed above
fvm flutter test --dart-define=platform=vm  # 4 fails listed above
```

Next: Plans A-E fix files, re-run gates, expect 0 infos, 0 relevant fails (analyzer gate will pass once infos cleared).

