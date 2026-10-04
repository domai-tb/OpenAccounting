import 'package:drift/drift.dart'
    show BatchedStatements, QueryExecutor, QueryExecutorUser, SqlDialect, TransactionExecutor;
import 'package:drift/native.dart' as drift_native;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

void main() {
  group('receivable request fingerprint migration', () {
    late drift_native.NativeDatabase native;

    setUp(() => native = drift_native.NativeDatabase.memory());

    tearDown(() => native.close());

    test('test_v7_lazy_table_migrates_without_changing_legacy_rows', () async {
      final AppDatabase seed = await _seedV8(native);
      final int partnerId = await seed.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Migration', 'A', '10115', 'Berlin', 'DE')",
        const <Object?>[],
      );
      final int forderungId = await seed.executor.runInsert(
        'INSERT INTO forderungen (betrag, anfangsbetrag, status, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[100, 100, 'offen', 'rechnung', 'kunde', partnerId],
      );
      final int journalId = await seed.executor.runInsert(
        "INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES ('2026-01-05', 'legacy payment', '10.00', 'zahlung', NULL, CURRENT_TIMESTAMP)",
        const <Object?>[],
      );
      final int secondJournalId = await seed.executor.runInsert(
        "INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES ('2026-01-06', 'legacy write-off', '5.00', 'ausbuchung', NULL, CURRENT_TIMESTAMP)",
        const <Object?>[],
      );
      await _dropFeatureTable(seed.executor);
      await seed.executor.runCustom(
        'CREATE TABLE forderung_zahlungen (id INTEGER PRIMARY KEY, forderung_id INTEGER, journal_id INTEGER, '
        'betrag NUMERIC, typ TEXT, datum TEXT, idempotency_key TEXT)',
      );
      await seed.executor.runCustom(
        'INSERT INTO forderung_zahlungen (id, forderung_id, journal_id, betrag, typ, datum, idempotency_key) '
        "VALUES (1, $forderungId, $journalId, '10.00', 'zahlung', '2026-01-05', 'legacy-1')",
      );
      await seed.executor.runCustom(
        'INSERT INTO forderung_zahlungen (id, forderung_id, journal_id, betrag, typ, datum, idempotency_key) '
        "VALUES (2, $forderungId, $secondJournalId, '5.00', 'ausbuchen', '2026-01-06', NULL)",
      );
      await seed.executor.runCustom('PRAGMA user_version = 7');

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _userVersion(native), 11);
      final List<String> columns = await _columnNames(native, 'forderung_zahlungen');
      expect(
        columns,
        containsAll(<String>['requested_betrag_cents', 'fingerprint_direction', 'fingerprint_date_policy']),
      );
      final List<Map<String, Object?>> rows = await native.runSelect(
        'SELECT id, forderung_id, journal_id, betrag, typ, datum, idempotency_key, '
        'requested_betrag_cents, fingerprint_direction, fingerprint_date_policy '
        'FROM forderung_zahlungen ORDER BY id',
        const <Object?>[],
      );
      expect(rows, hasLength(2));
      // Legacy values are preserved exactly; fingerprint fields stay null (legacy-unknown).
      expect(num.parse(rows[0]['betrag'].toString()), 10);
      expect(rows[0]['typ'], 'zahlung');
      expect(rows[0]['datum'], '2026-01-05');
      expect(rows[0]['idempotency_key'], 'legacy-1');
      expect(rows[0]['forderung_id'], forderungId);
      expect(rows[0]['journal_id'], journalId);
      expect(rows[0]['requested_betrag_cents'], isNull);
      expect(rows[0]['fingerprint_direction'], isNull);
      expect(rows[0]['fingerprint_date_policy'], isNull);
      expect(num.parse(rows[1]['betrag'].toString()), 5);
      expect(rows[1]['typ'], 'ausbuchen');
      expect(rows[1]['datum'], '2026-01-06');
      expect(rows[1]['idempotency_key'], isNull);
      expect(rows[1]['requested_betrag_cents'], isNull);
      // The migration must not infer fingerprint values from legacy data.
      final List<Map<String, Object?>> inferred = await native.runSelect(
        'SELECT count(*) AS c FROM forderung_zahlungen '
        'WHERE requested_betrag_cents IS NOT NULL OR fingerprint_direction IS NOT NULL '
        'OR fingerprint_date_policy IS NOT NULL',
        const <Object?>[],
      );
      expect(inferred.single['c'], 0);
    });

    test('test_missing_v7_relation_table_is_created_safely', () async {
      final AppDatabase seed = await _seedV8(native);
      await _dropFeatureTable(seed.executor);
      await seed.executor.runCustom('PRAGMA user_version = 7');
      expect(await _allTableCount(native), 40);

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _tableExists(native, 'forderung_zahlungen'), isTrue);
      expect(await _foreignKeyTargets(native, 'forderung_zahlungen'), containsAll(<String>['forderungen', 'journal']));
      expect(
        await _indexNames(native, 'forderung_zahlungen'),
        containsAll(<String>['forderung_zahlungen_key_unique', 'forderung_zahlungen_journal_unique']),
      );
      // No fabricated historical payment rows.
      expect(await _rowCount(native, 'forderung_zahlungen'), 0);
      expect(await _userVersion(native), 11);
      expect(await _allTableCount(native), 41);
    });

    test('test_present_v7_relation_table_repairs_missing_constraints', () async {
      final AppDatabase seed = await _seedV8(native);
      final int journalId = await seed.executor.runInsert(
        "INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES ('2026-02-02', 'legacy repair', '7.00', 'zahlung', NULL, CURRENT_TIMESTAMP)",
        const <Object?>[],
      );
      await _dropFeatureTable(seed.executor);
      await seed.executor.runCustom(
        'CREATE TABLE forderung_zahlungen (id INTEGER PRIMARY KEY, forderung_id INTEGER, journal_id INTEGER, '
        'betrag NUMERIC, typ TEXT, datum TEXT, idempotency_key TEXT)',
      );
      await seed.executor.runCustom(
        'INSERT INTO forderung_zahlungen (id, forderung_id, journal_id, betrag, typ, datum, idempotency_key) '
        "VALUES (1, 1, $journalId, '7.00', 'zahlung', '2026-02-02', 'legacy-repair')",
      );
      await seed.executor.runCustom('PRAGMA user_version = 7');
      expect(await _indexNames(native, 'forderung_zahlungen'), isEmpty);

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(
        await _indexNames(native, 'forderung_zahlungen'),
        containsAll(<String>['forderung_zahlungen_key_unique', 'forderung_zahlungen_journal_unique']),
      );
      final Map<String, Object?> row = (await native.runSelect(
        'SELECT forderung_id, journal_id, betrag, typ, datum, idempotency_key, requested_betrag_cents '
        'FROM forderung_zahlungen WHERE id = 1',
        const <Object?>[],
      )).single;
      expect(row['forderung_id'], 1);
      expect(row['journal_id'], journalId);
      expect(num.parse(row['betrag'].toString()), 7);
      expect(row['typ'], 'zahlung');
      expect(row['datum'], '2026-02-02');
      expect(row['idempotency_key'], 'legacy-repair');
      expect(row['requested_betrag_cents'], isNull);
      expect(await _userVersion(native), 11);
      // Base schema stays exactly 39 tables plus the feature table.
      expect(await _baseTableCount(native), 40);
      expect(await _allTableCount(native), 41);
    });

    test('test_duplicate_legacy_key_rolls_migration_back', () async {
      final AppDatabase seed = await _seedV8(native);
      await _dropFeatureTable(seed.executor);
      await seed.executor.runCustom(
        'CREATE TABLE forderung_zahlungen (id INTEGER PRIMARY KEY, forderung_id INTEGER, journal_id INTEGER, '
        'betrag NUMERIC, typ TEXT, datum TEXT, idempotency_key TEXT)',
      );
      await seed.executor.runCustom(
        "INSERT INTO forderung_zahlungen (id, idempotency_key) VALUES (1, 'duplicate'), (2, 'duplicate')",
      );
      await seed.executor.runCustom('PRAGMA user_version = 7');
      final int tablesBefore = await _allTableCount(native);

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      final ForderungenException error = await _expectSchemaMigrationFailed(db);

      expect(error, isA<ForderungenException>());
      expect(await _userVersion(native), 7);
      // Original columns, rows, and index state are preserved; no partial fingerprint residue.
      final List<String> columns = await _columnNames(native, 'forderung_zahlungen');
      expect(columns, isNot(contains('requested_betrag_cents')));
      expect(columns, isNot(contains('fingerprint_direction')));
      expect(columns, isNot(contains('fingerprint_date_policy')));
      expect(await _indexNames(native, 'forderung_zahlungen'), isEmpty);
      final List<Map<String, Object?>> rows = await native.runSelect(
        'SELECT id, idempotency_key FROM forderung_zahlungen ORDER BY id',
        const <Object?>[],
      );
      expect(rows, hasLength(2));
      expect(rows[0]['idempotency_key'], 'duplicate');
      expect(rows[1]['idempotency_key'], 'duplicate');
      expect(await _allTableCount(native), tablesBefore);
    });

    test('test_migration_failure_preserves_base_table_count', () async {
      final AppDatabase seed = await _seedV8(native);
      await _dropFeatureTable(seed.executor);
      await seed.executor.runCustom('PRAGMA user_version = 7');
      expect(await _allTableCount(native), 40);

      final AppDatabase db = AppDatabase.forTesting(
        native,
        afterFeatureSchemaDdl: (QueryExecutor executor) async => throw StateError('forced DDL failure'),
      );
      addTearDown(db.close);
      await _expectSchemaMigrationFailed(db);

      expect(await _allTableCount(native), 40);
      expect(await _tableExists(native, 'forderung_zahlungen'), isFalse);
      expect(await _userVersion(native), 7);
      expect(db.isOpen, isFalse);
      expect(() => db.kundenRepository, throwsStateError);
    });

    test('test_app_database_post_ddl_failure_rolls_back_before_startup_side_effects', () async {
      final AppDatabase seed = await _seedV8(native);
      await _dropFeatureTable(seed.executor);
      await seed.executor.runCustom('PRAGMA user_version = 7');
      final int triggerCountBefore = await _triggerCount(native);
      final int seedRowsBefore = await _seedRowCount(native);
      expect(triggerCountBefore, greaterThan(0), reason: 'fixture must already contain installed triggers');
      expect(seedRowsBefore, greaterThan(0), reason: 'fixture must already contain seed rows');

      final List<String> statements = <String>[];
      bool observedFeatureTable = false;
      final AppDatabase failing = AppDatabase.forTesting(
        _RecordingExecutor(native, statements),
        afterFeatureSchemaDdl: (QueryExecutor executor) async {
          final List<Map<String, Object?>> table = await executor.runSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
            const <Object?>[],
          );
          final List<Map<String, Object?>> columns = await executor.runSelect(
            'PRAGMA table_info(forderung_zahlungen)',
            const <Object?>[],
          );
          observedFeatureTable =
              table.isNotEmpty && columns.any((Map<String, Object?> row) => row['name'] == 'requested_betrag_cents');
          throw StateError('feature failure');
        },
      );
      addTearDown(failing.close);

      final ForderungenException error = await _expectSchemaMigrationFailed(failing);

      // The callback observed the feature DDL before throwing (inside the migration transaction).
      expect(observedFeatureTable, isTrue);
      expect(error.cause, isA<StateError>());
      // Failure surfaces typed, without requiring raw SQL text in the public message.
      expect(error.code, ForderungenErrorCode.schemaMigrationFailed);
      expect(error.toString(), isNot(contains('CREATE TABLE')));
      // Startup side effects never ran: no post-migration trigger installs and no
      // seed inserts during this open. Migration-transaction DDL for the
      // append-only category history triggers is rolled back with the rest.
      expect(
        statements.any((String s) => s.contains('CREATE TRIGGER') && !s.contains('CATEGORY_MAPPING_HISTORY')),
        isFalse,
      );
      expect(statements.any((String s) => s.startsWith('INSERT OR IGNORE')), isFalse);
      expect(failing.isOpen, isFalse);
      expect(() => failing.kundenRepository, throwsStateError);
      expect(() => failing.kategorienRepository, throwsStateError);
      // Rolled back to the v7 fixture: version, base tables, and seed/trigger state unchanged.
      expect(await _userVersion(native), 7);
      expect(await _allTableCount(native), 40);
      expect(await _tableExists(native, 'forderung_zahlungen'), isFalse);
      expect(await _triggerCount(native), triggerCountBefore);
      expect(await _seedRowCount(native), seedRowsBefore);
    });

    test('test_current_v11_repairs_missing_feature_table_transactionally', () async {
      final AppDatabase seed = await _seedV8(native);
      await _dropFeatureTable(seed.executor);
      await seed.executor.runCustom('PRAGMA user_version = 11');
      expect(await _allTableCount(native), 40);

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _tableExists(native, 'forderung_zahlungen'), isTrue);
      expect(await _userVersion(native), 11);
      expect(await _baseTableCount(native), 40);
      expect(await _allTableCount(native), 41);
      expect(db.isOpen, isTrue);
    });

    test('test_current_v11_repairs_all_columns_when_constraints_are_missing', () async {
      final AppDatabase seed = await _seedV8(native);
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await seed.executor.runCustom('''
CREATE TABLE forderung_zahlungen (
  id INTEGER PRIMARY KEY,
  forderung_id INTEGER,
  journal_id INTEGER,
  betrag NUMERIC,
  typ TEXT,
  datum TEXT,
  idempotency_key TEXT,
  requested_betrag_cents INTEGER,
  fingerprint_direction TEXT,
  fingerprint_date_policy TEXT
)''');
      await seed.executor.runCustom('PRAGMA user_version = 11');

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _foreignKeyTargets(native, 'forderung_zahlungen'), containsAll(<String>['forderungen', 'journal']));
      expect(
        await _indexNames(native, 'forderung_zahlungen'),
        containsAll(<String>['forderung_zahlungen_key_unique', 'forderung_zahlungen_journal_unique']),
      );
      expect(await _userVersion(native), 11);
    });

    test('test_fresh_upgrade_current_v11_repair_and_rollback_share_raw_begin_migration_path', () async {
      // Fixture A: fresh empty profile.
      final drift_native.NativeDatabase freshNative = drift_native.NativeDatabase.memory();
      final List<String> freshStatements = <String>[];
      final AppDatabase fresh = AppDatabase.forTesting(_RecordingExecutor(freshNative, freshStatements));
      await fresh.ensureOpen();
      final int freshBegin = freshStatements.indexOf('BEGIN');
      final int freshCommit = freshStatements.indexOf('COMMIT');
      expect(freshBegin, greaterThanOrEqualTo(0));
      expect(freshBegin, lessThan(freshCommit));
      expect(freshCommit, greaterThan(0));
      final int freshDdl = freshStatements.indexWhere(
        (String s) => s.startsWith('CREATE TABLE') && s.contains('FORDERUNG_ZAHLUNGEN'),
      );
      expect(freshDdl, greaterThan(freshBegin));
      expect(freshDdl, lessThan(freshCommit));
      final int freshVersion = freshStatements.indexOf('PRAGMA USER_VERSION = 11');
      expect(freshVersion, greaterThan(freshBegin));
      expect(freshVersion, lessThan(freshCommit));
      expect(
        freshStatements.indexWhere(
          (String s) => s.contains('CREATE TRIGGER') && !s.contains('CATEGORY_MAPPING_HISTORY'),
        ),
        greaterThan(freshCommit),
      );
      expect(freshStatements.indexWhere((String s) => s.startsWith('INSERT OR IGNORE')), greaterThan(freshCommit));
      expect(await _userVersion(freshNative), 11);
      await fresh.close();

      // Fixture B: v7 upgrade.
      final drift_native.NativeDatabase upgradeNative = drift_native.NativeDatabase.memory();
      final AppDatabase upgradeSeed = AppDatabase.forTesting(upgradeNative);
      await upgradeSeed.ensureOpen();
      await _dropFeatureTable(upgradeSeed.executor);
      await upgradeSeed.executor.runCustom('PRAGMA user_version = 7');
      final List<String> upgradeStatements = <String>[];
      final AppDatabase upgraded = AppDatabase.forTesting(_RecordingExecutor(upgradeNative, upgradeStatements));
      await upgraded.ensureOpen();
      final int upgradeBegin = upgradeStatements.indexOf('BEGIN');
      final int upgradeCommit = upgradeStatements.indexOf('COMMIT');
      expect(upgradeBegin, greaterThanOrEqualTo(0));
      expect(upgradeBegin, lessThan(upgradeCommit));
      final int upgradeDdl = upgradeStatements.indexWhere(
        (String s) => s.startsWith('CREATE TABLE') && s.contains('FORDERUNG_ZAHLUNGEN'),
      );
      expect(upgradeDdl, greaterThan(upgradeBegin));
      expect(upgradeDdl, lessThan(upgradeCommit));
      final int upgradeVersion = upgradeStatements.indexOf('PRAGMA USER_VERSION = 11');
      expect(upgradeVersion, greaterThan(upgradeBegin));
      expect(upgradeVersion, lessThan(upgradeCommit));
      expect(
        upgradeStatements.indexWhere(
          (String s) => s.contains('CREATE TRIGGER') && !s.contains('CATEGORY_MAPPING_HISTORY'),
        ),
        greaterThan(upgradeCommit),
      );
      expect(await _userVersion(upgradeNative), 11);
      expect(await _tableExists(upgradeNative, 'forderung_zahlungen'), isTrue);
      await upgraded.close();

      // Fixture C: current-version repair of a missing feature table.
      final drift_native.NativeDatabase repairNative = drift_native.NativeDatabase.memory();
      final AppDatabase repairSeed = AppDatabase.forTesting(repairNative);
      await repairSeed.ensureOpen();
      await _dropFeatureTable(repairSeed.executor);
      final List<String> repairStatements = <String>[];
      final AppDatabase repaired = AppDatabase.forTesting(_RecordingExecutor(repairNative, repairStatements));
      await repaired.ensureOpen();
      final int repairBegin = repairStatements.indexOf('BEGIN');
      final int repairCommit = repairStatements.indexOf('COMMIT');
      expect(repairBegin, greaterThanOrEqualTo(0));
      expect(repairBegin, lessThan(repairCommit));
      final int repairDdl = repairStatements.indexWhere(
        (String s) => s.startsWith('CREATE TABLE') && s.contains('FORDERUNG_ZAHLUNGEN'),
      );
      expect(repairDdl, greaterThan(repairBegin));
      expect(repairDdl, lessThan(repairCommit));
      final int repairVersion = repairStatements.indexOf('PRAGMA USER_VERSION = 11');
      expect(repairVersion, greaterThan(repairBegin));
      expect(repairVersion, lessThan(repairCommit));
      expect(repairStatements.indexWhere((String s) => s.contains('CREATE TRIGGER')), greaterThan(repairCommit));
      expect(repairStatements.indexWhere((String s) => s.startsWith('INSERT OR IGNORE')), greaterThan(repairCommit));
      expect(await _userVersion(repairNative), 11);
      expect(await _tableExists(repairNative, 'forderung_zahlungen'), isTrue);
      await repaired.close();

      // Fixture D: injected current-version failure records raw BEGIN then ROLLBACK and leaves no residue.
      final drift_native.NativeDatabase failNative = drift_native.NativeDatabase.memory();
      final AppDatabase failSeed = AppDatabase.forTesting(failNative);
      await failSeed.ensureOpen();
      await _dropFeatureTable(failSeed.executor);
      final List<String> failStatements = <String>[];
      final AppDatabase failing = AppDatabase.forTesting(
        _RecordingExecutor(failNative, failStatements),
        afterFeatureSchemaDdl: (QueryExecutor executor) async => throw StateError('forced repair failure'),
      );
      await _expectSchemaMigrationFailed(failing);
      final int failBegin = failStatements.indexOf('BEGIN');
      expect(failBegin, greaterThanOrEqualTo(0));
      expect(failStatements, contains('ROLLBACK'));
      expect(failStatements, isNot(contains('COMMIT')));
      expect(failBegin, lessThan(failStatements.indexOf('ROLLBACK')));
      final int failDdl = failStatements.indexWhere(
        (String s) => s.startsWith('CREATE TABLE') && s.contains('FORDERUNG_ZAHLUNGEN'),
      );
      expect(failDdl, greaterThan(failBegin));
      expect(failDdl, lessThan(failStatements.indexOf('ROLLBACK')));
      // No startup side effects after the failed transaction (migration-internal
      // category-history trigger DDL rolls back with the transaction).
      expect(
        failStatements.any((String s) => s.contains('CREATE TRIGGER') && !s.contains('CATEGORY_MAPPING_HISTORY')),
        isFalse,
      );
      expect(failStatements.any((String s) => s.startsWith('INSERT OR IGNORE')), isFalse);
      expect(await _userVersion(failNative), 11);
      expect(await _allTableCount(failNative), 40);
      expect(await _tableExists(failNative, 'forderung_zahlungen'), isFalse);
      expect(failing.isOpen, isFalse);
      await failing.close();
    });
  });
}

