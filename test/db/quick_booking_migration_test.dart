import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';

/// Schnellbuchungen explicit contract: fresh schema, legacy migration, rollback.
void main() {
  group('Quick-booking migration', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_quick_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    test('test_fresh_schema_stores_the_complete_preset_contract', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      final cols = await db.executor.runSelect('PRAGMA table_info(schnellbuchungen)', const <Object?>[]);
      final names = <String>{for (final row in cols) row['name'].toString()};
      expect(
        names,
        containsAll(<String>[
          'id',
          'name',
          'kategorie_id',
          'konto_id',
          'betrag',
          'beschreibung',
          'art',
          'ust_satz_id',
          'eingabemodus',
        ]),
      );
      final betrag = cols.where((c) => c['name'] == 'betrag').single;
      expect((betrag['notnull']! as num).toInt(), 0);

      await db.executor.runInsert(
        'INSERT INTO schnellbuchungen (name, art, ust_satz_id, eingabemodus) VALUES (?, ?, ?, ?)',
        const <Object?>['Halbfertig', 'einnahme', 2, 'netto'],
      );
      await expectLater(
        db.executor.runInsert('INSERT INTO schnellbuchungen (name, art) VALUES (?, ?)', const <Object?>[
          'Falsch',
          'diagonal',
        ]),
        throwsA(anything),
      );
    });

    test('test_legacy_preset_migration_preserves_values', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      final legacyId = await db.executor.runInsert(
        'INSERT INTO schnellbuchungen (name, kategorie_id, konto_id, betrag, beschreibung) VALUES (?, ?, ?, ?, ?)',
        const <Object?>['Alt', null, null, '42.50', 'Beschreibung'],
      );
      await db.executor.runCustom('ALTER TABLE schnellbuchungen RENAME TO schnellbuchungen_probe');
      await db.executor.runCustom('''
CREATE TABLE schnellbuchungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  konto_id INTEGER REFERENCES konten(id),
  betrag NUMERIC(12,2) NOT NULL,
  beschreibung TEXT
)''');
      await db.executor.runCustom(
        'INSERT INTO schnellbuchungen (id, name, kategorie_id, konto_id, betrag, beschreibung) '
        'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung FROM schnellbuchungen_probe',
      );
      await db.executor.runCustom('DROP TABLE schnellbuchungen_probe');

      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(11);
      await runner.run(createSchema: () async {});

      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
      final rows = await db.executor.runSelect('SELECT * FROM schnellbuchungen WHERE id = ?', <Object?>[legacyId]);
      expect(rows.single['name'], 'Alt');
      expect(rows.single['betrag'].toString(), contains('42.5'));
      expect(rows.single['beschreibung'], 'Beschreibung');
      expect(rows.single['art'], isNull);
      expect(rows.single['ust_satz_id'], isNull);
      expect(rows.single['eingabemodus'], isNull);
    });

    // DB migration contract: failed v12 rebuild preserves legacy schema, values, and version.
    test('test_failed_table_rebuild_rolls_back', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runCustom('DROP TABLE schnellbuchungen');
      await db.executor.runCustom('''
CREATE TABLE schnellbuchungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  konto_id INTEGER REFERENCES konten(id),
  betrag NUMERIC(12,2) NOT NULL,
  beschreibung TEXT
)''');
      const legacyId = 741;
      await db.executor.runInsert(
        'INSERT INTO schnellbuchungen (id, name, kategorie_id, konto_id, betrag, beschreibung) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        const <Object?>[legacyId, 'Rollback sentinel', null, null, '42.50', 'Keep exactly'],
      );

      final beforeSchema = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        const <Object?>['schnellbuchungen'],
      );
      final beforeColumns = await db.executor.runSelect('PRAGMA table_info(schnellbuchungen)', const <Object?>[]);
      final beforeForeignKeyList = await db.executor.runSelect(
        'PRAGMA foreign_key_list(schnellbuchungen)',
        const <Object?>[],
      );
      final beforeRows = await db.executor.runSelect(
        'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung FROM schnellbuchungen WHERE id = ?',
        const <Object?>[legacyId],
      );
      final foreignKeysBefore = await db.executor.runSelect('PRAGMA foreign_keys', const <Object?>[]);
      final foreignKeyCheckBefore = await db.executor.runSelect('PRAGMA foreign_key_check', const <Object?>[]);
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(11);
      final versionBefore = await runner.getUserVersion();
      var rebuiltSchemaObserved = false;
      List<Map<String, Object?>> rowsDuringRebuild = <Map<String, Object?>>[];

      await expectLater(
        runner.run(
          createSchema: () async {},
          afterFeatureSchemaDdl: (executor) async {
            final rebuiltColumns = await executor.runSelect('PRAGMA table_info(schnellbuchungen)', const <Object?>[]);
            final rebuiltNames = <String>{for (final row in rebuiltColumns) row['name'].toString()};
            final rebuiltBetrag = rebuiltColumns.where((row) => row['name'] == 'betrag').single;
            rowsDuringRebuild = await executor.runSelect(
              'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung FROM schnellbuchungen WHERE id = ?',
              const <Object?>[legacyId],
            );
            rebuiltSchemaObserved =
                rebuiltNames.containsAll(<String>['art', 'ust_satz_id', 'eingabemodus']) &&
                (rebuiltBetrag['notnull']! as num).toInt() == 0;
            throw StateError('Injected failure after v12 quick-booking rebuild');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(versionBefore, 11);
      expect(rebuiltSchemaObserved, isTrue);
      expect(rowsDuringRebuild, beforeRows);
      expect(await runner.getUserVersion(), versionBefore);
      final afterSchema = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        const <Object?>['schnellbuchungen'],
      );
      final afterColumns = await db.executor.runSelect('PRAGMA table_info(schnellbuchungen)', const <Object?>[]);
      final afterForeignKeyList = await db.executor.runSelect(
        'PRAGMA foreign_key_list(schnellbuchungen)',
        const <Object?>[],
      );
      final afterRows = await db.executor.runSelect(
        'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung FROM schnellbuchungen WHERE id = ?',
        const <Object?>[legacyId],
      );
      final foreignKeysAfter = await db.executor.runSelect('PRAGMA foreign_keys', const <Object?>[]);
      final foreignKeyCheckAfter = await db.executor.runSelect('PRAGMA foreign_key_check', const <Object?>[]);
      final leftoverLegacyTable = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'schnellbuchungen_legacy'",
        const <Object?>[],
      );

      expect((beforeColumns.singleWhere((row) => row['name'] == 'betrag')['notnull']! as num).toInt(), 1);
      expect(beforeRows.single['id'], legacyId);
      expect(afterSchema, beforeSchema);
      expect(afterColumns, beforeColumns);
      expect(afterForeignKeyList, beforeForeignKeyList);
      expect(afterRows, beforeRows);
      expect(foreignKeysBefore.single.values.single, 1);
      expect(foreignKeysAfter, foreignKeysBefore);
      expect(foreignKeyCheckAfter, foreignKeyCheckBefore);
      expect(foreignKeyCheckAfter, isEmpty);
      expect(leftoverLegacyTable, isEmpty);
    });
  });
}
