import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/seed.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';

void main() {
  group('SeedData', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    test('seeds standard tax rates and document number ranges', () async {
      final rates = await db.executor.runSelect('SELECT satz FROM ust_saetze ORDER BY id', const []);
      expect(rates.map((row) => row['satz']), containsAll(<num>[0, 7, 19]));
      expect(rates, hasLength(3));

      final ranges = await db.executor.runSelect('SELECT typ FROM nummernkreise ORDER BY id', const []);
      expect(
        ranges.map((row) => row['typ']),
        containsAll(<String>[
          'rechnung_ausgang',
          'rechnung_eingang',
          'angebot',
          'auftrag',
          'proforma',
          'lieferschein',
          'stornorechnung',
          'gutschrift',
          'debitor',
          'kreditor',
          'bank_import',
        ]),
      );
    });

    test('fresh profile without approved catalog has no preconfigured mappings', () async {
      final rows = await db.executor.runSelect('SELECT konto_skr03, konto_skr04, euer_zeile FROM kategorien', const []);

      expect(rows, isEmpty, reason: 'No synthetic categories without an approved manifest');
      expect(await db.kategorienRepository.isAccountingConfigured(), isFalse);
    });

    test('is idempotent and preserves existing seed values', () async {
      await db.executor.runCustom("UPDATE ust_saetze SET bezeichnung = 'Eigene Bezeichnung' WHERE id = 1");
      final created = await db.kategorienRepository.create(bezeichnung: 'Eigene Kategorie');
      await SeedData.run(db.executor);

      final rates = await db.executor.runSelect('SELECT bezeichnung FROM ust_saetze WHERE id = 1', const []);
      expect(rates.single['bezeichnung'], 'Eigene Bezeichnung');

      final counts = await db.executor.runSelect(
        'SELECT (SELECT count(*) FROM ust_saetze) AS rates, '
        '(SELECT count(*) FROM nummernkreise) AS ranges, '
        '(SELECT count(*) FROM kategorien) AS categories',
        const [],
      );
      expect(counts.single['rates'], 3);
      expect(counts.single['ranges'], 11);
      expect(counts.single['categories'], 1);

      final kept = await db.kategorienRepository.findById(created.id);
      expect(kept?.bezeichnung, 'Eigene Kategorie');
      expect(kept?.mappingStatus, CategoryMappingStatus.unmapped);
    });
  });
}
