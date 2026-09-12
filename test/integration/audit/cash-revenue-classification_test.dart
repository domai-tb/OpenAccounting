// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';

void main() {
  group('Cash & revenue classification — Plan B', () {
    late AppDatabase db;
    late EuerService euer;
    late ForderungenRepository forderungen;
    late SetupRepository setup;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      euer = EuerService(db.executor);
      forderungen = ForderungenRepository(db.executor);
      setup = SetupRepository(db.executor);
      await forderungen.ensureSchema();
    });

    tearDown(() async => db.close());

    Future<void> insertKategorie({required int id, required int zeile}) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv) VALUES (?, ?, ?, ?, ?, 1)',
        <Object?>[id, 'Kat $id', '800$id', '400$id', zeile],
      );
    }

    Future<void> insertJournal({
      required int kategorieId,
      required String betrag,
      required String datum,
      String belegTyp = BelegTyp.einnahme,
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>[datum, 'Test $kategorieId $belegTyp', kategorieId, betrag, belegTyp],
      );
    }

    test('test_cash_revenue_classification_1_1_euer_excludes_cash_categories', () async {
      await insertKategorie(id: 990, zeile: 12);
      await insertKategorie(id: 991, zeile: 60);
      await insertKategorie(id: 992, zeile: 15);

      // Genuine revenue/expense — must be counted.
      await insertJournal(kategorieId: 990, betrag: '1000.00', datum: '2025-02-15');
      await insertJournal(kategorieId: 991, betrag: '400.00', datum: '2025-03-10', belegTyp: BelegTyp.ausgabe);
      await insertJournal(kategorieId: 992, betrag: '200.00', datum: '2025-04-01');

      // Cash movements — must NOT be counted, same kategorie/zeile as revenue would pollute.
      await insertJournal(kategorieId: 990, betrag: '500.00', datum: '2025-02-16', belegTyp: BelegTyp.eroeffnung);
      await insertJournal(kategorieId: 990, betrag: '300.00', datum: '2025-02-17', belegTyp: BelegTyp.zahlung);
      await insertJournal(kategorieId: 990, betrag: '200.00', datum: '2025-02-18', belegTyp: BelegTyp.ueberzahlung);
      await insertJournal(kategorieId: 990, betrag: '100.00', datum: '2025-02-19', belegTyp: BelegTyp.ausbuchung);
      // Write-off masquerading as expense must not affect zeile 60.
      await insertJournal(kategorieId: 991, betrag: '250.00', datum: '2025-03-11', belegTyp: BelegTyp.ausbuchung);

      final result = await euer.generate(jahr: 2025);

      expect(
        result.zeile(12),
        '1000.00',
        reason: 'Eroeffnung/Zahlung/Ueberzahlung/Ausbuchung must not pollute Einnahme zeile 12',
      );
      expect(result.zeile(15), '200.00');
      expect(result.zeile(60), '400.00', reason: 'Ausbuchung must not pollute Ausgabe zeile 60');
      // Gewinn = Einnahmen(1200) - Ausgaben(400) = 800. Polluted would be 1200+1000 extra -650 =1150.
      expect(result.gewinn, '800.00');
    });

    test('test_cash_revenue_classification_1_2_forderungen_payments_use_typed_beleg_typ', () async {
      await insertKategorie(id: 993, zeile: 12);
      await db.executor.runInsert(
        'INSERT INTO kunden (id, name, strasse, plz, ort) VALUES (1, ?, ?, ?, ?)',
        const <Object?>['Test Kunde', 'Str', '12345', 'Ort'],
      );
      // Create receivable 100 via repo (requires rechnung for betrag? use create directly)
      final f = await forderungen.create(typ: 'rechnung', partnerTyp: 'kunde', partnerId: 1, betrag: 100.00);
      // Pay 60 partial — must create Zahl journal not Einnahme.
      await forderungen.zahlungBuchen(forderungId: f.id, betrag: 60.00, datum: '2025-05-10');

      final journals = await db.executor.runSelect(
        "SELECT beleg_typ, betrag FROM journal WHERE beschreibung LIKE 'Zahlung%' ORDER BY id",
        const [],
      );
      expect(journals, isNotEmpty);
      expect(
        journals.single['beleg_typ'],
        BelegTyp.zahlung,
        reason: 'Payment journal must be Zahlung, not Einnahme pollution',
      );
      expect(journals.single['beleg_typ'] != BelegTyp.einnahme, isTrue);

      // EÜR must not count it even if we force kategorie onto it for the test (prove predicate).
      final int jId =
          (await db.executor.runSelect('SELECT id FROM journal WHERE beleg_typ = ?', [BelegTyp.zahlung])).single['id']!
              as int;
      await db.executor.runUpdate('UPDATE journal SET kategorie_id = ?, datum = ? WHERE id = ?', [
        993,
        '2025-05-10',
        jId,
      ]);

      final result = await euer.generate(jahr: 2025);
      expect(result.gewinn, '0.00', reason: 'Zahlung must not affect Gewinn');
      expect(result.zeile(12), '0.00');
    });

    test('test_cash_revenue_classification_1_3_overpayment_and_writeoff_typed_and_excluded', () async {
      await insertKategorie(id: 994, zeile: 12);
      await db.executor.runInsert(
        'INSERT INTO kunden (id, name, strasse, plz, ort) VALUES (2, ?, ?, ?, ?)',
        const <Object?>['K2', 'Str', '12345', 'Ort'],
      );
      final f = await forderungen.create(typ: 'rechnung', partnerTyp: 'kunde', partnerId: 2, betrag: 200.00);
      await forderungen.zahlungBuchen(forderungId: f.id, betrag: 250.00, datum: '2025-06-15');

      // Two journals: Zahlung 200 and Ueberzahlung 50
      final types = (await db.executor.runSelect(
        'SELECT beleg_typ FROM journal ORDER BY id DESC LIMIT 2',
        const [],
      )).map((Map<String, Object?> m) => m['beleg_typ'].toString()).toSet();
      expect(types, contains(BelegTyp.zahlung));
      expect(types, contains(BelegTyp.ueberzahlung));
      expect(types, isNot(contains(BelegTyp.einnahme)));

      // Write-off
      final f2 = await forderungen.create(typ: 'rechnung', partnerTyp: 'kunde', partnerId: 2, betrag: 80.00);
      await forderungen.ausbuchen(forderungId: f2.id, grund: 'uneinbringlich');
      final wb = await db.executor.runSelect(
        "SELECT beleg_typ FROM journal WHERE beschreibung LIKE 'Forderungsausfall:%' ORDER BY id DESC LIMIT 1",
        const [],
      );
      expect(wb.single['beleg_typ'], BelegTyp.ausbuchung, reason: 'Write-off must be Ausbuchung not Ausgabe');
      expect(wb.single['beleg_typ'] != BelegTyp.ausgabe, isTrue);

      // Force kategorie on all three cash journals and ensure EÜR still 0.
      final allCashIds = await db.executor.runSelect(
        'SELECT id FROM journal WHERE beleg_typ IN (?, ?, ?) ORDER BY id',
        [BelegTyp.zahlung, BelegTyp.ueberzahlung, BelegTyp.ausbuchung],
      );
      for (final Map<String, Object?> row in allCashIds) {
        await db.executor.runUpdate('UPDATE journal SET kategorie_id = ?, datum = ? WHERE id = ?', [
          994,
          '2025-06-15',
          row['id']! as int,
        ]);
      }
      final result = await euer.generate(jahr: 2025);
      expect(result.gewinn, '0.00', reason: 'Ueberzahlung/Ausbuchung must not affect Gewinn');
      expect(result.zeile(12), '0.00');
    });

    test('test_cash_revenue_classification_2_1_opening_cash_uses_eroeffnung_and_excluded', () async {
      await insertKategorie(id: 995, zeile: 12);
      // Ensure minimal kategorie available for setup fallback
      await setup.ensureKassenKonto(betrag: '500.00');

      final journals = await db.executor.runSelect(
        "SELECT id, beleg_typ, betrag, beschreibung FROM journal WHERE beschreibung LIKE '%Eröffnung Kasse%' LIMIT 1",
        const [],
      );
      expect(journals, isNotEmpty);
      expect(journals.single['beleg_typ'], BelegTyp.eroeffnung, reason: 'Opening cash must be Eroeffnung not Einnahme');
      expect(journals.single['beleg_typ'] != BelegTyp.einnahme, isTrue);

      // Even if that journal's kategorie happens to be euer-relevant, EÜR must ignore it.
      // Force kategorie to euer-relevant to prove predicate.
      final int openingId = journals.single['id']! as int;
      await db.executor.runUpdate('UPDATE journal SET kategorie_id = ? WHERE id = ?', [995, openingId]);
      final result = await euer.generate(jahr: DateTime.now().year);
      expect(result.gewinn, '0.00', reason: 'Eroeffnung forced to euer kategorie must still be excluded');
      // Insert a genuine Einnahme for same year to prove counting still works.
      await insertJournal(kategorieId: 995, betrag: '123.45', datum: '${DateTime.now().year}-01-10');
      final result2 = await euer.generate(jahr: DateTime.now().year);
      expect(result2.gewinn, '123.45', reason: 'Only genuine Einnahme counts, Eroeffnung excluded');
      expect(result2.zeile(12), '123.45');
    });
  });
}
