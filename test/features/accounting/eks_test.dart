import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/eks_entity.dart';
import 'package:openaccounting/features/accounting/eks_service.dart';

void main() {
  group('Anlage EKS 9-page — Jobcenter Transferleistungen', () {
    late AppDatabase db;
    late EksService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await _ensureEksColumns(db);
      service = EksService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertKategorie({
      required int id,
      required String eksKategorie,
      String bezeichnung = 'EKS Kat',
    }) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, eks_kategorie) VALUES (?, ?, ?, ?, ?, 1, ?)',
        <Object?>[id, bezeichnung, '800$id', '400$id', null, eksKategorie],
      );
    }

    Future<void> insertJournal({
      required int kategorieId,
      required String betrag,
      required String datum,
      String art = 'Einnahme',
      String? kmAnzahl,
    }) async {
      // ponytail: insert with km_anzahl if column exists
      if (kmAnzahl != null) {
        await db.executor.runInsert(
          'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable, km_anzahl) VALUES (?, ?, ?, ?, ?, 0, ?)',
          <Object?>[datum, 'Test $kategorieId', kategorieId, betrag, art, kmAnzahl],
        );
      } else {
        await db.executor.runInsert(
          'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
          <Object?>[datum, 'Test $kategorieId', kategorieId, betrag, art],
        );
      }
    }

    Future<void> upsertUnternehmen({
      String? berufsbezeichnung,
      String? kammer,
      String? geburtsdatum,
      String? bgNummer,
      String? jobcenter,
    }) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT id FROM unternehmen LIMIT 1',
        const <Object?>[],
      );
      if (rows.isEmpty) {
        await db.executor.runInsert(
          'INSERT INTO unternehmen (name, berufsbezeichnung, kammer_mitgliedschaft, geburtsdatum, bg_nummer, jobcenter_name) VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>['Test Firma', berufsbezeichnung, kammer, geburtsdatum, bgNummer, jobcenter],
        );
      } else {
        final int id = (rows.first['id'] as num).toInt();
        await db.executor.runCustom(
          'UPDATE unternehmen SET berufsbezeichnung=?, kammer_mitgliedschaft=?, geburtsdatum=?, bg_nummer=?, jobcenter_name=? WHERE id=?',
          <Object?>[berufsbezeichnung, kammer, geburtsdatum, bgNummer, jobcenter, id],
        );
      }
    }

    test('Section D — populated from unternehmen fields', () async {
      await upsertUnternehmen(
        berufsbezeichnung: 'Freiberufler IT',
        kammer: 'IHK Berlin',
        geburtsdatum: '1985-04-12',
        bgNummer: '123456BG789',
        jobcenter: 'JC Berlin Mitte',
      );

      final EksResult result = await service.generate(jahr: 2025);

      expect(result.sectionD.berufsbezeichnung, 'Freiberufler IT');
      expect(result.sectionD.kammerMitgliedschaft, 'IHK Berlin');
      expect(result.sectionD.geburtsdatum, '1985-04-12');
      expect(result.sectionD.bgNummer, '123456BG789');
      expect(result.sectionD.jobcenterName, 'JC Berlin Mitte');
      // String money pure check - sectionD fields are strings, not money
      expect(result.jahr, 2025);
    });

    test('Section F Zeilen 23-41 from journal via eks_kategorie', () async {
      await upsertUnternehmen(bgNummer: 'BG1', jobcenter: 'JC1');
      await insertKategorie(id: 701, eksKategorie: 'F23', bezeichnung: 'Einnahmen F23');
      await insertKategorie(id: 702, eksKategorie: 'F30', bezeichnung: 'Kosten F30');
      await insertKategorie(id: 703, eksKategorie: 'F41', bezeichnung: 'Sonstiges F41');
      await insertKategorie(id: 704, eksKategorie: 'B6_5', bezeichnung: 'Travel B6_5');
      // Only F23,F30,F41 should be in sectionF (23-41), B6_5 is separate but still via eks_kategorie
      await insertJournal(kategorieId: 701, betrag: '1000.00', datum: '2025-02-10', art: 'Einnahme');
      await insertJournal(kategorieId: 701, betrag: '500.00', datum: '2025-03-10', art: 'Einnahme');
      await insertJournal(kategorieId: 702, betrag: '200.00', datum: '2025-04-10', art: 'Ausgabe');
      await insertJournal(kategorieId: 703, betrag: '300.00', datum: '2025-05-10', art: 'Ausgabe');
      // Different year must be ignored
      await insertJournal(kategorieId: 701, betrag: '9999.00', datum: '2024-06-10', art: 'Einnahme');

      final EksResult result = await service.generate(jahr: 2025);

      expect(result.sectionF['F23'], '1500.00');
      expect(result.sectionF['F30'], '200.00');
      expect(result.sectionF['F41'], '300.00');
      // String money pure 2 decimals
      expect(result.sectionF['F23'], matches(RegExp(r'^-?\d+\.\d{2}$')));
      // Ensure 2024 not counted
      expect(result.sectionF['F23'] != '11499.00', isTrue);
    });

    test('B6_5 km_anzahl *0.10 travel allowance', () async {
      await upsertUnternehmen(bgNummer: 'BG1', jobcenter: 'JC1');
      await insertKategorie(id: 710, eksKategorie: 'B6_5', bezeichnung: 'Fahrtkosten');
      await insertKategorie(id: 711, eksKategorie: 'F23', bezeichnung: 'Einnahmen');
      // 100km =>10.00, 50km=>5.00 total 15.00
      await insertJournal(kategorieId: 710, betrag: '0.00', datum: '2025-06-10', art: 'Ausgabe', kmAnzahl: '100');
      await insertJournal(kategorieId: 710, betrag: '0.00', datum: '2025-06-15', art: 'Ausgabe', kmAnzahl: '50');
      await insertJournal(kategorieId: 711, betrag: '1000.00', datum: '2025-06-10', art: 'Einnahme');
      // Different year ignored
      await insertJournal(kategorieId: 710, betrag: '0.00', datum: '2024-06-10', art: 'Ausgabe', kmAnzahl: '999');

      final EksResult result = await service.generate(jahr: 2025);

      expect(result.b6_5, '15.00');
      expect(result.b6_5, matches(RegExp(r'^-?\d+\.\d{2}$')));
    });

    test('B6_4_priv Betriebs-KFZ privat_anteil_prozent deduction via anlageverzeichnis', () async {
      await upsertUnternehmen(bgNummer: 'BG1', jobcenter: 'JC1');
      // KFZ 1200 /3=400 *30% =120.00
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Betriebs-KFZ', '2025-01-01', '1200.00', 3, '30', 'aktiv'],
      );

      final EksResult result = await service.generate(jahr: 2025);

      expect(result.b6_4_priv, '120.00');
      expect(result.b6_4_priv, matches(RegExp(r'^-?\d+\.\d{2}$')));
    });

    test('Page9 summary total income/costs/net', () async {
      await upsertUnternehmen(bgNummer: 'BG1', jobcenter: 'JC1');
      await insertKategorie(id: 720, eksKategorie: 'F23', bezeichnung: 'Einnahmen');
      await insertKategorie(id: 721, eksKategorie: 'F30', bezeichnung: 'Kosten');
      await insertKategorie(id: 722, eksKategorie: 'B6_5', bezeichnung: 'Travel');
      await insertJournal(kategorieId: 720, betrag: '2000.00', datum: '2025-03-10', art: 'Einnahme');
      await insertJournal(kategorieId: 720, betrag: '500.00', datum: '2025-04-10', art: 'Einnahme');
      await insertJournal(kategorieId: 721, betrag: '800.00', datum: '2025-05-10', art: 'Ausgabe');
      // Travel 100km =>10.00
      await insertJournal(kategorieId: 722, betrag: '0.00', datum: '2025-06-10', art: 'Ausgabe', kmAnzahl: '100');
      // KFZ private 120.00 (1200/3*30%)
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Betriebs-KFZ', '2025-01-01', '1200.00', 3, '30', 'aktiv'],
      );

      final EksResult result = await service.generate(jahr: 2025);

      // totalIncome = 2500.00
      expect(result.page9.totalIncome, '2500.00');
      // totalCosts = 800.00 + 10.00 +120.00 =930.00
      expect(result.page9.totalCosts, '930.00');
      // net = 2500-930=1570.00
      expect(result.page9.netResult, '1570.00');
      expect(result.page9.netResult, matches(RegExp(r'^-?\d+\.\d{2}$')));
      // 9-page structure: ensure page9 present and income/costs/net strings
      expect(result.page9.totalIncome, isNotEmpty);
      expect(result.page9.totalCosts, isNotEmpty);
    });

    test('Missing bg_nummer/jobcenter → empty + warn log not fail', () async {
      // Unternehmen without bg/jobcenter
      await upsertUnternehmen(
        berufsbezeichnung: 'Freiberufler',
        kammer: null,
        geburtsdatum: null,
        bgNummer: null,
        jobcenter: null,
      );
      await insertKategorie(id: 730, eksKategorie: 'F23', bezeichnung: 'Einnahmen');
      await insertJournal(kategorieId: 730, betrag: '100.00', datum: '2025-07-10', art: 'Einnahme');

      final List<String> prints = <String>[];
      final EksResult result = await _capturePrints(() => service.generate(jahr: 2025), prints);

      // Must not throw, fields empty
      expect(result.sectionD.bgNummer, '');
      expect(result.sectionD.jobcenterName, '');
      // Must log warning via debugPrint
      final bool hasWarn = prints.any(
        (String s) =>
            s.toLowerCase().contains('warn') && (s.contains('bg') || s.contains('jobcenter') || s.contains('eks')),
      );
      expect(hasWarn, isTrue, reason: 'Expected warn log for missing bg_nummer/jobcenter, prints: $prints');
      // Still succeeds with income
      expect(result.page9.totalIncome, '100.00');
      expect(result.sectionF['F23'], '100.00');
    });

    test('Empty period all 0 and page9 net 0', () async {
      await upsertUnternehmen(bgNummer: 'BG1', jobcenter: 'JC1');
      final EksResult result = await service.generate(jahr: 2024);
      expect(result.page9.totalIncome, '0.00');
      expect(result.page9.totalCosts, '0.00');
      expect(result.page9.netResult, '0.00');
      expect(result.b6_5, '0.00');
      expect(result.b6_4_priv, '0.00');
      // sectionF values 0.00 for missing keys via helper or missing
      expect(result.sectionF.isEmpty || result.sectionF.values.every((String v) => v == '0.00'), isTrue);
    });

    test('kundeId filter does not break generation', () async {
      await upsertUnternehmen(bgNummer: 'BG1', jobcenter: 'JC1');
      await insertKategorie(id: 740, eksKategorie: 'F23', bezeichnung: 'Einnahmen');
      await insertJournal(kategorieId: 740, betrag: '300.00', datum: '2025-08-10', art: 'Einnahme');
      // Should accept kundeId optional
      final EksResult result = await service.generate(jahr: 2025, kundeId: 999);
      expect(result.sectionF['F23'], '300.00');
    });
  });
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
  // also legacy jobcenter column
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
  // schnellbuchungen and eks_einstellungen already exist, ensure not missing
  try {
    await db.executor.runSelect('SELECT * FROM eks_einstellungen LIMIT 1', const <Object?>[]);
  } catch (_) {}
  try {
    await db.executor.runSelect('SELECT * FROM schnellbuchungen LIMIT 1', const <Object?>[]);
  } catch (_) {}
}

Future<T> _capturePrints<T>(Future<T> Function() fn, List<String> out) async {
  final DebugPrintCallback? old = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      out.add(message);
    }
  };
  try {
    final T result = await runZoned<Future<T>>(
      () async => await fn(),
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          out.add(line);
          parent.print(zone, line);
        },
      ),
    );
    return result;
  } finally {
    debugPrint = old!;
  }
}
