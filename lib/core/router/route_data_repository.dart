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
