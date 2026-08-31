# Lieferanten Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tested full CRUD for Lieferanten with Kunden-style contact, address, payment, and tax fields, sequential Kreditor-Nr assignment, VAT validation, and reference-safe deletion.

**Architecture:** Keep a dedicated `LieferantenRepository` beside `KundenRepository`, using the existing raw Drift `QueryExecutor` and `lieferanten` table. Use immutable `Lieferant` values, explicit update allowlists, transactional number allocation, and parameterized SQL. Extend the existing supplier table only for fields selected by the broader scope.

**Tech Stack:** Dart, Flutter test, Drift `QueryExecutor`, SQLite, existing OpenAccounting raw-SQL schema and number-range seed.

## Global Constraints

- Use absolute package imports and single quotes.
- Run all Dart/Flutter commands through `fvm`.
- Keep functions small, dependencies explicit, and domain values immutable.
- Validate required fields and EU VAT IDs at repository boundaries.
- Never cascade-delete accounting data or expose SQL/connection details.
- Follow Arrange → Act → Assert tests with happy, boundary, and error cases.
- Preserve unrelated parallel-agent work in the worktree.

---

### Task 1: Lieferanten red tests

**Files:**
- Create: `test/features/stammdaten/lieferanten_test.dart`
- Reference: `test/features/stammdaten/kunden_test.dart`
- Reference: `lib/core/db/database.dart`

**Interfaces:**
- Consumes: `AppDatabase.createTestDatabase()`, `AppDatabase.ensureOpen()`, `db.executor`.
- Produces: executable acceptance tests for `LieferantenRepository` and `Lieferant`.

- [ ] **Step 1: Write failing CRUD and field-round-trip tests**

Use the repository contract below from tests through a dynamic accessor until the implementation exists:

```dart
final created = await repository.create(
  name: 'Bürobedarf AG',
  anrede: 'Frau',
  firma: 'Bürobedarf AG',
  strasse: 'Marktstraße 1',
  hausnummer: '1',
  plz: '10115',
  ort: 'Berlin',
  land: 'DE',
  ustIdNr: 'DE123456789',
  foreignTaxNumber: null,
  telefon: '+49 30 123456',
  email: 'rechnung@buerobedarf.de',
  iban: 'DE02120300000000202051',
  zahlungsziel: 30,
  skontoProzent: 2,
  skontoTage: 10,
  note: 'Papierlieferant',
);
expect(created.kreditorNr, isNotEmpty);
expect((await repository.findById(created.id))!.name, 'Bürobedarf AG');
await repository.update(created.id, <String, dynamic>{'ort': 'Potsdam'});
expect((await repository.findById(created.id))!.ort, 'Potsdam');
await repository.delete(created.id);
expect(await repository.findById(created.id), isNull);
```

- [ ] **Step 2: Add number-range, validation, VAT, and reference tests**

Cover these exact behaviors:

```dart
test('assigns Kreditor-Nr from kreditor number range', () async {
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = '7####', naechste_nummer = 9 WHERE typ = 'kreditor'",
  );
  final supplier = await repository.create(name: 'Lieferant', strasse: 'Straße', plz: '10115', ort: 'Berlin');
  expect(supplier.kreditorNr, '70009');
});

test('rejects invalid EU VAT and accepts non-EU free text', () async {
  await expectLater(
    repository.create(name: 'AT', strasse: 'Straße', plz: '10115', ort: 'Wien', land: 'AT', ustIdNr: 'AT12345678'),
    throwsA(isA<LieferantenException>()),
  );
  final swiss = await repository.create(
    name: 'CH', strasse: 'Straße', plz: '8000', ort: 'Zürich', land: 'CH', ustIdNr: 'CHE-123.456.789',
  );
  expect(swiss.ustIdNr, 'CHE-123.456.789');
});
```

Insert one invoice reference and one journal reference using parameterized SQL, then assert `delete` rejects each and includes the referenced row ID. Also test blank required fields, overlong `foreignTaxNumber`, unknown update fields, and omitted optional values.

- [ ] **Step 3: Run red tests**

Run: `fvm flutter test test/features/stammdaten/lieferanten_test.dart`

Expected: FAIL because `LieferantenRepository` and `Lieferant` are not implemented.

- [ ] **Step 4: Commit red tests**

```bash
git add test/features/stammdaten/lieferanten_test.dart
git commit -m "test(stammdaten): add Lieferanten red tests"
```

### Task 2: Supplier entity and schema compatibility

**Files:**
- Create: `lib/pages/stammdaten/lieferanten_repository.dart`
- Modify: `lib/core/db/database.dart:268-280`
- Test: `test/features/stammdaten/lieferanten_test.dart`

**Interfaces:**
- Consumes: existing `lieferanten` table, `nummernkreise.typ = 'kreditor'`, and Kunden VAT patterns.
- Produces: immutable `Lieferant`, `LieferantenException`, and `LieferantenRepository(this.executor)`.

- [ ] **Step 1: Add immutable entity and exception**

Implement this public shape:

