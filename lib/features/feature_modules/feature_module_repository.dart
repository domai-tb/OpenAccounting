import 'package:drift/drift.dart';

import 'package:openaccounting/features/feature_modules/feature_module_state.dart';

class FeatureModuleException implements Exception {
  const FeatureModuleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sole reader and writer of `unternehmen.feature_modules_json`.
/// Legacy columns are never read or written here as runtime state;
/// they are migration-only inputs handled by the schema migration.
class FeatureModuleRepository {
  FeatureModuleRepository(this.executor);
  final QueryExecutor executor;

  /// Idempotent column hook for fresh and repaired profiles. The ordered
  /// schema migration owns backfill; this never rewrites stored values.
  Future<void> ensureColumn() async {
    final tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'unternehmen'",
      const <Object?>[],
    );
    if (tables.isEmpty) {
      throw const FeatureModuleException('Tabelle unternehmen fehlt');
    }
    final columns = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    if (columns.any((row) => row['name'] == 'feature_modules_json')) return;
    await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN feature_modules_json TEXT');
    final verified = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    if (!verified.any((row) => row['name'] == 'feature_modules_json')) {
      throw const FeatureModuleException('Funktionsmodul-Spalte konnte nicht verifiziert werden');
    }
  }

  Future<String?> loadRaw() async {
    final columns = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    if (columns.isEmpty || !columns.any((row) => row['name'] == 'feature_modules_json')) return null;
    final rows = await executor.runSelect('SELECT feature_modules_json FROM unternehmen LIMIT 1', const <Object?>[]);
    if (rows.isEmpty) return null;
    final Object? raw = rows.single['feature_modules_json'];
    return raw is String ? raw : null;
  }

  /// Saved state, or declared defaults when absent/unreadable. Never
  /// rewrites the stored value and never touches business records.
  Future<FeatureModuleState> loadOrDefaults() async {
    return FeatureModuleState.tryParse(await loadRaw()) ?? FeatureModuleState.defaults();
  }

  /// Profile initialization: persists version-1 defaults only when no
  /// canonical value exists. A malformed value resolves to defaults
  /// without rewriting the stored data.
  Future<FeatureModuleState> loadOrInitDefaults() async {
    final String? raw = await loadRaw();
    if (raw == null) return save(FeatureModuleState.defaults());
    return FeatureModuleState.tryParse(raw) ?? FeatureModuleState.defaults();
  }

  /// Persists version-1 defaults for fresh company rows (NULL-only).
  /// Single statement; leaves existing canonical values untouched.
  Future<void> ensureDefaults() async {
    await executor.runUpdate(
      'UPDATE unternehmen SET feature_modules_json = ? WHERE id = 1 AND feature_modules_json IS NULL',
      <Object?>[FeatureModuleState.defaultsEncoded()],
    );
  }

  /// Writes through the canonical column only. A failed write throws and
  /// leaves the prior canonical value in force.
  Future<FeatureModuleState> save(FeatureModuleState state) async {
    try {
      final int updated = await executor.runUpdate('UPDATE unternehmen SET feature_modules_json = ?', <Object?>[
        state.encode(),
      ]);
      if (updated == 0) {
        throw const FeatureModuleException('Kein Unternehmensprofil für Funktionsmodule vorhanden');
      }
      return state;
    } catch (error) {
      if (error is FeatureModuleException) rethrow;
      throw FeatureModuleException('Funktionsmodule konnten nicht gespeichert werden: $error');
    }
  }
}
