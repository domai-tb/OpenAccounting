// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/datev_entity.dart';
import 'package:openaccounting/features/accounting/datev_service.dart';
import 'package:openaccounting/features/accounting/euer_entity.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/accounting/eks_entity.dart';
import 'package:openaccounting/features/accounting/eks_service.dart';
import 'package:openaccounting/features/accounting/ustva_entity.dart';
import 'package:openaccounting/features/accounting/ustva_service.dart';

void main() {
  group('Tax reporting and export integrity', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await _ensureColumn(db, 'journal', 'kunde_id', 'INTEGER');
      await _ensureColumn(db, 'anlageverzeichnis', 'verkauft_am', 'TEXT');
    });

    tearDown(() async {
      await db.close();
    });

    test('UStVA uses journal direction and reports reverse charge on its net base', () async {
      await _insertJournal(db, betrag: '119.00', datum: '2026-09-01', ustSatz: '19');
      await _insertJournal(db, betrag: '200.00', datum: '2026-09-02', ustSatz: '19', belegTyp: 'Ausgabe');
      await _insertJournal(db, betrag: '500.00', datum: '2026-09-03', ustSatz: '19', ustSonderfall: '13b_abs1');

      final UstvaResult result = await UstvaService(db.executor)
          .compute(jahr: 2026, monatOrQuartal: 9, rhythmus: 'monatlich');

      expect(result.kz1, '119.00');
      expect(result.kz3, '19.00');
      expect(result.kz89, '500.00');
      expect(result.kz93, '95.00');
      expect(result.kz4, '0.00');
    });

    test('UStVA service returns every required Kennzahl, including zero values', () async {
      final UstvaResult result = await UstvaService(db.executor)
          .compute(jahr: 2026, monatOrQuartal: 9, rhythmus: 'monatlich');

      for (int key = 1; key <= 22; key++) {
        expect(result.kzValue('$key'), '0.00', reason: 'UStVA KZ $key must be present');
      }
    });

    test('EÜR calculates profit from booking direction, independent of EÜR line number', () async {
      await _insertKategorie(db, id: 801, euerZeile: 60, bezeichnung: 'Income on expense line');
      await _insertKategorie(db, id: 802, euerZeile: 12, bezeichnung: 'Expense on income line');
      await _insertJournal(db, kategorieId: 801, betrag: '200.00', datum: '2026-01-10');
      await _insertJournal(db, kategorieId: 802, betrag: '80.00', datum: '2026-01-11', belegTyp: 'Ausgabe');

      final EuerResult result = await EuerService(db.executor).generate(jahr: 2026);

      expect(result.zeile(60), '200.00');
      expect(result.zeile(12), '80.00');
      expect(result.gewinn, '120.00');
    });

    test('EÜR prorates depreciation through the disposal month', () async {
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis '
        '(bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, privatanteil, status, verkauft_am) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Disposed laptop', '2026-01-01', '1200.00', 3, '0', 'aktiv', '2026-06-15'],
      );

      final EuerResult result = await EuerService(db.executor).generate(jahr: 2026);

      expect(result.zeile(33), '200.00');
    });

    test('EÜR uses the configured cutover deterministically', () async {
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (betrag, faelligkeit, status) VALUES (?, ?, ?)',
        <Object?>['19.00', '2026-03-01', 'offen'],
      );
      final EuerService service = EuerService(db.executor, defaultCutoverDatum: DateTime(2026));

      final EuerResult first = await service.generate(jahr: 2026);
      final EuerResult second = await service.generate(jahr: 2026);

      expect(first.vorsteuerBetrag, '19.00');
      expect(second.vorsteuerBetrag, first.vorsteuerBetrag);
    });

    test('DATEV writes a reopenable artifact and records its actual path', () async {
      await _configureUnternehmen(db, berater: '123', mandant: '456', kontoBank: '1200');
      await _insertKategorie(db, id: 901, euerZeile: null, skr03: '8400');
      await _insertJournal(db, kategorieId: 901, betrag: '10.005', datum: '2026-04-01');
      final Directory directory = await Directory.systemTemp.createTemp('openaccounting-tax-audit-');
      addTearDown(() => directory.delete(recursive: true));
      final String path = '${directory.path}/buchungsstapel.csv';

      final String csv = await DatevService(db.executor).exportCsv(jahr: 2026, destinationPath: path);
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

    test('DATEV reports an unavailable artifact destination without success history', () async {
      await _configureUnternehmen(db, berater: '123', mandant: '456', kontoBank: '1200');
      final int before = await _count(db, 'datev_export_log');
      final String path = '${Directory.systemTemp.path}/missing-openaccounting-tax-audit/datev.csv';

      await expectLater(
        DatevService(db.executor).exportCsv(jahr: 2026, destinationPath: path),
        throwsA(isA<DatevException>()),
      );

      expect(await _count(db, 'datev_export_log'), before);
    });

    test('EKS scopes journal rows to the requested customer and exposes all-customer mode', () async {
      final int customerA = await _insertKunde(db, 'Customer A');
      final int customerB = await _insertKunde(db, 'Customer B');
      await _insertKategorie(db, id: 950, euerZeile: null, eksKategorie: 'F23');
      await _insertJournal(db, kategorieId: 950, betrag: '100.00', datum: '2026-05-01', kundeId: customerA);
      await _insertJournal(db, kategorieId: 950, betrag: '200.00', datum: '2026-05-02', kundeId: customerB);

      final EksService service = EksService(db.executor);
      final EksResult scoped = await service.generate(jahr: 2026, kundeId: customerA);
      final EksResult unscoped = await service.generate(jahr: 2026);

      expect(scoped.kundeId, customerA);
      expect(scoped.isUnscoped, isFalse);
      expect(scoped.page9.totalIncome, '100.00');
      expect(unscoped.kundeId, isNull);
      expect(unscoped.isUnscoped, isTrue);
      expect(unscoped.page9.totalIncome, '300.00');
      await expectLater(service.generate(jahr: 2026, kundeId: 999999), throwsA(isA<EksException>()));
    });
  });
}

