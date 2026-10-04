import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/bank_import/bank_import_mode_repository.dart';

/// Profile import mode: migration and persistence (bank-import section 4).
void main() {
  group('Import mode migration', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    test('test_missing_profile_mode_defaults_to_manual', () async {
      expect(await BankImportModeRepository(db.executor).getMode(), BankImportMode.manual);
    });

    test('test_version_9_profile_migrates_without_changing_company_data', () async {
      final profileDirectory = await Directory.systemTemp.createTemp('openaccounting_bank_mode_test_');
      addTearDown(() => profileDirectory.delete(recursive: true));
      final legacy = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await legacy.ensureOpen();
      addTearDown(legacy.close);
      await legacy.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Bestand GmbH']);
      // Rebuild unternehmen in its version-9 shape (without the mode column).
      final info = await legacy.executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
      final keep = <String>[
        for (final row in info)
          if (row['name'] != 'bank_import_manuell') row['name'].toString(),
      ];
      expect(keep, isNotEmpty);
      await legacy.executor.runCustom('ALTER TABLE unternehmen RENAME TO unternehmen_legacy');
      await legacy.executor.runCustom('CREATE TABLE unternehmen (${keep.join(', ')})');
      await legacy.executor.runCustom(
        'INSERT INTO unternehmen (${keep.join(', ')}) SELECT ${keep.join(', ')} FROM unternehmen_legacy',
      );
      await legacy.executor.runCustom('DROP TABLE unternehmen_legacy');

      final runner = MigrationRunner(executor: legacy.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(9);
      await runner.run(createSchema: () async {});

      expect(await runner.getUserVersion(), 10);
      final cols = await legacy.executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
      final mode = cols.where((c) => c['name'] == 'bank_import_manuell').toList(growable: false);
      expect(mode, hasLength(1));
      final names = await legacy.executor.runSelect('SELECT name, bank_import_manuell FROM unternehmen', const []);
      expect(names.single['name'], 'Bestand GmbH');
      expect(names.single['bank_import_manuell'], 1);
    });

    test('test_failed_mode_migration_rolls_back', () async {
      final profileDirectory = await Directory.systemTemp.createTemp('openaccounting_bank_mode_fail_');
      addTearDown(() => profileDirectory.delete(recursive: true));
      final broken = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await broken.ensureOpen();
      addTearDown(broken.close);
      await broken.executor.runCustom('DROP TABLE unternehmen');
      final runner = MigrationRunner(executor: broken.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(9);
      await expectLater(runner.run(createSchema: () async {}), throwsA(isA<StateError>()));
      expect(await runner.getUserVersion(), 9);
    });

    test('test_import_mode_remains_profile_scoped', () async {
      final profileDirectory = await Directory.systemTemp.createTemp('openaccounting_bank_mode_scope_');
      addTearDown(() => profileDirectory.delete(recursive: true));
      final first = AppDatabase.forProfile(profileDirectory.path);
      await first.ensureOpen();
      await first.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Profil A']);
      await BankImportModeRepository(first.executor).setMode(BankImportMode.automatic);
      await first.close();

      final reopened = AppDatabase.forProfile(profileDirectory.path);
      await reopened.ensureOpen();
      addTearDown(reopened.close);
      expect(await BankImportModeRepository(reopened.executor).getMode(), BankImportMode.automatic);

      final other = AppDatabase.createTestDatabase();
      await other.ensureOpen();
      addTearDown(other.close);
      expect(await BankImportModeRepository(other.executor).getMode(), BankImportMode.manual);
    });
  });
}
