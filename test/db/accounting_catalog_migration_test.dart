import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/core/db/seed.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';

/// Category mapping provenance: seed, migration, and persistence scenarios
/// (accounting-catalog-provenance, db delta). All tests start red.
void main() {
  group('Seed Data', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    test('test_accounting_catalog_026_fresh_profile_without_an_approved_category_catalog', () async {
      final rows = await db.executor.runSelect('SELECT id FROM kategorien', const []);
      expect(rows, isEmpty);
      expect(await db.kategorienRepository.isAccountingConfigured(), isFalse);
    });

    test('test_accounting_catalog_027_ust_saetze_seeded', () async {
      final rows = await db.executor.runSelect('SELECT satz FROM ust_saetze ORDER BY id', const []);
      final values = rows.map((r) => num.tryParse(r['satz'].toString()) ?? -1).toList();
      expect(values, <num>[0, 7, 19]);
    });

    test('test_accounting_catalog_028_nummernkreise_seeded', () async {
      final rows = await db.executor.runSelect('SELECT typ FROM nummernkreise', const []);
      expect(
        rows.map((r) => r['typ']),
        containsAll(<String>[
          'rechnung_ausgang',
          'rechnung_eingang',
          'angebot',
          'auftrag',
          'proforma',
          'lieferschein',
          'stornorechnung',
          'gutschrift',
          'debitor',
          'kreditor',
          'bank_import',
        ]),
      );
    });

    test('test_accounting_catalog_029_kategorien_seeded_with_skr_accounts', () async {
      const manifest = CategoryCatalogManifest(
        sourceReference: 'TEST-SKR03',
        sourceVersion: '2026-test.1',
        reviewApproved: true,
        entries: <CategoryCatalogEntry>[
          CategoryCatalogEntry(
            key: 'TEST-001',
            bezeichnung: 'Testkategorie',
            kontoSkr03: '8001',
            kontoSkr04: '4001',
            euerZeile: 11,
          ),
        ],
      );
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      expect(imported, hasLength(1));
      expect(imported.single.kontoSkr03, '8001');
      expect(imported.single.kontoSkr04, '4001');
      expect(imported.single.mappingStatus, CategoryMappingStatus.catalogVerified);
    });

    test('test_accounting_catalog_030_approved_category_manifest_is_seeded_with_provenance', () async {
      const manifest = CategoryCatalogManifest(
        sourceReference: 'TEST-SKR03',
        sourceVersion: '2026-test.1',
        reviewApproved: true,
        entries: <CategoryCatalogEntry>[
          CategoryCatalogEntry(key: 'TEST-010', bezeichnung: 'A', kontoSkr03: '8010', euerZeile: 12),
        ],
      );
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final stored = imported.single;
      expect(stored.catalogEntryKey, 'TEST-010');
      expect(stored.catalogSourceReference, 'TEST-SKR03');
      expect(stored.catalogSourceVersion, '2026-test.1');
      expect(stored.mappingStatus, CategoryMappingStatus.catalogVerified);
      expect(await db.kategorienRepository.isAccountingConfigured(), isTrue);
    });

    test('test_accounting_catalog_031_unapproved_manifest_is_rejected', () async {
      const manifest = CategoryCatalogManifest(
        sourceReference: '',
        sourceVersion: '',
        reviewApproved: false,
        entries: <CategoryCatalogEntry>[CategoryCatalogEntry(key: 'TEST-099', bezeichnung: 'X')],
      );
      await expectLater(db.kategorienRepository.importApprovedManifest(manifest), throwsA(isA<KategorieException>()));
      final rows = await db.executor.runSelect(
        "SELECT id FROM kategorien WHERE mapping_status = 'catalog_verified'",
        const [],
      );
      expect(rows, isEmpty);
      expect(await db.kategorienRepository.isAccountingConfigured(), isFalse);
    });

    test('test_accounting_catalog_033_seed_restart_preserves_reviewed_category_values', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Manuell', kontoSkr03: '8015');
      final reviewed = KategorienRepository(db.executor, categoryWorkspaceAvailable: true);
      final confirmed = await reviewed.reviewMapping(created.id);
      expect(confirmed.mappingStatus, CategoryMappingStatus.userConfirmed);

      await SeedData.run(db.executor);

      final kept = await db.kategorienRepository.findById(created.id);
      expect(kept?.kontoSkr03, '8015');
      expect(kept?.mappingStatus, CategoryMappingStatus.userConfirmed);
    });

    test('test_accounting_catalog_034_seed_data_not_duplicated_on_restart', () async {
      await db.kategorienRepository.create(bezeichnung: 'Einmalig');
      await SeedData.run(db.executor);
      await SeedData.run(db.executor);
      final rows = await db.executor.runSelect('SELECT COUNT(*) AS c FROM kategorien', const []);
      expect(rows.single['c'], 1);
      final rates = await db.executor.runSelect('SELECT COUNT(*) AS c FROM ust_saetze', const []);
      expect(rates.single['c'], 3);
    });
  });

  group('Provenance migration (v9)', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_catalog_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    Future<AppDatabase> openFresh() async {
      final fresh = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await fresh.ensureOpen();
      addTearDown(fresh.close);
      return fresh;
    }

    /// Simulates a pre-provenance (v8) profile: old-shape kategorien with
    /// arbitrary user values, then runs the v9 migration through the runner.
    Future<AppDatabase> openLegacyWithRows(List<String> inserts) async {
      final legacy = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await legacy.ensureOpen();
      await legacy.executor.runCustom('DROP TABLE kategorien');
      await legacy.executor.runCustom('''
CREATE TABLE kategorien (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bezeichnung TEXT NOT NULL,
  beschreibung TEXT,
  konto_skr03 TEXT,
  konto_skr04 TEXT,
  euer_zeile INTEGER,
  aktiv INTEGER DEFAULT 1,
  typ TEXT,
  eks_kategorie TEXT
)''');
      for (final insert in inserts) {
        await legacy.executor.runCustom(insert);
      }
      final runner = MigrationRunner(executor: legacy.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(8);
      await runner.run(createSchema: () async {});
      return legacy;
    }

    test('test_accounting_catalog_032_existing_categories_are_preserved_during_migration', () async {
      final legacy = await openLegacyWithRows(<String>[
        "INSERT INTO kategorien (id, bezeichnung, beschreibung, konto_skr03, konto_skr04, euer_zeile, aktiv) VALUES (7, 'Alt', 'Beschreibung', '8123', '4123', 15, 1)",
      ]);
      addTearDown(legacy.close);
      final rows = await legacy.executor.runSelect(
        'SELECT bezeichnung, beschreibung, konto_skr03, konto_skr04, euer_zeile, aktiv, mapping_status FROM kategorien WHERE id = 7',
        const [],
      );
      expect(rows.single['bezeichnung'], 'Alt');
      expect(rows.single['beschreibung'], 'Beschreibung');
      expect(rows.single['konto_skr03'], '8123');
      expect(rows.single['konto_skr04'], '4123');
      expect(rows.single['euer_zeile'], 15);
      expect(rows.single['aktiv'], 1);
      expect(rows.single['mapping_status'], 'legacy_unverified');
    });

    test('test_accounting_catalog_041_v9_migration_adds_category_history', () async {
      final fresh = await openFresh();
      final tables = await fresh.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='category_mapping_history'",
        const [],
      );
      expect(tables, hasLength(1));
      final version = await MigrationRunner(
        executor: fresh.executor,
        profileDir: profileDirectory.path,
      ).getUserVersion();
      expect(version, MigrationRunner.currentVersion);
    });

    test('test_accounting_catalog_046_provenance_migration_preserves_and_marks_existing_categories', () async {
      final legacy = await openLegacyWithRows(<String>[
        "INSERT INTO kategorien (id, bezeichnung, konto_skr03, euer_zeile, aktiv) VALUES (3, 'Bestand', '8100', 11, 0)",
      ]);
      addTearDown(legacy.close);
      final cats = await legacy.executor.runSelect('SELECT mapping_status FROM kategorien WHERE id = 3', const []);
      expect(cats.single['mapping_status'], 'legacy_unverified');
      final history = await legacy.executor.runSelect(
        "SELECT vorher_mapping_json, nachher_mapping_json, aktion FROM category_mapping_history WHERE kategorie_id = 3 AND aktion = 'migration'",
        const [],
      );
      expect(history, hasLength(1));
      expect(history.single['vorher_mapping_json'], contains('8100'));
      expect(history.single['nachher_mapping_json'], contains('legacy_unverified'));
    });

    test('test_accounting_catalog_047_mapping_status_and_values_update_atomically', () async {
      final fresh = await openFresh();
      final created = await fresh.kategorienRepository.create(bezeichnung: 'Atomar', kontoSkr03: '8001');
      expect(created.mappingStatus, CategoryMappingStatus.reviewRequired);

      await fresh.kategorienRepository.update(created.id, <String, dynamic>{'konto_skr03': '8002'});
      final stored = await fresh.kategorienRepository.findById(created.id);
      expect(stored?.kontoSkr03, '8002');
      expect(stored?.mappingStatus, CategoryMappingStatus.reviewRequired);
      final history = await fresh.executor.runSelect(
        "SELECT nachher_mapping_json FROM category_mapping_history WHERE kategorie_id = ? AND aktion = 'mapping_edit' ORDER BY id DESC LIMIT 1",
        <Object?>[created.id],
      );
      expect(history.single['nachher_mapping_json'], contains('8002'));

      await expectLater(
        fresh.kategorienRepository.update(created.id, <String, dynamic>{'unbekannt': 'x'}),
        throwsA(isA<KategorieException>()),
      );
      final unchanged = await fresh.kategorienRepository.findById(created.id);
      expect(unchanged?.kontoSkr03, '8002');
    });

    test('test_accounting_catalog_037_missing_v7_payment_table_is_created_by_the_v7_to_v8_migration', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(7);
      await runner.run(createSchema: () async {});
      final tables = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='forderung_zahlungen'",
        const [],
      );
      expect(tables, hasLength(1));
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
    });

    test('test_accounting_catalog_039_current_payment_table_repair_preserves_existing_rows', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');
      await db.executor.runCustom('''
CREATE TABLE forderung_zahlungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  forderung_id INTEGER NOT NULL REFERENCES forderungen(id),
  journal_id INTEGER NOT NULL UNIQUE REFERENCES journal(id),
  betrag NUMERIC(12,2) NOT NULL,
  typ TEXT NOT NULL,
  datum TEXT NOT NULL,
  idempotency_key TEXT UNIQUE
)''');
      final katId = await db.executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Fixture', 1)",
        const <Object?>[],
      );
      final journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ) VALUES (?, ?, ?, ?, ?)',
        <Object?>['2026-01-05', 'Fixture', katId, '10.00', 'Einnahme'],
      );
      final forderungId = await db.executor.runInsert(
        "INSERT INTO forderungen (betrag) VALUES ('10.00')",
        const <Object?>[],
      );
      await db.executor.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, ?, ?)',
        <Object?>[forderungId, journalId, '10.00', 'zahlung', '2026-01-05'],
      );
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.run(createSchema: () async {});
      final rows = await db.executor.runSelect('SELECT betrag, typ FROM forderung_zahlungen', const []);
      expect(rows.single['betrag'].toString(), contains('10'));
      expect(rows.single['typ'], 'zahlung');
    });

    test('test_accounting_catalog_043_table_count_verification', () async {
      final fresh = await openFresh();
      final rows = await fresh.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        const [],
      );
      final names = rows.map((r) => r['name'].toString()).toSet();
      expect(names.length, 44);
      for (final t in AppDatabase.allTableNames) {
        expect(names, contains(t));
      }
      expect(names, containsAll(<String>['forderung_zahlungen', 'category_mapping_history']));
    });

    test('test_accounting_catalog_045_missing_table_detection', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(8);
      await expectLater(
        runner.run(
          createSchema: () async {},
          afterFeatureSchemaDdl: (executor) async => throw StateError('CREATE TABLE failed'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await runner.getUserVersion(), 8);
    });
  });
}
