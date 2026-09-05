// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

const int _kontoId = 1;

Future<AppDatabase> _openConfiguredDatabase() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Acceptance GmbH']);
  await db.executor.runInsert('INSERT INTO konten (id, name, iban, waehrung) VALUES (?, ?, ?, ?)', <Object?>[
    _kontoId,
    'Girokonto',
    'DE44500606000000000000',
    'EUR',
  ]);
  return db;
}

Future<int> _transactionCount(AppDatabase db) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'SELECT count(*) AS count FROM bank_transaktionen',
    const <Object?>[],
  );
  return (rows.single['count']! as num).toInt();
}

Future<List<Map<String, Object?>>> _importHistory(AppDatabase db) {
  return db.executor.runSelect('SELECT * FROM bank_imports ORDER BY id', const <Object?>[]);
}

BankTemplate _sparkasseTemplate() {
  return BankTemplate.predefined.firstWhere((BankTemplate template) => template.typ == 'sparkasse');
}

Widget _bankImportPageApp(
  AppDatabase db, {
  String? initialContent,
  String initialFileName = 'import.csv',
  BankTemplate? initialTemplate,
}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      home: BankImportPage(
        initialContent: initialContent,
        initialFileName: initialFileName,
        initialTemplate: initialTemplate,
      ),
    ),
  );
}

Future<void> _pumpBankingPage(WidgetTester tester, AppDatabase db) async {
  await _pumpImportPage(tester, db);
}

Future<void> _pumpImportPage(
  WidgetTester tester,
  AppDatabase db, {
  String? initialContent,
  String initialFileName = 'import.csv',
  BankTemplate? initialTemplate,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    _bankImportPageApp(
      db,
      initialContent: initialContent,
      initialFileName: initialFileName,
      initialTemplate: initialTemplate,
    ),
  );
  await tester.pumpAndSettle();
}

RawTx _transaction({required String purpose, required String partner, required String amount, required int day}) {
  return RawTx(datum: DateTime(2026, 3, day), betrag: amount, verwendungszweck: purpose, partner: partner);
}

