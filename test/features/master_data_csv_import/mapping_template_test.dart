import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_service.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_templates.dart';

/// Mapping templates: save/reuse, conflict rejection, profile locality.
void main() {
  group('Mapping templates', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_csv_templates_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    Future<AppDatabase> openDatabase([String? path]) async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: path ?? profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      return db;
    }

    MasterDataFieldMapping articleCreateMapping() {
      return const MasterDataFieldMapping(
        entity: MasterDataImportEntity.article,
        columnToField: <int, String>{0: 'bezeichnung', 1: 'typ', 2: 'vk_netto'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.skip,
        matchField: 'bezeichnung',
        articlePriceBasis: ArticlePriceBasis.net,
      );
    }

    test('test_master_data_csv_import_save_and_reuse_an_article_create_mapping', () async {
      final AppDatabase db = await openDatabase();
      final MasterDataImportTemplateStore store = MasterDataImportTemplateStore(db.executor);
      final MasterDataFieldMapping mapping = articleCreateMapping();

      final MasterDataImportTemplate saved = await store.save(name: 'Artikel Standard', mapping: mapping);
      expect(saved.id, greaterThan(0));

      // Reloaded template restores positions, options, and policy without any source values.
      final MasterDataImportTemplate? reloaded = await store.findById(saved.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.entity, MasterDataImportEntity.article);
      expect(reloaded.mapping.columnToField, <int, String>{0: 'bezeichnung', 1: 'typ', 2: 'vk_netto'});
      expect(reloaded.mapping.hasHeader, isTrue);
      expect(reloaded.mapping.delimiter, CsvImportDelimiter.semicolon);
      expect(reloaded.mapping.decimalConvention, CsvDecimalConvention.comma);
      expect(reloaded.mapping.duplicatePolicy, MasterDataDuplicatePolicy.skip);
      expect(reloaded.mapping.matchField, 'bezeichnung');
      expect(reloaded.mapping.articlePriceBasis, ArticlePriceBasis.net);

      final List<MasterDataImportTemplate> listed = await store.list(MasterDataImportEntity.article);
      expect(listed.map((MasterDataImportTemplate t) => t.id), contains(saved.id));

      // Reuse through the entity gate restores the same mapping for a later file.
      final MasterDataFieldMapping reused = store.requireForEntity(reloaded, MasterDataImportEntity.article);
      expect(reused.columnToField, mapping.columnToField);
      expect(reused.decimalConvention, mapping.decimalConvention);
    });

    test('test_master_data_csv_import_reject_a_conflicting_or_cross_entity_mapping', () async {
      final AppDatabase db = await openDatabase();
      final MasterDataImportTemplateStore store = MasterDataImportTemplateStore(db.executor);

      // Two columns on one target field conflict and never enter preview.
      const MasterDataFieldMapping conflicting = MasterDataFieldMapping(
        entity: MasterDataImportEntity.customer,
        columnToField: <int, String>{0: 'name', 1: 'name'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
      );
      void validateConflicting() => MasterDataImportTemplateStore.validateMapping(conflicting);
      expect(validateConflicting, throwsA(isA<MasterDataCsvMappingException>()));
      await expectLater(
        store.save(name: 'Konflikt', mapping: conflicting),
        throwsA(isA<MasterDataCsvMappingException>()),
      );

      // Primary keys and arbitrary columns are not mapping targets.
      const MasterDataFieldMapping unsupported = MasterDataFieldMapping(
        entity: MasterDataImportEntity.customer,
        columnToField: <int, String>{0: 'id'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
      );
      void validateUnsupported() => MasterDataImportTemplateStore.validateMapping(unsupported);
      expect(validateUnsupported, throwsA(isA<MasterDataCsvMappingException>()));

      // A customer template never loads for a supplier import.
      const MasterDataFieldMapping customerMapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.customer,
        columnToField: <int, String>{0: 'name', 1: 'strasse', 2: 'plz', 3: 'ort'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
      );
      final MasterDataImportTemplate customerTemplate = await store.save(
        name: 'Kunden Standard',
        mapping: customerMapping,
      );
      expect(
        () => store.requireForEntity(customerTemplate, MasterDataImportEntity.supplier),
        throwsA(isA<MasterDataCsvMappingException>()),
      );
      final MasterDataCsvImportService service = MasterDataCsvImportService(db.executor);
      await expectLater(
        service.templates.save(name: 'x', mapping: conflicting),
        throwsA(isA<MasterDataCsvMappingException>()),
      );
    });

    test('test_master_data_csv_import_keep_templates_inside_their_profile', () async {
      final Directory dirA = await Directory.systemTemp.createTemp('openaccounting_csv_profile_a_');
      final Directory dirB = await Directory.systemTemp.createTemp('openaccounting_csv_profile_b_');
      addTearDown(() => dirA.delete(recursive: true));
      addTearDown(() => dirB.delete(recursive: true));
      final AppDatabase dbA = await openDatabase(dirA.path);
      final AppDatabase dbB = await openDatabase(dirB.path);

      const MasterDataFieldMapping mapping = MasterDataFieldMapping(
        entity: MasterDataImportEntity.customer,
        columnToField: <int, String>{0: 'name', 1: 'strasse', 2: 'plz', 3: 'ort'},
        hasHeader: true,
        delimiter: CsvImportDelimiter.semicolon,
        decimalConvention: CsvDecimalConvention.comma,
        duplicatePolicy: MasterDataDuplicatePolicy.createNew,
      );
      final MasterDataImportTemplate saved = await MasterDataImportTemplateStore(dbA.executor)
          .save(name: 'Profil A Vorlage', mapping: mapping);

      // Profile B neither lists nor loads profile A's template.
      expect(await MasterDataImportTemplateStore(dbB.executor).list(MasterDataImportEntity.customer), isEmpty);
      expect(await MasterDataImportTemplateStore(dbB.executor).findById(saved.id), isNull);
      expect(await MasterDataImportTemplateStore(dbA.executor).list(MasterDataImportEntity.customer), hasLength(1));
    });
  });
}
