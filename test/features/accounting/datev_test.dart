import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/datev_entity.dart';
import 'package:openaccounting/features/accounting/datev_service.dart';

void main() {
  group('DATEV EXTF — Buchungsstapel', () {
    late AppDatabase db;
    late DatevService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await _ensureDatevColumns(db);
      service = DatevService(db.executor);
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

    Future<int> insertKonto({required String name, String? datevKontonummer}) async {
      return await db.executor.runInsert('INSERT INTO konten (name, datev_kontonummer) VALUES (?, ?)', <Object?>[
        name,
        datevKontonummer,
      ]);
    }

    Future<void> insertKategorie({
      required int id,
      required String skr03,
      String skr04 = '4400',
      String bezeichnung = 'Test Kategorie',
    }) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[id, bezeichnung, skr03, skr04, 15, 'catalog_verified', 'TEST-DATEV', '2026-test.1'],
      );
    }

    Future<void> insertJournal({
      required int kategorieId,
      required String betrag,
      required String datum,
      String bezeichnung = 'Test Buchung',
      String art = 'Einnahme',
      int? kontoId,
      String? belegNr,
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable, konto_id, beleg_nr) VALUES (?, ?, ?, ?, ?, 0, ?, ?)',
        <Object?>[datum, bezeichnung, kategorieId, betrag, art, kontoId, belegNr],
      );
    }

    test('header EXTF valid with berater/mandant and 700 Buchungsstapel', () async {
      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: '1200');
      await insertKategorie(id: 901, skr03: '8400');
      await insertJournal(kategorieId: 901, betrag: '119.00', datum: '2025-03-15', bezeichnung: 'Erlös Test');

      final String csv = await service.exportCsv(jahr: 2025, kontoBankFallback: '1200');

      final List<String> lines = csv.split('\n').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();
      expect(lines.isNotEmpty, isTrue);
      final String header = lines.first;
      expect(header.startsWith('EXTF'), isTrue, reason: 'header 0 must be EXTF record');
      expect(header.contains('700'), isTrue);
      expect(header.contains('Buchungsstapel'), isTrue);
      expect(header.contains('12345'), isTrue, reason: 'header must contain berater');
      expect(header.contains('678'), isTrue, reason: 'header must contain mandant');
      // encoding: semicolon separated, at least 10 fields
      expect(header.split(';').length, greaterThanOrEqualTo(10));
      // stable encoding: must be semicolon CSV, not comma header
      expect(header.contains(';'), isTrue);
    });

    test('data rows German DD.MM.YYYY and comma decimal + SKR03 mapping', () async {
      await upsertUnternehmen(berater: '12345', mandant: '678', kontoBank: '1200');
      await insertKategorie(id: 902, skr03: '8400', bezeichnung: 'Umsatz 19%');
      await insertKategorie(id: 903, skr03: '8300', bezeichnung: 'Umsatz 7%');
      await insertJournal(
        kategorieId: 902,
        betrag: '1234.56',
        datum: '2025-06-15',
        bezeichnung: 'Rechnung 1',
        belegNr: 'RE001',
      );
      await insertJournal(kategorieId: 903, betrag: '100.00', datum: '2025-06-20', bezeichnung: 'Rechnung 2');

      final String csv = await service.exportCsv(jahr: 2025, kontoBankFallback: '1200');
      final List<String> lines = csv.split('\r\n').expand((String l) => l.split('\n')).toList();

      // header + colHeader + 2 data lines >=4
      expect(lines.length, greaterThanOrEqualTo(4));

      // find data lines containing amounts
      final String dataJoined = csv;
      expect(dataJoined.contains('15.06.2025'), isTrue, reason: 'German date DD.MM.YYYY');
      expect(dataJoined.contains('20.06.2025'), isTrue);
      expect(dataJoined.contains('1234,56'), isTrue, reason: 'comma decimal');
      expect(dataJoined.contains('100,00'), isTrue);
      // SKR03 appears as Konto or Gegenkonto
      expect(dataJoined.contains('8400'), isTrue);
      expect(dataJoined.contains('8300'), isTrue);
      // Beleg text and beleg_nr
      expect(dataJoined.contains('Rechnung 1'), isTrue);
      expect(dataJoined.contains('RE001'), isTrue);
      // Soll/Haben Kennzeichen H for Einnahme
      expect(dataJoined.contains(';H;'), isTrue);
      // decimal formatting pure: two decimals, no float drift
      expect(dataJoined, contains(RegExp(r'\d+,\d{2}')));
      // encoding check: semicolon rows
      for (final String line in lines.skip(2)) {
        if (line.trim().isEmpty) continue;
        expect(line.contains(';'), isTrue);
      }
    });

    test('konto.datev_kontonummer wins over explicit override; no implicit global', () async {
      await upsertUnternehmen(berater: '999', mandant: '111', kontoBank: '1200');
      await insertKategorie(id: 910, skr03: '8400', bezeichnung: 'Erlös');
      final int kontoMit = await insertKonto(name: 'Bank A', datevKontonummer: '1800');
      final int kontoLeer = await insertKonto(name: 'Bank B');

      // Entry with per-konto override 1800
      await insertJournal(
        kategorieId: 910,
        betrag: '500.00',
        datum: '2025-04-10',
        bezeichnung: 'Mit Override',
        kontoId: kontoMit,
      );
      // Entry with konto lacking a datev number and no override → fail-closed.
      await insertJournal(
        kategorieId: 910,
        betrag: '300.00',
        datum: '2025-04-11',
        bezeichnung: 'Ohne Quelle',
        kontoId: kontoLeer,
      );

      await expectLater(service.exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      // Stored global 1200 is never applied implicitly; explicit override works.
      final String csvParam = await service.exportCsv(jahr: 2025, kontoBankFallback: '1220');
      expect(csvParam.contains('1220'), isTrue);
      final List<String> paramLines = csvParam.split('\r\n').expand((String l) => l.split('\n')).skip(2).toList();
      final bool still1800 = paramLines.any((String l) => l.contains('1800'));
      expect(still1800, isTrue);
    });

    test('unresolved slots fail without synthetic accounts', () async {
      await upsertUnternehmen(berater: '555', mandant: '777');
      await insertKategorie(id: 911, skr03: '8910', bezeichnung: 'Fallback Kategorie');
      await insertJournal(kategorieId: 911, betrag: '50.00', datum: '2025-05-01', bezeichnung: 'Kategorie Fallback');

      await expectLater(
        service.exportCsv(jahr: 2025),
        throwsA(
          isA<DatevException>()
              .having((e) => e.unresolvedSlot, 'slot', 'Konto')
              .having((e) => e.toString(), 'message', isNot(contains('1200'))),
        ),
      );
    });

    test('period filter jahr and von/bis', () async {
      await upsertUnternehmen(berater: '123', mandant: '456', kontoBank: '1200');
      await insertKategorie(id: 920, skr03: '8400');
      await insertJournal(kategorieId: 920, betrag: '100.00', datum: '2025-01-10', bezeichnung: 'Jan');
      await insertJournal(kategorieId: 920, betrag: '200.00', datum: '2025-06-15', bezeichnung: 'Jun');
      await insertJournal(kategorieId: 920, betrag: '999.00', datum: '2024-12-31', bezeichnung: 'Vorjahr');
      await insertJournal(kategorieId: 920, betrag: '888.00', datum: '2025-12-31', bezeichnung: 'Dez');

      final String csvJahr = await service.exportCsv(jahr: 2025, kontoBankFallback: '1200');
      expect(csvJahr.contains('Jan'), isTrue);
      expect(csvJahr.contains('Jun'), isTrue);
      expect(csvJahr.contains('Dez'), isTrue);
      expect(csvJahr.contains('Vorjahr'), isFalse);
      expect(csvJahr.contains('999,00'), isFalse);

      final String csvRange = await service.exportCsv(
        von: DateTime(2025, 6),
        bis: DateTime(2025, 6, 30),
        kontoBankFallback: '1200',
      );
      expect(csvRange.contains('Jun'), isTrue);
      expect(csvRange.contains('Jan'), isFalse);
      expect(csvRange.contains('Dez'), isFalse);
      expect(csvRange.contains('200,00'), isTrue);
      expect(csvRange.contains('100,00'), isFalse);
    });

    test('missing berater/mandant throws DatevException not crash', () async {
      // No unternehmen or empty berater/mandant
      await upsertUnternehmen(kontoBank: '1200');
      await insertKategorie(id: 930, skr03: '8400');
      await insertJournal(kategorieId: 930, betrag: '10.00', datum: '2025-07-01', bezeichnung: 'Test');

      await expectLater(
        service.exportCsv(jahr: 2025),
        throwsA(predicate<Object>((Object e) => e is DatevException && e.toString().toLowerCase().contains('datev'))),
      );

      // Missing mandant only
      await upsertUnternehmen(berater: '12345', mandant: '', kontoBank: '1200');
      await expectLater(service.exportCsv(jahr: 2025), throwsA(isA<DatevException>()));

      // Missing berater only
      await upsertUnternehmen(berater: '', mandant: '678', kontoBank: '1200');
      await expectLater(service.exportCsv(jahr: 2025), throwsA(isA<DatevException>()));
    });

    test('decimal formatting pure string comma and encoding stable', () async {
      await upsertUnternehmen(berater: '1', mandant: '2', kontoBank: '1200');
      await insertKategorie(id: 940, skr03: '8400');
      await insertJournal(kategorieId: 940, betrag: '1000.00', datum: '2025-08-01', bezeichnung: 'Glatt');
      await insertJournal(kategorieId: 940, betrag: '0.50', datum: '2025-08-02', bezeichnung: 'Klein');
      await insertJournal(kategorieId: 940, betrag: '1234.50', datum: '2025-08-03', bezeichnung: 'Mit Komma');

      final String csv = await service.exportCsv(jahr: 2025, kontoBankFallback: '1200');
      expect(csv.contains('1000,00'), isTrue);
      expect(csv.contains('0,50'), isTrue);
      expect(csv.contains('1234,50'), isTrue);
      // No dot decimal in data rows (header contains dots in dates, so check data lines only)
      final List<String> dataLines = csv
          .split('\r\n')
          .expand((String l) => l.split('\n'))
          .skip(2)
          .where((String l) => l.trim().isNotEmpty)
          .toList();
      for (final String line in dataLines) {
        // Betrag field is first column before first ';' — check it has comma
        final String betragField = line.split(';').first.replaceAll('"', '');
        expect(betragField, matches(RegExp(r'^-?\d+,\d{2}$')), reason: 'betrag must be German comma 2 decimals: $line');
      }
      // header 0 EXTF and no crash on empty warnings
      expect(csv.split('\r\n').first.startsWith('EXTF'), isTrue);
    });

    test('export alias works and logs to datev_export_log', () async {
      await upsertUnternehmen(berater: '777', mandant: '888', kontoBank: '1210');
      await insertKategorie(id: 950, skr03: '8400');
      await insertJournal(kategorieId: 950, betrag: '42.00', datum: '2025-09-01', bezeichnung: 'Log Test');

      final String csv1 = await service.export(jahr: 2025, kontoBankFallback: '1210');
      final String csv2 = await service.exportCsv(jahr: 2025, kontoBankFallback: '1210');
      expect(csv1, csv2);
      expect(csv1.contains('EXTF'), isTrue);
      // log exists
      final List<Map<String, Object?>> logs = await db.executor.runSelect(
        'SELECT * FROM datev_export_log',
        const <Object?>[],
      );
      expect(logs.isNotEmpty, isTrue);
      final Map<String, Object?> last = logs.last;
      expect((last['anzahl_buchungen']! as num).toInt(), greaterThanOrEqualTo(1));
      expect(last['status'], 'erfolg');
    });

    test('empty period returns header only, no data crash', () async {
      await upsertUnternehmen(berater: '123', mandant: '456', kontoBank: '1200');
      await insertKategorie(id: 960, skr03: '8400');
      await insertJournal(kategorieId: 960, betrag: '100.00', datum: '2025-01-01');

      final String csv = await service.exportCsv(jahr: 2024);
      final List<String> lines = csv
          .split('\r\n')
          .expand((String l) => l.split('\n'))
          .where((String s) => s.trim().isNotEmpty)
          .toList();
      // header + colHeader only, no data
      expect(lines.length, 2);
      expect(lines.first.startsWith('EXTF'), isTrue);
    });

    test('writes a reopenable artifact and records the selected path', () async {
      await upsertUnternehmen(berater: '123', mandant: '456', kontoBank: '1200');
      await insertKategorie(id: 970, skr03: '8400');
      await insertJournal(kategorieId: 970, betrag: '10.005', datum: '2025-10-01', bezeichnung: 'Rundung');
      final Directory directory = await Directory.systemTemp.createTemp('openaccounting-datev-');
      addTearDown(() => directory.delete(recursive: true));
      final String path = '${directory.path}/buchungsstapel.csv';

      final String csv = await service.exportCsv(jahr: 2025, destinationPath: path, kontoBankFallback: '1200');

      final File artifact = File(path);
      expect(artifact.existsSync(), isTrue);
      expect(await artifact.readAsString(), csv);
      expect(csv, contains('10,01'));
      final List<Map<String, Object?>> logs = await db.executor.runSelect(
        'SELECT datei_pfad, status FROM datev_export_log ORDER BY id DESC LIMIT 1',
        const <Object?>[],
      );
      expect(logs.single['datei_pfad'], path);
      expect(logs.single['status'], 'erfolg');
    });

    test('unavailable artifact destination fails without success history', () async {
      await upsertUnternehmen(berater: '123', mandant: '456', kontoBank: '1200');
      final int before =
          ((await db.executor.runSelect(
                    'SELECT COUNT(*) AS count FROM datev_export_log',
                    const <Object?>[],
                  )).single['count']!
                  as num)
              .toInt();

      await expectLater(
        service.exportCsv(jahr: 2025, destinationPath: '${Directory.systemTemp.path}/does-not-exist/datev.csv'),
        throwsA(isA<DatevException>()),
      );

      final int after =
          ((await db.executor.runSelect(
                    'SELECT COUNT(*) AS count FROM datev_export_log',
                    const <Object?>[],
                  )).single['count']!
                  as num)
              .toInt();
      expect(after, before);
    });
  });
}

Future<void> _ensureDatevColumns(AppDatabase db) async {
  final List<Map<String, Object?>> uCols = await db.executor.runSelect(
    'PRAGMA table_info(unternehmen)',
    const <Object?>[],
  );
  final Set<String> uNames = <String>{for (final Map<String, Object?> r in uCols) r['name'].toString()};
  if (!uNames.contains('datev_beraternummer')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN datev_beraternummer TEXT');
  }
  if (!uNames.contains('datev_mandantennummer')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN datev_mandantennummer TEXT');
  }
  if (!uNames.contains('datev_konto_bank')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN datev_konto_bank TEXT');
  }
  if (!uNames.contains('datev_konto_bar')) {
    await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN datev_konto_bar TEXT');
  }
  final List<Map<String, Object?>> kCols = await db.executor.runSelect('PRAGMA table_info(konten)', const <Object?>[]);
  final Set<String> kNames = <String>{for (final Map<String, Object?> r in kCols) r['name'].toString()};
  if (!kNames.contains('datev_kontonummer')) {
    await db.executor.runCustom('ALTER TABLE konten ADD COLUMN datev_kontonummer TEXT');
  }
}
