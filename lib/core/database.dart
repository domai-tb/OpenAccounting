import 'package:drift/drift.dart';
import 'package:drift/native.dart' as drift_native;
import 'package:drift_flutter/drift_flutter.dart' show driftDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ponytail: placeholder drift wiring — no tables yet (Batch 3 adds 38 tables).
// Uses drift executor directly to avoid codegen. Upgrade to @DriftDatabase when schema lands.
// ponytail: keep get_it alongside Riverpod for migration — Riverpod per D1, AppScope wrapper stays per AGENTS.md.

/// Minimal app database that opens a SQLite connection on startup.
/// Batch 1: only verifies connection opens; schema deferred to Batch 3.
class AppDatabase {
  final QueryExecutor _executor;

  AppDatabase([QueryExecutor? executor]) : _executor = executor ?? driftDatabase(name: 'openaccounting');

  /// Test constructor — inject in-memory executor.
  AppDatabase.forTesting(QueryExecutor executor) : _executor = executor;

  bool _opened = false;

  /// Opens the underlying connection. In Batch 1 this just marks opened.
  /// Future batches will run migrations + seed.
  Future<void> ensureOpen() async {
    _opened = true;
  }

  bool get isOpen => _opened;

  Future<void> close() async {
    await _executor.close();
    _opened = false;
  }

  QueryExecutor get executor => _executor;
}

/// Riverpod provider for the app database. Overridden in tests with in-memory.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() async {
    await db.close();
  });
  return db;
});

/// Helper for VM tests that need an in-memory instance.
AppDatabase createTestDatabase() => AppDatabase.forTesting(drift_native.NativeDatabase.memory());