Future<void> _ensureColumn(AppDatabase db, String table, String column, String definition) async {
  final List<Map<String, Object?>> columns = await db.executor.runSelect(
    'PRAGMA table_info($table)',
    const <Object?>[],
  );
  if (!columns.any((Map<String, Object?> row) => row['name'] == column)) {
    await db.executor.runCustom('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}

Future<void> _configureUnternehmen(
  AppDatabase db, {
  required String berater,
  required String mandant,
  required String kontoBank,
}) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'SELECT id FROM unternehmen LIMIT 1',
    const <Object?>[],
  );
  if (rows.isEmpty) {
    await db.executor.runInsert(
      'INSERT INTO unternehmen (name, datev_beraternummer, datev_mandantennummer, datev_konto_bank) VALUES (?, ?, ?, ?)',
      <Object?>['Tax audit company', berater, mandant, kontoBank],
    );
  } else {
    await db.executor.runUpdate(
      'UPDATE unternehmen SET datev_beraternummer = ?, datev_mandantennummer = ?, datev_konto_bank = ? WHERE id = ?',
      <Object?>[berater, mandant, kontoBank, rows.first['id']],
    );
  }
}

Future<int> _insertKunde(AppDatabase db, String name) {
  return db.executor.runInsert('INSERT INTO kunden (name, strasse, plz, ort) VALUES (?, ?, ?, ?)', <Object?>[
    name,
    'Teststraße 1',
    '10115',
    'Berlin',
  ]);
}

Future<void> _insertKategorie(
  AppDatabase db, {
  required int id,
  required int? euerZeile,
  String? eksKategorie,
  String? skr03,
  String bezeichnung = 'Tax audit category',
}) async {
  await db.executor.runInsert(
    'INSERT OR REPLACE INTO kategorien '
    '(id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, eks_kategorie) VALUES (?, ?, ?, ?, ?, 1, ?)',
    <Object?>[id, bezeichnung, skr03 ?? '8400', skr03 ?? '8400', euerZeile, eksKategorie],
  );
}

Future<void> _insertJournal(
  AppDatabase db, {
  required String betrag,
  required String datum,
  String belegTyp = 'Einnahme',
  String? ustSatz,
  String? ustSonderfall,
  int? kategorieId,
  int? kundeId,
}) async {
  await db.executor.runInsert(
    'INSERT INTO journal '
    '(datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable, ust_satz, ust_sonderfall, kunde_id) '
    'VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?)',
    <Object?>[datum, 'Tax audit booking', kategorieId, betrag, belegTyp, ustSatz, ustSonderfall, kundeId],
  );
}

Future<int> _count(AppDatabase db, String table) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'SELECT COUNT(*) AS count FROM $table',
    const <Object?>[],
  );
  return (rows.single['count']! as num).toInt();
}
