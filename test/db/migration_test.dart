import 'dart:io';

import 'package:drift/native.dart' as drift_native;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';

void main() {
  group('MigrationRunner', () {
    late AppDatabase db;
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_migration_test_');
      db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
      await profileDirectory.delete(recursive: true);
    });

    test('increments schema version after an outdated migration', () async {
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(MigrationRunner.currentVersion - 1);

      var migrationCalled = false;
      final migrated = await runner.run(
        createSchema: () async {
          migrationCalled = true;
        },
      );

      expect(migrated, isTrue);
      expect(migrationCalled, isTrue);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
    });

    test('rolls back schema changes when migration fails', () async {
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(MigrationRunner.currentVersion - 1);

      await expectLater(
        runner.run(
          createSchema: () async {
            await db.executor.runCustom('CREATE TABLE migration_partial (id INTEGER PRIMARY KEY)');
            throw StateError('migration failed');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(await runner.getUserVersion(), MigrationRunner.currentVersion - 1);
      final rows = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='migration_partial'",
        const [],
      );
      expect(rows, isEmpty);
    });

    test('rolls back fresh schema creation when creation fails', () async {
      final executor = drift_native.NativeDatabase.memory();
      addTearDown(executor.close);
      final runner = MigrationRunner(executor: executor, profileDir: profileDirectory.path);

      await expectLater(
        runner.run(
          createSchema: () async {
            await executor.runCustom('CREATE TABLE fresh_partial (id INTEGER PRIMARY KEY)');
            throw StateError('fresh schema failed');
          },
        ),
        throwsA(isA<StateError>()),
      );

      final rows = await executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='fresh_partial'",
        const [],
      );
      expect(rows, isEmpty);
      expect(await runner.getUserVersion(), 0);
    });

    test('preserves legacy non-draft status during v2 rebuild', () async {
      await db.executor.runCustom('PRAGMA foreign_keys = OFF');
      await db.executor.runCustom('DROP TABLE rechnungen');
      await db.executor.runCustom('''
CREATE TABLE rechnungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rechnungsnummer TEXT NOT NULL,
  typ TEXT NOT NULL,
  status TEXT DEFAULT 'entwurf',
  kunde_id INTEGER,
  lieferant_id INTEGER,
  datum TEXT NOT NULL,
  faelligkeit TEXT,
  netto_betrag NUMERIC(12,2) DEFAULT 0,
  brutto_betrag NUMERIC(12,2) DEFAULT 0,
  ust_betrag NUMERIC(12,2) DEFAULT 0,
  skonto_prozent NUMERIC(12,2) DEFAULT 0,
  skonto_faelligkeit TEXT,
  notiz TEXT,
  unternehmen_id INTEGER,
  nummernkreis_id INTEGER,
  storno_von INTEGER
)''');
      await db.executor.runCustom('''
INSERT INTO rechnungen (rechnungsnummer, typ, status, datum)
VALUES ('RE-260001', 'rechnung', 'ausgestellt', '2026-08-30')''');
      await db.executor.runCustom('PRAGMA foreign_keys = ON');

      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(MigrationRunner.currentVersion - 1);
      final migrated = await runner.run(createSchema: () async {});

      expect(migrated, isTrue);
      final rows = await db.executor.runSelect(
        'SELECT status, ist_entwurf FROM rechnungen WHERE rechnungsnummer = ?',
        <Object?>['RE-260001'],
      );
      expect(rows.single['status'], 'ausgestellt');
      expect(rows.single['ist_entwurf'], 0);

      final positionFks = await db.executor.runSelect('PRAGMA foreign_key_list(rechnungspositionen)', const []);
      expect(positionFks.any((row) => row['table'] == 'rechnungen'), isTrue);
      final foreignKeys = await db.executor.runSelect('PRAGMA foreign_keys', const []);
      expect(foreignKeys.single.values.first, 1);
    });
  });
}
