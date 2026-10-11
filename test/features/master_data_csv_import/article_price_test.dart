import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_parser.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_service.dart';

/// Article prices: single-basis create, price-preserving update, price rejection on update.
void main() {
  group('Article prices', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_csv_article_price_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    Future<AppDatabase> openDatabase() async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      return db;
    }

    Future<Map<String, Object?>> articleRow(AppDatabase db, int id) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT bezeichnung, beschreibung, vk_netto, vk_brutto, vk_eingabe, ust_satz, ust_satz_id, '
        'differenzbesteuerung, ek_netto FROM artikel WHERE id = ?',
        <Object?>[id],
      );
      return rows.single;
    }

    Future<int> articleIdByNumber(AppDatabase db, String number) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT id FROM artikel WHERE artikelnummer = ?',
        <Object?>[number],
      );
      return rows.single['id']! as int;
    }

    test('test_master_data_csv_import_create_an_article_from_one_selected_price_basis', () async {
      final AppDatabase db = await openDatabase();
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      const MasterDataFieldMapping mapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.article,
        columnToField: <int, String>{0: 'bezeichnung', 1: 'typ', 2: 'vk_brutto', 3: 'ust_satz'},
        hasHeader: false,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
        articlePriceBasis: ArticlePriceBasis.gross,
      );
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Drucker P1;Artikel;119,00;19',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: false,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      expect(preview.rows.single.isValid, isTrue);

      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{preview.rows.single.sourceRowNumber: MasterDataRowSelection.create},
        ),
        mapping,
      );
      expect(result.created, 1);

      // The existing create validator derives and persists the paired prices.
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT vk_netto, vk_brutto, vk_eingabe, ust_satz FROM artikel WHERE bezeichnung = ?',
        const <Object?>['Drucker P1'],
      );
      expect(rows, hasLength(1));
      expect((rows.single['vk_brutto']! as num).toDouble(), closeTo(119.0, 0.001));
      expect((rows.single['vk_netto']! as num).toDouble(), closeTo(100.0, 0.01));
      expect(rows.single['vk_eingabe'], 'brutto');
      expect((rows.single['ust_satz']! as num).toDouble(), closeTo(19.0, 0.001));
    });

    test('test_master_data_csv_import_update_other_article_fields_while_preserving_prices', () async {
      final AppDatabase db = await openDatabase();
      final ArtikelRepository artikel = ArtikelRepository(db.executor);
      final Artikel stored = await artikel.create(
        bezeichnung: 'Drucker',
        beschreibung: 'Alte Beschreibung',
        vkBrutto: 119,
        ustSatz: 19,
        artikelnummer: 'A-100',
      );
      final Map<String, Object?> before = await articleRow(db, stored.id);
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      const MasterDataFieldMapping mapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.article,
        columnToField: <int, String>{0: 'artikelnummer', 1: 'beschreibung'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.update,
        matchField: 'artikelnummer',
        articlePriceBasis: ArticlePriceBasis.gross,
      );
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Artikelnummer;Beschreibung\nA-100;Neue Beschreibung',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      expect(preview.rows.single.proposedAction, MasterDataRowAction.update);

      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{preview.rows.single.sourceRowNumber: MasterDataRowSelection.update},
        ),
        mapping,
      );
      expect(result.updated, 1);

      final Map<String, Object?> after = await articleRow(db, stored.id);
      expect(after['beschreibung'], 'Neue Beschreibung');
      expect(after['vk_netto'], before['vk_netto']);
      expect(after['vk_brutto'], before['vk_brutto']);
      expect(after['vk_eingabe'], before['vk_eingabe']);
      expect(after['ust_satz'], before['ust_satz']);
      expect(after['ust_satz_id'], before['ust_satz_id']);
      expect(after['differenzbesteuerung'], before['differenzbesteuerung']);
    });

    test('test_master_data_csv_import_reject_supplied_price_fields_on_article_update', () async {
      final AppDatabase db = await openDatabase();
      final ArtikelRepository artikel = ArtikelRepository(db.executor);
      final Artikel stored = await artikel.create(
        bezeichnung: 'Drucker',
        beschreibung: 'Alte Beschreibung',
        vkBrutto: 119,
        ustSatz: 19,
        artikelnummer: 'A-200',
      );
      final Map<String, Object?> before = await articleRow(db, stored.id);
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      const MasterDataFieldMapping mapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.article,
        columnToField: <int, String>{0: 'artikelnummer', 1: 'beschreibung', 2: 'vk_netto'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.update,
        matchField: 'artikelnummer',
        articlePriceBasis: ArticlePriceBasis.gross,
      );
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Artikelnummer;Beschreibung;vk_netto\nA-200;Geändert;50,00',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      final MasterDataRowPreview row = preview.rows.single;
      expect(row.isValid, isFalse);
      expect(row.proposedAction, MasterDataRowAction.invalid);
      expect(row.errors.map((MasterDataFieldError e) => e.field), contains('vk_netto'));
      expect(row.errors.singleWhere((MasterDataFieldError e) => e.field == 'vk_netto').messageDe, contains('vk_netto'));

      // The row is unavailable for update and writes none of its fields.
      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{row.sourceRowNumber: MasterDataRowSelection.update},
        ),
        mapping,
      );
      expect(result.isFailure, isTrue);
      final Map<String, Object?> after = await articleRow(db, stored.id);
      expect(after['beschreibung'], 'Alte Beschreibung');
      expect(after['vk_netto'], before['vk_netto']);
      expect(after['vk_brutto'], before['vk_brutto']);
      expect(after['vk_eingabe'], before['vk_eingabe']);
      expect(await articleIdByNumber(db, 'A-200'), stored.id);
    });
  });
}
