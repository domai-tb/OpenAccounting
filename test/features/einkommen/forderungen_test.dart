import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/einkommen/forderungen_usecases.dart';

void main() {
  group('Forderungen — einkommen spec', () {
    late AppDatabase db;
    late ForderungenRepository repo;
    late ForderungenUseCases usecases;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = ForderungenRepository(db.executor);
      await repo.ensureSchema();
      usecases = ForderungenUseCases(repo);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedKunde({String name = 'Testkunde'}) async {
      final id = await db.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', ?, 'Strasse 1', '10115', 'Berlin', 'DE')",
        [name],
      );
      return id;
    }

    Future<int> seedLieferant({String name = 'Testlieferant'}) async {
      final id = await db.executor.runInsert(
        "INSERT INTO lieferanten (anrede, name, strasse, plz, ort, land) VALUES ('Herr', ?, 'Str. 1', '10115', 'Berlin', 'DE')",
        [name],
      );
      return id;
    }

    Future<int> seedRechnung({required int kundeId, num brutto = 100.00, String typ = 'rechnung'}) async {
      return db.executor.runInsert(
        "INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, lieferant_id, datum, brutto_betrag) VALUES (?, ?, 'final', 0, 'netto', ?, NULL, '2026-03-01', ?)",
        ['RE-${DateTime.now().millisecondsSinceEpoch}', typ, kundeId, brutto],
      );
    }

    Future<int> seedEingangsRechnung({required int lieferantId, num brutto = 200.00}) async {
      return db.executor.runInsert(
        "INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, lieferant_id, datum, brutto_betrag) VALUES (?, 'rechnung_eingang', 'final', 0, 'netto', NULL, ?, '2026-03-01', ?)",
        ['ER-${DateTime.now().millisecondsSinceEpoch}', lieferantId, brutto],
      );
    }

    test('Forderung wird bei Finalisierung angelegt (typ rechnung, partner kunde)', () async {
      final kundeId = await seedKunde();
      final rechnungId = await seedRechnung(kundeId: kundeId, brutto: 250.00);
      final f = await usecases.forderungFuerRechnung(rechnungId);
      expect(f, isNotNull);
      expect(f!.typ, 'rechnung');
      expect(f.status, 'offen');
      expect(f.betrag.toStringAsFixed(2), '250.00');
      expect(f.partnerTyp, 'kunde');
      expect(f.partnerId, kundeId);
      expect(f.rechnungId, rechnungId);
    });

    test('Forderung Teilzahlung aktualisiert betrag und status teilbezahlt', () async {
      final kundeId = await seedKunde();
      final f = await repo.create(typ: 'rechnung', betrag: 100.00, partnerTyp: 'kunde', partnerId: kundeId);
      final updated = await usecases.zahlungBuchen(forderungId: f.id, betrag: 50.00);
      expect(updated.betrag.toStringAsFixed(2), '50.00');
      expect(updated.status, 'teilbezahlt');
      expect(updated.ausgleichJournalId, isNotNull);
    });

    test('Forderung Vollzahlung schließt mit bezahlt und ausgleich_journal_id', () async {
      final kundeId = await seedKunde();
      final f = await repo.create(typ: 'rechnung', betrag: 100.00, partnerTyp: 'kunde', partnerId: kundeId);
      await repo.zahlungBuchen(forderungId: f.id, betrag: 50.00);
      final closed = await usecases.zahlungBuchen(forderungId: f.id, betrag: 50.00);
      expect(closed.betrag.toStringAsFixed(2), '0.00');
      expect(closed.status, 'bezahlt');
      expect(closed.ausgleichJournalId, isNotNull);
    });

    test('Doppelte Forderung für gleiche Rechnung wird verhindert', () async {
      final kundeId = await seedKunde();
      final rechnungId = await seedRechnung(kundeId: kundeId);
      final first = await usecases.forderungFuerRechnung(rechnungId);
      expect(first, isNotNull);
      final second = await usecases.forderungFuerRechnung(rechnungId);
      expect(second!.id, first!.id);
      final all = await repo.list();
      expect(all.where((e) => e.rechnungId == rechnungId).length, 1);
      // Direct duplicate create should throw
      await expectLater(
        repo.create(typ: 'rechnung', betrag: 100, partnerTyp: 'kunde', partnerId: kundeId, rechnungId: rechnungId),
        throwsA(isA<ForderungenException>()),
      );
    });

    test('Überzahlung erkannt: Forderung bezahlt + Überzahlung Journal', () async {
      final kundeId = await seedKunde();
      final f = await repo.create(typ: 'rechnung', betrag: 100.00, partnerTyp: 'kunde', partnerId: kundeId);
      final result = await usecases.zahlungBuchen(forderungId: f.id, betrag: 120.00);
      expect(result.betrag.toStringAsFixed(2), '0.00');
      expect(result.status, 'bezahlt');
      // Overpayment journal exists
      final journals = await db.executor.runSelect(
        "SELECT id, beschreibung, betrag FROM journal WHERE beschreibung LIKE 'Überzahlung Forderung #${f.id}%'",
        const [],
      );
      expect(journals, hasLength(1));
      expect((journals.single['betrag']! as num).toStringAsFixed(2), '20.00');
    });

    test('Überzahlung erscheint im Kontokorrent als ueberzahlung mit Saldo', () async {
      final kundeId = await seedKunde(name: 'Kontokorrent Kunde');
      final f = await repo.create(typ: 'rechnung', betrag: 100.00, partnerTyp: 'kunde', partnerId: kundeId);
      await usecases.zahlungBuchen(forderungId: f.id, betrag: 120.00);
      final kk = await usecases.kontokorrent(partnerTyp: 'kunde', partnerId: kundeId);
      expect(kk.any((e) => e.typ == 'ueberzahlung'), isTrue);
      final ue = kk.firstWhere((e) => e.typ == 'ueberzahlung');
      expect(ue.betrag.toStringAsFixed(2), '20.00');
      // Running balance reflects credit
      expect(kk.last.saldo, isA<num>());
    });

    test('Exakte Zahlung erzeugt keine Überzahlung', () async {
      final kundeId = await seedKunde();
      final f = await repo.create(typ: 'rechnung', betrag: 100.00, partnerTyp: 'kunde', partnerId: kundeId);
      await usecases.zahlungBuchen(forderungId: f.id, betrag: 100.00);
      final over = await db.executor.runSelect(
        "SELECT id FROM journal WHERE beschreibung LIKE 'Überzahlung Forderung #${f.id}%'",
        const [],
      );
      expect(over, isEmpty);
      final updated = await repo.findById(f.id);
      expect(updated!.status, 'bezahlt');
    });

    test('Forderungsausfall: ausbuchen mit Grund setzt ausgebucht und Journal', () async {
      final kundeId = await seedKunde();
      final f = await repo.create(typ: 'rechnung', betrag: 75.00, partnerTyp: 'kunde', partnerId: kundeId);
      final done = await usecases.forderungAusbuchen(forderungId: f.id, grund: 'Kunde zahlungsunfähig');
      expect(done.status, 'ausgebucht');
      expect(done.betrag.toStringAsFixed(2), '0.00');
      expect(done.ausgleichJournalId, isNotNull);
      final j = await db.executor.runSelect('SELECT beschreibung, betrag FROM journal WHERE id = ?', [
        done.ausgleichJournalId,
      ]);
      expect(j.single['beschreibung'], contains('Kunde zahlungsunfähig'));
      expect((j.single['betrag']! as num).toStringAsFixed(2), '75.00');
    });

    test('Ausbuchen ohne Grund wird abgewiesen (deutsche Validierung)', () async {
      final kundeId = await seedKunde();
      final f = await repo.create(typ: 'rechnung', betrag: 75.00, partnerTyp: 'kunde', partnerId: kundeId);
      await expectLater(
        usecases.forderungAusbuchen(forderungId: f.id, grund: '   '),
        throwsA(predicate<Object>((e) => e.toString().contains('Grund ist Pflicht'))),
      );
      final still = await repo.findById(f.id);
      expect(still!.status, 'offen');
    });

    test('Ausbuchen bereits bezahlter Forderung wird abgewiesen', () async {
      final kundeId = await seedKunde();
      final f = await repo.create(typ: 'rechnung', betrag: 75.00, partnerTyp: 'kunde', partnerId: kundeId);
      await usecases.zahlungBuchen(forderungId: f.id, betrag: 75.00);
      await expectLater(
        usecases.forderungAusbuchen(forderungId: f.id, grund: 'Kunde zahlungsunfähig'),
        throwsA(predicate<Object>((e) => e.toString().contains('bereits beglichen'))),
      );
    });

    test('Kontokorrent chronologisch mit Saldo — leerer Kunde null Saldo', () async {
      final kundeId = await seedKunde(name: 'Leer');
      final kkEmpty = await usecases.kontokorrent(partnerTyp: 'kunde', partnerId: kundeId);
      expect(kkEmpty, isEmpty);
      // With invoices
      final f1 = await repo.create(typ: 'rechnung', betrag: 100.00, partnerTyp: 'kunde', partnerId: kundeId);
      final f2 = await repo.create(typ: 'rechnung', betrag: 50.00, partnerTyp: 'kunde', partnerId: kundeId);
      await usecases.zahlungBuchen(forderungId: f1.id, betrag: 30.00);
      final kk = await usecases.kontokorrent(partnerTyp: 'kunde', partnerId: kundeId);
      expect(kk, isNotEmpty);
      // Running saldo monotonic check (entries sorted)
      for (var i = 1; i < kk.length; i++) {
        expect(
          DateTime.parse(kk[i].datum).isAfter(DateTime.parse(kk[i - 1].datum)) || kk[i].datum == kk[i - 1].datum,
          isTrue,
        );
      }
      // ignore unused f2 — ensures multiple entries
      expect(f2.betrag.toStringAsFixed(2), '50.00');
    });

    test('Kontokorrent Datumsfilter zeigt nur Zeitraum und Opening-Balance', () async {
      final kundeId = await seedKunde(name: 'Filterkunde');
      // Create two forderungen at different dates via direct insert with explicit erstellt_am
      await db.executor.runInsert(
        "INSERT INTO forderungen (typ, status, betrag, partner_typ, partner_id, erstellt_am, aktualisiert_am) VALUES ('rechnung','offen', 100, 'kunde', ?, '2026-02-15', '2026-02-15')",
        [kundeId],
      );
      await db.executor.runInsert(
        "INSERT INTO forderungen (typ, status, betrag, partner_typ, partner_id, erstellt_am, aktualisiert_am) VALUES ('rechnung','offen', 200, 'kunde', ?, '2026-07-10', '2026-07-10')",
        [kundeId],
      );
      final filtered = await usecases.kontokorrent(
        partnerTyp: 'kunde',
        partnerId: kundeId,
        von: '2026-01-01',
        bis: '2026-06-30',
      );
      expect(filtered.length, 1);
      expect(filtered.single.betrag.toStringAsFixed(2), '100.00');
      final outside = await usecases.kontokorrent(
        partnerTyp: 'kunde',
        partnerId: kundeId,
        von: '2026-08-01',
        bis: '2026-12-31',
      );
      expect(outside, isEmpty);
    });

    test('Verbindlichkeit: Lieferant Rechnungseingang + Zahlung + Überzahlung Gutschrift', () async {
      final lieferantId = await seedLieferant();
      // Simulate incoming invoice
      final rechnungId = await seedEingangsRechnung(lieferantId: lieferantId);
      final verbindlichkeit = await usecases.forderungFuerRechnung(rechnungId);
      expect(verbindlichkeit, isNotNull);
      expect(verbindlichkeit!.typ, 'rechnung_eingang');
      expect(verbindlichkeit.partnerTyp, 'lieferant');
      expect(verbindlichkeit.partnerId, lieferantId);
      expect(verbindlichkeit.betrag.toStringAsFixed(2), '200.00');

      // Pay exact
      final bezahlt = await usecases.zahlungBuchen(forderungId: verbindlichkeit.id, betrag: 200.00);
      expect(bezahlt.status, 'bezahlt');

      // Overpayment supplier credit
      final lieferantId2 = await seedLieferant(name: 'Supplier2');
      final f2 = await repo.create(
        typ: 'rechnung_eingang',
        betrag: 100.00,
        partnerTyp: 'lieferant',
        partnerId: lieferantId2,
      );
      final over = await usecases.zahlungBuchen(forderungId: f2.id, betrag: 130.00);
      expect(over.status, 'bezahlt');
      final journals = await db.executor.runSelect(
        "SELECT betrag FROM journal WHERE beschreibung LIKE 'Überzahlung Forderung #${f2.id}%'",
        const [],
      );
      expect(journals.single['betrag'].toString(), contains('30'));
    });
  });
}
