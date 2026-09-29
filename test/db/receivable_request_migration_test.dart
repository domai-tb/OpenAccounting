import 'package:drift/drift.dart';
import 'package:drift/native.dart' as drift_native;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

void main() {
  group('receivable request fingerprint migration', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() => db.close());

    test('test_v7_lazy_table_migrates_without_changing_legacy_rows', () async {
      final repo = ForderungenRepository(db.executor);
      final f = await repo.create(typ: 'rechnung', betrag: 20, partnerTyp: 'kunde', partnerId: await _kunde(db));
      final rows = await db.executor.runSelect('PRAGMA table_info(forderung_zahlungen)', const <Object?>[]);
      expect(rows.map((row) => row['name']), contains('requested_betrag_cents'));
      expect(f.id, greaterThan(0));
    });

    test('test_missing_v7_relation_table_is_created_safely', () async {
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');
      await db.executor.runCustom('PRAGMA user_version = 7');
      final runner = MigrationRunner(executor: db.executor, profileDir: '/tmp');
      await runner.run(createSchema: () async {});
      expect(await _tableExists(db, 'forderung_zahlungen'), isTrue);
      expect(await runner.getUserVersion(), 8);
    });

    test('test_present_v7_relation_table_repairs_missing_constraints', () async {
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');
      await db.executor.runCustom(
        'CREATE TABLE forderung_zahlungen (id INTEGER PRIMARY KEY, forderung_id INTEGER, journal_id INTEGER, betrag NUMERIC, typ TEXT, datum TEXT, idempotency_key TEXT)',
      );
      await db.executor.runCustom('PRAGMA user_version = 7');
      final runner = MigrationRunner(executor: db.executor, profileDir: '/tmp');
      await runner.run(createSchema: () async {});
      final columns = await db.executor.runSelect('PRAGMA table_info(forderung_zahlungen)', const <Object?>[]);
      expect(
        columns.map((row) => row['name']),
        containsAll(<String>['requested_betrag_cents', 'fingerprint_direction', 'fingerprint_date_policy']),
      );
    });

    test('test_duplicate_legacy_key_rolls_migration_back', () async {
      await db.executor.runCustom('PRAGMA user_version = 7');
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');
      await db.executor.runCustom(
        'CREATE TABLE forderung_zahlungen (id INTEGER PRIMARY KEY, forderung_id INTEGER, journal_id INTEGER, betrag NUMERIC, typ TEXT, datum TEXT, idempotency_key TEXT)',
      );
      await db.executor.runCustom(
        "INSERT INTO forderung_zahlungen (id, idempotency_key) VALUES (1, 'duplicate'), (2, 'duplicate')",
      );
      await expectLater(
        MigrationRunner(executor: db.executor, profileDir: '/tmp').run(createSchema: () async {}),
        throwsA(anything),
      );
      expect(await MigrationRunner(executor: db.executor, profileDir: '/tmp').getUserVersion(), 7);
    });

    test('test_migration_failure_preserves_base_table_count', () async {
      final before = await _baseTableCount(db);
      await db.executor.runCustom('PRAGMA user_version = 7');
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');
      await expectLater(
        MigrationRunner(
          executor: db.executor,
          profileDir: '/tmp',
        ).run(createSchema: () async {}, afterFeatureSchemaDdl: (executor) async => throw StateError('failure')),
        throwsA(anything),
      );
      expect(await _baseTableCount(db), before);
    });

    test('test_app_database_post_ddl_failure_rolls_back_before_startup_side_effects', () async {
      final failing = AppDatabase.forTesting(
        drift_native.NativeDatabase.memory(),
        afterFeatureSchemaDdl: (executor) async => throw StateError('feature failure'),
      );
      addTearDown(failing.close);
      await expectLater(failing.ensureOpen(), throwsA(isA<ForderungenException>()));
      expect(failing.isOpen, isFalse);
    });

    test('test_current_v8_repairs_missing_feature_table_transactionally', () async {
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');
      await db.executor.runCustom('PRAGMA user_version = 8');
      final runner = MigrationRunner(executor: db.executor, profileDir: '/tmp');
      await runner.run(createSchema: () async {});
      expect(await _tableExists(db, 'forderung_zahlungen'), isTrue);
      expect(await runner.getUserVersion(), 8);
    });

    test('test_fresh_upgrade_current_v8_repair_and_rollback_share_raw_begin_migration_path', () async {
      final statements = <String>[];
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');
      await db.executor.runCustom('PRAGMA user_version = 8');
      final recording = _RecordingExecutor(db.executor, statements);
      final runner = MigrationRunner(executor: recording, profileDir: '/tmp');
      await runner.run(createSchema: () async {});
      expect(statements, contains('BEGIN'));
      expect(statements, contains('COMMIT'));
    });
  });
}

Future<int> _kunde(AppDatabase db) => db.executor.runInsert(
  "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Migration', 'A', '10115', 'Berlin', 'DE')",
  const <Object?>[],
);

Future<bool> _tableExists(AppDatabase db, String table) async {
  final rows = await db.executor.runSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    <Object?>[table],
  );
  return rows.isNotEmpty;
}

Future<int> _baseTableCount(AppDatabase db) async {
  final rows = await db.executor.runSelect(
    "SELECT count(*) AS c FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'forderung_zahlungen'",
    const <Object?>[],
  );
  return (rows.single['c']! as num).toInt();
}

class _RecordingExecutor extends QueryExecutor {
  _RecordingExecutor(this.delegate, this.statements);

  final QueryExecutor delegate;
  final List<String> statements;

  @override
  SqlDialect get dialect => delegate.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => delegate.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) =>
      delegate.runSelect(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) => delegate.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) => delegate.runUpdate(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) => delegate.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    statements.add(statement.trim().toUpperCase());
    return delegate.runCustom(statement, args);
  }

  @override
  Future<void> runBatched(BatchedStatements statements) => delegate.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => delegate.beginTransaction();

  @override
  QueryExecutor beginExclusive() => delegate.beginExclusive();

  @override
  Future<void> close() => delegate.close();
}
