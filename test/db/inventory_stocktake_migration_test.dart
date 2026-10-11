import 'package:drift/native.dart' as drift_native;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

/// Migration boundary for physical stocktake count evidence (v18).
/// Covers specs/db Table Definitions + Explicit feature-table migrations.
void main() {
  group('inventory stocktake migration', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    Future<Set<String>> tableNames() async {
      final rows = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        const <Object?>[],
      );
      return <String>{for (final row in rows) row['name'].toString()};
    }

    Future<int> userVersion() async {
      final rows = await db.executor.runSelect('PRAGMA user_version', const <Object?>[]);
      return (rows.single.values.first! as num).toInt();
    }

    // v18 has 41 declared tables. These v19 settlement tables belong to a separate feature.
    const expectedV18BaseTables = <String>{
      'unternehmen',
      'kunden',
      'lieferanten',
      'artikel',
      'journal',
      'rechnungen',
      'rechnungspositionen',
      'kategorien',
      'konten',
      'nummernkreise',
      'ust_saetze',
      'tagesabschluesse',
      'belege',
      'mahnungen',
      'mahnstufen',
      'mahnwesen_einstellungen',
      'forderungen',
      'bank_transaktionen',
      'bank_templates',
      'bank_imports',
      'kunden_belege',
      'kunden_lieferadressen',
      'artikel_gruppen',
      'rechnungsvorlagen',
      'buchungsvorlagen',
      'anlageverzeichnis',
      'dokumentenpakete',
      'dokumentenpaket_belege',
      'ustva_exporte',
      'euer_exporte',
      'eks_exporte',
      'datev_export_log',
      'eu_laender',
      'eks_einstellungen',
      'vorsteuer_ansprueche',
      'schnellbuchungen',
      'auto_filter_regeln',
      'import_mapping_vorlagen',
      'inventarbewegungen',
      'inventuren',
      'inventur_positionen',
    };
    const expectedVersionedFeatureTables = <String>{
      'forderung_zahlungen',
      'category_mapping_history',
      'feature_table_state',
      'mileage_trips',
      'mileage_trip_corrections',
      'master_data_import_templates',
      'anlage_afa_jahreswerte',
    };
    const unrelatedV19SettlementTables = <String>{
      'settlement_groups',
      'settlement_allocations',
      'statutory_timing_rules',
    };

    Set<String> expectedDeclaredTablesForVersion(int version) => switch (version) {
      18 => expectedV18BaseTables,
      19 => <String>{...expectedV18BaseTables, ...unrelatedV19SettlementTables},
      _ => throw ArgumentError.value(version, 'version', 'Expected schema version 18 or 19'),
    };

    Set<String> expectedTablesForVersion(int version) => <String>{
      ...expectedDeclaredTablesForVersion(version),
      ...expectedVersionedFeatureTables,
    };

    Future<void> dropStocktakeTables() async {
      for (final trigger in <String>[
        'trg_inventuren_insert_only_entwurf',
        'trg_inventuren_no_update_recorded',
        'trg_inventuren_record_needs_counts',
        'trg_inventuren_no_delete_recorded',
        'trg_inventur_positionen_no_insert_recorded',
        'trg_inventur_positionen_no_update_recorded',
        'trg_inventur_positionen_no_delete_recorded',
      ]) {
        await db.executor.runCustom('DROP TRIGGER IF EXISTS $trigger');
      }
      await db.executor.runCustom('DROP TABLE IF EXISTS inventur_positionen');
      await db.executor.runCustom('DROP TABLE IF EXISTS inventuren');
    }

    test('test_all_tables_created_on_fresh_install', () async {
      const int currentVersion = MigrationRunner.currentVersion;
      final Set<String> expectedCurrentDeclaredTables = expectedDeclaredTablesForVersion(currentVersion);
      final Set<String> expectedCurrentTables = expectedTablesForVersion(currentVersion);
      final names = await tableNames();

      expect(currentVersion, anyOf(18, 19));
      expect(expectedV18BaseTables, hasLength(41));
      expect(unrelatedV19SettlementTables, hasLength(3));
      expect(expectedVersionedFeatureTables, hasLength(7));
      expect(expectedDeclaredTablesForVersion(18), hasLength(41));
      expect(expectedDeclaredTablesForVersion(19), hasLength(44));
      expect(expectedTablesForVersion(18), hasLength(48));
      expect(expectedTablesForVersion(19), hasLength(51));
      expect(AppDatabase.allTableNames.toSet(), expectedCurrentDeclaredTables);
      expect(names, expectedCurrentTables);
      expect(await userVersion(), currentVersion);
    });

    test('test_table_count_verification', () async {
      const int currentVersion = MigrationRunner.currentVersion;
      final Set<String> expectedCurrentTables = expectedTablesForVersion(currentVersion);

      expect(await tableNames(), expectedCurrentTables);
      expect(await userVersion(), currentVersion);

      if (currentVersion == 18) {
        expect(await tableNames(), expectedTablesForVersion(18));
        expect(await userVersion(), 18);
      } else {
        for (final tableName in unrelatedV19SettlementTables) {
          await db.executor.runCustom('DROP TABLE $tableName');
        }
        await db.executor.runCustom('PRAGMA user_version = 18');

        expect(await tableNames(), expectedTablesForVersion(18));
        expect(await userVersion(), 18);
      }
    });

    test('test_missing_table_detection', () async {
      await dropStocktakeTables();
      await db.executor.runCustom(
        'CREATE VIEW inventuren AS SELECT 1 AS id, 1 AS stichtag, 1 AS status, 1 AS erstellt_am',
      );
      await db.executor.runCustom('PRAGMA user_version = 17');

      final upgraded = AppDatabase.forTesting(db.executor);
      addTearDown(upgraded.close);
      try {
        await upgraded.ensureOpen();
        fail('expected migration failure when inventuren cannot be created');
      } on ForderungenException catch (error) {
        expect(error.code, ForderungenErrorCode.schemaMigrationFailed);
      }
      final tables = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('inventuren', 'inventur_positionen')",
        const <Object?>[],
      );
      expect(tables, isEmpty, reason: 'no stocktake table may remain after rollback');
      expect(await userVersion(), 17);
    });

    test('test_named_inventory_table_migration', () async {
      await db.executor.runCustom('DROP TABLE inventarbewegungen');
      await db.executor.runCustom('PRAGMA user_version = 5');

      final upgraded = AppDatabase.forTesting(db.executor);
      addTearDown(upgraded.close);
      await upgraded.ensureOpen();

      final cols = await db.executor.runSelect('PRAGMA table_info(inventarbewegungen)', const <Object?>[]);
      final names = <String>{for (final row in cols) row['name'].toString()};
      expect(names, containsAll(<String>['id', 'artikel_id', 'datum', 'diff', 'grund', 'referenz_typ', 'referenz_id']));
      expect(await tableNames(), expectedTablesForVersion(MigrationRunner.currentVersion));
      expect(await userVersion(), MigrationRunner.currentVersion);
    });

    test('test_named_stocktake_table_migration', () async {
      final artikel = await db.artikelRepository.create(bezeichnung: 'Bestand', vkBrutto: 11.9, lagerAktiv: true);
      await db.artikelRepository.setBestand(artikel.id, 7);
      await dropStocktakeTables();
      await db.executor.runCustom('PRAGMA user_version = 17');

      final upgraded = AppDatabase.forTesting(db.executor);
      addTearDown(upgraded.close);
      await upgraded.ensureOpen();

      final headerCols = await db.executor.runSelect('PRAGMA table_info(inventuren)', const <Object?>[]);
      expect(<String>{
        for (final row in headerCols) row['name'].toString(),
      }, containsAll(<String>['id', 'stichtag', 'status', 'erstellt_am']));
      final positionCols = await db.executor.runSelect('PRAGMA table_info(inventur_positionen)', const <Object?>[]);
      expect(
        <String>{for (final row in positionCols) row['name'].toString()},
        containsAll(<String>[
          'id',
          'inventur_id',
          'artikel_id',
          'bezeichnung_snapshot',
          'einheit_snapshot',
          'menge_gezaehlt',
        ]),
      );
      final foreignKeys = await db.executor.runSelect(
        'PRAGMA foreign_key_list(inventur_positionen)',
        const <Object?>[],
      );
      expect(foreignKeys.any((row) => row['table'] == 'inventuren'), isTrue);
      final reloaded = await db.artikelRepository.findById(artikel.id);
      expect(reloaded!.bestandAktuell, 7);
      final movements = await db.executor.runSelect('SELECT id FROM inventarbewegungen', const <Object?>[]);
      expect(movements, hasLength(1));
      expect(await userVersion(), MigrationRunner.currentVersion);
    });

    test('test_empty_recorded_header_insert_is_rejected_by_the_database', () async {
      await expectLater(
        db.executor.runInsert(
          "INSERT INTO inventuren (stichtag, status, erstellt_am) VALUES (?, 'erfasst', ?)",
          <Object?>['2026-01-31', DateTime.now().toUtc().toIso8601String()],
        ),
        throwsA(anything),
      );
      final rows = await db.executor.runSelect("SELECT id FROM inventuren WHERE status = 'erfasst'", const <Object?>[]);
      expect(rows, isEmpty);
    });

    test('test_recorded_count_immutability_is_enforced_by_the_database', () async {
      final headerId = await db.executor.runInsert(
        "INSERT INTO inventuren (stichtag, status, erstellt_am) VALUES (?, 'entwurf', ?)",
        <Object?>['2026-01-31', DateTime.now().toUtc().toIso8601String()],
      );
      await db.executor.runInsert(
        'INSERT INTO inventur_positionen (inventur_id, artikel_id, bezeichnung_snapshot,'
        ' einheit_snapshot, menge_gezaehlt) VALUES (?, ?, ?, ?, ?)',
        <Object?>[headerId, 1, 'Ware', 'Stk', 2.5],
      );
      await db.executor.runUpdate("UPDATE inventuren SET status = 'erfasst' WHERE id = ?", <Object?>[headerId]);

      await expectLater(
        db.executor.runUpdate("UPDATE inventuren SET stichtag = '2026-02-01' WHERE id = ?", <Object?>[headerId]),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runDelete('DELETE FROM inventuren WHERE id = ?', <Object?>[headerId]),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runInsert(
          'INSERT INTO inventur_positionen (inventur_id, artikel_id, bezeichnung_snapshot,'
          ' einheit_snapshot, menge_gezaehlt) VALUES (?, ?, ?, ?, ?)',
          <Object?>[headerId, 2, 'Neu', 'Stk', 1],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runUpdate(
          'UPDATE inventur_positionen SET menge_gezaehlt = 9 WHERE inventur_id = ? AND artikel_id = ?',
          <Object?>[headerId, 1],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runDelete('DELETE FROM inventur_positionen WHERE inventur_id = ? AND artikel_id = ?', <Object?>[
          headerId,
          1,
        ]),
        throwsA(anything),
      );

      final header = await db.executor.runSelect('SELECT stichtag, status FROM inventuren WHERE id = ?', <Object?>[
        headerId,
      ]);
      expect(header.single['stichtag'], '2026-01-31');
      expect(header.single['status'], 'erfasst');
      final positions = await db.executor.runSelect(
        'SELECT menge_gezaehlt FROM inventur_positionen WHERE inventur_id = ?',
        <Object?>[headerId],
      );
      expect(positions, hasLength(1));
      expect(num.parse(positions.single['menge_gezaehlt'].toString()), 2.5);
    });

    test('test_failed_stocktake_migration_leaves_prior_schema_intact', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      final AppDatabase seed = AppDatabase.forTesting(native);
      await seed.ensureOpen();
      final artikel = await seed.artikelRepository.create(
        bezeichnung: 'Vor Migration',
        vkBrutto: 11.9,
        lagerAktiv: true,
      );
      await seed.artikelRepository.setBestand(artikel.id, 4);
      await seed.executor.runCustom('DROP TRIGGER IF EXISTS trg_inventuren_insert_only_entwurf');
      await seed.executor.runCustom('DROP TRIGGER IF EXISTS trg_inventuren_no_update_recorded');
      await seed.executor.runCustom('DROP TRIGGER IF EXISTS trg_inventuren_record_needs_counts');
      await seed.executor.runCustom('DROP TRIGGER IF EXISTS trg_inventuren_no_delete_recorded');
      await seed.executor.runCustom('DROP TRIGGER IF EXISTS trg_inventur_positionen_no_insert_recorded');
      await seed.executor.runCustom('DROP TRIGGER IF EXISTS trg_inventur_positionen_no_update_recorded');
      await seed.executor.runCustom('DROP TRIGGER IF EXISTS trg_inventur_positionen_no_delete_recorded');
      await seed.executor.runCustom('DROP TABLE IF EXISTS inventur_positionen');
      await seed.executor.runCustom('DROP TABLE IF EXISTS inventuren');
      await seed.executor.runCustom('PRAGMA user_version = 17');

      final failing = AppDatabase.forTesting(
        native,
        afterFeatureSchemaDdl: (executor) async => throw StateError('forced stocktake failure'),
      );
      addTearDown(failing.close);
      try {
        await failing.ensureOpen();
        fail('expected ForderungenException with code schemaMigrationFailed');
      } on ForderungenException catch (error) {
        expect(error.code, ForderungenErrorCode.schemaMigrationFailed);
      }

      final tables = await native.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('inventuren', 'inventur_positionen')",
        const <Object?>[],
      );
      expect(tables, isEmpty);
      final version = await native.runSelect('PRAGMA user_version', const <Object?>[]);
      expect((version.single.values.first! as num).toInt(), 17);
      final reloaded = await seed.artikelRepository.findById(artikel.id);
      expect(reloaded!.bestandAktuell, 4);
      final movements = await native.runSelect('SELECT diff FROM inventarbewegungen', const <Object?>[]);
      expect(movements, hasLength(1));
    });
  });
}
