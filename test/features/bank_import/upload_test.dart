import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

void main() {
  group('Bank Import Upload — CSV parses into transactions', () {
    late AppDatabase db;
    late BankImportService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      // Kategorie + Konto per spec §Konto selection — upload step validates konto exists.
      await db.executor.runInsert('INSERT INTO konten (id, name, iban, waehrung) VALUES (?, ?, ?, ?)', <Object?>[
        1,
        'Giro Sparkasse',
        'DE44500606000000000000',
        'EUR',
      ]);
      // Seed templates already via SeedData, but ensure fallback map works.
      service = BankImportService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('parses semicolon German format DD.MM.YYYY and 1.234,56', () {
      const String csv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;1.234,56;Miete März;Vermieter GmbH\n'
          '16.03.2026;1234.56;Rechnung 123;Kunde AG\n'
          '17.03.2026;-42,50;Gebühr;Bank\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> rows = service.parseCsv(csv: csv, template: template);

      expect(rows, hasLength(3));
      expect(rows[0].datum, DateTime(2026, 3, 15));
      expect(rows[0].betrag, '1234.56');
      expect(rows[0].verwendungszweck, 'Miete März');
      expect(rows[0].partner, 'Vermieter GmbH');
      // German thousand + comma.
      expect(rows[0].betrag, matches(RegExp(r'^-?\d+\.\d{2}$')));
      // Dot amount stays 1234.56
      expect(rows[1].betrag, '1234.56');
      expect(rows[1].datum, DateTime(2026, 3, 16));
      // Negative German with comma
      expect(rows[2].betrag, '-42.50');
    });

    test('parses comma variant YYYY-MM-DD and 1234.56', () {
      const String csv =
          'Datum,Betrag,Verwendungszweck,Partner\n'
          '2026-03-15,1234.56,Miete März,Vermieter GmbH\n'
          '2026-03-16,42.50,Gebühr,Bank\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'paypal');
      final List<RawTx> rows = service.parseCsv(csv: csv, template: template);

      expect(rows, hasLength(2));
      expect(rows[0].datum, DateTime(2026, 3, 15));
      expect(rows[0].betrag, '1234.56');
      expect(rows[0].verwendungszweck, 'Miete März');
      expect(rows[1].betrag, '42.50');
      expect(rows[1].datum, DateTime(2026, 3, 16));
    });

    test('upload step does not insert into bank_transaktionen', () async {
      const String csv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;100,00;Test;Partner\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> rows = service.parseCsv(csv: csv, template: template);
      expect(rows, hasLength(1));

      final List<Map<String, Object?>> dbRows = await db.executor.runSelect(
        'SELECT count(*) as c FROM bank_transaktionen',
        const <Object?>[],
      );
      final int count = (dbRows.first['c']! as num).toInt();
      expect(count, 0, reason: 'upload step only parses, no DB import');
    });

    test('invalid file no header throws BankImportException', () {
      const String csv =
          '15.03.2026;1234,56;Miete;Partner\n'
          '16.03.2026;42,50;Gebühr;Bank\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      expect(() => service.parseCsv(csv: csv, template: template), throwsA(isA<BankImportException>()));
    });

    test('no template matches throws prompt', () {
      const String csv =
          'Foo;Bar;Baz\n'
          '1;2;3\n'
          '4;5;6\n';
      // No valid datum/betrag header — should prompt template selection.
      expect(
        () => service.parseCsv(csv: csv),
        throwsA(predicate<Object>((e) => e is BankImportException && e.message.toLowerCase().contains('template'))),
      );
    });

    test('predefined templates contain 7 banks', () {
      const List<BankTemplate> templates = BankTemplate.predefined;
      expect(templates.length, greaterThanOrEqualTo(7));
      final Set<String> typs = templates.map((t) => t.typ).toSet();
      expect(typs, containsAll(<String>['sparkasse', 'paypal', 'n26', 'vivid', 'ing', 'dkb', 'commerzbank']));
    });

    test('handles quoted fields with delimiter inside', () {
      const String csv =
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;"1.234,56";"Miete; März";"Vermieter, GmbH"\n';
      final BankTemplate template = BankTemplate.predefined.firstWhere((t) => t.typ == 'sparkasse');
      final List<RawTx> rows = service.parseCsv(csv: csv, template: template);

      expect(rows, hasLength(1));
      expect(rows[0].betrag, '1234.56');
      expect(rows[0].verwendungszweck, 'Miete; März');
      expect(rows[0].partner, 'Vermieter, GmbH');
    });
  });
}
