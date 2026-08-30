import 'dart:io';

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
  });
}
