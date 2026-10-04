import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/bank_import/bank_import_failure_payload.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

Future<AppDatabase> _openConfiguredDatabase() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO konten (id, name, iban, waehrung) VALUES (?, ?, ?, ?)', <Object?>[
    1,
    'Girokonto',
    'DE44500606000000000000',
    'EUR',
  ]);
  return db;
}

Future<int> _transactionCount(AppDatabase db) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'SELECT COUNT(*) AS count FROM bank_transaktionen',
    const <Object?>[],
  );
  return (rows.single['count']! as num).toInt();
}

void main() {
  testWidgets('test_bank_import_parse_review_confirm_preserves_invalid_date_with_valid_row', (tester) async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: BankImportPage(
            initialContent:
                'Datum;Betrag;Verwendungszweck;Partner\n'
                '15.03.2026;10,00;Valid;A\n'
                'not-a-date;20,00;Invalid date;B\n',
            initialFileName: 'review.csv',
            initialTemplate: BankTemplate.predefined.firstWhere((BankTemplate template) => template.typ == 'sparkasse'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vorschau'));
    await tester.pumpAndSettle();

    final List<String> dateAndAmountTexts = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((TextField field) => field.controller?.text ?? '')
        .toList();
    expect(dateAndAmountTexts, contains('not-a-date'));
    expect(find.textContaining('Vorschau prüfen und bearbeiten', skipOffstage: false), findsOneWidget);

    await tester.tap(find.textContaining('Import bestätigen', skipOffstage: false).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import bestätigen', skipOffstage: false).last);
    await tester.pumpAndSettle();

    expect(await _transactionCount(db), 1);
    final List<Map<String, Object?>> history = await db.executor.runSelect(
      'SELECT status, anzahl_importiert, anzahl_fehlgeschlagen, fehler_details FROM bank_imports ORDER BY id',
      const <Object?>[],
    );
    expect(history, hasLength(1));
    expect(history.single['status'], 'teilweise');
    expect(history.single['anzahl_importiert'], 1);
    expect(history.single['anzahl_fehlgeschlagen'], 1);
    final Map<String, Object?> envelope = BankImportFailurePayload.decodeValidated(
      history.single['fehler_details']! as String,
    );
    expect(envelope['kind'], 'rows');
    final List<Map<String, Object?>> payloadRows = (envelope['rows']! as List).cast<Map<String, Object?>>();
    expect(payloadRows.single['diagnostic_codes'], contains('invalid_date'));
  });
}
