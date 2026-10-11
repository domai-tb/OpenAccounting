import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_parser.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_service.dart';

/// Batch atomicity: reviewed commit, rollback, accounting separation.
void main() {
  group('Import batches', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_csv_batch_test_');
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

    MasterDataFieldMapping customerUpdateMapping() {
      return const MasterDataFieldMapping(
        entity: MasterDataImportEntity.customer,
        columnToField: <int, String>{0: 'email', 1: 'name', 2: 'strasse', 3: 'plz', 4: 'ort'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.update,
        matchField: 'email',
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

    Future<int> debitorNextNumber(AppDatabase db) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'debitor' AND aktiv = 1 ORDER BY id LIMIT 1",
        const <Object?>[],
      );
      final Object? value = rows.single['naechste_nummer'];
      return value is int ? value : int.parse(value.toString());
    }

    test('test_master_data_csv_import_commit_a_reviewed_batch', () async {
      final AppDatabase db = await openDatabase();
      final KundenRepository kunden = KundenRepository(db.executor);
      final Kunde toUpdate = await kunden.create(
        name: 'Update Alt',
        strasse: 'Alte Straße 1',
        plz: '10115',
        ort: 'Berlin',
        email: 'update@x.de',
      );
      await kunden.create(name: 'Skip Gleich', strasse: 'Weg 5', plz: '50667', ort: 'Köln', email: 'skip@x.de');
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      final MasterDataFieldMapping mapping = customerUpdateMapping();
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'E-Mail;Name;Straße;PLZ;Ort\n'
        'neu@x.de;Neu GmbH;Weg 1;10115;Berlin\n'
        'update@x.de;Update Neu;Neue Straße 9;10115;Berlin\n'
        'skip@x.de;Skip Gleich;Weg 5;50667;Köln\n'
        'fehler@x.de;Fehler GmbH;Weg 7;20354;',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      expect(preview.rows, hasLength(4));
      expect(preview.rows[0].proposedAction, MasterDataRowAction.create);
      expect(preview.rows[1].proposedAction, MasterDataRowAction.update);
      expect(preview.rows[3].proposedAction, MasterDataRowAction.invalid);

      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{
            preview.rows[0].sourceRowNumber: MasterDataRowSelection.create,
            preview.rows[1].sourceRowNumber: MasterDataRowSelection.update,
            preview.rows[2].sourceRowNumber: MasterDataRowSelection.skip,
            preview.rows[3].sourceRowNumber: MasterDataRowSelection.excluded,
          },
        ),
        mapping,
      );

      expect(result.isFailure, isFalse);
      expect(result.created, 1);
      expect(result.updated, 1);
      expect(result.skipped, 1);
      expect(result.invalid, 1);
      expect((await kunden.findById(toUpdate.id))!.name, 'Update Neu');
      final List<Map<String, Object?>> created = await db.executor.runSelect(
        'SELECT id FROM kunden WHERE email = ?',
        const <Object?>['neu@x.de'],
      );
      expect(created, hasLength(1));
    });

    test('test_master_data_csv_import_roll_back_when_a_write_fails', () async {
      final AppDatabase db = await openDatabase();
      final KundenRepository kunden = KundenRepository(db.executor);
      await kunden.create(name: 'Bestand GmbH', strasse: 'Weg 1', plz: '10115', ort: 'Berlin');
      final int customersBefore = await tableCount(db, 'kunden');
      final int nextNumberBefore = await debitorNextNumber(db);
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      final MasterDataFieldMapping mapping = customerUpdateMapping();
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'E-Mail;Name;Straße;PLZ;Ort\nok@x.de;Ok GmbH;Weg 2;10115;Berlin\nkaputt@x.de;Kaputt GmbH;Weg 3;20354;',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );
      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      expect(preview.rows[1].proposedAction, MasterDataRowAction.invalid);

      // Forcing the invalid row into the selection fails the whole transaction.
      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{
            preview.rows[0].sourceRowNumber: MasterDataRowSelection.create,
            preview.rows[1].sourceRowNumber: MasterDataRowSelection.create,
          },
        ),
        mapping,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureMessage, contains('ungültig'));
      expect(result.created, 0);
      expect(result.updated, 0);
      // No record and no allocated customer number from this batch survived.
      expect(await tableCount(db, 'kunden'), customersBefore);
      expect(await debitorNextNumber(db), nextNumberBefore);
    });

    test('test_master_data_csv_import_keep_import_separate_from_accounting_effects', () async {
      final AppDatabase db = await openDatabase();
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      const MasterDataFieldMapping mapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.article,
        columnToField: <int, String>{0: 'bezeichnung', 1: 'typ', 2: 'vk_brutto', 3: 'ust_satz'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
        articlePriceBasis: ArticlePriceBasis.gross,
      );
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        'Bezeichnung;Typ;vk_brutto;ust_satz\nDrucker P9;Artikel;119,00;19',
        delimiter: CsvImportDelimiter.semicolon,
        hasHeader: true,
      );

      final MasterDataImportPreview preview = await service.buildPreview(parsed, mapping);
      final MasterDataImportResult result = await service.commit(
        MasterDataReviewedBatch(
          preview: preview,
          selections: <int, MasterDataRowSelection>{preview.rows.single.sourceRowNumber: MasterDataRowSelection.create},
        ),
        mapping,
      );

      expect(result.isFailure, isFalse);
      expect(result.created, 1);
      final List<Map<String, Object?>> articles = await db.executor.runSelect(
        'SELECT vk_netto, vk_brutto, bestand_aktuell, lager_aktiv FROM artikel WHERE bezeichnung = ?',
        const <Object?>['Drucker P9'],
      );
      expect(articles, hasLength(1));
      expect((articles.single['vk_brutto']! as num).toDouble(), closeTo(119.0, 0.001));
      expect((articles.single['vk_netto']! as num).toDouble(), closeTo(100.0, 0.01));
      // No invoice, payment, dunning, stock, or inventory side effects.
      expect(await tableCount(db, 'rechnungen'), 0);
      expect((articles.single['bestand_aktuell']! as num).toDouble(), 0);
      expect(articles.single['lager_aktiv'], 0);
      final List<Map<String, Object?>> tables = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
        const <Object?>[],
      );
      final Set<String> names = <String>{for (final Map<String, Object?> t in tables) t['name'].toString()};
      const Set<String> accountingTables = <String>{
        'journal',
        'buchungen',
        'buchungssaetze',
        'zahlungen',
        'zahlungseingaenge',
        'mahnungen',
        'lagerbewegungen',
        'lager_bewegungen',
        'inventur',
      };
      for (final String table in accountingTables.intersection(names)) {
        expect(await tableCount(db, table), 0, reason: '$table must stay empty after import');
      }
    });
  });
}
