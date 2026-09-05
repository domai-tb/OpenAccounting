import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

void main() {
  group('Bank import history compatibility', () {
    late AppDatabase db;
    late BankImportService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runInsert('INSERT INTO konten (id, name, iban, waehrung) VALUES (?, ?, ?, ?)', <Object?>[
        1,
        'Giro Sparkasse',
        'DE44500606000000000000',
        'EUR',
      ]);
      service = BankImportService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('retains source, time, template, and persisted duplicate counts', () async {
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> batch = <RawTx>[
        RawTx(
          datum: DateTime(2026, 3, 15),
          betrag: '10.00',
          verwendungszweck: 'History compatibility row',
          partner: 'Example Partner',
        ),
      ];

      final ImportResult first = await service.importTransactions(
        kontoId: 1,
        rawTxs: batch,
        dateiname: 'sparkasse-march.csv',
        template: template,
      );
      final ImportResult second = await service.importTransactions(
        kontoId: 1,
        rawTxs: batch,
        dateiname: 'sparkasse-march.csv',
        template: template,
      );

      expect(first.imported, 1);
      expect(first.duplicatesSkipped, 0);
      expect(second.imported, 0);
      expect(second.duplicatesSkipped, 1);

      final List<Map<String, Object?>> history = await db.executor.runSelect(
        'SELECT konto_id, dateiname, datum, anzahl_transaktionen, duplikate, template_typ, status '
        'FROM bank_imports ORDER BY id',
        const <Object?>[],
      );
      expect(history, hasLength(2));

      final Map<String, Object?> firstHistory = history[0];
      expect(firstHistory['konto_id'], 1);
      expect(firstHistory['dateiname'], 'sparkasse-march.csv');
      expect(DateTime.tryParse(firstHistory['datum']?.toString() ?? ''), isNotNull);
      expect((firstHistory['anzahl_transaktionen']! as num).toInt(), 1);
      expect((firstHistory['duplikate']! as num).toInt(), 0);
      expect(firstHistory['template_typ'], 'sparkasse');
      expect(firstHistory['status'], 'importiert');

      final Map<String, Object?> retryHistory = history[1];
      expect((retryHistory['anzahl_transaktionen']! as num).toInt(), 0);
      expect((retryHistory['duplikate']! as num).toInt(), 1);
      expect(retryHistory['template_typ'], 'sparkasse');
      expect(retryHistory['status'], 'importiert');
    });
  });
}
