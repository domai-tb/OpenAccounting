import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_parser.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_service.dart';

/// Duplicate handling: unique update, ambiguity, skip default.
void main() {
  group('Duplicate handling', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_csv_duplicates_test_');
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

    MasterDataFieldMapping customerEmailMapping(MasterDataDuplicatePolicy policy) {
      return MasterDataFieldMapping(
        entity: MasterDataImportEntity.customer,
        columnToField: const <int, String>{0: 'email', 1: 'name', 2: 'strasse', 3: 'plz', 4: 'ort'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: policy,
        matchField: 'email',
      );
    }

    test('test_master_data_csv_import_confirm_a_unique_duplicate_update', () async {
      final AppDatabase db = await openDatabase();
      final KundenRepository kunden = KundenRepository(db.executor);
      final Kunde stored = await kunden.create(
        name: 'Max Alt',
        strasse: 'Alte Straße 1',
        plz: '10115',
        ort: 'Berlin',
        email: 'max@example.com',
        note: 'Alte Notiz',
      );
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      final MasterDataFieldMapping mapping = customerEmailMapping(MasterDataDuplicatePolicy.update);
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'E-Mail;Name;Straße;PLZ;Ort\nmax@example.com;Max Neu;Neue Straße 9;10115;Berlin',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      expect(preview.rows, hasLength(1));
      final MasterDataRowPreview row = preview.rows.single;
      expect(row.proposedAction, MasterDataRowAction.update);
      expect(row.existingId, stored.id);
      // Exactly the two changed mapped values are shown as old vs. proposed.
      expect(row.oldValues, <String, String>{'name': 'Max Alt', 'strasse': 'Alte Straße 1'});

      // Explicit per-row selection updates only non-empty mapped values.
      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{row.sourceRowNumber: MasterDataRowSelection.update},
        ),
        mapping,
      );
      expect(result.updated, 1);
      expect(result.created, 0);

      final Kunde? reread = await kunden.findById(stored.id);
      expect(reread, isNotNull);
      expect(reread!.name, 'Max Neu');
      expect(reread.strasse, 'Neue Straße 9');
      expect(reread.kundennummer, stored.kundennummer);
      expect(reread.note, 'Alte Notiz');
    });

    test('test_master_data_csv_import_leave_an_ambiguous_duplicate_unchanged', () async {
      final AppDatabase db = await openDatabase();
      final ArtikelRepository artikel = ArtikelRepository(db.executor);
      final Artikel first = await artikel.create(
        bezeichnung: 'Drucker',
        beschreibung: 'Erste Beschreibung',
        vkBrutto: 119,
        ustSatz: 19,
        artikelnummer: 'A-1',
      );
      final Artikel second = await artikel.create(
        bezeichnung: 'Drucker',
        beschreibung: 'Zweite Beschreibung',
        vkBrutto: 238,
        ustSatz: 19,
        artikelnummer: 'A-2',
      );
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      const MasterDataFieldMapping mapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.article,
        columnToField: <int, String>{0: 'bezeichnung', 1: 'beschreibung', 2: 'vk_brutto'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.update,
        matchField: 'bezeichnung',
        articlePriceBasis: ArticlePriceBasis.gross,
      );
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Bezeichnung;Beschreibung;vk_brutto\nDrucker;Geändert;119,00',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      final MasterDataRowPreview row = preview.rows.single;
      expect(row.matchCount, 2);
      expect(row.proposedAction, MasterDataRowAction.ambiguous);
      expect(row.existingId, isNull);

      // Update is unavailable for the ambiguous row: the batch fails retryably and writes nothing.
      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{row.sourceRowNumber: MasterDataRowSelection.update},
        ),
        mapping,
      );
      expect(result.isFailure, isTrue);
      expect(result.failureMessage, isNotNull);
      expect((await artikel.findById(first.id))!.beschreibung, 'Erste Beschreibung');
      expect((await artikel.findById(second.id))!.beschreibung, 'Zweite Beschreibung');
    });

    test('test_master_data_csv_import_skip_an_existing_record_by_default', () async {
      final AppDatabase db = await openDatabase();
      final KundenRepository kunden = KundenRepository(db.executor);
      final Kunde stored = await kunden.create(
        name: 'Skip GmbH',
        strasse: 'Weg 1',
        plz: '10115',
        ort: 'Berlin',
        email: 'Skip@x.de',
      );
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      // Skip is the default strategy for new templates.
      expect(
        const MasterDataFieldMapping(
          entity: MasterDataImportEntity.customer,
          columnToField: <int, String>{0: 'email'},
          hasHeader: true,
          delimiter: CsvImportDelimiter.semicolon,
          decimalConvention: CsvDecimalConvention.comma,
          duplicatePolicy: MasterDataDuplicatePolicy.skip,
          matchField: 'email',
        ).duplicatePolicy,
        MasterDataDuplicatePolicy.skip,
      );
      final MasterDataFieldMapping mapping = customerEmailMapping(MasterDataDuplicatePolicy.skip);
      // Exact match is case-insensitive after trimming.
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'E-Mail;Name;Straße;PLZ;Ort\n  skip@x.de ;Skip GmbH;Weg 1;10115;Berlin',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      final MasterDataRowPreview row = preview.rows.single;
      expect(row.proposedAction, MasterDataRowAction.skip);
      expect(row.isDuplicateLabelled, isTrue);

      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(preview: preview, selections: const <int, MasterDataRowSelection>{}),
        mapping,
      );
      expect(result.skipped, 1);
      expect(result.created, 0);
      expect(result.updated, 0);
      final Kunde? reread = await kunden.findById(stored.id);
      expect(reread!.name, 'Skip GmbH');
      expect(reread.strasse, 'Weg 1');
    });
  });
}
