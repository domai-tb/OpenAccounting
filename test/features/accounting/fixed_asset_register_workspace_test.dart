import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/assets/asset_repository.dart';
import 'package:openaccounting/features/assets/asset_schedule_service.dart';
import 'package:openaccounting/features/assets/asset_usecases.dart';

/// Accounting Anlagenverzeichnis contract (delta spec, group 1).
void main() {
  group('Fixed asset register workspace — accounting', () {
    late AppDatabase db;
    late AssetRegisterUseCases assets;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      assets = AssetRegisterUseCases(AssetRepository(db.executor));
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> journalCount() async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM journal',
        const <Object?>[],
      );
      return (rows.single['c']! as num).toInt();
    }

    test('test_asset_registration', () async {
      final asset = await assets.createAsset(
        bezeichnung: 'Büro-PC',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );
      const AssetScheduleService service = AssetScheduleService();
      final AssetScheduleRow row = service.computeRow(asset: asset, jahr: 2024);

      expect(row.isAvailable, isTrue);
      expect(row.betrag, '333.33');
      expect(row.anlageId, asset.id);
      expect(row.formel, contains('1000.00 / 3'));
      expect(row.quellSnapshot, contains('1000.00'));
      expect(await journalCount(), 0);
    });

    test('test_kfz_with_private_share', () async {
      final asset = await assets.createAsset(
        bezeichnung: 'Betriebs-KFZ',
        assetTyp: 'KFZ',
        anschaffungsdatum: '2022-03-10',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
        privatAnteilProzent: '30',
      );
      const AssetScheduleService service = AssetScheduleService();
      final AssetScheduleRow row = service.computeRow(asset: asset, jahr: 2024);

      expect(row.isAvailable, isTrue);
      expect(row.betrag, '233.33');
    });

    test('test_non_kfz_private_use_amount_remains_unavailable', () async {
      // Migrated data may carry a private share on non-KFZ types; the KFZ
      // reduction must not be applied by analogy.
      final int id = await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'status, privatanteil, asset_typ, kaufpreis_netto, nutzungsdauer_jahre, afa_methode, '
        'privat_anteil_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Büro-PC', '2022-06-15', '1000.00', 3, 'aktiv', '20', 'EDV', '1000.00', 3, 'linear', '20'],
      );
      final asset = await assets.getAsset(id);
      const AssetScheduleService service = AssetScheduleService();
      final AssetScheduleRow row = service.computeRow(asset: asset!, jahr: 2024);

      expect(row.isAvailable, isFalse);
      expect(row.betrag, isNull);
      expect(row.blockierungsgrund, contains('privatanteil-ohne-regel'));
    });

    test('test_asset_disposal', () async {
      // No accepted disposal-cutoff or remaining-book-value contract exists,
      // so disposal years fail closed instead of stopping AfA by invention.
      final asset = await assets.createAsset(
        bezeichnung: 'Laptop',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-01-10',
        kaufpreisNetto: '1200.00',
        nutzungsdauerJahre: 3,
        verkauftAm: '2025-06-15',
      );
      const AssetScheduleService service = AssetScheduleService();
      final AssetScheduleRow before = service.computeRow(asset: asset, jahr: 2024);
      final AssetScheduleRow disposalYear = service.computeRow(asset: asset, jahr: 2025);

      expect(before.isAvailable, isTrue);
      expect(disposalYear.isAvailable, isFalse);
      expect(disposalYear.betrag, isNull);
      expect(disposalYear.blockierungsgrund, contains('entsorgung-ohne-vertrag'));
      await expectLater(
        EuerService(db.executor).generate(jahr: 2025),
        throwsA(isA<EuerException>().having((EuerException e) => e.message, 'message', contains('${asset.id}'))),
      );
    });

    test('test_aveuer_integration', () async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, '
        'mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[941, 'AfA Kategorie', '4830', '4830', 33, 'catalog_verified', 'TEST-AVEUER', '2026-test.1'],
      );
      // Journal rows pointing at line 33 must be ignored in favour of the schedule owner.
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) '
        'VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2024-07-01', 'AfA Journal', 941, '9999.99', 'Ausgabe'],
      );
      final asset = await assets.createAsset(
        bezeichnung: 'Büro-PC',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );

      final result = await EuerService(db.executor).generate(jahr: 2024);

      expect(result.zeile(33), '333.33');
      final List<Object?> refs = (result.provenanceSnapshot['afa_assets'] as List?) ?? <Object?>[];
      expect(refs.whereType<Map>().any((Map ref) => ref['anlage_id'] == asset.id), isTrue);
    });

    test('test_euer_fails_closed_on_unmapped_legacy_asset_values', () async {
      final int id = await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'status, privatanteil) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Altlaptop', '2022-01-10', '1200.00', 3, 'aktiv', '0'],
      );

      await expectLater(
        EuerService(db.executor).generate(jahr: 2024),
        throwsA(isA<EuerException>().having((EuerException error) => error.message, 'message', contains('$id'))),
      );
    });

    test('test_unresolved_afa_or_disposal_inputs', () async {
      // Missing method with otherwise canonical inputs: fail closed.
      final int id = await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'status, privatanteil, asset_typ, kaufpreis_netto, nutzungsdauer_jahre, afa_methode, '
        'privat_anteil_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Altanlage', '2022-01-10', '1000.00', 3, 'aktiv', '0', 'EDV', '1000.00', 3, null, '0'],
      );
      await expectLater(
        EuerService(db.executor).generate(jahr: 2024),
        throwsA(isA<EuerException>().having((EuerException e) => e.message, 'message', contains('$id'))),
      );
      // Partial acquisition year without an accepted proration rule: also incomplete.
      final partial = await assets.createAsset(
        bezeichnung: 'Neuzugang',
        assetTyp: 'EDV',
        anschaffungsdatum: '2024-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );
      const AssetScheduleService service = AssetScheduleService();
      final AssetScheduleRow row = service.computeRow(asset: partial, jahr: 2024);
      expect(row.isAvailable, isFalse);
      expect(row.betrag, isNull);
    });
  });
}
