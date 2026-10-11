import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_parser.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_service.dart';

/// CSV import scope: mapped customer parsing, invalid-source rejection, header option.
void main() {
  group('CSV import scope', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_csv_scope_test_');
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

    MasterDataFieldMapping customerCreateMapping() {
      return const MasterDataFieldMapping(
        entity: MasterDataImportEntity.customer,
        columnToField: <int, String>{0: 'name', 1: 'strasse', 2: 'plz', 3: 'ort'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
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

    test('test_master_data_csv_import_parse_a_mapped_customer_source', () async {
      final AppDatabase db = await openDatabase();
      const String text =
          'Name;Straße;PLZ;Ort\n"Müller; GmbH";"Haupt""straße 1";10115;Berlin\nSchmidt;Lagerweg 2;50667;Köln';
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        text,
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      // Header is excluded from data rows; quoted delimiters and escaped quotes stay in-cell.
      expect(parsed.header, <String>['Name', 'Straße', 'PLZ', 'Ort']);
      expect(parsed.rows, hasLength(2));
      expect(parsed.rows[0].sourceRowNumber, 2);
      expect(parsed.rows[1].sourceRowNumber, 3);
      expect(parsed.rows[0].cells[0], 'Müller; GmbH');
      expect(parsed.rows[0].cells[1], 'Haupt"straße 1');

      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      final MasterDataImportPreview preview = await service.buildPreview(parsed, customerCreateMapping());

      expect(preview.rows, hasLength(2));
      expect(preview.rows[0].sourceRowNumber, 2);
      expect(preview.rows[0].mappedValues['name'], 'Müller; GmbH');
      expect(preview.rows[0].mappedValues['strasse'], 'Haupt"straße 1');
      expect(preview.rows[0].isValid, isTrue);
      expect(preview.rows[0].proposedAction, MasterDataRowAction.create);
      expect(preview.validCount, 2);
    });

    test('test_master_data_csv_import_reject_an_invalid_source_before_persistence', () async {
      final AppDatabase db = await openDatabase();

      // Unterminated quote, empty file, and non-UTF-8 bytes are file-level errors.
      expect(
        () => MasterDataCsvParser.parseText(
          'Name;Straße\n"offen;Müller',
          delimiter: CsvImportDelimiter.semicolon,
          hasHeader: true,
        ),
        throwsA(isA<MasterDataCsvParseException>()),
      );
      expect(
        () => MasterDataCsvParser.parseText('   \n  ', delimiter: CsvImportDelimiter.semicolon, hasHeader: true),
        throwsA(isA<MasterDataCsvParseException>()),
      );
      expect(
        () => MasterDataCsvParser.parseBytes(
          <int>[0xFF, 0xFE, 0x4E, 0x61],
          delimiter: CsvImportDelimiter.semicolon,
          hasHeader: true,
        ),
        throwsA(isA<MasterDataCsvParseException>()),
      );
      // Inconsistent column counts cannot be mapped unambiguously.
      expect(
        () => MasterDataCsvParser.parseText(
          'Name;Straße;PLZ\nMüller;Weg 1\nSchmidt;Weg 2;50667;Köln',
          delimiter: CsvImportDelimiter.semicolon,
          hasHeader: true,
        ),
        throwsA(isA<MasterDataCsvParseException>()),
      );

      // Nothing was persisted: no business rows and no templates.
      expect(await tableCount(db, 'kunden'), 0);
      expect(await tableCount(db, 'lieferanten'), 0);
      expect(await tableCount(db, 'artikel'), 0);
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      expect(await service.templates.list(MasterDataImportEntity.customer), isEmpty);
    });

    test('test_master_data_csv_import_choose_whether_the_first_row_is_a_header', () async {
      await openDatabase();
      const String text = 'Name;Straße;PLZ;Ort\nMüller;Weg 1;10115;Berlin';

      final MasterDataParsedCsv withHeader = MasterDataCsvParser.parseText(
        text,
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );
      expect(withHeader.header, <String>['Name', 'Straße', 'PLZ', 'Ort']);
      expect(withHeader.rows, hasLength(1));
      expect(withHeader.rows.single.sourceRowNumber, 2);
      expect(withHeader.rows.single.cells.first, 'Müller');

      // No header guessing: without the option the first record stays data.
      final MasterDataParsedCsv withoutHeader = MasterDataCsvParser.parseText(
        text,
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: false,
      );
      expect(withoutHeader.header, isNull);
      expect(withoutHeader.rows, hasLength(2));
      expect(withoutHeader.rows.first.sourceRowNumber, 1);
      expect(withoutHeader.rows.first.cells, <String>['Name', 'Straße', 'PLZ', 'Ort']);

      // A UTF-8 BOM is accepted and never leaks into the first cell.
      final MasterDataParsedCsv withBom = MasterDataCsvParser.parseBytes(
        utf8.encode('\uFEFF$text'),
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );
      expect(withBom.header!.first, 'Name');
      expect(withBom.rows.single.cells.first, 'Müller');
    });
  });
}
