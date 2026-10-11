import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/assets/asset_entity.dart';
import 'package:openaccounting/features/assets/asset_repository.dart';
import 'package:openaccounting/features/assets/asset_schedule_service.dart';
import 'package:openaccounting/features/assets/asset_usecases.dart';

/// Reachable register, traceable schedule, and no journal side effect
/// (delta spec, groups 3–5).
void main() {
  group('Fixed asset register workspace', () {
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

    Future<int> count(String table) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM $table',
        const <Object?>[],
      );
      return (rows.single['c']! as num).toInt();
    }

    test('test_create_and_update_an_asset_record', () async {
      final created = await assets.createAsset(
        bezeichnung: 'Büro-PC',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );
      expect(created.bezeichnung, 'Büro-PC');
      expect(created.assetTyp, AssetTyp.edv);
      expect(created.kaufpreisNetto, '1000.00');

      final updated = await assets.updateAsset(created.id, bezeichnung: 'Büro-PC aktualisiert');

      expect(updated.id, created.id);
      expect(updated.bezeichnung, 'Büro-PC aktualisiert');
      expect(updated.kaufpreisNetto, '1000.00');
      // Compat write: the legacy required column carries the same amount.
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT kaufpreis_netto, anschaffungskosten FROM anlageverzeichnis WHERE id = ?',
        <Object?>[created.id],
      );
      expect(money.formatBetrag(rows.single['kaufpreis_netto']!.toString()), '1000.00');
      expect(money.formatBetrag(rows.single['anschaffungskosten']!.toString()), '1000.00');
      expect(await count('journal'), 0);
    });

    test('test_reject_invalid_new_asset_inputs', () async {
      Future<void> expectField(Future<void> Function() call, String field) {
        return expectLater(
          call(),
          throwsA(isA<AssetValidationException>().having((AssetValidationException e) => e.field, 'field', field)),
        );
      }

      await expectField(
        () => assets.createAsset(
          bezeichnung: ' ',
          assetTyp: 'EDV',
          anschaffungsdatum: '2022-06-15',
          kaufpreisNetto: '100.00',
          nutzungsdauerJahre: 3,
        ),
        'bezeichnung',
      );
      await expectField(
        () => assets.createAsset(
          bezeichnung: 'PC',
          assetTyp: 'RAUMSCHIFF',
          anschaffungsdatum: '2022-06-15',
          kaufpreisNetto: '100.00',
          nutzungsdauerJahre: 3,
        ),
        'asset_typ',
      );
      await expectField(
        () => assets.createAsset(
          bezeichnung: 'PC',
          assetTyp: 'EDV',
          anschaffungsdatum: 'kein-datum',
          kaufpreisNetto: '100.00',
          nutzungsdauerJahre: 3,
        ),
        'anschaffungsdatum',
      );
      await expectField(
        () => assets.createAsset(
          bezeichnung: 'PC',
          assetTyp: 'EDV',
          anschaffungsdatum: '2022-06-15',
          kaufpreisNetto: '-5.00',
          nutzungsdauerJahre: 3,
        ),
        'kaufpreis_netto',
      );
      await expectField(
        () => assets.createAsset(
          bezeichnung: 'PC',
          assetTyp: 'EDV',
          anschaffungsdatum: '2022-06-15',
          kaufpreisNetto: '100.00',
          nutzungsdauerJahre: 0,
        ),
        'nutzungsdauer_jahre',
      );
      await expectField(
        () => assets.createAsset(
          bezeichnung: 'PC',
          assetTyp: 'EDV',
          anschaffungsdatum: '2022-06-15',
          kaufpreisNetto: '100.00',
          nutzungsdauerJahre: 3,
          privatAnteilProzent: '101',
        ),
        'privat_anteil_prozent',
      );
      await expectField(
        () => assets.createAsset(
          bezeichnung: 'KFZ',
          assetTyp: 'KFZ',
          anschaffungsdatum: '2022-06-15',
          kaufpreisNetto: '100.00',
          nutzungsdauerJahre: 3,
          afaMethode: 'degressiv',
        ),
        'afa_methode',
      );
      expect(await count('anlageverzeichnis'), 0);
    });

    test('test_preserve_assets_with_schedule_history', () async {
      final asset = await assets.createAsset(
        bezeichnung: 'Büro-PC',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );
      await assets.generateSchedule(anlageId: asset.id, jahr: 2024);

      await expectLater(assets.deleteAsset(asset.id), throwsA(isA<AssetInUseException>()));
      expect(await assets.getAsset(asset.id), isNotNull);

      final archived = await assets.archiveAsset(asset.id);
      expect(archived.id, asset.id);
      expect(archived.status, 'archiviert');
      expect(await assets.getAsset(asset.id), isNotNull);
    });

    test('test_do_not_reinterpret_legacy_asset_fields', () async {
      final int id = await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'status, privatanteil) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Altlaptop', '2021-04-02', '899.99', 3, 'aktiv', '12.50'],
      );
      final asset = await assets.getAsset(id);

      expect(asset, isNotNull);
      expect(asset!.kaufpreisNetto, isNull);
      expect(asset.nutzungsdauerJahre, isNull);
      expect(asset.hasUnresolvedLegacy, isTrue);
      expect(asset.legacyAnschaffungskosten, '899.99');
      const AssetScheduleService service = AssetScheduleService();
      final AssetScheduleRow row = service.computeRow(asset: asset, jahr: 2024);
      expect(row.isAvailable, isFalse);
      expect(row.betrag, isNull);
    });

    test('test_fail_closed_on_malformed_persisted_canonical_amount', () async {
      final int id = await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'status, asset_typ, kaufpreis_netto, nutzungsdauer_jahre, afa_methode, privat_anteil_prozent) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Büro-PC', '2022-06-15', '1000.00', 3, 'aktiv', 'EDV', 'unbekannt', 3, 'linear', '0'],
      );
      final FixedAsset asset = (await assets.getAsset(id))!;
      const AssetScheduleService service = AssetScheduleService();
      final AssetScheduleRow row = service.computeRow(asset: asset, jahr: 2024);

      expect(asset.kaufpreisNetto, isNull);
      expect(row.isAvailable, isFalse);
      expect(row.betrag, isNull);
      expect(row.blockierungsgrund, contains('unaufgeloeste-quelle'));
    });

    test('test_show_a_supported_full_year_linear_amount', () async {
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
      expect(row.anlageId, asset.id);
      expect(row.formel, '1000.00 / 3 × 70%');
      expect(row.betrag, '233.33');
      expect(row.blockierungsgrund, isNull);

      // Useful-life bound with independent half-up cent rounding, no remainder adjustment.
      final plain = await assets.createAsset(
        bezeichnung: 'Büro-PC',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );
      final List<AssetScheduleRow> full = service.fullSchedule(plain);
      expect(full.length, 3);
      expect(full.map((AssetScheduleRow r) => r.betrag), everyElement('333.33'));
      final AssetScheduleRow beyond = service.computeRow(asset: plain, jahr: 2026);
      expect(beyond.isAvailable, isFalse);
      expect(beyond.betrag, isNull);
      expect(beyond.blockierungsgrund, contains('nutzungsdauer-ueberschritten'));
    });

    test('test_non_kfz_private_use_rule_is_unresolved', () async {
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

    test('test_fail_closed_on_partial_year_or_disposal_calculations', () async {
      final asset = await assets.createAsset(
        bezeichnung: 'Neuzugang',
        assetTyp: 'EDV',
        anschaffungsdatum: '2024-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );
      const AssetScheduleService service = AssetScheduleService();
      final AssetScheduleRow acquisitionYear = service.computeRow(asset: asset, jahr: 2024);
      expect(acquisitionYear.isAvailable, isFalse);
      expect(acquisitionYear.betrag, isNull);
      expect(acquisitionYear.blockierungsgrund, contains('anschaffungsjahr-teiljahr'));

      final disposed = await assets.createAsset(
        bezeichnung: 'Laptop',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-01-10',
        kaufpreisNetto: '1200.00',
        nutzungsdauerJahre: 3,
        verkauftAm: '2024-06-15',
      );
      final AssetScheduleRow disposalYear = service.computeRow(asset: disposed, jahr: 2024);
      expect(disposalYear.isAvailable, isFalse);
      expect(disposalYear.betrag, isNull);
      expect(disposalYear.blockierungsgrund, contains('entsorgung-ohne-vertrag'));
    });

    test('test_fail_closed_on_ambiguous_source_values', () async {
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'status, privatanteil) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Altlaptop', '2021-04-02', '899.99', 3, 'aktiv', '12.50'],
      );
      await assets.createAsset(
        bezeichnung: 'Büro-PC',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );

      final AssetAfaConsumption consumption = await assets.consumeCompleteAfa(2024);

      expect(consumption.total, '333.33');
      expect(consumption.incomplete.length, 1);
      expect(consumption.assetRefs.length, 1);
    });

    test('test_save_an_asset_without_posting', () async {
      final before = await count('journal');
      final created = await assets.createAsset(
        bezeichnung: 'Büro-PC',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );
      await assets.updateAsset(created.id, bezeichnung: 'Büro-PC v2');
      await assets.generateFullSchedule(created.id);

      expect(await count('journal'), before);
      expect(await count('vorsteuer_ansprueche'), 0);
    });

    test('test_block_an_unsupported_financial_effect', () async {
      final before = await count('journal');
      await expectLater(assets.requestFinancialEffect('abschreibung-buchen'), throwsA(isA<AssetPostingUnavailable>()));
      expect(await count('journal'), before);
    });
  });
}
