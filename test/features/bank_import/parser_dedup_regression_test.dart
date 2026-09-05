import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

void main() {
  group('Bank import parser and dedup regression coverage', () {
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

    test('equivalent German and ISO amounts deduplicate after parsing', () async {
      const String germanCsv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;1.234,50;Miete März;Vermieter GmbH\n';
      const String isoCsv =
          'Datum,Betrag,Verwendungszweck,Partner\n'
          '2026-03-15,1234.50,Miete März,Vermieter GmbH\n';
      final BankTemplate sparkasse = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final BankTemplate paypal = BankTemplate.predefined.firstWhere((t) => t.typ == 'paypal');

      final List<RawTx> germanRows = service.parseCsv(csv: germanCsv, template: sparkasse);
      final List<RawTx> isoRows = service.parseCsv(csv: isoCsv, template: paypal);
      expect(germanRows.single.betrag, '1234.50');
      expect(isoRows.single.betrag, '1234.50');

      final ImportResult first = await service.importTransactions(kontoId: 1, rawTxs: germanRows, template: sparkasse);
      final ImportResult second = await service.importTransactions(kontoId: 1, rawTxs: isoRows, template: paypal);

      expect(first.imported, 1);
      expect(second.imported, 0);
      expect(second.duplicatesSkipped, 1);

      final List<Map<String, Object?>> persisted = await db.executor.runSelect(
        'SELECT count(*) AS count FROM bank_transaktionen WHERE konto_id = 1',
        const <Object?>[],
      );
      expect((persisted.single['count']! as num).toInt(), 1);
    });
  });
}