Future<AppDatabase> _seedV8(QueryExecutor executor) async {
  final AppDatabase seed = AppDatabase.forTesting(executor);
  await seed.ensureOpen();
  return seed;
}

Future<void> _dropFeatureTable(QueryExecutor executor) => executor.runCustom('DROP TABLE forderung_zahlungen');

Future<ForderungenException> _expectSchemaMigrationFailed(AppDatabase db) async {
  try {
    await db.ensureOpen();
    fail('expected ForderungenException with code schemaMigrationFailed');
  } on ForderungenException catch (error) {
    expect(error.code, ForderungenErrorCode.schemaMigrationFailed);
    return error;
  }
}

Future<int> _userVersion(QueryExecutor executor) async {
  final List<Map<String, Object?>> rows = await executor.runSelect('PRAGMA user_version', const <Object?>[]);
  final Object? value = rows.single.values.first;
  if (value is int) return value;
  return (value! as num).toInt();
}

Future<bool> _tableExists(QueryExecutor executor, String table) async {
  final List<Map<String, Object?>> rows = await executor.runSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    <Object?>[table],
  );
  return rows.isNotEmpty;
}

Future<int> _rowCount(QueryExecutor executor, String table) async {
  final List<Map<String, Object?>> rows = await executor.runSelect(
    'SELECT count(*) AS c FROM $table',
    const <Object?>[],
  );
  return (rows.single['c']! as num).toInt();
}