```dart
class Lieferant {
  const Lieferant({
    required this.id,
    required this.kreditorNr,
    required this.anrede,
    required this.name,
    this.firma,
    required this.strasse,
    this.hausnummer,
    required this.plz,
    required this.ort,
    required this.land,
    this.ustIdNr,
    this.foreignTaxNumber,
    this.telefon,
    this.email,
    this.iban,
    required this.zahlungsziel,
    required this.skontoProzent,
    required this.skontoTage,
    this.note,
  });
}

class LieferantenException implements Exception {
  const LieferantenException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

- [ ] **Step 2: Extend supplier DDL for selected mirror fields**

Add nullable/defaulted columns to `CREATE TABLE lieferanten`: `anrede TEXT NOT NULL DEFAULT 'Herr'`, `firma TEXT`, `hausnummer TEXT`, `steuernummer_ausland VARCHAR(50)`, `zahlungsziel INTEGER DEFAULT 14`, `skonto_prozent NUMERIC(12,2) DEFAULT 0`, `skonto_tage INTEGER NOT NULL DEFAULT 0`, and `note TEXT`. Preserve existing `iban`, contact, identity, and foreign-key columns.

- [ ] **Step 3: Add idempotent compatibility columns**

Implement `ensureSchema()` with one cached future, inspect `PRAGMA table_info(lieferanten)`, and add missing columns through parameter-free DDL constants. Do not call `ensureOpen` on the app-owned executor; transaction tests may open their own transaction executor with `schemaVersion: 0`.

- [ ] **Step 4: Run schema-focused test**

Run: `fvm flutter test test/features/stammdaten/lieferanten_test.dart --plain-name "round-trips"`

Expected: still FAIL at missing repository methods, but schema setup must complete without lifecycle errors.

### Task 3: Repository CRUD, numbering, and validation

**Files:**
- Modify: `lib/pages/stammdaten/lieferanten_repository.dart`
- Test: `test/features/stammdaten/lieferanten_test.dart`

**Interfaces:**
- Consumes: `QueryExecutor`, schema compatibility from Task 2.
- Produces these methods:

```dart
Future<void> ensureSchema();
Future<Lieferant> create({
  required String name,
  String anrede = 'Herr',
  String? firma,
  required String strasse,
  String? hausnummer,
  required String plz,
  required String ort,
  String land = 'DE',
  String? ustIdNr,
  String? foreignTaxNumber,
  String? telefon,
  String? email,
  String? iban,
  int zahlungsziel = 14,
  num skontoProzent = 0,
  int skontoTage = 0,
  String? note,
});
Future<Lieferant?> findById(int id);
Future<List<Lieferant>> list();
Future<Lieferant> update(int id, Map<String, dynamic> values);
Future<void> delete(int id);
```

- [ ] **Step 1: Implement row mapping and reads**

Map all selected columns by name, normalize country codes to uppercase, return `null` for missing IDs, and order `list()` by `id`.

- [ ] **Step 2: Implement required and field validation**

Reject blank `anrede`, `name`, `strasse`, `plz`, `ort`, or `land`; reject foreign tax numbers longer than 50 characters; reject negative/invalid payment values; validate EU VAT through the same country patterns as Kunden and accept non-EU text.

- [ ] **Step 3: Implement transactional Kreditor allocation and create**

Inside `executor.beginTransaction()`, lock the `kreditor` row by transaction-local select, consume `naechste_nummer`, format with its `format` value (`#` placeholders), insert the supplier with parameterized values, update the counter, send transaction, then read back by ID. Roll back and rethrow `LieferantenException` on expected errors.

- [ ] **Step 4: Implement allowlisted update**

Allow only the entity field names and snake_case aliases. Merge changes with current row, re-run all boundary validation, build SQL assignments only from allowlisted columns, and return the refreshed entity. Unknown keys throw `LieferantenException`.

- [ ] **Step 5: Implement reference-safe delete**

Use a transaction to check `rechnungen.lieferant_id` and `journal.lieferant_id`. If either has rows, throw an error containing the table label and IDs; otherwise delete exactly one row and reject missing IDs. Roll back on every failure.

- [ ] **Step 6: Run supplier tests and commit**

Run: `fvm flutter test test/features/stammdaten/lieferanten_test.dart`

Expected: PASS.

```bash
git add lib/pages/stammdaten/lieferanten_repository.dart lib/core/db/database.dart test/features/stammdaten/lieferanten_test.dart
git commit -m "feat(stammdaten): add Lieferanten CRUD"
```

### Task 4: Integration verification and task ledger

**Files:**
- Modify: `openspec/changes/openinvoices/tasks.md:62-74`
- Modify: `openspec/changes/openinvoices/test-plan.md` only if test mappings are missing
- Test: `test/features/stammdaten/lieferanten_test.dart`

**Interfaces:**
- Consumes: completed repository and passing supplier tests.
- Produces: checked-off OpenSpec tasks 8.3 and 8.4 with no regression.

- [ ] **Step 1: Run targeted analysis**

Run: `fvm flutter analyze lib/pages/stammdaten/lieferanten_repository.dart lib/core/db/database.dart test/features/stammdaten/lieferanten_test.dart`

Expected: no issues.

- [ ] **Step 2: Run full suite**

Run: `fvm flutter test`

Expected: all tests pass.

- [ ] **Step 3: Mark OpenSpec tasks complete**

Change only these checklist entries:

```text
- [x] 8.3 Write failing test: `test/features/stammdaten/lieferanten_test.dart` — create/read/update/delete Lieferanten
- [x] 8.4 Implement: Lieferanten CRUD, Kreditor-Nr auto-assign
```

- [ ] **Step 4: Commit ledger update**

```bash
git add openspec/changes/openinvoices/tasks.md openspec/changes/openinvoices/test-plan.md
git commit -m "chore(openinvoices): mark Lieferanten tasks done"
```

## Self-Review

- Spec coverage: CRUD, mirrored fields, Kreditor numbering, EU/non-EU VAT, update validation, and invoice/journal deletion references each map to Tasks 1–3.
- Placeholder scan: no TBD, TODO, or unspecified implementation step.
- Type consistency: entity, exception, repository constructor, CRUD signatures, test usage, and later verification use matching names and types.
- Scope: limited to tasks 8.3–8.4; no UI, article, or unrelated accounting refactor.
