import 'package:drift/drift.dart';

import 'package:openaccounting/core/db/backup_service.dart';
import 'package:openaccounting/core/db/gobd_triggers.dart';
import 'package:openaccounting/core/db/seed.dart';

/// Migration runner per spec §Schema Versioning + §Migration System.
/// Handles PRAGMA user_version, backup-before-migrate, post-hooks.
class MigrationRunner {
  MigrationRunner({required this.executor, required this.profileDir});

  final QueryExecutor executor;
  final String profileDir;

  static const int currentVersion = 1;

  Future<int> getUserVersion() async {
    final rows = await executor.runSelect('PRAGMA user_version', const []);
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<void> setUserVersion(int v) async {
    await executor.runCustom('PRAGMA user_version = $v');
  }

  Future<bool> hasAnyTables() async {
    final rows = await executor.runSelect(
      "SELECT count(*) as c FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      const [],
    );
    final c = rows.first['c'];
    if (c is int) return c > 0;
    if (c is num) return c > 0;
    return false;
  }

  /// Run migrations if needed. Returns true if migration executed.
  Future<bool> run({required Future<void> Function() createSchema}) async {
    final version = await getUserVersion();
    final hasTables = await hasAnyTables();

    // If the database is up to date and has tables, do nothing.
    if (version == currentVersion && hasTables) {
      return false;
    }

    // If the database is from the future, we cannot downgrade.
    if (version > currentVersion) {
      return false;
    }

    // If the database is at version 0 and has no tables, it's a fresh install.
    if (version == 0 && !hasTables) {
      await createSchema();
      await setUserVersion(currentVersion);
      return false;
    }

    // If the database is at the current version but has no tables, we need to create the schema.
    if (version == currentVersion && !hasTables) {
      await createSchema();
      await setUserVersion(currentVersion);
      return true;
    }

    // If the database is outdated (version < currentVersion), we need to migrate.
    if (version < currentVersion) {
      // WAL checkpoint before backup for consistency
      try {
        await executor.runCustom('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {}
      final backup = BackupService(profileDir: profileDir, executor: executor);
      try {
        await backup.createLocalBackup();
      } catch (e) {
        // Backup failure prevents migration per spec.
        throw StateError('Backup vor Migration fehlgeschlagen: $e');
      }
      // Execute incremental migrations
      for (var v = version + 1; v <= currentVersion; v++) {
        await _migrateTo(v, createSchema);
      }
      await _postHooks();
      await setUserVersion(currentVersion);
      return true;
    }

    // Should not reach here.
    return false;
  }

  Future<void> _migrateTo(int version, Future<void> Function() createSchema) async {
    // ponytail: greenfield — only version 1 exists, future migrations stub.
    // If upgrading from 0 with existing tables, ensure missing tables created idempotently.
    if (version == 1) {
      await createSchema();
    }
  }

  Future<void> _postHooks() async {
    // Intentionally left empty.
    // Triggers and seeds are installed in AppDatabase.ensureOpen after migration.
  }
}
