// ignore_for_file: file_names, avoid_redundant_argument_values, prefer_const_declarations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/datev_entity.dart';
import 'package:openaccounting/features/accounting/datev_service.dart';
import 'package:openaccounting/features/accounting/eks_entity.dart';
import 'package:openaccounting/features/accounting/eks_service.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';

void main() {
  group('Accounting calc validation — AfA + stock decimals (Plan D)', () {
    late AppDatabase db;
    late EuerService euer;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      euer = EuerService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertKategorie({required int id, required int zeile}) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv) VALUES (?, ?, ?, ?, ?, 1)',
        <Object?>[id, 'K$zeile', '800$zeile', '400$zeile', zeile],
      );
    }

    Future<void> insertJournal({
      required int kategorieId,
      required String betrag,
      required String datum,
      String art = 'Einnahme',
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>[datum, 'Test $kategorieId', kategorieId, betrag, art],
      );
    }

    test('Gewinn includes valid AfA — Einnahmen minus Ausgaben minus AfA', () async {
      await insertKategorie(id: 920, zeile: 15);
      await insertKategorie(id: 921, zeile: 60);
      await insertKategorie(id: 922, zeile: 33);
      await insertJournal(kategorieId: 920, betrag: '5000.00', datum: '2025-02-01');
      await insertJournal(kategorieId: 921, betrag: '1000.00', datum: '2025-02-02', art: 'Ausgabe');
      await insertJournal(kategorieId: 922, betrag: '9999.99', datum: '2025-02-03');
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Laptop', '2025-01-01', '1200.00', 3, '0', 'aktiv'],
      );

      final result = await euer.generate(jahr: 2025);

      expect(result.zeile(33), '400.00');
      expect(result.zeile(33) != '9999.99', isTrue);
      // Gewinn = 5000 - 1000 - 400 = 3600
      expect(result.gewinn, '3600.00');
    });

    test('Gewinn excludes Hinweis but includes AfA privatanteil reduction', () async {
      await insertKategorie(id: 930, zeile: 15);
      await insertKategorie(id: 931, zeile: 60);
      await insertKategorie(id: 932, zeile: 106);
      await insertKategorie(id: 933, zeile: 107);
      await insertJournal(kategorieId: 930, betrag: '2000.00', datum: '2025-03-01');
      await insertJournal(kategorieId: 931, betrag: '200.00', datum: '2025-03-02', art: 'Ausgabe');
      await insertJournal(kategorieId: 932, betrag: '500.00', datum: '2025-03-03', art: 'Ausgabe');
      await insertJournal(kategorieId: 933, betrag: '300.00', datum: '2025-03-04');
      // KFZ 1200/4=300 *30% privat => 210
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['KFZ', '2025-01-01', '1200.00', 4, '30', 'aktiv'],
      );

      final result = await euer.generate(jahr: 2025);

      expect(result.zeile(33), '210.00');
      expect(result.zeile(106), '500.00');
      expect(result.zeile(107), '300.00');
      // Gewinn = 2000 -200 -210 =1590, Hinweis excluded
      expect(result.gewinn, '1590.00');
    });

    test('Gewinn excludes inaktiv AfA', () async {
      await insertKategorie(id: 940, zeile: 15);
      await insertJournal(kategorieId: 940, betrag: '1000.00', datum: '2025-04-01');
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Alt', '2025-01-01', '1200.00', 3, '0', 'inaktiv'],
      );

      final result = await euer.generate(jahr: 2025);

      expect(result.zeile(33), '0.00');
      expect(result.gewinn, '1000.00');
    });

    group('artikel stock 3 decimals — every write', () {
      test('create accepts 1.234, rejects 1.2345', () async {
        final ok = await db.artikelRepository.create(
          bezeichnung: 'OK 3',
          vkBrutto: 10,
          bestandAktuell: 1.234,
          mindestbestand: 0.001,
        );
        expect(ok.bestandAktuell, 1.234);

        await expectLater(
          () => db.artikelRepository.create(bezeichnung: 'Bad 4', vkBrutto: 10, bestandAktuell: 1.2345),
          throwsA(isA<ArtikelException>().having((e) => e.toString().toLowerCase(), 'msg', contains('precision'))),
        );
        await expectLater(
          () => db.artikelRepository.create(
            bezeichnung: 'Bad mind',
            vkBrutto: 10,
            bestandAktuell: 0,
            mindestbestand: 1.2345,
          ),
          throwsA(isA<ArtikelException>().having((e) => e.toString().toLowerCase(), 'msg', contains('precision'))),
        );
      });

      test('update validates 3 decimals, boundary 1.234 passes, 1.2345 fails', () async {
        final a = await db.artikelRepository.create(bezeichnung: 'Upd', vkBrutto: 10, bestandAktuell: 0);
        final updated = await db.artikelRepository.update(a.id, <String, dynamic>{'bestand_aktuell': 1.234});
        expect(updated.bestandAktuell, 1.234);
        final updated2 = await db.artikelRepository.update(a.id, <String, dynamic>{'bestandAktuell': 2.5});
        expect(updated2.bestandAktuell, 2.5);
        final updated3 = await db.artikelRepository.update(a.id, <String, dynamic>{'mindestbestand': 0.001});
        expect(updated3.mindestbestand, 0.001);

        await expectLater(
          () => db.artikelRepository.update(a.id, <String, dynamic>{'bestand_aktuell': 1.2345}),
          throwsA(isA<ArtikelException>().having((e) => e.toString().toLowerCase(), 'msg', contains('precision'))),
        );
        await expectLater(
          () => db.artikelRepository.update(a.id, <String, dynamic>{'mindestbestand': 0.0001 + 1.2345}),
          throwsA(isA<ArtikelException>()),
        );
        // ensure not silently rounded
        final reloaded = await db.artikelRepository.findById(a.id);
        expect(reloaded!.bestandAktuell, 2.5);
      });

      test('setBestand and adjustBestand enforce 3 decimals', () async {
        final a = await db.artikelRepository.create(bezeichnung: 'Stock', vkBrutto: 10, lagerAktiv: true);
        final ok = await db.artikelRepository.setBestand(a.id, 1.234);
        expect(ok.bestandAktuell, 1.234);
        await expectLater(
          () => db.artikelRepository.setBestand(a.id, 1.2345),
          throwsA(isA<ArtikelException>().having((e) => e.toString().toLowerCase(), 'msg', contains('precision'))),
        );
        // 2.5 is 1 decimal — should pass
        await db.artikelRepository.setBestand(a.id, 2.5);
        await db.artikelRepository.adjustBestand(a.id, 0.001);
        expect((await db.artikelRepository.findById(a.id))!.bestandAktuell, closeTo(2.501, 0.0001));
        await expectLater(() => db.artikelRepository.adjustBestand(a.id, 0.0001), throwsA(isA<ArtikelException>()));
        await expectLater(() => db.artikelRepository.adjustBestand(a.id, 1.2345), throwsA(isA<ArtikelException>()));
      });

      test('integer and 0 pass, non-finite rejected', () async {
        final a = await db.artikelRepository.create(bezeichnung: 'Int', vkBrutto: 10, bestandAktuell: 5);
        expect(a.bestandAktuell, 5);
        await db.artikelRepository.setBestand(a.id, 0);
        expect((await db.artikelRepository.findById(a.id))!.bestandAktuell, 0);
        await expectLater(
          () => db.artikelRepository.setBestand(a.id, double.infinity),
          throwsA(isA<ArtikelException>().having((e) => e.toString(), 'msg', contains('finite'))),
        );
      });
    });
  });

  group('EKS ownership + DDL fail-closed (Plan D-09)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      // Ensure journal.kunde_id exists for ownership tests — mirrors production migration via PRAGMA
      await _ensureColumn(db, 'journal', 'kunde_id', 'INTEGER REFERENCES kunden(id)');
      await _ensureColumn(db, 'rechnungen', 'kunde_id', 'INTEGER REFERENCES kunden(id)');
      await _ensureEksColumns(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertKunde(String name) async {
      return db.executor.runInsert('INSERT INTO kunden (name, strasse, plz, ort) VALUES (?, ?, ?, ?)', <Object?>[
        name,
        'Straße 1',
        '10115',
        'Berlin',
      ]);
    }

    Future<void> insertKategorieEks({required int id, required String eksKategorie}) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, eks_kategorie) VALUES (?, ?, ?, ?, ?, 1, ?)',
        <Object?>[id, 'K $eksKategorie', '8400', '4400', null, eksKategorie],
      );
    }

    Future<void> insertJournalEks({
      required int kategorieId,
      required String betrag,
      required String datum,
      String art = 'Einnahme',
      int? kundeId,
      int? rechnungId,
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable, kunde_id, rechnung_id) VALUES (?, ?, ?, ?, ?, 0, ?, ?)',
        <Object?>[datum, 'EKS $kategorieId', kategorieId, betrag, art, kundeId, rechnungId],
      );
    }

    test('EKS scopes journal to requested kunde — cross-owner denied', () async {
      final int kundeA = await insertKunde('Kunde A');
      final int kundeB = await insertKunde('Kunde B');
      await insertKategorieEks(id: 801, eksKategorie: 'F23');
      await insertJournalEks(kategorieId: 801, betrag: '100.00', datum: '2025-05-01', kundeId: kundeA);
      await insertJournalEks(kategorieId: 801, betrag: '200.00', datum: '2025-05-02', kundeId: kundeB);
      // Also via rechnungen join path: journal with rechnung_id linking to kunde
      final int rechnungB = await db.executor.runInsert(
        'INSERT INTO rechnungen (typ, status, ist_entwurf, eingabemodus, kunde_id, datum) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['rechnung', 'entwurf', 1, 'netto', kundeB, '2025-05-03'],
      );
      await insertJournalEks(
        kategorieId: 801,
        betrag: '50.00',
        datum: '2025-05-03',
        kundeId: null,
        rechnungId: rechnungB,
      );

      final EksService service = EksService(db.executor);
      final EksResult scopedA = await service.generate(jahr: 2025, kundeId: kundeA);
      final EksResult scopedB = await service.generate(jahr: 2025, kundeId: kundeB);
      final EksResult unscoped = await service.generate(jahr: 2025);

      expect(scopedA.page9.totalIncome, '100.00');
      expect(scopedA.kundeId, kundeA);
      expect(scopedA.isUnscoped, isFalse);
      expect(scopedB.page9.totalIncome, '250.00'); // 200 + 50 via rechnung join
      expect(unscoped.page9.totalIncome, '350.00');
      expect(unscoped.isUnscoped, isTrue);
      // cross-owner: A must not contain B amounts
      expect(scopedA.sectionF['F23'], '100.00');
      expect(scopedB.sectionF['F23'], '250.00');
    });

    test('EKS scoped B6_4_priv owner-isolated — unscoped leaks if not filtered', () async {
      // Baseline schema has no kunde_id on anlageverzeichnis — scoped must exclude to avoid leak
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Betriebs-KFZ', '2025-01-01', '1200.00', 3, '30', 'aktiv'],
      );
      final int kundeA = await insertKunde('Owner A');
      await insertKategorieEks(id: 802, eksKategorie: 'F23');
      await insertJournalEks(kategorieId: 802, betrag: '1000.00', datum: '2025-02-01', kundeId: kundeA);

      final EksService service = EksService(db.executor);
      final EksResult unscoped = await service.generate(jahr: 2025);
      final EksResult scoped = await service.generate(jahr: 2025, kundeId: kundeA);

      // unscoped includes KFZ 1200/3*30% =120
      expect(unscoped.b6_4_priv, '120.00');
      expect(unscoped.page9.totalCosts, '120.00');
      // ponytail: assets without owner column — scoped report excludes private deduction to stay owner-isolated
      expect(scoped.b6_4_priv, '0.00');
      expect(scoped.page9.totalCosts, '0.00');
    });

    test('EKS with anlage kunde_id column scopes assets per owner', () async {
      await _ensureColumn(db, 'anlageverzeichnis', 'kunde_id', 'INTEGER REFERENCES kunden(id)');
      final int kundeA = await insertKunde('Kunde A2');
      final int kundeB = await insertKunde('Kunde B2');
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status, kunde_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['KFZ A', '2025-01-01', '1200.00', 3, '30', 'aktiv', kundeA],
      );
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status, kunde_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['KFZ B', '2025-01-01', '2400.00', 3, '30', 'aktiv', kundeB],
      );

      final EksService service = EksService(db.executor);
      final EksResult scopedA = await service.generate(jahr: 2025, kundeId: kundeA);
      final EksResult scopedB = await service.generate(jahr: 2025, kundeId: kundeB);
      final EksResult unscoped = await service.generate(jahr: 2025);

      expect(scopedA.b6_4_priv, '120.00');
      expect(scopedB.b6_4_priv, '240.00');
      // unscoped sums both when owner column present? currently unscoped selects all — sums both
      expect(unscoped.b6_4_priv, '360.00');
    });

    test('EKS DDL fail-closed: missing kategorien table throws, not empty success', () async {
      await db.executor.runCustom('DROP TABLE kategorien');
      await expectLater(EksService(db.executor).generate(jahr: 2025), throwsA(isA<EksException>()));
      await expectLater(EksService(db.executor).generate(jahr: 2025, kundeId: 1), throwsA(isA<EksException>()));
    });

    test('EKS DDL fail-closed: missing anlageverzeichnis table throws', () async {
      await db.executor.runCustom('DROP TABLE anlageverzeichnis');
      await insertKategorieEks(id: 803, eksKategorie: 'F23');
      // journal exists but anlage missing should fail-closed
      await expectLater(EksService(db.executor).generate(jahr: 2025), throwsA(isA<EksException>()));
    });

    test('EKS DDL fail-closed: missing eks_einstellungen table throws', () async {
      await db.executor.runCustom('CREATE TABLE eks_einstellungen_temp AS SELECT * FROM eks_einstellungen');
      await db.executor.runCustom('DROP TABLE eks_einstellungen');
      await insertKategorieEks(id: 804, eksKategorie: 'F23');
      await expectLater(EksService(db.executor).generate(jahr: 2025), throwsA(isA<EksException>()));
      // restore for tearDown not needed as db is per-test
    });

    test('EKS DDL fail-closed: missing journal table throws', () async {
      await db.executor.runCustom('DROP TABLE journal');
      await expectLater(EksService(db.executor).generate(jahr: 2025), throwsA(isA<EksException>()));
    });

    test('EKS unknown kundeId is rejected not unscoped', () async {
      await insertKategorieEks(id: 805, eksKategorie: 'F23');
      await expectLater(EksService(db.executor).generate(jahr: 2025, kundeId: 99999), throwsA(isA<EksException>()));
      // 0 and negative also rejected
      await expectLater(EksService(db.executor).generate(jahr: 2025, kundeId: 0), throwsA(isA<EksException>()));
      await expectLater(EksService(db.executor).generate(jahr: 2025, kundeId: -1), throwsA(isA<EksException>()));
    });
  });

  group('DATEV EXTF validation — field/header/encoding (Plan D-09)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> upsertUnternehmen({String? berater, String? mandant, String? kontoBank}) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT id FROM unternehmen LIMIT 1',
        const <Object?>[],
      );
      if (rows.isEmpty) {
        await db.executor.runInsert(
          'INSERT INTO unternehmen (name, datev_beraternummer, datev_mandantennummer, datev_konto_bank) VALUES (?, ?, ?, ?)',
          <Object?>['Test Firma', berater, mandant, kontoBank],
        );
      } else {
        final int id = (rows.first['id'] as num?)?.toInt() ?? 0;
        await db.executor.runCustom(
          'UPDATE unternehmen SET datev_beraternummer=?, datev_mandantennummer=?, datev_konto_bank=? WHERE id=?',
          <Object?>[berater, mandant, kontoBank, id],
        );
      }
    }

    Future<void> insertKategorieDatev({required int id, required String skr03}) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv) VALUES (?, ?, ?, ?, ?, 1)',
        <Object?>[id, 'K $skr03', skr03, '4400', 15],
      );
    }

    Future<void> insertJournalDatev({
      required int kategorieId,
      required String betrag,
      required String datum,
      String bezeichnung = 'Test Buchung',
      String art = 'Einnahme',
      String? belegNr,
      int? kontoId,
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable, konto_id, beleg_nr) VALUES (?, ?, ?, ?, ?, 0, ?, ?)',
        <Object?>[datum, bezeichnung, kategorieId, betrag, art, kontoId, belegNr],
      );
    }

    test('DATEV rejects malformed betrag — fail then pass, no success log on fail', () async {
      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: '1200');
      await insertKategorieDatev(id: 901, skr03: '8400');
      await insertJournalDatev(kategorieId: 901, betrag: 'not-a-number', datum: '2025-03-15');

      final int before =
          (await db.executor.runSelect('SELECT COUNT(*) as c FROM datev_export_log', const <Object?>[])).single['c']!
              as int;

      await expectLater(DatevService(db.executor).exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      final int afterFail =
          (await db.executor.runSelect('SELECT COUNT(*) as c FROM datev_export_log', const <Object?>[])).single['c']!
              as int;
      expect(afterFail, before, reason: 'malformed row must not log erfolg');

      // fix fixture — update betrag to valid
      await db.executor.runCustom('DELETE FROM journal');
      await insertJournalDatev(kategorieId: 901, betrag: '119.00', datum: '2025-03-15', bezeichnung: 'Erlös Test');
      final String csv = await DatevService(db.executor).exportCsv(jahr: 2025);
      expect(csv.contains('EXTF'), isTrue);
      expect(csv.contains('119,00'), isTrue);
      final int afterPass =
          (await db.executor.runSelect('SELECT COUNT(*) as c FROM datev_export_log', const <Object?>[])).single['c']!
              as int;
      expect(afterPass, before + 1);
    });

    test('DATEV rejects invalid datum — fail then pass', () async {
      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: '1200');
      await insertKategorieDatev(id: 902, skr03: '8400');
      await insertJournalDatev(kategorieId: 902, betrag: '100.00', datum: 'not-a-date');

      await expectLater(DatevService(db.executor).exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      await db.executor.runCustom('DELETE FROM journal');
      await insertJournalDatev(kategorieId: 902, betrag: '100.00', datum: '2025-04-01');
      final String csv = await DatevService(db.executor).exportCsv(jahr: 2025);
      expect(csv.contains('01.04.2025'), isTrue);
    });

    test('DATEV validates Belegfeld 1 length >36 fails, boundary 36 passes', () async {
      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: '1200');
      await insertKategorieDatev(id: 903, skr03: '8400');
      final String tooLong = 'X' * 37;
      final String boundary = 'Y' * 36;
      await insertJournalDatev(kategorieId: 903, betrag: '10.00', datum: '2025-05-01', belegNr: tooLong);

      await expectLater(DatevService(db.executor).exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      await db.executor.runCustom('DELETE FROM journal');
      await insertJournalDatev(kategorieId: 903, betrag: '10.00', datum: '2025-05-01', belegNr: boundary);
      final String csv = await DatevService(db.executor).exportCsv(jahr: 2025);
      expect(csv.contains(boundary), isTrue);
    });

    test('DATEV validates Buchungstext >60 fails, 60 passes, umlauts preserved', () async {
      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: '1200');
      await insertKategorieDatev(id: 904, skr03: '8400');
      final String tooLong = 'A' * 61;
      await insertJournalDatev(kategorieId: 904, betrag: '20.00', datum: '2025-06-01', bezeichnung: tooLong);

      await expectLater(DatevService(db.executor).exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      await db.executor.runCustom('DELETE FROM journal');
      final String withUmlauts = 'Müller Ärger Übergröße Grüße — äöü ÄÖÜ ß €';
      // ponytail: UTF-8 CSV — umlauts must survive; DATEV CP1252 conversion is one-liner if reader requires latin1
      await insertJournalDatev(kategorieId: 904, betrag: '20.00', datum: '2025-06-01', bezeichnung: withUmlauts);
      final String csv = await DatevService(db.executor).exportCsv(jahr: 2025);
      expect(csv.contains('Müller'), isTrue);
      expect(csv.contains('Ärger'), isTrue);
      expect(csv.contains('Übergröße'), isTrue);
      expect(csv.contains('äöü'), isTrue);
      expect(csv.contains('ÄÖÜ'), isTrue);
      expect(csv.contains('ß'), isTrue);

      // Verify artifact file preserves umlauts via UTF-8 round-trip
      final Directory dir = await Directory.systemTemp.createTemp('datev-umlauts-');
      addTearDown(() => dir.delete(recursive: true));
      final String path = '${dir.path}/buchung.csv';
      final String csv2 = await DatevService(db.executor).exportCsv(jahr: 2025, destinationPath: path);
      final String fileContent = await File(path).readAsString();
      expect(fileContent, csv2);
      expect(fileContent.contains('Müller'), isTrue);
      expect(csv2.contains('20,00'), isTrue);
      // boundary 60 exactly
      await db.executor.runCustom('DELETE FROM journal');
      final String exactly60 = 'B' * 60;
      await insertJournalDatev(kategorieId: 904, betrag: '30.00', datum: '2025-06-02', bezeichnung: exactly60);
      final String csv3 = await DatevService(db.executor).exportCsv(jahr: 2025);
      expect(csv3.contains(exactly60), isTrue);
    });

    test('DATEV validates Konto numeric 4-8 — malformed global konto fails', () async {
      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: 'ABC');
      await insertKategorieDatev(id: 905, skr03: '8400');
      await insertJournalDatev(kategorieId: 905, betrag: '50.00', datum: '2025-07-01');

      await expectLater(DatevService(db.executor).exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: '1200');
      final String csv = await DatevService(db.executor).exportCsv(jahr: 2025);
      expect(csv.contains('1200'), isTrue);
    });

    test('DATEV header validation — berater/mandant numeric and length, jahr range, von/bis order', () async {
      await upsertUnternehmen(berater: 'ABC', mandant: '678', kontoBank: '1200');
      await insertKategorieDatev(id: 906, skr03: '8400');
      await insertJournalDatev(kategorieId: 906, betrag: '10.00', datum: '2025-08-01');

      await expectLater(DatevService(db.executor).exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      await upsertUnternehmen(berater: '12345678', mandant: '678', kontoBank: '1200'); // 8 >7
      await expectLater(DatevService(db.executor).exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      await upsertUnternehmen(berater: '12345', mandant: '123456', kontoBank: '1200'); // 6 >5
      await expectLater(DatevService(db.executor).exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: '1200');
      await expectLater(DatevService(db.executor).exportCsv(jahr: 999), throwsA(isA<DatevException>()));
      await expectLater(
        DatevService(db.executor).exportCsv(von: DateTime(2025, 06, 10), bis: DateTime(2025, 05, 10)),
        throwsA(isA<DatevException>()),
      );

      // valid header passes
      final String csv = await DatevService(db.executor).exportCsv(jahr: 2025);
      expect(csv.startsWith('EXTF'), isTrue);
      // header must have 17 fields
      expect(csv.split('\r\n').first.split(';').length, 17);
    });

    test('DATEV EXTF header + data row field structure strict', () async {
      await upsertUnternehmen(berater: '123', mandant: '456', kontoBank: '1200');
      await insertKategorieDatev(id: 907, skr03: '8400');
      await insertJournalDatev(
        kategorieId: 907,
        betrag: '1234.56',
        datum: '2025-09-15',
        bezeichnung: 'Rechnung',
        belegNr: 'RE001',
      );

      final String csv = await DatevService(db.executor).exportCsv(jahr: 2025);
      final List<String> lines = csv.split('\r\n');
      expect(lines.length, greaterThanOrEqualTo(3));
      expect(lines[0].startsWith('EXTF;700;21;Buchungsstapel'), isTrue);
      expect(lines[1].split(';').length, 9);
      final String dataLine = lines[2];
      final List<String> fields = dataLine.split(';');
      expect(fields.length, 9);
      // Betrag German comma 2 decimals
      expect(fields[0], matches(RegExp(r'^-?\d+,\d{2}$')));
      expect(fields[1], anyOf('S', 'H'));
      expect(fields[3], matches(RegExp(r'^\d{4,8}$')));
      expect(fields[4], matches(RegExp(r'^\d{4,8}$')));
      expect(fields[6], matches(RegExp(r'^\d{2}\.\d{2}\.\d{4}$')));
    });

    test('DATEV does not log success when destination unavailable', () async {
      await upsertUnternehmen(berater: '123', mandant: '456', kontoBank: '1200');
      await insertKategorieDatev(id: 908, skr03: '8400');
      await insertJournalDatev(kategorieId: 908, betrag: '10.00', datum: '2025-10-01');

      final int before =
          (await db.executor.runSelect('SELECT COUNT(*) as c FROM datev_export_log', const <Object?>[])).single['c']!
              as int;
      await expectLater(
        DatevService(db.executor).exportCsv(jahr: 2025, destinationPath: '/tmp/does-not-exist-xyz/datev.csv'),
        throwsA(isA<DatevException>()),
      );
      final int after =
          (await db.executor.runSelect('SELECT COUNT(*) as c FROM datev_export_log', const <Object?>[])).single['c']!
              as int;
      expect(after, before);
    });
  });

  group('Plan D-10: PDF immutable snapshot + forderungen memoization race', () {
    test('PDF snapshot immutable after finalize and not minimal blank', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      final Directory tmpDir = await Directory.systemTemp.createTemp('pdf-snapshot-');
      addTearDown(() async {
        try {
          await tmpDir.delete(recursive: true);
        } catch (_) {}
        await db.close();
      });
      final RechnungenDataSource ds = RechnungenDataSource(db.executor);
      final int rechnungId = await ds.createDraftRechnung(
        datum: '2025-01-15',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Snapshot-Leistung', menge: 2, einzelpreis: 50, gesamt: 100, ustSatz: 19),
        ],
      );
      await ds.finalizeRechnung(rechnungId: rechnungId, profileDir: tmpDir);
      final Map<String, Object?> row = (await db.executor.runSelect(
        'SELECT rechnungsnummer, original_pdf_pfad FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      )).single;
      final String? storedPath = row['original_pdf_pfad'] as String?;
      final String? docNum = row['rechnungsnummer'] as String?;
      expect(storedPath, isNotNull, reason: 'finalize must store PDF path');
      expect(docNum, isNotNull);
      final File pdfFile = File(storedPath!);
      expect(pdfFile.existsSync(), isTrue, reason: 'PDF file must exist');
      final List<int> bytesBefore = pdfFile.readAsBytesSync();
      expect(bytesBefore.length, greaterThan(700), reason: 'PDF must not be minimal blank');
      expect(String.fromCharCodes(bytesBefore.sublist(0, 4)), '%PDF');
      final String pdfText = String.fromCharCodes(bytesBefore);
      expect(pdfText.contains('Snapshot-Leistung'), isTrue, reason: 'PDF must contain position description');
      expect(pdfText.contains(docNum!), isTrue, reason: 'PDF must contain document number');
      // Post-finalize edit attempt must not mutate stored PDF bytes.
      try {
        await db.executor.runCustom('UPDATE rechnungen SET notiz = ? WHERE id = ?', <Object?>['hacked', rechnungId]);
      } catch (_) {}
      // Even if edit succeeded for non-protected column, PDF file must remain unchanged.
      // Try protected position edit as well.
      try {
        await db.executor.runCustom('UPDATE rechnungspositionen SET bezeichnung = ? WHERE rechnung_id = ?', <Object?>[
          'HACKED',
          rechnungId,
        ]);
      } catch (_) {}
      final List<int> bytesAfter = pdfFile.readAsBytesSync();
      expect(bytesAfter.length, bytesBefore.length, reason: 'PDF bytes length must be immutable');
      expect(bytesAfter, bytesBefore, reason: 'PDF bytes must be immutable after post-finalize edit');
      // bytes must not be minimal placeholder
      expect(bytesAfter.length, greaterThan(700));
    });

    test('Forderungen memoization concurrent loads return consistent schema', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(() async => db.close());
      final ForderungenRepository repo = ForderungenRepository(db.executor);
      // Concurrent ensureSchema must not race to duplicate column error
      await Future.wait(List<Future<void>>.generate(5, (_) => repo.ensureSchema()));
      final List<Map<String, Object?>> cols = await db.executor.runSelect(
        'PRAGMA table_info(forderungen)',
        const <Object?>[],
      );
      final Set<String> names = cols.map((r) => r['name'].toString()).toSet();
      expect(names, containsAll(<String>['typ', 'partner_typ', 'partner_id', 'anfangsbetrag']));
    });

    test('Forderungen memoization stale after migration is refreshed', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(() async => db.close());
      final ForderungenRepository repo = ForderungenRepository(db.executor);
      await repo.ensureSchema();
      // Simulate external migration drift: drop a required column that ensureSchema must re-add
      bool dropped = false;
      try {
        await db.executor.runCustom('ALTER TABLE forderungen DROP COLUMN anfangsbetrag');
        dropped = true;
      } catch (_) {
        // Fallback for SQLite without DROP COLUMN: recreate without anfangsbetrag
        await db.executor.runCustom('ALTER TABLE forderungen RENAME TO forderungen_tmp');
        await db.executor.runCustom('''
CREATE TABLE forderungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kunde_id INTEGER REFERENCES kunden(id),
  rechnung_id INTEGER REFERENCES rechnungen(id),
  betrag NUMERIC(12,2) NOT NULL,
  status TEXT DEFAULT 'offen',
  faelligkeit TEXT,
  beschreibung TEXT,
  typ TEXT NOT NULL DEFAULT 'rechnung' CHECK (typ IN ('rechnung','rechnung_eingang','journal')),
  partner_typ TEXT NOT NULL DEFAULT 'kunde' CHECK (partner_typ IN ('kunde','lieferant')),
  partner_id INTEGER NOT NULL DEFAULT 0,
  journal_id INTEGER REFERENCES journal(id),
  ausgleich_journal_id INTEGER REFERENCES journal(id),
  erstellt_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  aktualisiert_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)''');
        await db.executor.runCustom(
          'INSERT INTO forderungen (id, kunde_id, rechnung_id, betrag, status, faelligkeit, beschreibung, typ, partner_typ, partner_id, journal_id, ausgleich_journal_id, erstellt_am, aktualisiert_am) SELECT id, kunde_id, rechnung_id, betrag, status, faelligkeit, beschreibung, typ, partner_typ, partner_id, journal_id, ausgleich_journal_id, erstellt_am, aktualisiert_am FROM forderungen_tmp',
        );
        await db.executor.runCustom('DROP TABLE forderungen_tmp');
        dropped = true;
      }
      expect(dropped, isTrue);
      final List<Map<String, Object?>> before = await db.executor.runSelect(
        'PRAGMA table_info(forderungen)',
        const <Object?>[],
      );
      expect(
        before.any((r) => r['name'] == 'anfangsbetrag'),
        isFalse,
        reason: 'anfangsbetrag must be missing before re-ensure',
      );
      // Stale memoization would leave column missing; drift-aware must re-add
      await repo.ensureSchema();
      final List<Map<String, Object?>> cols = await db.executor.runSelect(
        'PRAGMA table_info(forderungen)',
        const <Object?>[],
      );
      final Set<String> names = cols.map((r) => r['name'].toString()).toSet();
      expect(names, containsAll(<String>['typ', 'partner_typ', 'partner_id', 'anfangsbetrag']));
      // Concurrent after drift must still be consistent
      await Future.wait(List<Future<void>>.generate(3, (_) => repo.ensureSchema()));
      final List<Map<String, Object?>> cols2 = await db.executor.runSelect(
        'PRAGMA table_info(forderungen)',
        const <Object?>[],
      );
      final Set<String> names2 = cols2.map((r) => r['name'].toString()).toSet();
      expect(names2, containsAll(<String>['typ', 'partner_typ', 'partner_id']));
    });

    test('Forderungen occurrence check/insert atomic for concurrent createForRechnung', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(() async => db.close());
      final int kundeId = await db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort) VALUES (?, ?, ?, ?)',
        const <Object?>['Kunde Race', 'Strasse 1', '10115', 'Berlin'],
      );
      final RechnungenDataSource ds = RechnungenDataSource(db.executor);
      final int rechnungId = await ds.createDraftRechnung(
        datum: '2025-01-15',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'RacePos', menge: 1, einzelpreis: 100, gesamt: 100),
        ],
      );
      await db.executor.runUpdate('UPDATE rechnungen SET kunde_id = ? WHERE id = ?', <Object?>[kundeId, rechnungId]);
      await ds.finalizeRechnung(rechnungId: rechnungId);
      // Clean forderungen to test race via repository directly: delete then race create
      await db.executor.runCustom('DELETE FROM forderungen WHERE rechnung_id = ?', <Object?>[rechnungId]);
      final ForderungenRepository repo = ForderungenRepository(db.executor);
      await repo.ensureSchema();
      final List<Forderung?> results = await Future.wait(<Future<Forderung?>>[
        repo.createForRechnung(rechnungId),
        repo.createForRechnung(rechnungId),
        repo.createForRechnung(rechnungId),
      ]);
      final Set<int> ids = results.whereType<Forderung>().map((f) => f.id).toSet();
      expect(ids.length, 1, reason: 'concurrent createForRechnung must be idempotent, single row');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM forderungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      expect(rows.single['c'], 1);
    });
  });
}

