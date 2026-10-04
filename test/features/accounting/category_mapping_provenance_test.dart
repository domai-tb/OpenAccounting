import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';

/// Category mapping provenance: accounting behavior scenarios
/// (accounting-catalog-provenance, accounting delta). All tests start red.
void main() {
  group('Kategorien', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    const manifest = CategoryCatalogManifest(
      sourceReference: 'TEST-SKR03',
      sourceVersion: '2026-test.1',
      reviewApproved: true,
      entries: <CategoryCatalogEntry>[
        CategoryCatalogEntry(
          key: 'TEST-100',
          bezeichnung: 'Katalogkategorie',
          beschreibung: 'Beschreibung',
          kontoSkr03: '8200',
          kontoSkr04: '4200',
          euerZeile: 14,
        ),
      ],
    );

    test('test_accounting_catalog_001_approved_catalog_category_has_traceable_mappings', () async {
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final stored = imported.single;
      expect(stored.kontoSkr03, '8200');
      expect(stored.euerZeile, 14);
      expect(stored.catalogEntryKey, 'TEST-100');
      expect(stored.catalogSourceVersion, '2026-test.1');
      expect(stored.mappingStatus, CategoryMappingStatus.catalogVerified);
    });

    test('test_accounting_catalog_002_category_with_skr_mapping', () async {
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final stored = imported.single;
      expect(stored.kontoSkr03, '8200');
      expect(stored.kontoSkr04, '4200');
      expect(stored.mappingStatus, CategoryMappingStatus.catalogVerified);
    });

    test('test_accounting_catalog_003_user_defined_category_is_not_described_as_a_standard_mapping', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Eigen', kontoSkr03: '8999');
      expect(created.mappingStatus, isNot(CategoryMappingStatus.catalogVerified));
      expect(created.catalogEntryKey, isNull);
      expect(created.catalogSourceReference, isNull);
    });

    test('test_accounting_catalog_004_unmapped_user_category_remains_explicitly_unmapped', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Ohne Mapping');
      expect(created.mappingStatus, CategoryMappingStatus.unmapped);
      expect(created.kontoSkr03, isNull);
      expect(created.kontoSkr04, isNull);
      expect(created.euerZeile, isNull);
    });

    test('test_accounting_catalog_005_editing_a_catalog_mapping_requires_review', () async {
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final edited = await db.kategorienRepository.update(imported.single.id, <String, dynamic>{'euer_zeile': 20});
      expect(edited.mappingStatus, CategoryMappingStatus.reviewRequired);
      expect(edited.catalogSourceVersion, '2026-test.1');
      expect(edited.mappingStatus, isNot(CategoryMappingStatus.catalogVerified));
    });

    test('test_accounting_catalog_006_user_modified_skr_account', () async {
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final edited = await db.kategorienRepository.update(imported.single.id, <String, dynamic>{'konto_skr03': '8999'});
      expect(edited.kontoSkr03, '8999');
      expect(edited.mappingStatus, CategoryMappingStatus.reviewRequired);
    });

    test('test_accounting_catalog_007_legacy_category_values_are_retained_but_untrusted', () async {
      await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, beschreibung, konto_skr03, konto_skr04, euer_zeile, aktiv) VALUES (?, ?, ?, ?, ?, ?)',
        const <Object?>['Bestand', 'Alt', '8100', '4100', 11, 1],
      );
      final rows = await db.executor.runSelect('SELECT id FROM kategorien LIMIT 1', const []);
      final stored = await db.kategorienRepository.findById((rows.single['id']! as num).toInt());
      expect(stored?.kontoSkr03, '8100');
      expect(stored?.mappingStatus, CategoryMappingStatus.legacyUnverified);
      final visible = await db.kategorienRepository.list();
      expect(visible.map((k) => k.id), contains(stored?.id));
    });

    test('test_accounting_catalog_010_inactive_category', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Inaktiv', aktiv: false);
      final selectable = await db.kategorienRepository.list(onlyActive: true);
      expect(selectable.map((k) => k.id), isNot(contains(created.id)));
      final stored = await db.kategorienRepository.findById(created.id);
      expect(stored, isNotNull);
    });

    test('test_accounting_catalog_011_category_description', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Mit Hinweis', beschreibung: 'Hinweistext');
      final stored = await db.kategorienRepository.findById(created.id);
      expect(stored?.beschreibung, 'Hinweistext');
    });

    test('test_accounting_catalog_014_category_review_is_unavailable_until_its_workspace_is_accepted', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Ungeprüft', kontoSkr03: '8001');
      await expectLater(db.kategorienRepository.reviewMapping(created.id), throwsA(isA<CategoryReviewUnavailable>()));
      final stored = await db.kategorienRepository.findById(created.id);
      expect(stored?.mappingStatus, CategoryMappingStatus.reviewRequired);
    });
  });
}