Future<int> _allTableCount(QueryExecutor executor) async {
  final List<Map<String, Object?>> rows = await executor.runSelect(
    "SELECT count(*) AS c FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    const <Object?>[],
  );
  return (rows.single['c']! as num).toInt();
}

Future<int> _baseTableCount(QueryExecutor executor) async {
  final List<Map<String, Object?>> rows = await executor.runSelect(
    "SELECT count(*) AS c FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
    "AND name != 'forderung_zahlungen'",
    const <Object?>[],
  );
  return (rows.single['c']! as num).toInt();
}

Future<List<String>> _columnNames(QueryExecutor executor, String table) async {
  final List<Map<String, Object?>> rows = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
  return rows.map((Map<String, Object?> row) => row['name']! as String).toList();
}

Future<List<String>> _indexNames(QueryExecutor executor, String table) async {
  final List<Map<String, Object?>> rows = await executor.runSelect('PRAGMA index_list($table)', const <Object?>[]);
  return rows.map((Map<String, Object?> row) => row['name']! as String).toList();
}

Future<List<String>> _foreignKeyTargets(QueryExecutor executor, String table) async {
  final List<Map<String, Object?>> rows = await executor.runSelect(
    'PRAGMA foreign_key_list($table)',
    const <Object?>[],
  );
  return rows.map((Map<String, Object?> row) => row['table']! as String).toList();
}

Future<int> _triggerCount(QueryExecutor executor) async {
  final List<Map<String, Object?>> rows = await executor.runSelect(
    "SELECT count(*) AS c FROM sqlite_master WHERE type = 'trigger'",
    const <Object?>[],
  );
  return (rows.single['c']! as num).toInt();
}

Future<int> _seedRowCount(QueryExecutor executor) async {
  final List<Map<String, Object?>> rows = await executor.runSelect(
    'SELECT (SELECT count(*) FROM ust_saetze) + (SELECT count(*) FROM kategorien) + '
    '(SELECT count(*) FROM nummernkreise) AS c',
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