Future<void> _ensureColumn(AppDatabase db, String table, String column, String definition) async {
  final List<Map<String, Object?>> cols = await db.executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
  if (!cols.any((Map<String, Object?> r) => r['name'] == column)) {
    await db.executor.runCustom('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}

Future<void> _ensureEksColumns(AppDatabase db) async {
  final List<Map<String, Object?>> uCols = await db.executor.runSelect(
    'PRAGMA table_info(unternehmen)',
    const <Object?>[],
  );
  final Set<String> uNames = uCols.map((Map<String, Object?> r) => r['name'].toString()).toSet();
  if (!uNames.contains('berufsbezeichnung')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN berufsbezeichnung TEXT');
  }
  if (!uNames.contains('kammer_mitgliedschaft')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN kammer_mitgliedschaft TEXT');
  }
  if (!uNames.contains('geburtsdatum')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN geburtsdatum TEXT');
  }
  if (!uNames.contains('bg_nummer')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN bg_nummer TEXT');
  }
  if (!uNames.contains('jobcenter_name')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN jobcenter_name TEXT');
  }
  if (!uNames.contains('jobcenter')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN jobcenter TEXT');
  }
  final List<Map<String, Object?>> kCols = await db.executor.runSelect(
    'PRAGMA table_info(kategorien)',
    const <Object?>[],
  );
  final Set<String> kNames = kCols.map((Map<String, Object?> r) => r['name'].toString()).toSet();
  if (!kNames.contains('eks_kategorie')) {
    await db.executor.runCustom('ALTER TABLE kategorien ADD COLUMN eks_kategorie TEXT');
  }
  final List<Map<String, Object?>> jCols = await db.executor.runSelect('PRAGMA table_info(journal)', const <Object?>[]);
  final Set<String> jNames = jCols.map((Map<String, Object?> r) => r['name'].toString()).toSet();
  if (!jNames.contains('km_anzahl')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN km_anzahl NUMERIC(12,2)');
  }
}
