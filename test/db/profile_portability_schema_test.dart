import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/rechnungsvorlagen_repository.dart';

void main() {
  group('Profile portability schema', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase.createTestDatabase();
      await database.ensureOpen();
    });

    tearDown(() async {
      await database.close();
    });

    test('test_profile_data_portability_001_all_tables_created_on_fresh_install', () async {
      final rows = await database.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        const [],
      );
      final tableNames = rows.map((row) => row['name']?.toString() ?? '').toSet();
      const migrationRequiredTables = <String>{
        'forderung_zahlungen',
        'mileage_trips',
        'mileage_trip_corrections',
        'category_mapping_history',
      };

      expect(tableNames, hasLength(44));
      expect(tableNames, containsAll(AppDatabase.allTableNames));
      expect(tableNames, contains('feature_table_state'));
      expect(tableNames, containsAll(migrationRequiredTables));
      expect(tableNames, isNot(contains('buchungsvorlagen_occurrences')));
      expect(tableNames, isNot(contains('rechnungsvorlagen_occurrences')));

      final markerRows = await database.executor.runSelect(
        'SELECT table_name, state FROM feature_table_state ORDER BY table_name',
        const [],
      );
      expect(markerRows, hasLength(2));
      expect(markerRows.map((row) => (row['table_name'], row['state'])), <(Object?, Object?)>[
        ('buchungsvorlagen_occurrences', 'never_initialized'),
        ('rechnungsvorlagen_occurrences', 'never_initialized'),
      ]);

      final versionRows = await database.executor.runSelect('PRAGMA user_version', const []);
      expect(versionRows.single.values.single, 13);
    });

    test('test_profile_data_portability_006_v12_to_v13_migration_adds_shared_markers_and_mileage', () async {
      final Directory profileDirectory = await Directory.systemTemp.createTemp('profile_portability_v12_');
      final AppDatabase legacyDatabase = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      addTearDown(() async {
        await legacyDatabase.close();
        await profileDirectory.delete(recursive: true);
      });
      await legacyDatabase.ensureOpen();
      await BuchungsVorlagenRepository(legacyDatabase.executor).ensureSchema();
      await legacyDatabase.executor.runCustom('DROP TABLE mileage_trip_corrections');
      await legacyDatabase.executor.runCustom('DROP TABLE mileage_trips');
      await legacyDatabase.executor.runCustom('DROP TABLE feature_table_state');
      await legacyDatabase.executor.runCustom('PRAGMA user_version = 12');

      final MigrationRunner runner = MigrationRunner(
        executor: legacyDatabase.executor,
        profileDir: profileDirectory.path,
        requiredTables: AppDatabase.allTableNames,
      );
      final bool migrated = await runner.run(createSchema: () async {});

      expect(migrated, isTrue);
      expect(await runner.getUserVersion(), 13);
      final List<Map<String, Object?>> newTables = await legacyDatabase.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
        "('feature_table_state', 'mileage_trips', 'mileage_trip_corrections')",
        const <Object?>[],
      );
      expect(
        newTables.map((row) => row['name']),
        containsAll(<String>['feature_table_state', 'mileage_trips', 'mileage_trip_corrections']),
      );

      final List<Map<String, Object?>> markerRows = await legacyDatabase.executor.runSelect(
        'SELECT table_name, state FROM feature_table_state ORDER BY table_name',
        const <Object?>[],
      );
      expect(markerRows, <Map<String, Object?>>[
        <String, Object?>{'table_name': 'buchungsvorlagen_occurrences', 'state': 'initialized'},
        <String, Object?>{'table_name': 'rechnungsvorlagen_occurrences', 'state': 'unknown'},
      ]);

      final SchemaHealthReport health = await runner.inspectSchemaHealth();
      expect(health.isHealthy, isTrue);
      expect(health.isCompleteForVersion13Export, isFalse);
    });

    test('test_profile_data_portability_002_pre_v13_profile_is_valid_before_marker_migration', () async {
      await database.executor.runCustom('DROP TABLE mileage_trip_corrections');
      await database.executor.runCustom('DROP TABLE mileage_trips');
      await database.executor.runCustom('DROP TABLE feature_table_state');
      await database.executor.runCustom('PRAGMA user_version = 12');

      final MigrationRunner runner = MigrationRunner(
        executor: database.executor,
        profileDir: Directory.systemTemp.path,
        requiredTables: AppDatabase.allTableNames,
      );
      final SchemaHealthReport health = await runner.inspectSchemaHealth();
      expect(health.isHealthy, isTrue);
      expect(health.isCompleteForVersion13Export, isFalse);
      expect(await runner.getUserVersion(), 12);
    });

    test('test_profile_data_portability_003_missing_v7_payment_table_is_created_by_the_v7_to', () async {
      final Directory profileDirectory = await Directory.systemTemp.createTemp('profile_portability_v7_');
      final AppDatabase legacyDatabase = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      addTearDown(() async {
        await legacyDatabase.close();
        await profileDirectory.delete(recursive: true);
      });
      await legacyDatabase.ensureOpen();
      await legacyDatabase.executor.runCustom("INSERT INTO kategorien (bezeichnung) VALUES ('Legacy category')");
      await legacyDatabase.executor.runCustom('DROP TABLE forderung_zahlungen');
      await legacyDatabase.executor.runCustom('PRAGMA user_version = 7');

      final MigrationRunner runner = MigrationRunner(
        executor: legacyDatabase.executor,
        profileDir: profileDirectory.path,
        requiredTables: AppDatabase.allTableNames,
      );
      var verifiedBeforeVersionBump = false;
      await runner.run(
        createSchema: () async {},
        afterFeatureSchemaDdl: (executor) async {
          final List<Map<String, Object?>> paymentTable = await executor.runSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
            const <Object?>[],
          );
          final List<Map<String, Object?>> foreignKeys = await executor.runSelect(
            'PRAGMA foreign_key_list(forderung_zahlungen)',
            const <Object?>[],
          );
          final List<Map<String, Object?>> indexes = await executor.runSelect(
            'PRAGMA index_list(forderung_zahlungen)',
            const <Object?>[],
          );
          verifiedBeforeVersionBump =
              paymentTable.isNotEmpty &&
              foreignKeys.map((row) => row['table']).toSet().containsAll(<String>{'forderungen', 'journal'}) &&
              indexes.map((row) => row['name']).toSet().containsAll(<String>{
                'forderung_zahlungen_key_unique',
                'forderung_zahlungen_journal_unique',
              }) &&
              await runner.getUserVersion() == 7;
        },
      );

      expect(verifiedBeforeVersionBump, isTrue);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
      final List<Map<String, Object?>> categoryRows = await legacyDatabase.executor.runSelect(
        "SELECT bezeichnung FROM kategorien WHERE bezeichnung = 'Legacy category'",
        const <Object?>[],
      );
      expect(categoryRows, hasLength(1));
      final List<Map<String, Object?>> paymentRows = await legacyDatabase.executor.runSelect(
        'SELECT count(*) AS count FROM forderung_zahlungen',
        const <Object?>[],
      );
      expect(paymentRows.single['count'], 0);
    });

    test(
      'test_profile_data_portability_004_missing_payment_table_at_v8_or_later_preserves_the_incomplete_signal',
      () async {
        await database.executor.runCustom('DROP TABLE forderung_zahlungen');
        final MigrationRunner runner = MigrationRunner(
          executor: database.executor,
          profileDir: Directory.systemTemp.path,
          requiredTables: AppDatabase.allTableNames,
        );

        final SchemaHealthReport health = await runner.inspectSchemaHealth();
        expect(health.isHealthy, isFalse);
        expect(health.isCompleteForVersion13Export, isFalse);
        expect(health.missingTables, contains('forderung_zahlungen'));

        await expectLater(
          runner.run(createSchema: () async {}),
          throwsA(isA<StateError>().having((error) => error.message, 'message', contains('forderung_zahlungen'))),
        );
        expect(await runner.getUserVersion(), 13);
        final List<Map<String, Object?>> paymentTable = await database.executor.runSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
          const <Object?>[],
        );
        expect(paymentTable, isEmpty);
      },
    );

    test('test_profile_data_portability_005_current_payment_table_repair_preserves_existing', () async {
      final int customerId = await database.executor.runInsert(
        'INSERT INTO kunden (anrede, name, strasse, plz, ort, land) '
        "VALUES ('Frau', 'Portability', 'Hauptstrasse 1', '10115', 'Berlin', 'DE')",
        const <Object?>[],
      );
      final int receivableId = await database.executor.runInsert(
        'INSERT INTO forderungen (betrag, anfangsbetrag, status, typ, partner_typ, partner_id) '
        "VALUES ('87.50', '87.50', 'offen', 'rechnung', 'kunde', ?)",
        <Object?>[customerId],
      );
      final int journalId = await database.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, erstellungsdatum) '
        "VALUES ('2026-09-12', 'Legacy payment', '12.50', 'zahlung', CURRENT_TIMESTAMP)",
        const <Object?>[],
      );
      await database.executor.runCustom('DROP TABLE forderung_zahlungen');
      await database.executor.runCustom('''
CREATE TABLE forderung_zahlungen (
  id INTEGER PRIMARY KEY,
  forderung_id INTEGER,
  journal_id INTEGER,
  betrag NUMERIC,
  typ TEXT,
  datum TEXT,
  idempotency_key TEXT
)''');
      await database.executor.runCustom(
        'INSERT INTO forderung_zahlungen '
        '(id, forderung_id, journal_id, betrag, typ, datum, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[1, receivableId, journalId, '12.50', 'zahlung', '2026-09-12', 'legacy-key-005'],
      );

      final MigrationRunner runner = MigrationRunner(
        executor: database.executor,
        profileDir: Directory.systemTemp.path,
        requiredTables: AppDatabase.allTableNames,
      );
      await runner.run(createSchema: () async {});

      final List<Map<String, Object?>> rows = await database.executor.runSelect(
        'SELECT id, forderung_id, journal_id, betrag, typ, datum, idempotency_key, '
        'requested_betrag_cents, fingerprint_direction, fingerprint_date_policy FROM forderung_zahlungen',
        const <Object?>[],
      );
      expect(rows, hasLength(1));
      expect(rows.single['id'], 1);
      expect(rows.single['forderung_id'], receivableId);
      expect(rows.single['journal_id'], journalId);
      expect(rows.single['betrag'].toString(), contains('12.5'));
      expect(rows.single['typ'], 'zahlung');
      expect(rows.single['datum'], '2026-09-12');
      expect(rows.single['idempotency_key'], 'legacy-key-005');
      expect(rows.single['requested_betrag_cents'], isNull);
      expect(rows.single['fingerprint_direction'], isNull);
      expect(rows.single['fingerprint_date_policy'], isNull);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);

      final List<Map<String, Object?>> foreignKeys = await database.executor.runSelect(
        'PRAGMA foreign_key_list(forderung_zahlungen)',
        const <Object?>[],
      );
      expect(foreignKeys.map((row) => row['table']).toSet(), containsAll(<String>{'forderungen', 'journal'}));
    });

    test('test_profile_data_portability_007_v9_migration_adds_category_history', () async {
      final Directory profileDirectory = await Directory.systemTemp.createTemp('profile_portability_v8_');
      final AppDatabase legacyDatabase = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      addTearDown(() async {
        await legacyDatabase.close();
        await profileDirectory.delete(recursive: true);
      });
      await legacyDatabase.ensureOpen();
      await legacyDatabase.executor.runCustom('DROP TABLE category_mapping_history');
      await legacyDatabase.executor.runCustom('DROP TABLE mileage_trip_corrections');
      await legacyDatabase.executor.runCustom('DROP TABLE mileage_trips');
      await legacyDatabase.executor.runCustom('DROP TABLE feature_table_state');
      await legacyDatabase.executor.runCustom('DROP TABLE kategorien');
      await legacyDatabase.executor.runCustom('''
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
      await legacyDatabase.executor.runCustom(
        'INSERT INTO kategorien (id, bezeichnung, konto_skr03, euer_zeile, aktiv) '
        "VALUES (7, 'Legacy category', '8123', 15, 1)",
      );
      await legacyDatabase.executor.runCustom('PRAGMA user_version = 8');

      final MigrationRunner runner = MigrationRunner(
        executor: legacyDatabase.executor,
        profileDir: profileDirectory.path,
        requiredTables: AppDatabase.allTableNames,
      );
      var historyCreatedBeforeVersionBump = false;
      await runner.run(
        createSchema: () async {},
        afterFeatureSchemaDdl: (executor) async {
          final List<Map<String, Object?>> table = await executor.runSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'category_mapping_history'",
            const <Object?>[],
          );
          final List<Map<String, Object?>> history = await executor.runSelect(
            "SELECT kategorie_id, aktion FROM category_mapping_history WHERE kategorie_id = 7 AND aktion = 'migration'",
            const <Object?>[],
          );
          historyCreatedBeforeVersionBump =
              table.isNotEmpty && history.length == 1 && await runner.getUserVersion() == 8;
        },
      );

      expect(historyCreatedBeforeVersionBump, isTrue);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
      final List<Map<String, Object?>> category = await legacyDatabase.executor.runSelect(
        'SELECT bezeichnung, konto_skr03, euer_zeile FROM kategorien WHERE id = 7',
        const <Object?>[],
      );
      expect(category.single['bezeichnung'], 'Legacy category');
      expect(category.single['konto_skr03'], '8123');
      expect(category.single['euer_zeile'], 15);
    });

    test('test_profile_data_portability_008_unknown_lazy_table_state_is_not_repaired_by_init', () async {
      const List<String> lazyTables = <String>['buchungsvorlagen_occurrences', 'rechnungsvorlagen_occurrences'];
      final List<(String, Future<void> Function())> initializers = <(String, Future<void> Function())>[
        ('buchungsvorlagen_occurrences', () => BuchungsVorlagenRepository(database.executor).ensureSchema()),
        ('rechnungsvorlagen_occurrences', () => RechnungsVorlagenRepository(database.executor).ensureSchema()),
      ];

      await Future.wait<void>(initializers.map((entry) => entry.$2()));
      for (final (String tableName, _) in initializers) {
        final List<Map<String, Object?>> state = await database.executor.runSelect(
          'SELECT state FROM feature_table_state WHERE table_name = ?',
          <Object?>[tableName],
        );
        expect(state.single['state'], 'initialized');
      }

      for (final String tableName in lazyTables) {
        await database.executor.runCustom('DROP TABLE $tableName');
        await database.executor.runCustom(
          "UPDATE feature_table_state SET state = 'unknown' WHERE table_name = ?",
          <Object?>[tableName],
        );
      }
      for (final (String tableName, Future<void> Function() initialize) in initializers) {
        await expectLater(initialize(), throwsA(isA<StateError>()));
        final List<Map<String, Object?>> occurrenceTable = await database.executor.runSelect(
          'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
          <Object?>['table', tableName],
        );
        expect(occurrenceTable, isEmpty);
        final List<Map<String, Object?>> state = await database.executor.runSelect(
          'SELECT state FROM feature_table_state WHERE table_name = ?',
          <Object?>[tableName],
        );
        expect(state.single['state'], 'unknown');
      }
    });

    test('test_profile_data_portability_marker_table_mismatch_fails_schema_health', () async {
      await BuchungsVorlagenRepository(database.executor).ensureSchema();
      await database.executor.runCustom(
        "UPDATE feature_table_state SET state = 'never_initialized' WHERE table_name = 'buchungsvorlagen_occurrences'",
      );

      final MigrationRunner runner = MigrationRunner(
        executor: database.executor,
        profileDir: Directory.systemTemp.path,
        requiredTables: AppDatabase.allTableNames,
      );
      final SchemaHealthReport health = await runner.inspectSchemaHealth();

      expect(health.isHealthy, isFalse);
      expect(health.isCompleteForVersion13Export, isFalse);

      await database.executor.runCustom(
        "UPDATE feature_table_state SET state = 'initialized' WHERE table_name = 'buchungsvorlagen_occurrences'",
      );
      await database.executor.runCustom('DROP TABLE buchungsvorlagen_occurrences');
      expect((await runner.inspectSchemaHealth()).isHealthy, isFalse);

      await database.executor.runCustom(
        "DELETE FROM feature_table_state WHERE table_name = 'buchungsvorlagen_occurrences'",
      );
      expect((await runner.inspectSchemaHealth()).isHealthy, isFalse);
    });
  });
}
