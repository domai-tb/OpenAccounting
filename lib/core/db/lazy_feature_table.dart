import 'dart:async';

import 'package:drift/drift.dart';

/// Creates one recurring feature table only when its durable state permits initialization.
class LazyFeatureTableInitializer {
  /// Names of the lazy occurrence tables guarded by `feature_table_state`.
  static const Set<String> tableNames = <String>{'buchungsvorlagen_occurrences', 'rechnungsvorlagen_occurrences'};
  static final Expando<Future<void>> _pendingByExecutor = Expando<Future<void>>();

  /// Ensures [tableName] exists and atomically records its transition to `initialized`.
  static Future<void> ensure({
    required QueryExecutor executor,
    required String tableName,
    required String createTableSql,
  }) {
    if (!tableNames.contains(tableName)) {
      throw ArgumentError.value(tableName, 'tableName', 'Unknown lazy feature table');
    }

    final Future<void> previous = _pendingByExecutor[executor] ?? Future<void>.value();
    final Completer<void> release = Completer<void>();
    _pendingByExecutor[executor] = release.future;
    return _ensureAfter(previous, release, executor, tableName, createTableSql);
  }

  static Future<void> _ensureAfter(
    Future<void> previous,
    Completer<void> release,
    QueryExecutor executor,
    String tableName,
    String createTableSql,
  ) async {
    try {
      await previous;
    } catch (_) {}
    try {
      await _ensureUnlocked(executor, tableName, createTableSql);
    } finally {
      release.complete();
    }
  }

  static Future<void> _ensureUnlocked(QueryExecutor executor, String tableName, String createTableSql) async {
    final String? currentState = await _readState(executor, tableName);
    final bool tableExists = await _tableExists(executor, tableName);
    if (currentState == 'unknown') {
      throw StateError('Feature table $tableName has unknown data state; integrity reconciliation is required.');
    }
    if (currentState == 'initialized') {
      if (!tableExists) throw StateError('Feature table $tableName is marked initialized but is missing.');
      return;
    }
    if (currentState != 'never_initialized' || tableExists) {
      throw StateError('Feature table $tableName has an inconsistent state and cannot be initialized.');
    }

    await executor.runCustom('BEGIN');
    try {
      final String? transactionState = await _readState(executor, tableName);
      final bool tableExistsInTransaction = await _tableExists(executor, tableName);
      if (transactionState == 'initialized' && tableExistsInTransaction) {
        await executor.runCustom('COMMIT');
        return;
      }
      if (transactionState != 'never_initialized' || tableExistsInTransaction) {
        throw StateError('Feature table $tableName changed state before initialization.');
      }

      await executor.runCustom(createTableSql);
      final int changed = await executor.runUpdate(
        "UPDATE feature_table_state SET state = 'initialized' "
        "WHERE table_name = ? AND state = 'never_initialized'",
        <Object?>[tableName],
      );
      if (changed != 1 || !(await _tableExists(executor, tableName))) {
        throw StateError('Feature table $tableName initialization could not be verified.');
      }
      await executor.runCustom('COMMIT');
    } catch (error, stackTrace) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<String?> _readState(QueryExecutor executor, String tableName) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT state FROM feature_table_state WHERE table_name = ?',
      <Object?>[tableName],
    );
    if (rows.length != 1) return null;
    return rows.single['state']?.toString();
  }

  static Future<bool> _tableExists(QueryExecutor executor, String tableName) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      <Object?>[tableName],
    );
    return rows.isNotEmpty;
  }
}
