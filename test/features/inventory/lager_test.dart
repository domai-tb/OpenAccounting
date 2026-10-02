import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

void main() {
  group('Lagerführung', () {
    late AppDatabase db;
    late RechnungenDataSource rechnungen;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      rechnungen = RechnungenDataSource(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> createArtikel({
      required String bezeichnung,
      bool lagerAktiv = true,
      num bestandAktuell = 0,
      num mindestbestand = 0,
      bool minusErlaubt = false,
    }) async {
      final art = await db.artikelRepository.create(
        bezeichnung: bezeichnung,
        vkBrutto: 11.9,
        lagerAktiv: lagerAktiv,
        bestandAktuell: bestandAktuell,
        mindestbestand: mindestbestand,
        minusbestandErlaubt: minusErlaubt,
      );
      return art.id;
    }

    Future<num> bestandOf(int id) async {
      final a = await db.artikelRepository.findById(id);
      return a!.bestandAktuell;
    }

    Future<void> ensureInventar() async {
      await db.executor.runCustom('''
CREATE TABLE IF NOT EXISTS inventarbewegungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artikel_id INTEGER NOT NULL REFERENCES artikel(id),
  datum TEXT NOT NULL,
  diff NUMERIC(10,3) NOT NULL,
  grund TEXT NOT NULL,
  referenz_typ TEXT,
  referenz_id INTEGER
)''');
    }

    Future<List<Map<String, Object?>>> bewegungen(int artikelId) async {
      await ensureInventar();
      return db.executor.runSelect('SELECT * FROM inventarbewegungen WHERE artikel_id = ? ORDER BY id', <Object?>[
        artikelId,
      ]);
    }

    Future<List<Map<String, Object?>>> warnungen() async {
      return db.executor.runSelect(
        'SELECT id, bezeichnung, bestand_aktuell, mindestbestand FROM artikel '
        'WHERE lager_aktiv = 1 AND bestand_aktuell <= mindestbestand ORDER BY id',
        const <Object?>[],
      );
    }

    test('Artikel mit lager_aktiv=false wird nicht abgebucht', () async {
      final id = await createArtikel(bezeichnung: 'Ohne Lager', lagerAktiv: false, bestandAktuell: 50);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Ohne Lager', menge: 3, einzelpreis: 10, gesamt: 30, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      expect(await bestandOf(id), 50);
    });

    test('Bestand wird bei Finalisierung dekrementiert', () async {
      final id = await createArtikel(bezeichnung: 'Mit Lager', bestandAktuell: 50, mindestbestand: 10);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Mit Lager', menge: 3, einzelpreis: 10, gesamt: 30, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      expect(await bestandOf(id), 47);
    });

    test('Minusbestand blockiert wenn nicht erlaubt', () async {
      final id = await createArtikel(bezeichnung: 'Knapp', bestandAktuell: 2);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Knapp', menge: 5, einzelpreis: 10, gesamt: 50, artikelId: id),
        ],
      );
      await expectLater(
        rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId),
        throwsA(isA<StateError>()),
      );
      expect(await bestandOf(id), 2);
      final rows = await bewegungen(id);
      expect(rows, isEmpty);
    });

    test('Minusbestand erlaubt führt zu negativem Bestand', () async {
      final id = await createArtikel(bezeichnung: 'Negativ OK', bestandAktuell: 2, minusErlaubt: true);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Negativ OK', menge: 5, einzelpreis: 10, gesamt: 50, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      expect(await bestandOf(id), -3);
    });

    test('Fraktionierte Mengen werden korrekt gebucht', () async {
      final id = await createArtikel(bezeichnung: 'Kg Ware', bestandAktuell: 10.5);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Kg Ware', menge: 2.5, einzelpreis: 10, gesamt: 25, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      final bestand = await bestandOf(id);
      expect(bestand.toDouble(), closeTo(8.0, 0.001));
    });

    test('Mehrere Positionen selektiv — nur lager_aktiv wird gebucht', () async {
      final a = await createArtikel(bezeichnung: 'A Lager', bestandAktuell: 20);
      final b = await createArtikel(bezeichnung: 'B Ohne', lagerAktiv: false, bestandAktuell: 20);
      final c = await createArtikel(bezeichnung: 'C Lager', bestandAktuell: 20);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A Lager', menge: 10, einzelpreis: 10, gesamt: 100, artikelId: a),
          RechnungPositionItem(bezeichnung: 'B Ohne', menge: 5, einzelpreis: 10, gesamt: 50, artikelId: b),
          RechnungPositionItem(bezeichnung: 'C Lager', menge: 3, einzelpreis: 10, gesamt: 30, artikelId: c),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      expect(await bestandOf(a), 10);
      expect(await bestandOf(b), 20);
      expect(await bestandOf(c), 17);
    });

    test('Atomar: bei Minusbestand-Fehler wird kein Artikel gebucht', () async {
      final a = await createArtikel(bezeichnung: 'A OK', bestandAktuell: 100);
      final b = await createArtikel(bezeichnung: 'B Knapp', bestandAktuell: 2);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A OK', menge: 10, einzelpreis: 10, gesamt: 100, artikelId: a),
          RechnungPositionItem(bezeichnung: 'B Knapp', menge: 5, einzelpreis: 10, gesamt: 50, artikelId: b),
        ],
      );
      await expectLater(
        rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId),
        throwsA(isA<StateError>()),
      );
      expect(await bestandOf(a), 100);
      expect(await bestandOf(b), 2);
    });

    test('test_repeated_article_quantities_are_combined', () async {
      final id = await createArtikel(bezeichnung: 'Repeated quantity', bestandAktuell: 20);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Repeated quantity', menge: 3, einzelpreis: 10, gesamt: 30, artikelId: id),
          RechnungPositionItem(bezeichnung: 'Repeated quantity', menge: 4, einzelpreis: 10, gesamt: 40, artikelId: id),
        ],
      );

      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);

      expect(await bestandOf(id), 13);
      final rows = await bewegungen(id);
      expect(rows, hasLength(1));
      expect(num.parse(rows.single['diff'].toString()), -7);
    });

    test('test_repeated_quantities_fail_atomically', () async {
      final id = await createArtikel(bezeichnung: 'Repeated exceeds stock', bestandAktuell: 5);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(
            bezeichnung: 'Repeated exceeds stock',
            menge: 3,
            einzelpreis: 10,
            gesamt: 30,
            artikelId: id,
          ),
          RechnungPositionItem(
            bezeichnung: 'Repeated exceeds stock',
            menge: 3,
            einzelpreis: 10,
            gesamt: 30,
            artikelId: id,
          ),
        ],
      );

      await expectLater(
        rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId),
        throwsA(isA<StateError>()),
      );

      expect(await bestandOf(id), 5);
      expect(await bewegungen(id), isEmpty);
    });

    test('test_legacy_stock_is_migrated_on_first_outgoing_movement', () async {
      final id = await createArtikel(bezeichnung: 'Legacy stock', lagerAktiv: false);
      await db.executor.runUpdate('UPDATE artikel SET bestand = 20 WHERE id = ?', <Object?>[id]);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Legacy stock', menge: 3, einzelpreis: 10, gesamt: 30, artikelId: id),
        ],
      );

      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);

      final article = (await db.executor.runSelect(
        'SELECT lager_aktiv, bestand, bestand_aktuell FROM artikel WHERE id = ?',
        <Object?>[id],
      )).single;
      expect(article['lager_aktiv'], 1);
      expect(num.parse(article['bestand'].toString()), 17);
      expect(num.parse(article['bestand_aktuell'].toString()), 17);
      final rows = await bewegungen(id);
      expect(rows, hasLength(1));
      expect(num.parse(rows.single['diff'].toString()), -3);
    });

    test('test_disabled_stock_is_not_misclassified_as_legacy', () async {
      final id = await createArtikel(bezeichnung: 'Disabled zero stock', lagerAktiv: false);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(
            bezeichnung: 'Disabled zero stock',
            menge: 5,
            einzelpreis: 10,
            gesamt: 50,
            artikelId: id,
          ),
        ],
      );

      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);

      final article = (await db.executor.runSelect(
        'SELECT lager_aktiv, bestand, bestand_aktuell FROM artikel WHERE id = ?',
        <Object?>[id],
      )).single;
      expect(article['lager_aktiv'], 0);
      expect(num.parse(article['bestand'].toString()), 0);
      expect(num.parse(article['bestand_aktuell'].toString()), 0);
      expect(await bewegungen(id), isEmpty);
    });

    test('Storno stellt Bestand wieder her', () async {
      final id = await createArtikel(bezeichnung: 'Storno A', bestandAktuell: 50);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Storno A', menge: 10, einzelpreis: 10, gesamt: 100, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      expect(await bestandOf(id), 40);
      await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Korrektur');
      expect(await bestandOf(id), 50);
    });

    test('Storno addiert volle Menge trotz manueller Anpassung', () async {
      final id = await createArtikel(bezeichnung: 'Manuell', bestandAktuell: 50);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Manuell', menge: 10, einzelpreis: 10, gesamt: 100, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      // manuelle Reduktion auf 20
      await db.executor.runUpdate('UPDATE artikel SET bestand_aktuell = ?, bestand = ? WHERE id = ?', <Object?>[
        20,
        20,
        id,
      ]);
      await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Storno trotz Anpassung');
      expect(await bestandOf(id), 30);
    });

    test('test_storno_without_source_movement_does_not_add_stock', () async {
      final id = await createArtikel(bezeichnung: 'Incoming item', bestandAktuell: 20);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        typ: 'rechnung_eingang',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Incoming item', menge: 5, einzelpreis: 10, gesamt: 50, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      expect(await bestandOf(id), 20);
      expect(await bewegungen(id), isEmpty);

      final stornoId = await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'No source movement');

      expect(await bestandOf(id), 20);
      expect(
        await db.executor.runSelect(
          "SELECT id FROM inventarbewegungen WHERE artikel_id = ? AND referenz_typ = 'storno' AND referenz_id = ?",
          <Object?>[id, stornoId],
        ),
        isEmpty,
      );
    });

    test('test_storno_filters_and_aggregates_source_movements', () async {
      final id = await createArtikel(bezeichnung: 'Ledger quantities', bestandAktuell: 20);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Ledger quantities', menge: 1, einzelpreis: 10, gesamt: 10, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      await db.executor.runCustom(
        "DELETE FROM inventarbewegungen WHERE referenz_typ = 'rechnung' AND referenz_id = $rechnungId",
      );
      for (final movement in <({num diff, String referenceType, int referenceId})>[
        (diff: -2, referenceType: 'rechnung', referenceId: rechnungId),
        (diff: -3.5, referenceType: 'rechnung', referenceId: rechnungId),
        (diff: 7, referenceType: 'rechnung', referenceId: rechnungId),
        (diff: -4, referenceType: 'rechnung', referenceId: rechnungId + 1),
        (diff: -9, referenceType: 'storno', referenceId: rechnungId),
      ]) {
        await db.executor.runInsert(
          'INSERT INTO inventarbewegungen (artikel_id, datum, diff, grund, referenz_typ, referenz_id) VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[id, '2026-03-01', movement.diff, 'Seed movement', movement.referenceType, movement.referenceId],
        );
      }

      final stornoId = await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Restore ledger total');

      expect(await bestandOf(id), 24.5);
      final restorations = await db.executor.runSelect(
        "SELECT diff FROM inventarbewegungen WHERE artikel_id = ? AND referenz_typ = 'storno' AND referenz_id = ?",
        <Object?>[id, stornoId],
      );
      expect(restorations, hasLength(1));
      expect(num.parse(restorations.single['diff'].toString()), 5.5);
    });

    test('test_storno_promotes_legacy_and_skips_disabled_stock', () async {
      final legacyId = await createArtikel(bezeichnung: 'Legacy at storno', lagerAktiv: false);
      final disabledId = await createArtikel(bezeichnung: 'Disabled at storno', lagerAktiv: false);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(
            bezeichnung: 'Legacy at storno',
            menge: 3,
            einzelpreis: 10,
            gesamt: 30,
            artikelId: legacyId,
          ),
          RechnungPositionItem(
            bezeichnung: 'Disabled at storno',
            menge: 4,
            einzelpreis: 10,
            gesamt: 40,
            artikelId: disabledId,
          ),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      await db.executor.runUpdate('UPDATE artikel SET bestand = 17 WHERE id = ?', <Object?>[legacyId]);
      await db.executor.runInsert(
        'INSERT INTO inventarbewegungen (artikel_id, datum, diff, grund, referenz_typ, referenz_id) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[legacyId, '2026-03-01', -3, 'Legacy source movement', 'rechnung', rechnungId],
      );
      await db.executor.runInsert(
        'INSERT INTO inventarbewegungen (artikel_id, datum, diff, grund, referenz_typ, referenz_id) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[disabledId, '2026-03-01', -4, 'Historical disabled movement', 'rechnung', rechnungId],
      );

      final stornoId = await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Legacy and disabled');

      final legacy = (await db.executor.runSelect(
        'SELECT lager_aktiv, bestand, bestand_aktuell FROM artikel WHERE id = ?',
        <Object?>[legacyId],
      )).single;
      final disabled = (await db.executor.runSelect(
        'SELECT lager_aktiv, bestand, bestand_aktuell FROM artikel WHERE id = ?',
        <Object?>[disabledId],
      )).single;
      expect(legacy['lager_aktiv'], 1);
      expect(num.parse(legacy['bestand'].toString()), 20);
      expect(num.parse(legacy['bestand_aktuell'].toString()), 20);
      expect(disabled['lager_aktiv'], 0);
      expect(num.parse(disabled['bestand'].toString()), 0);
      expect(num.parse(disabled['bestand_aktuell'].toString()), 0);
      expect(
        await db.executor.runSelect(
          "SELECT id FROM inventarbewegungen WHERE artikel_id = ? AND referenz_typ = 'storno' AND referenz_id = ?",
          <Object?>[disabledId, stornoId],
        ),
        isEmpty,
      );
    });

    test('test_storno_failure_rolls_back_and_retry_restores_once', () async {
      final id = await createArtikel(bezeichnung: 'Storno rollback', bestandAktuell: 20);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Storno rollback', menge: 3, einzelpreis: 10, gesamt: 30, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      final rangeBefore = (await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'stornorechnung'",
        const <Object?>[],
      )).single['naechste_nummer'];

      await expectLater(
        rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Injected rollback', debugFailAt: 'movement'),
        throwsA(isA<StateError>()),
      );

      final source = (await db.executor.runSelect('SELECT status, storno_datum FROM rechnungen WHERE id = ?', <Object?>[
        rechnungId,
      ])).single;
      expect(source['status'], 'offen');
      expect(source['storno_datum'], isNull);
      expect(await bestandOf(id), 17);
      expect(
        await db.executor.runSelect('SELECT id FROM rechnungen WHERE storno_von = ?', <Object?>[rechnungId]),
        isEmpty,
      );
      expect(
        await db.executor.runSelect("SELECT id FROM inventarbewegungen WHERE referenz_typ = 'storno'", const []),
        isEmpty,
      );
      expect(
        (await db.executor.runSelect(
          "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'stornorechnung'",
          const <Object?>[],
        )).single['naechste_nummer'],
        rangeBefore,
      );

      final stornoId = await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Successful retry');
      expect(await bestandOf(id), 20);
      expect(
        await db.executor.runSelect(
          "SELECT id FROM inventarbewegungen WHERE referenz_typ = 'storno' AND referenz_id = ?",
          <Object?>[stornoId],
        ),
        hasLength(1),
      );
    });

    test('test_repeated_legacy_quantity_roundtrip_matches_movements', () async {
      final id = await createArtikel(bezeichnung: 'Legacy repeated', lagerAktiv: false);
      await db.executor.runUpdate('UPDATE artikel SET bestand = 20 WHERE id = ?', <Object?>[id]);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Legacy repeated', menge: 3, einzelpreis: 10, gesamt: 30, artikelId: id),
          RechnungPositionItem(bezeichnung: 'Legacy repeated', menge: 4, einzelpreis: 10, gesamt: 40, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      expect(await bestandOf(id), 13);
      final invoiceMovements = await bewegungen(id);
      expect(invoiceMovements, hasLength(1));
      expect(num.parse(invoiceMovements.single['diff'].toString()), -7);

      final stornoId = await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Legacy roundtrip');

      final article = (await db.executor.runSelect(
        'SELECT lager_aktiv, bestand, bestand_aktuell FROM artikel WHERE id = ?',
        <Object?>[id],
      )).single;
      expect(article['lager_aktiv'], 1);
      expect(num.parse(article['bestand'].toString()), 20);
      expect(num.parse(article['bestand_aktuell'].toString()), 20);
      final restorations = await db.executor.runSelect(
        "SELECT diff FROM inventarbewegungen WHERE artikel_id = ? AND referenz_typ = 'storno' AND referenz_id = ?",
        <Object?>[id, stornoId],
      );
      expect(restorations, hasLength(1));
      expect(num.parse(restorations.single['diff'].toString()), 7);
    });

    test('Storno bei Nicht-Lager Artikel ändert nichts', () async {
      final a = await createArtikel(bezeichnung: 'Lager', bestandAktuell: 50);
      final b = await createArtikel(bezeichnung: 'Kein Lager', lagerAktiv: false, bestandAktuell: 50);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Lager', menge: 10, einzelpreis: 10, gesamt: 100, artikelId: a),
          RechnungPositionItem(bezeichnung: 'Kein Lager', menge: 5, einzelpreis: 10, gesamt: 50, artikelId: b),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      expect(await bestandOf(a), 40);
      expect(await bestandOf(b), 50);
      await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Gemischt stornieren');
      expect(await bestandOf(a), 50);
      expect(await bestandOf(b), 50);
    });

    test('Mindestbestand-Warnung: bestand <= mindestbestand', () async {
      await createArtikel(bezeichnung: 'Warn X', bestandAktuell: 3, mindestbestand: 10);
      await createArtikel(bezeichnung: 'OK Y', bestandAktuell: 20, mindestbestand: 10);
      await createArtikel(bezeichnung: 'Gleich', bestandAktuell: 10, mindestbestand: 10);
      final rows = await warnungen();
      final namen = rows.map((r) => r['bezeichnung']?.toString() ?? '').toList();
      expect(namen, contains('Warn X'));
      expect(namen, contains('Gleich'));
      expect(namen, isNot(contains('OK Y')));
    });

    test('Keine Warnungen wenn alle über Mindestbestand', () async {
      await createArtikel(bezeichnung: 'Gut A', bestandAktuell: 20, mindestbestand: 10);
      await createArtikel(bezeichnung: 'Gut B', bestandAktuell: 11, mindestbestand: 10);
      final rows = await warnungen();
      expect(rows, isEmpty);
    });

    test('Manuelle Bestandsanpassung wird geloggt', () async {
      final id = await createArtikel(bezeichnung: 'LogTest', bestandAktuell: 15);
      await ensureInventar();
      // absolute Setzung via Repository-Helper simuliert durch inventarbewegungen
      final before = await bestandOf(id);
      expect(before, 15);
      // simuliere manuelle Korrektur: setze auf 100
      await db.executor.runUpdate('UPDATE artikel SET bestand_aktuell = ?, bestand = ? WHERE id = ?', <Object?>[
        100,
        100,
        id,
      ]);
      await db.executor.runInsert(
        'INSERT INTO inventarbewegungen (artikel_id, datum, diff, grund) VALUES (?, ?, ?, ?)',
        <Object?>[id, '2026-03-02', 85, 'Manuelle Korrektur'],
      );
      expect(await bestandOf(id), 100);
      final rows = await bewegungen(id);
      expect(rows.length, 1);
      expect(rows.single['diff'].toString(), contains('85'));
      expect(rows.single['grund'], 'Manuelle Korrektur');
    });

    test('Inventarbewegungen werden bei Finalisierung geschrieben', () async {
      final id = await createArtikel(bezeichnung: 'Bewegung', bestandAktuell: 20);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Bewegung', menge: 4, einzelpreis: 10, gesamt: 40, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      final rows = await bewegungen(id);
      expect(rows.length, 1);
      final diff = num.tryParse(rows.single['diff'].toString()) ?? 0;
      expect(diff, -4);
      expect(rows.single['referenz_typ'], 'rechnung');
      expect(rows.single['referenz_id'].toString(), '$rechnungId');
    });

    test('Inventarbewegungen bei Storno positiv', () async {
      final id = await createArtikel(bezeichnung: 'Storno Bewegung', bestandAktuell: 20);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Storno Bewegung', menge: 4, einzelpreis: 10, gesamt: 40, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Test Storno');
      final rows = await bewegungen(id);
      expect(rows.length, 2);
      final diffs = rows.map((r) => num.tryParse(r['diff'].toString()) ?? 0).toList();
      expect(diffs, contains(-4));
      expect(diffs, contains(4));
      final stornoRow = rows.firstWhere((r) => (num.tryParse(r['diff'].toString()) ?? 0) > 0);
      expect(stornoRow['referenz_typ'], 'storno');
    });

    test('inventarbewegungen Tabelle existiert mit Pflichtspalten', () async {
      await ensureInventar();
      final cols = await db.executor.runSelect('PRAGMA table_info(inventarbewegungen)', const <Object?>[]);
      final names = cols.map((c) => c['name']?.toString() ?? '').toList();
      expect(names, contains('id'));
      expect(names, contains('artikel_id'));
      expect(names, contains('datum'));
      expect(names, contains('diff'));
      expect(names, contains('grund'));
      expect(names, contains('referenz_typ'));
      expect(names, contains('referenz_id'));
    });

    test('AdjustBestand adds to the current value and rejects non-finite quantities', () async {
      final id = await createArtikel(bezeichnung: 'Atomic adjustment', bestandAktuell: 10);

      await db.artikelRepository.adjustBestand(id, 2.555);

      expect(await bestandOf(id), 12.555);
      await expectLater(
        db.artikelRepository.adjustBestand(id, double.infinity),
        throwsA(isA<Exception>().having((Exception e) => e.toString(), 'message', contains('finite'))),
      );
      expect(await bestandOf(id), 12.555);
    });
  });
}
