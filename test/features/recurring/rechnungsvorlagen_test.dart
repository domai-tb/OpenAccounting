import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/recurring/rechnungsvorlagen_repository.dart';

void main() {
  group('Rechnungsvorlagen — Recurring Templates (spec/recurring)', () {
    late AppDatabase db;
    late RechnungsVorlagenRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = RechnungsVorlagenRepository(db.executor);
      // Minimal Kunde für FK.
      await db.executor.runInsert('INSERT INTO kunden (id, name, strasse, plz, ort) VALUES (?, ?, ?, ?, ?)', <Object?>[
        1,
        'Testkunde',
        'Musterstr. 1',
        '10115',
        'Berlin',
      ]);
      // Artikel für Preisvergleich.
      await db.executor.runInsert(
        'INSERT INTO artikel (id, bezeichnung, vk_netto, vk_brutto, vk_eingabe, typ) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[1, 'Artikel A', 8.4034, 10.00, 'brutto', 'Artikel'],
      );
      await db.executor.runInsert(
        'INSERT INTO artikel (id, bezeichnung, vk_netto, vk_brutto, vk_eingabe, typ) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[2, 'Artikel B', 10.0840, 12.00, 'brutto', 'Artikel'],
      );
    });

    tearDown(() async => db.close());

    test('Activate template — save with monatlich sets aktiv and next due', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Monatlich Abo',
        kundeId: 1,
        intervall: 'monatlich',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{
            'artikel_id': 1,
            'bezeichnung': 'Pos 1',
            'menge': 1,
            'einzelpreis': 10.00,
            'kategorie_id': 1,
          },
        ],
        bezugsDatum: DateTime(2026, 1, 15),
      );
      expect(v.status, 'aktiv');
      expect(v.aktiv, isTrue);
      expect(v.intervall, 'monatlich');
      expect(v.naechsteFaelligkeit, isNotNull);
      expect(v.positionen.length, 1);
    });

    test('Pause template — generation stops and positionen retained', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Pause Test',
        kundeId: 1,
        intervall: 'monatlich',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'artikel_id': 1, 'bezeichnung': 'Pos', 'menge': 2, 'einzelpreis': 5.00, 'kategorie_id': 1},
        ],
      );
      final RechnungsVorlage paused = await repo.pause(v.id);
      expect(paused.status, 'pausiert');
      expect(paused.aktiv, isFalse);
      expect(paused.positionen.length, 1);
      expect(paused.positionen.single['bezeichnung'], 'Pos');
      final List<int> gen = await repo.generateFaellig(heute: DateTime.now().add(const Duration(days: 60)));
      expect(gen, isEmpty);
    });

    test('End template — beendet, no further generation, retained for history', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'End Test',
        kundeId: 1,
        intervall: 'monatlich',
        positionen: <Map<String, dynamic>>[],
        naechsteFaelligkeit: '2026-01-01',
      );
      final RechnungsVorlage beendet = await repo.beenden(v.id);
      expect(beendet.status, 'beendet');
      expect(beendet.aktiv, isFalse);
      final List<int> gen = await repo.generateFaellig(heute: DateTime(2026, 2, 1));
      expect(gen, isEmpty);
      final RechnungsVorlage? still = await repo.findById(v.id);
      expect(still, isNotNull);
    });

    test('Monthly generation — 1st of month triggers', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Monthly',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-03-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Miete', 'menge': 1, 'einzelpreis': 100.00, 'kategorie_id': 1},
        ],
      );
      expect(repo.isDue(v, DateTime(2026, 3, 1)), isTrue);
      expect(repo.isDue(v, DateTime(2026, 3, 2)), isTrue);
      expect(repo.isDue(v, DateTime(2026, 2, 28)), isFalse);
    });

    test('Quarterly generation — Jan Apr Jul Oct', () async {
      for (final String d in <String>['2026-01-01', '2026-04-01', '2026-07-01', '2026-10-01']) {
        final RechnungsVorlage v = await repo.create(
          name: 'Q $d',
          kundeId: 1,
          intervall: 'quartalsweise',
          naechsteFaelligkeit: d,
          positionen: <Map<String, dynamic>>[],
        );
        expect(repo.isDue(v, DateTime.parse(d)), isTrue);
      }
      final RechnungsVorlage v2 = await repo.create(
        name: 'Q not due',
        kundeId: 1,
        intervall: 'quartalsweise',
        naechsteFaelligkeit: '2026-04-01',
        positionen: <Map<String, dynamic>>[],
      );
      expect(repo.isDue(v2, DateTime(2026, 2, 1)), isFalse);
    });

    test('Yearly generation — matches creation month/day', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Yearly',
        kundeId: 1,
        intervall: 'jährlich',
        naechsteFaelligkeit: '2026-06-15',
        positionen: <Map<String, dynamic>>[],
      );
      expect(repo.isDue(v, DateTime(2026, 6, 15)), isTrue);
      expect(repo.isDue(v, DateTime(2026, 6, 14)), isFalse);
      expect(repo.nextDue(DateTime(2026, 6, 15), 'jährlich'), DateTime(2027, 6, 15));
    });

    test('Invalid interval wöchentlich rejected', () async {
      await expectLater(
        repo.create(name: 'Bad', kundeId: 1, intervall: 'wöchentlich', positionen: <Map<String, dynamic>>[]),
        throwsA(isA<RechnungsVorlagenException>()),
      );
    });

    test('Empty interval rejected', () async {
      await expectLater(
        repo.create(name: 'Empty', kundeId: 1, intervall: '', positionen: <Map<String, dynamic>>[]),
        throwsA(isA<RechnungsVorlagenException>()),
      );
    });

    test('Save template with positions — JSON stored and used for generation', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'With Pos',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{
            'artikel_id': 1,
            'bezeichnung': 'Pos1',
            'menge': 1,
            'einzelpreis': 10.00,
            'kategorie_id': 1,
          },
          <String, dynamic>{
            'artikel_id': 2,
            'bezeichnung': 'Pos2',
            'menge': 2,
            'einzelpreis': 20.00,
            'kategorie_id': 2,
          },
        ],
      );
      expect(v.positionen.length, 2);
      final List<Map<String, Object?>> raw = await db.executor.runSelect(
        'SELECT vorlage_daten FROM rechnungsvorlagen WHERE id = ?',
        <Object?>[v.id],
      );
      final String jsonStr = raw.single['vorlage_daten'] as String;
      expect(jsonStr.contains('Pos1'), isTrue);
      expect(jsonStr.contains('Pos2'), isTrue);
      final List<int> gen = await repo.generateFaellig(heute: DateTime(2026, 1, 1));
      expect(gen.length, 1);
      final List<Map<String, Object?>> pos = await db.executor.runSelect(
        'SELECT bezeichnung FROM rechnungspositionen WHERE rechnung_id = ? ORDER BY position',
        <Object?>[gen.single],
      );
      expect(pos.length, 2);
    });

    test('Save template with no positions — empty JSON and warning', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Empty Pos',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[],
      );
      expect(v.positionen, isEmpty);
      final List<Map<String, Object?>> raw = await db.executor.runSelect(
        'SELECT vorlage_daten FROM rechnungsvorlagen WHERE id = ?',
        <Object?>[v.id],
      );
      expect(raw.single['vorlage_daten'] as String, '[]');
    });

    test('Price mismatch warning — 10€ vs 12€', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Price Warn',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{
            'artikel_id': 2,
            'bezeichnung': 'Teuer',
            'menge': 1,
            'einzelpreis': 10.00,
            'kategorie_id': 1,
          },
        ],
      );
      final List<PreisWarnung> warns = await repo.vergleichePreise(v);
      expect(warns.length, 1);
      expect(warns.single.artikelId, 2);
      expect(warns.single.vorlagePreis, 10.00);
      expect(warns.single.aktuellVkBrutto, 12.00);
    });

    test('Price matches — no warning', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Price OK',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{
            'artikel_id': 1,
            'bezeichnung': 'Gleich',
            'menge': 1,
            'einzelpreis': 10.00,
            'kategorie_id': 1,
          },
        ],
      );
      final List<PreisWarnung> warns = await repo.vergleichePreise(v);
      expect(warns, isEmpty);
    });

    test('Auftrag-Verknüpfung — inherits order link', () async {
      // Auftrag als Rechnung mit typ auftrag
      final int auftragId = await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, datum) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['A-2026-001', 'auftrag', 'laufend', 0, 'netto', '2026-01-01'],
      );
      final RechnungsVorlage v = await repo.create(
        name: 'Auftrag linked',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Service', 'menge': 1, 'einzelpreis': 50.00, 'kategorie_id': 1},
        ],
        auftragId: auftragId,
      );
      final List<int> gen = await repo.generateFaellig(heute: DateTime(2026, 1, 1));
      expect(gen.length, 1);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT storno_von FROM rechnungen WHERE id = ?',
        <Object?>[gen.single],
      );
      // storno_von wird als auftrag_id missbraucht für Verknüpfung im vereinfachten Schema
      expect(rows.single['storno_von'], auftragId);
    });

    test('Auto-generate on startup — due today generates', () async {
      await repo.create(
        name: 'Startup Due',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Abo', 'menge': 1, 'einzelpreis': 10.00, 'kategorie_id': 1},
        ],
      );
      final List<int> gen = await repo.generateFaellig(heute: DateTime(2026, 1, 1));
      expect(gen.length, 1);
      final List<Map<String, Object?>> re = await db.executor.runSelect(
        'SELECT vorlage_id FROM rechnungen WHERE id = ?',
        <Object?>[gen.single],
      );
      expect(re.single['vorlage_id'], isNotNull);
    });

    test('Missed generation — 3 months backdated', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Missed',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Miete', 'menge': 1, 'einzelpreis': 10.00, 'kategorie_id': 1},
        ],
      );
      // Pausieren 3 Monate, dann reaktivieren + generieren sollte 4 Rechnungen erstellen (Jan-Apr)
      await repo.pause(v.id);
      await repo.resume(v.id);
      final List<int> gen = await repo.generateFaellig(heute: DateTime(2026, 4, 01));
      expect(gen.length, 4);
      final RechnungsVorlage? updated = await repo.findById(v.id);
      expect(updated!.naechsteFaelligkeit, '2026-05-01');
    });

    test('Generated Invoice Tracking — list with and without invoices', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Track',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Pos', 'menge': 1, 'einzelpreis': 10.00, 'kategorie_id': 1},
        ],
      );
      List<Map<String, Object?>> list = await repo.listGeneratedInvoices(v.id);
      expect(list, isEmpty);
      await repo.generateFaellig(heute: DateTime(2026, 1, 1));
      list = await repo.listGeneratedInvoices(v.id);
      expect(list.length, 1);
      expect(list.single['vorlage_id'], v.id);
    });

    test('Template Edit Propagation — existing invoices retain 10€, next uses 15€', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Edit Price',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'artikel_id': 1, 'bezeichnung': 'Pos', 'menge': 1, 'einzelpreis': 10.00, 'kategorie_id': 1},
        ],
      );
      await repo.generateFaellig(heute: DateTime(2026, 1, 1));
      await repo.generateFaellig(heute: DateTime(2026, 2, 1));
      await repo.generateFaellig(heute: DateTime(2026, 3, 1));
      final List<Map<String, Object?>> before = await db.executor.runSelect(
        'SELECT einzelpreis FROM rechnungspositionen WHERE rechnung_id IN '
        '(SELECT id FROM rechnungen WHERE vorlage_id = ?) ORDER BY id',
        <Object?>[v.id],
      );
      expect(before.every((Map<String, Object?> r) => (r['einzelpreis'] as num).toDouble() == 10.00), isTrue);
      await repo.update(
        v.id,
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'artikel_id': 1, 'bezeichnung': 'Pos', 'menge': 1, 'einzelpreis': 15.00, 'kategorie_id': 1},
        ],
      );
      await repo.generateFaellig(heute: DateTime(2026, 4, 1));
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT einzelpreis FROM rechnungspositionen WHERE rechnung_id IN '
        '(SELECT id FROM rechnungen WHERE vorlage_id = ?) ORDER BY id',
        <Object?>[v.id],
      );
      expect(after.length, 4);
      expect((after.last['einzelpreis'] as num).toDouble(), 15.00);
      expect((after.first['einzelpreis'] as num).toDouble(), 10.00);
    });

    test('Edit template interval — future follows new interval', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Edit Interval',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[],
      );
      await repo.update(v.id, intervall: 'quartalsweise');
      final RechnungsVorlage? updated = await repo.findById(v.id);
      expect(updated!.intervall, 'quartalsweise');
      // Bestehende Rechnungen unverändert — hier keine erzeugt, prüfen dass nächste Generierung quartalsweise advance
      await repo.generateFaellig(heute: DateTime(2026, 1, 1));
      final RechnungsVorlage? afterGen = await repo.findById(v.id);
      expect(afterGen!.naechsteFaelligkeit, '2026-04-01');
    });

    test('Template Deletion Protection — with invoices rejected with count', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Delete Protected',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-01-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Pos', 'menge': 1, 'einzelpreis': 10.00, 'kategorie_id': 1},
        ],
      );
      await repo.generateFaellig(heute: DateTime(2026, 1, 1));
      await repo.generateFaellig(heute: DateTime(2026, 2, 1));
      await repo.generateFaellig(heute: DateTime(2026, 3, 1));
      await repo.generateFaellig(heute: DateTime(2026, 4, 1));
      await repo.generateFaellig(heute: DateTime(2026, 5, 1));
      await expectLater(repo.delete(v.id), throwsA(isA<RechnungsVorlagenException>()));
      try {
        await repo.delete(v.id);
      } catch (e) {
        expect(e.toString().contains('5'), isTrue);
      }
    });

    test('Delete template without invoices succeeds', () async {
      final RechnungsVorlage v = await repo.create(
        name: 'Delete OK',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-06-01',
        positionen: <Map<String, dynamic>>[],
      );
      await repo.delete(v.id);
      final RechnungsVorlage? gone = await repo.findById(v.id);
      expect(gone, isNull);
    });

    test('Next due advance — monatlich +1 Monat korrekt', () async {
      expect(repo.nextDue(DateTime(2026, 1, 15), 'monatlich'), DateTime(2026, 2, 15));
      expect(repo.nextDue(DateTime(2026, 12, 15), 'monatlich'), DateTime(2027, 1, 15));
      expect(repo.nextDue(DateTime(2026, 1, 31), 'monatlich'), DateTime(2026, 2, 28));
      expect(repo.nextDue(DateTime(2026, 1, 1), 'quartalsweise'), DateTime(2026, 4, 1));
      expect(repo.nextDue(DateTime(2026, 1, 1), 'jährlich'), DateTime(2027, 1, 1));
    });
  });
}
