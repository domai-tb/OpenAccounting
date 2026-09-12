// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/rechnungsvorlagen_repository.dart';

void main() {
  group('Recurring accounting postings', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    test('mixed-rate invoice template generates exact totals through the repository', () async {
      final RechnungsVorlagenRepository repository = RechnungsVorlagenRepository(db.executor);
      final RechnungsVorlage template = await repository.create(
        name: 'Mixed recurring invoice',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Standard', 'menge': 1, 'einzelpreis': 100, 'ust_satz': 19},
          <String, dynamic>{'bezeichnung': 'Reduced', 'menge': 1, 'einzelpreis': 50, 'ust_satz': 7},
        ],
      );

      final List<int> generated = await repository.generateFaellig(heute: DateTime(2026));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
        <Object?>[generated.single],
      );

      expect(template.positionen, hasLength(2));
      expect(rows.single['netto_betrag'], 150.00);
      expect(rows.single['ust_betrag'], 22.50);
      expect(rows.single['brutto_betrag'], 172.50);
    });

    test('invalid recurring invoice tax rate fails at the service boundary', () async {
      final RechnungsVorlagenRepository repository = RechnungsVorlagenRepository(db.executor);

      await expectLater(
        repository.create(
          name: 'Invalid rate',
          intervall: 'monatlich',
          positionen: <Map<String, dynamic>>[
            <String, dynamic>{'bezeichnung': 'Bad', 'menge': 1, 'einzelpreis': 10, 'ust_satz': 101},
          ],
        ),
        throwsA(isA<RechnungsVorlagenException>()),
      );
    });

    test('gross recurring expense posts only its tax component', () async {
      final BuchungsVorlagenRepository repository = BuchungsVorlagenRepository(db.executor);
      await repository.create(
        name: 'Recurring expense',
        betrag: '119.00',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
      );

      final List<int> generated = await repository.generateFaellig(heute: DateTime(2026));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT betrag, vorsteuer_betrag, ust_satz FROM journal WHERE id = ?',
        <Object?>[generated.single],
      );

      expect(rows.single['betrag'], 119.00);
      expect(rows.single['vorsteuer_betrag'], 19.00);
      expect(rows.single['ust_satz'], 19.00);
    });

    test('retrying the same recurring booking occurrence is idempotent', () async {
      final BuchungsVorlagenRepository repository = BuchungsVorlagenRepository(db.executor);
      final BuchungsVorlage template = await repository.create(
        name: 'Retryable expense',
        betrag: '10.00',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
      );
      final List<int> first = await repository.generateFaellig(heute: DateTime(2026, 2));
      await db.executor.runUpdate('UPDATE buchungsvorlagen SET naechste_faelligkeit = ? WHERE id = ?', <Object?>[
        '2026-02-01',
        template.id,
      ]);
      final List<int> retry = await repository.generateFaellig(heute: DateTime(2026, 2));
      final List<Map<String, Object?>> count = await db.executor.runSelect(
        'SELECT COUNT(*) AS count FROM journal WHERE vorlage_id = ?',
        <Object?>[template.id],
      );

      expect(retry, <int>[first.single]);
      expect(count.single['count'], 1);
    });
  });
}