void main() {
  testWidgets('test_bank_import_workflow_integrity_1_1_user_reviews_before_import', (tester) async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);

    const String csv =
        'Datum;Betrag;Verwendungszweck;Partner\n'
        '15.03.2026;10,00;Erste Zahlung;Alpha GmbH\n';
    await _pumpImportPage(
      tester,
      db,
      initialContent: csv,
      initialFileName: 'review.csv',
      initialTemplate: _sparkasseTemplate(),
    );

    expect(
      await _transactionCount(db),
      0,
      reason: 'Selecting and parsing a file must not persist rows before explicit confirmation.',
    );
    expect(
      find.text('Datei auswählen'),
      findsOneWidget,
      reason: 'Banking must expose the upload step of the reviewable import lifecycle.',
    );
    expect(find.byType(DropdownButtonFormField<BankTemplate>), findsOneWidget);
    await tester.tap(find.text('Vorschau'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vorschau prüfen und bearbeiten', skipOffstage: false), findsOneWidget);
    expect(find.byType(TextField), findsWidgets, reason: 'Review must allow row edits before persistence.');
    expect(find.byType(Checkbox), findsWidgets, reason: 'Review must allow rows to be skipped.');
    expect(
      find.text('Kategorie', skipOffstage: false),
      findsOneWidget,
      reason: 'Review must expose manual categorization/editing for parsed rows.',
    );
    expect(
      find.textContaining('Import bestätigen', skipOffstage: false),
      findsOneWidget,
      reason: 'Persistence must be behind an explicit import confirmation action.',
    );
    expect(await _transactionCount(db), 0, reason: 'Preview/review must not persist before confirmation.');
  });

  testWidgets('test_bank_import_workflow_integrity_1_2_unsupported_input_remains_safe', (tester) async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    const String unsupported = 'not a bank statement\nunsupported payload';
    await _pumpImportPage(
      tester,
      db,
      initialContent: unsupported,
      initialFileName: 'unsupported.csv',
      initialTemplate: _sparkasseTemplate(),
    );
    await tester.tap(find.text('Vorschau'));
    await tester.pumpAndSettle();

    expect(await _transactionCount(db), 0, reason: 'Unsupported input must never persist a transaction.');
    expect(
      find.text('Erneut versuchen'),
      findsOneWidget,
      reason: 'Unsupported input must leave the user with a visible recovery action.',
    );
  });

  testWidgets('test_bank_import_workflow_integrity_2_1_successful_batch_counts_persisted_rows', (tester) async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);
    final BankTemplate template = _sparkasseTemplate();
    const String csv =
        'Datum;Betrag;Verwendungszweck;Partner\n'
        '15.03.2026;10,00;Erste Zahlung;Alpha GmbH\n'
        '16.03.2026;20,00;Zweite Zahlung;Beta GmbH\n'
        '15.03.2026;10,00;Erste Zahlung;Alpha GmbH\n';
    final List<RawTx> transactions = service.parseCsv(csv: csv, template: template);

    final ImportResult result = await service.importTransactions(
      kontoId: _kontoId,
      rawTxs: transactions,
      dateiname: 'maerz-2026.csv',
      template: template,
    );
    final List<Map<String, Object?>> persisted = await db.executor.runSelect(
      'SELECT datum, betrag, dedupe_hash FROM bank_transaktionen WHERE konto_id = ? ORDER BY id',
      <Object?>[_kontoId],
    );
    final List<Map<String, Object?>> history = await _importHistory(db);

    expect(result.imported, 2);
    expect(result.duplicatesSkipped, 1);
    expect(persisted, hasLength(result.imported));
    expect(persisted.map((Map<String, Object?> row) => row['dedupe_hash']).toSet(), hasLength(2));
    expect(history, hasLength(1));
    expect(history.single['dateiname'], 'maerz-2026.csv');
    expect(history.single['anzahl_transaktionen'], result.imported);
    expect(history.single['duplikate'], result.duplicatesSkipped);
    expect(history.single['template_typ'], template.typ);

    await _pumpBankingPage(tester, db);
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    expect(
      find.text('maerz-2026.csv'),
      findsOneWidget,
      reason: 'Import history must expose the source file for a successful persisted batch.',
    );
  });

  test('test_bank_import_workflow_integrity_2_2_a_row_failure_is_surfaced', () async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);
    final BankTemplate template = _sparkasseTemplate();
    await db.executor.runCustom('''
CREATE TRIGGER fail_selected_bank_import_row
BEFORE INSERT ON bank_transaktionen
WHEN NEW.verwendungszweck = 'FAIL-ROW-42'
BEGIN
  SELECT RAISE(ABORT, 'forced row failure: FAIL-ROW-42');
END
''');

    final ImportResult result = await service.importTransactions(
      kontoId: _kontoId,
      rawTxs: <RawTx>[
        _transaction(purpose: 'Valid row', partner: 'Alpha GmbH', amount: '10.00', day: 15),
        _transaction(purpose: 'FAIL-ROW-42', partner: 'Broken GmbH', amount: '20.00', day: 16),
      ],
      dateiname: 'row-failure.csv',
      template: template,
    );
    final List<Map<String, Object?>> persisted = await db.executor.runSelect(
      'SELECT verwendungszweck FROM bank_transaktionen WHERE konto_id = ? ORDER BY id',
      <Object?>[_kontoId],
    );
    final List<Map<String, Object?>> history = await _importHistory(db);
    final String historySnapshot = history.single.values.map((Object? value) => '$value').join(' | ').toLowerCase();

    expect(result.imported, persisted.length, reason: 'Imported count must only include rows actually persisted.');
    expect(persisted.map((Map<String, Object?> row) => row['verwendungszweck']), isNot(contains('FAIL-ROW-42')));
    expect(
      historySnapshot,
      allOf(anyOf(contains('partial'), contains('failed')), contains('fail-row-42')),
      reason: 'A failed row must surface row/error context and leave history partial or failed.',
    );
  });

  test('test_bank_import_workflow_integrity_2_3_retry_does_not_duplicate_rows', () async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);
    final BankTemplate template = _sparkasseTemplate();
    await db.executor.runCustom('''
CREATE TRIGGER fail_selected_bank_import_row
BEFORE INSERT ON bank_transaktionen
WHEN NEW.verwendungszweck = 'FAIL-ROW-42'
BEGIN
  SELECT RAISE(ABORT, 'forced row failure: FAIL-ROW-42');
END
''');

    final List<RawTx> firstAttempt = <RawTx>[
      _transaction(purpose: 'Valid row', partner: 'Alpha GmbH', amount: '10.00', day: 15),
      _transaction(purpose: 'FAIL-ROW-42', partner: 'Broken GmbH', amount: '20.00', day: 16),
    ];
    await service.importTransactions(
      kontoId: _kontoId,
      rawTxs: firstAttempt,
      dateiname: 'retry.csv',
      template: template,
    );
    await db.executor.runCustom('DROP TRIGGER fail_selected_bank_import_row');

    final ImportResult retry = await service.importTransactions(
      kontoId: _kontoId,
      rawTxs: <RawTx>[
        firstAttempt.first,
        _transaction(purpose: 'Corrected row', partner: 'Broken GmbH', amount: '20.00', day: 16),
      ],
      dateiname: 'retry.csv',
      template: template,
    );
    final List<Map<String, Object?>> persisted = await db.executor.runSelect(
      'SELECT dedupe_hash, verwendungszweck FROM bank_transaktionen WHERE konto_id = ? ORDER BY id',
      <Object?>[_kontoId],
    );
    final List<Map<String, Object?>> history = await _importHistory(db);
    final String firstHistorySnapshot = history.first.values.map((Object? value) => '$value').join(' | ').toLowerCase();

    expect(retry.imported, 1, reason: 'Retry should add only the corrected failed row.');
    expect(retry.duplicatesSkipped, 1, reason: 'The already persisted row must be skipped on retry.');
    expect(persisted, hasLength(2));
    expect(persisted.map((Map<String, Object?> row) => row['dedupe_hash']).toSet(), hasLength(2));
    expect(
      firstHistorySnapshot,
      anyOf(contains('partial'), contains('failed')),
      reason: 'Retry must start from a history record that truthfully records the partial failure.',
    );
  });
}
