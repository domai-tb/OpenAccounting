import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';

/// Database-backed read model used by the shell's first-release destinations.
///
/// Each route owns its presentation, while this boundary keeps the route
/// smoke surface connected to the same database that production injects.
class RouteDataRepository {
  const RouteDataRepository(this.executor);

  final QueryExecutor executor;

  static const Set<String> _allowedTables = <String>{
    'rechnungen',
    'belege',
    'bank_transaktionen',
    'kunden',
    'ustva_exporte',
    'journal',
    'unternehmen',
  };

  Future<int> count(String table) async {
    _checkTable(table);
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT COUNT(*) AS anzahl FROM $table',
      const <Object?>[],
    );
    final Object? value = rows.single['anzahl'];
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<bool> contains(String table, int id) async {
    _checkTable(table);
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id FROM $table WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    return rows.isNotEmpty;
  }

  /// Returns the latest rows for a destination. The table name is checked
  /// against the allow-list before it is interpolated into SQL; values remain
  /// bound parameters throughout the data boundary.
  Future<List<Map<String, Object?>>> list(String table, {int limit = 100, String? typ, String? status}) async {
    _checkTable(table);
    final int safeLimit = limit.clamp(1, 500);
    final List<String> predicates = <String>[];
    final List<Object?> args = <Object?>[];
    if (table == 'rechnungen') {
      if (typ != null && typ.trim().isNotEmpty) {
        predicates.add('typ = ?');
        args.add(typ.trim());
      }
      if (status != null && status.trim().isNotEmpty) {
        predicates.add('status = ?');
        args.add(status.trim());
      }
    }
    final String where = predicates.isEmpty ? '' : ' WHERE ${predicates.join(' AND ')}';
    args.add(safeLimit);
    return executor.runSelect('SELECT * FROM $table$where ORDER BY id DESC LIMIT ?', args);
  }

  Future<Map<String, Object?>?> find(String table, int id) async {
    _checkTable(table);
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM $table WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    return rows.isEmpty ? null : rows.single;
  }

  void _checkTable(String table) {
    if (!_allowedTables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Route table is not allow-listed');
    }
  }
}

final routeDataRepositoryProvider = Provider<RouteDataRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return RouteDataRepository(db.executor);
});

final routeRecordCountProvider = FutureProvider.family<int, String>((ref, table) {
  return ref.watch(routeDataRepositoryProvider).count(table);
});

final routeRecordsProvider = FutureProvider.family<List<Map<String, Object?>>, String>((ref, table) {
  return ref.watch(routeDataRepositoryProvider).list(table);
});

@immutable
class RouteRecordsQuery {
  const RouteRecordsQuery({required this.table, this.typ, this.status});

  final String table;
  final String? typ;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is RouteRecordsQuery && other.table == table && other.typ == typ && other.status == status;

  @override
  int get hashCode => Object.hash(table, typ, status);
}

final routeRecordsQueryProvider = FutureProvider.family<List<Map<String, Object?>>, RouteRecordsQuery>(
  (ref, query) => ref.watch(routeDataRepositoryProvider).list(query.table, typ: query.typ, status: query.status),
);

@immutable
class RouteRecordKey {
  const RouteRecordKey({required this.table, required this.id});

  final String table;
  final int id;

  @override
  bool operator ==(Object other) {
    return other is RouteRecordKey && other.table == table && other.id == id;
  }

  @override
  int get hashCode => Object.hash(table, id);
}

final routeRecordExistsProvider = FutureProvider.family<bool, RouteRecordKey>((ref, record) {
  return ref.watch(routeDataRepositoryProvider).contains(record.table, record.id);
});

final routeRecordProvider = FutureProvider.family<Map<String, Object?>?, RouteRecordKey>((ref, record) {
  return ref.watch(routeDataRepositoryProvider).find(record.table, record.id);
});
