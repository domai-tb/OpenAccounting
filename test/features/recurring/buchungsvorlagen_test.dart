import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';

void main() {
  group('Buchungsvorlagen — Fixed Costs (spec/recurring)', () {
    late AppDatabase db;
    late BuchungsVorlagenRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = BuchungsVorlagenRepository(db.executor);
      await db.executor.runInsert('INSERT INTO konten (id, name, iban) VALUES (?, ?, ?)', <Object?>[
        1,
        'Bank',
        'DE00111111111111111111',
      ]);
      await db.executor.runInsert('INSERT INTO lieferanten (id, name, strasse) VALUES (?, ?, ?)', <Object?>[
        1,
        'Vermieter',
        'Hauptstr. 1',
      ]);
    });

    tearDown(() async => db.close());

    test('Create booking template — monatlich Ausgabe Miete generates monthly', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Miete',
        kategorieId: 1,
        kontoId: 1,
        betrag: '800.00',
        beschreibung: 'Monatliche Miete',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
      );
      expect(v.name, 'Miete');
      expect(v.art, 'Ausgabe');
      expect(v.modus, 'direkt');
      expect(v.intervall, 'monatlich');
      expect(v.aktiv, isTrue);
      expect(repo.isDue(v, DateTime(2026)), isTrue);
    });

    test('Delete booking template without entries succeeds', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'ToDelete',
        kategorieId: 1,
        art: 'Ausgabe',
        intervall: 'monatlich',
        betrag: '10.00',
      );
      await repo.delete(v.id);
      expect(await repo.findById(v.id), isNull);
    });

    test('Direkt mode — creates journal entry automatically', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Direkt',
        kategorieId: 1,
        kontoId: 1,
        betrag: '100.00',
        beschreibung: 'Direkt Buchung',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026, 2));
      expect(ids.length, 1);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT beleg_typ, betrag, vorlage_id FROM journal WHERE id = ?',
        <Object?>[ids.single],
      );
      expect(rows.single['beleg_typ'], 'Ausgabe');
      expect(rows.single['vorlage_id'], v.id);
    });

    test('Beleg mode — creates Rechnung draft with pre-filled fields', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Beleg',
        kategorieId: 1,
        lieferantId: 1,
        betrag: '200.00',
        beschreibung: 'Beleg Buchung',
        modus: 'beleg',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026, 2));
      expect(ids.length, 1);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT typ, lieferant_id, vorlage_id FROM rechnungen WHERE id = ?',
        <Object?>[ids.single],
      );
      expect(rows.single['typ'], 'eingangsrechnung');
      expect(rows.single['lieferant_id'], 1);
      expect(rows.single['vorlage_id'], v.id);
    });

    test('Ausgabe direction — Vorsteuer KZ 66', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Ausgabe USt',
        kategorieId: 1,
        betrag: '119.00',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT beleg_typ, vorsteuer_betrag FROM journal WHERE id = ?',
        <Object?>[ids.single],
      );
      expect(rows.single['beleg_typ'], 'Ausgabe');
      expect(rows.single['vorsteuer_betrag'], isNotNull);
      expect(v.art, 'Ausgabe');
    });

    test('Einnahme direction — Umsatzsteuer KZ 81', () async {
      await repo.create(
        name: 'Einnahme USt',
        kategorieId: 1,
        betrag: '119.00',
        art: 'Einnahme',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT beleg_typ, vorsteuer_betrag FROM journal WHERE id = ?',
        <Object?>[ids.single],
      );
      expect(rows.single['beleg_typ'], 'Einnahme');
      // Einnahme should NOT have Vorsteuer
      expect(rows.single['vorsteuer_betrag'], isNull);
    });

    test('Auto-generate journal entry — scheduled date is today', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Auto',
        kategorieId: 1,
        betrag: '50.00',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-03-01',
      );
      expect(repo.isDue(v, DateTime(2026, 3)), isTrue);
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026, 03));
      expect(ids.length, 1);
    });

    test('Inactive template skipped — no journal created', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Inactive',
        kategorieId: 1,
        betrag: '50.00',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
      );
      await repo.pause(v.id);
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026));
      expect(ids, isEmpty);
    });

    test('Linked supplier — inherits supplier reference', () async {
      await repo.create(
        name: 'Supplier Link',
        kategorieId: 1,
        lieferantId: 1,
        betrag: '300.00',
        modus: 'beleg',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT lieferant_id FROM rechnungen WHERE id = ?',
        <Object?>[ids.single],
      );
      expect(rows.single['lieferant_id'], 1);
    });

    test('Linked account — uses specified bank account for DATEV export', () async {
      await repo.create(
        name: 'Konto Link',
        kategorieId: 1,
        kontoId: 1,
        betrag: '400.00',
        art: 'Ausgabe',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT konto_id FROM journal WHERE id = ?',
        <Object?>[ids.single],
      );
      expect(rows.single['konto_id'], 1);
    });

    test('Invalid intervall rejected', () async {
      await expectLater(
        repo.create(name: 'Bad', kategorieId: 1, art: 'Ausgabe', intervall: 'wöchentlich'),
        throwsA(isA<BuchungsVorlagenException>()),
      );
    });

    test('Invalid modus rejected', () async {
      await expectLater(
        repo.create(name: 'Bad Modus', kategorieId: 1, art: 'Ausgabe', intervall: 'monatlich', modus: 'falsch'),
        throwsA(isA<BuchungsVorlagenException>()),
      );
    });

    test('Invalid art rejected', () async {
      await expectLater(
        repo.create(name: 'Bad Art', kategorieId: 1, art: 'Unbekannt', intervall: 'monatlich'),
        throwsA(isA<BuchungsVorlagenException>()),
      );
    });

    test('Next due advance — monatlich/quartalsweise/jährlich', () async {
      expect(repo.nextDue(DateTime(2026, 1, 15), 'monatlich'), DateTime(2026, 02, 15));
      expect(repo.nextDue(DateTime(2026), 'quartalsweise'), DateTime(2026, 04));
      expect(repo.nextDue(DateTime(2026, 06, 15), 'jährlich'), DateTime(2027, 06, 15));
    });
  });
}
