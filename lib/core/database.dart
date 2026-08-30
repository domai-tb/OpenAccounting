import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' as drift_native;
import 'package:drift_flutter/drift_flutter.dart' show driftDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ponytail: placeholder drift wiring — no tables yet (Batch 3 adds 38 tables).
// Uses drift executor directly to avoid codegen. Upgrade to @DriftDatabase when schema lands.
// ponytail: keep get_it alongside Riverpod for migration — Riverpod per D1, AppScope wrapper stays per AGENTS.md.

/// Minimal app database that opens a SQLite connection on startup.
/// Batch 1: verifies connection opens with WAL + FK; schema deferred to Batch 3.
class AppDatabase {
  final QueryExecutor _executor;

  AppDatabase([QueryExecutor? executor]) : _executor = executor ?? driftDatabase(name: 'openaccounting');

  /// Test constructor — inject in-memory executor.
  AppDatabase.forTesting(QueryExecutor executor) : _executor = executor;

  bool _opened = false;

  /// Opens the underlying connection and enforces required PRAGMAs.
  /// Executes WAL + foreign_keys before any query per D2 spec.
  Future<void> ensureOpen() async {
    if (_opened) return;
    await _executor.ensureOpen(_NoopUser());
    await _executor.runCustom('PRAGMA journal_mode = WAL');
    await _executor.runCustom('PRAGMA foreign_keys = ON');
    await _executor.runSelect('SELECT 1', const []);
    _opened = true;
  }

  bool get isOpen => _opened;

  Future<void> close() async {
    await _executor.close();
    _opened = false;
  }

  QueryExecutor get executor => _executor;
}

class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

/// Riverpod provider for the app database. Overridden in tests with in-memory.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    unawaited(db.close());
  });
  return db;
});

/// Helper for VM tests that need an in-memory instance.
AppDatabase createTestDatabase() => AppDatabase.forTesting(drift_native.NativeDatabase.memory());
