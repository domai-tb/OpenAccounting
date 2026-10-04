import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';

/// Company fiscal-year start month migration (fiscal-year section 2).
void main() {
  group('Fiscal-year migration', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_fiscal_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    test('test_db_fresh_company_schema_defaults_to_january', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      final cols = await db.executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
      final col = cols.where((c) => c['name'] == 'geschaeftsjahr_startmonat').toList(growable: false);
      expect(col, hasLength(1));
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Neu')", const <Object?>[]);
      final rows = await db.executor.runSelect('SELECT geschaeftsjahr_startmonat FROM unternehmen', const []);
      expect(rows.single['geschaeftsjahr_startmonat'], 1);
    });

    test('test_db_existing_company_rows_are_migrated', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Bestand')", const <Object?>[]);
      final ddlRows = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'unternehmen'",
        const [],
      );
      final String ddl = ddlRows.single['sql']! as String;
      const String fiscalLine =
          ',\n  geschaeftsjahr_startmonat INTEGER NOT NULL DEFAULT 1 CHECK (geschaeftsjahr_startmonat BETWEEN 1 AND 12)';
      expect(ddl, contains('geschaeftsjahr_startmonat'));
      final String legacyDdl = ddl.replaceFirst(fiscalLine, '');
      final info = await db.executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
      final keep = <String>[
        for (final row in info)
          if (row['name'] != 'geschaeftsjahr_startmonat') row['name'].toString(),
      ];
      await db.executor.runCustom('ALTER TABLE unternehmen RENAME TO unternehmen_legacy');
      await db.executor.runCustom(legacyDdl);
      await db.executor.runCustom(
        'INSERT INTO unternehmen (${keep.join(', ')}) SELECT ${keep.join(', ')} FROM unternehmen_legacy',
      );
      await db.executor.runCustom('DROP TABLE unternehmen_legacy');

      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(10);
      await runner.run(createSchema: () async {});

      expect(await runner.getUserVersion(), 11);
      final rows = await db.executor.runSelect('SELECT name, geschaeftsjahr_startmonat FROM unternehmen', const []);
      expect(rows.single['name'], 'Bestand');
      expect(rows.single['geschaeftsjahr_startmonat'], 1);
    });

    test('test_db_migration_failure_preserves_the_prior_database', () async {
      final db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runCustom('DROP TABLE unternehmen');
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(10);
      await expectLater(runner.run(createSchema: () async {}), throwsA(isA<StateError>()));
      expect(await runner.getUserVersion(), 10);
    });
  });
}
