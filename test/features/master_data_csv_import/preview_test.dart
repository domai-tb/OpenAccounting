import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_parser.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_service.dart';

/// Preview validation: row review, numeric grammar, cancellation.
void main() {
  group('Import preview', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_csv_preview_test_');
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

    MasterDataFieldMapping supplierCreateMapping() {
      return const MasterDataFieldMapping(
        entity: MasterDataImportEntity.supplier,
        columnToField: <int, String>{0: 'name', 1: 'strasse', 2: 'plz', 3: 'ort', 4: 'ust_idnr'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
      );
    }

    MasterDataFieldMapping articleNetMapping() {
      return const MasterDataFieldMapping(
        entity: MasterDataImportEntity.article,
        columnToField: <int, String>{0: 'bezeichnung', 1: 'typ', 2: 'vk_netto'},
        hasHeader: false,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
        articlePriceBasis: ArticlePriceBasis.net,
      );
    }

    Future<int> tableCount(AppDatabase db, String table) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS n FROM $table',
        const <Object?>[],
      );
      final Object? value = rows.single['n'];
      return value is int ? value : int.parse(value.toString());
    }

    test('test_master_data_csv_import_review_valid_and_invalid_rows', () async {
      final AppDatabase db = await openDatabase();
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      const String text =
          'Name;Straße;PLZ;Ort;USt-IdNr\nGut GmbH;Weg 1;10115;Berlin;DE123456789\n'
          'Schlecht AG;Weg 2;80331;;UNGUELTIG';
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        text,
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, supplierCreateMapping());

      expect(preview.rows, hasLength(2));
      expect(preview.validCount, 1);
      expect(preview.invalidCount, 1);
      expect(preview.rows[0].isValid, isTrue);
      expect(preview.rows[0].proposedAction, MasterDataRowAction.create);
      // Second row names its missing address value and invalid VAT ID; nothing is written yet.
      final List<String> fields = <String>[for (final MasterDataFieldError e in preview.rows[1].errors) e.field];
      expect(fields, contains('ort'));
      expect(fields, contains('ust_idnr'));
      expect(preview.rows[1].proposedAction, MasterDataRowAction.invalid);
      expect(preview.rows[1].errors.first.messageDe.isNotEmpty, isTrue);
      expect(await tableCount(db, 'lieferanten'), 0);
    });

    test('test_master_data_csv_import_reject_an_ambiguous_numeric_value', () async {
      final AppDatabase db = await openDatabase();
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Drucker;Artikel;12abc',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: false,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, articleNetMapping());

      expect(preview.rows.single.isValid, isFalse);
      expect(preview.rows.single.proposedAction, MasterDataRowAction.invalid);
      expect(preview.rows.single.errors.map((MasterDataFieldError e) => e.field), contains('vk_netto'));
      // No rounded, default, or guessed price is proposed; the raw cell is preserved as-is.
      expect(preview.rows.single.mappedValues['vk_netto'], '12abc');
      expect(await tableCount(db, 'artikel'), 0);
    });

    test('test_master_data_csv_import_accept_decimal_comma_after_outer_trim', () async {
      expect(MasterDataNumericParser.tryNormalize(' 123,50 ', CsvDecimalConvention.comma), '123.50');

      final AppDatabase db = await openDatabase();
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Drucker;Artikel; 123,50 ',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: false,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, articleNetMapping());
      expect(preview.rows.single.isValid, isTrue);
      expect(preview.rows.single.proposedAction, MasterDataRowAction.create);
    });

    test('test_master_data_csv_import_accept_decimal_point_after_outer_trim', () async {
      expect(MasterDataNumericParser.tryNormalize(' 123.50 ', CsvDecimalConvention.point), '123.50');

      final AppDatabase db = await openDatabase();
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      const MasterDataFieldMapping mapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.article,
        columnToField: <int, String>{0: 'bezeichnung', 1: 'typ', 2: 'vk_netto'},
        hasHeader: false,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.point,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
        articlePriceBasis: ArticlePriceBasis.net,
      );
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Drucker;Artikel; 123.50 ',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: false,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      expect(preview.rows.single.isValid, isTrue);
      expect(preview.rows.single.proposedAction, MasterDataRowAction.create);
    });

    test('test_master_data_csv_import_reject_grouping_alternate_separators_exponents_and_partial_numbers', () async {
      const List<String> invalid = <String>[
        '1,234.56',
        '1.234,56',
        '123,50',
        '123.50',
        '1e3',
        '1E3',
        '1 2',
        '-12',
        '+12',
        '.5',
        '5.',
        '12abc',
        'abc',
        '12,34,56',
      ];
      // Each token is invalid under at least the convention it violates; the
      // grouped and alternate-separator forms fail under both conventions.
      for (final String token in invalid) {
        final bool pointOk = MasterDataNumericParser.tryNormalize(token, CsvDecimalConvention.point) != null;
        final bool commaOk = MasterDataNumericParser.tryNormalize(token, CsvDecimalConvention.comma) != null;
        expect(pointOk && commaOk, isFalse, reason: '$token must not parse under both conventions');
      }
      for (final String token in <String>['1,234.56', '1.234,56', '1e3', '1 2', '-12', '.5', '5.', '12abc']) {
        expect(
          MasterDataNumericParser.tryNormalize(token, CsvDecimalConvention.point),
          isNull,
          reason: '$token must fail with decimal point',
        );
        expect(
          MasterDataNumericParser.tryNormalize(token, CsvDecimalConvention.comma),
          isNull,
          reason: '$token must fail with decimal comma',
        );
      }
      // Opposite separator is rejected: comma value under point and vice versa.
      expect(MasterDataNumericParser.tryNormalize('123,50', CsvDecimalConvention.point), isNull);
      expect(MasterDataNumericParser.tryNormalize('123.50', CsvDecimalConvention.comma), isNull);
      // Plain integers stay valid under either convention.
      expect(MasterDataNumericParser.tryNormalize('123', CsvDecimalConvention.point), '123');
      expect(MasterDataNumericParser.tryNormalize('123', CsvDecimalConvention.comma), '123');

      // End to end: a grouped price fails preview with the numeric field named.
      final AppDatabase db = await openDatabase();
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Drucker;Artikel;1.234,56',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: false,
      );
      final MasterDataImportPreview preview = await service.buildPreview(parsed, articleNetMapping());
      expect(preview.rows.single.isValid, isFalse);
      expect(preview.rows.single.errors.map((MasterDataFieldError e) => e.field), contains('vk_netto'));
    });

    test('test_master_data_csv_import_cancel_before_confirmation', () async {
      final AppDatabase db = await openDatabase();
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      const MasterDataFieldMapping mapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.customer,
        columnToField: <int, String>{0: 'name', 1: 'strasse', 2: 'plz', 3: 'ort'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
      );
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Name;Straße;PLZ;Ort\nNeu GmbH;Weg 1;10115;Berlin',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      // Preparing the complete preview writes nothing.
      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      expect(preview.rows.single.isValid, isTrue);
      expect(await tableCount(db, 'kunden'), 0);

      // Cancelling (excluding every row from the batch) leaves all records unchanged.
      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{
            preview.rows.single.sourceRowNumber: MasterDataRowSelection.excluded,
          },
        ),
        mapping,
      );
      expect(result.created, 0);
      expect(result.updated, 0);
      expect(await tableCount(db, 'kunden'), 0);
      expect(await tableCount(db, 'lieferanten'), 0);
      expect(await tableCount(db, 'artikel'), 0);
    });
  });
}
