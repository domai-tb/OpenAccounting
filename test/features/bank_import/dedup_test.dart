import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

void main() {
  group('Bank Import Dedup + Auto-Categorization + Score', () {
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
      await db.executor.runInsert('INSERT INTO konten (id, name, iban, waehrung) VALUES (?, ?, ?, ?)', <Object?>[
        2,
        'Giro Zweite',
        'DE44500606000000000001',
        'EUR',
      ]);
      // Seed auto rules: Netflix -> kategorie 5, Amazon -> 6
      await db.executor.runInsert(
        'INSERT INTO auto_filter_regeln (muster, kategorie_id, aktiv, prioritaet) VALUES (?, ?, ?, ?)',
        <Object?>['Netflix', 5, 1, 10],
      );
      await db.executor.runInsert(
        'INSERT INTO auto_filter_regeln (muster, kategorie_id, aktiv, prioritaet) VALUES (?, ?, ?, ?)',
        <Object?>['Amazon', 6, 1, 5],
      );
      service = BankImportService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('computeDedupeHash is deterministic SHA-256 hex', () {
      final String h1 = service.computeDedupeHash(DateTime(2026, 3, 15), '100.00', 'Netflix', 'Abo März');
      final String h2 = service.computeDedupeHash(DateTime(2026, 3, 15), '100.00', 'Netflix', 'Abo März');
      expect(h1, equals(h2));
      expect(h1.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h1), isTrue);
      final String hDiff = service.computeDedupeHash(DateTime(2026, 3, 16), '100.00', 'Netflix', 'Abo März');
      expect(hDiff, isNot(equals(h1)));
    });

    test('duplicate hash prevents re-import same konto', () async {
      const String csv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;100,00;Netflix Abo;Netflix\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> raw = service.parseCsv(csv: csv, template: template);

      final ImportResult r1 = await service.importTransactions(kontoId: 1, rawTxs: raw);
      expect(r1.imported, 1);
      expect(r1.duplicatesSkipped, 0);
      // dedupe_hash computed and stored
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT dedupe_hash, betrag, kategorie_id FROM bank_transaktionen WHERE konto_id = 1',
        const <Object?>[],
      );
      expect(rows, hasLength(1));
      final String storedHash = rows.first['dedupe_hash'] as String;
      expect(storedHash.length, 64);
      final String expectedHash = service.computeDedupeHash(DateTime(2026, 3, 15), '100.00', 'Netflix', 'Netflix Abo');
      expect(storedHash, expectedHash);

      // second import same CSV same konto -> duplicate skipped
      final ImportResult r2 = await service.importTransactions(kontoId: 1, rawTxs: raw);
      expect(r2.imported, 0);
      expect(r2.duplicatesSkipped, 1);
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT count(*) as c FROM bank_transaktionen WHERE konto_id = 1',
        const <Object?>[],
      );
      expect((after.first['c'] as num).toInt(), 1);

      // history rows inserted
      final List<Map<String, Object?>> hist = await db.executor.runSelect(
        'SELECT count(*) as c FROM bank_imports',
        const <Object?>[],
      );
      expect((hist.first['c'] as num).toInt(), greaterThanOrEqualTo(2));
    });

    test('same hash different konto is not duplicate', () async {
      const String csv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;100,00;Netflix Abo;Netflix\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> raw = service.parseCsv(csv: csv, template: template);
      final ImportResult r1 = await service.importTransactions(kontoId: 1, rawTxs: raw);
      expect(r1.imported, 1);
      final ImportResult r2 = await service.importTransactions(kontoId: 2, rawTxs: raw);
      expect(r2.imported, 1);
      expect(r2.duplicatesSkipped, 0);
    });

    test('pattern match assigns kategorie_id, no match leaves null', () async {
      const String csv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;12,99;Netflix Monatsabo;Netflix\n'
          '16.03.2026;20,00;Supermarkt Einkauf;Edeka\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> raw = service.parseCsv(csv: csv, template: template);
      final ImportResult result = await service.importTransactions(kontoId: 1, rawTxs: raw);
      expect(result.imported, 2);
      expect(result.autoCategorized, 1);
      expect(result.manualReview, 1);

      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT verwendungszweck, kategorie_id FROM bank_transaktionen WHERE konto_id = 1 ORDER BY datum',
        const <Object?>[],
      );
      expect(rows[0]['verwendungszweck'], contains('Netflix'));
      expect(rows[0]['kategorie_id'], 5);
      expect(rows[1]['kategorie_id'], isNull);

      // direct applyRules helper
      final int? catNetflix = await service.applyRules('Zahlung Netflix April');
      expect(catNetflix, 5);
      final int? catNone = await service.applyRules('Unbekannt XYZ');
      expect(catNone, isNull);
    });

    test('manual override trotzdem importieren with hash suffix', () async {
      const String csv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;100,00;Netflix Abo;Netflix\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> raw = service.parseCsv(csv: csv, template: template);

      final ImportResult r1 = await service.importTransactions(kontoId: 1, rawTxs: raw);
      expect(r1.imported, 1);

      final ImportResult r2 = await service.importTransactions(kontoId: 1, rawTxs: raw);
      expect(r2.duplicatesSkipped, 1);
      expect(r2.imported, 0);

      // override -> should import with suffix hash
      final ImportResult r3 = await service.importTransactions(kontoId: 1, rawTxs: raw, allowDuplicateOverride: true);
      expect(r3.imported, 1);
      expect(r3.duplicatesSkipped, 0);

      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT dedupe_hash FROM bank_transaktionen WHERE konto_id = 1 ORDER BY id',
        const <Object?>[],
      );
      expect(rows, hasLength(2));
      final String h1 = rows[0]['dedupe_hash'] as String;
      final String h2 = rows[1]['dedupe_hash'] as String;
      expect(h1, isNot(equals(h2)));
      expect(h2.startsWith(h1), isTrue);
      expect(h2, contains('-'));
    });

    test('score matching high >=90 suggests match, low no match', () async {
      // Seed journal entry: similar amount/date/partner
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, soll, haben, beleg_typ) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['2026-03-15', 'Netflix GmbH', 5, '100.00', '100.00', '0', 'Einnahme'],
      );
      final List<Map<String, Object?>> journals = await db.executor.runSelect(
        'SELECT * FROM journal',
        const <Object?>[],
      );
      expect(journals, hasLength(1));
      final Map<String, Object?> jRow = journals.first;

      final RawTx txHigh = RawTx(
        datum: DateTime(2026, 3, 16),
        betrag: '100.00',
        verwendungszweck: 'Netflix Abo',
        partner: 'Netflix GmbH',
      );
      final int highScore = service.computeScore(txHigh, jRow);
      expect(highScore, greaterThanOrEqualTo(90));

      final RawTx txLow = RawTx(
        datum: DateTime(2026, 1, 1),
        betrag: '999.99',
        verwendungszweck: 'Unrelated',
        partner: 'Unbekannt Partner XYZ',
      );
      final int lowScore = service.computeScore(txLow, jRow);
      expect(lowScore, lessThan(90));

      // findBestMatch helper via import should auto-link in automatisch mode
      final RawTx txForImport = RawTx(
        datum: DateTime(2026, 3, 16),
        betrag: '100.00',
        verwendungszweck: 'Zahlung Netflix',
        partner: 'Netflix GmbH',
      );
      // manual mode -> journal_id stays null even with high score
      await db.executor.runCustom('DELETE FROM bank_transaktionen');
      await db.executor.runCustom('DELETE FROM bank_imports');
      final ImportResult manual = await service.importTransactions(
        kontoId: 1,
        rawTxs: <RawTx>[txForImport],
        mode: 'manuell',
      );
      expect(manual.imported, 1);
      final List<Map<String, Object?>> manualRows = await db.executor.runSelect(
        'SELECT journal_id FROM bank_transaktionen',
        const <Object?>[],
      );
      expect(manualRows.first['journal_id'], isNull);

      // automatisch mode -> high score auto-books journal_id
      await db.executor.runCustom('DELETE FROM bank_transaktionen');
      await db.executor.runCustom('DELETE FROM bank_imports');
      final ImportResult auto = await service.importTransactions(
        kontoId: 1,
        rawTxs: <RawTx>[txForImport],
        mode: 'automatisch',
      );
      expect(auto.imported, 1);
      final List<Map<String, Object?>> autoRows = await db.executor.runSelect(
        'SELECT journal_id FROM bank_transaktionen',
        const <Object?>[],
      );
      expect(autoRows.first['journal_id'], isNotNull);
      expect(autoRows.first['journal_id'], jRow['id']);
    });

    test('import statistics totals', () async {
      const String csv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;12,99;Netflix Abo;Netflix\n'
          '16.03.2026;20,00;Edeka Einkauf;Edeka\n'
          '17.03.2026;30,00;Amazon Bestellung;Amazon\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> raw = service.parseCsv(csv: csv, template: template);
      final ImportResult r = await service.importTransactions(kontoId: 1, rawTxs: raw);
      expect(r.imported, 3);
      expect(r.duplicatesSkipped, 0);
      // Netflix and Amazon match -> 2 auto, 1 manual
      expect(r.autoCategorized, 2);
      expect(r.manualReview, 1);
    });
  });
}
