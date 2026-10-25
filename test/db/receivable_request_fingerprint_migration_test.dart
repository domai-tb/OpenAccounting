import 'package:drift/drift.dart'
    show BatchedStatements, QueryExecutor, QueryExecutorUser, SqlDialect, TransactionExecutor;
import 'package:drift/native.dart' as drift_native;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/einkommen/forderungen_usecases.dart';

Future<AppDatabase> _seedCurrent(drift_native.NativeDatabase native) async {
  final AppDatabase seed = AppDatabase.forTesting(native);
  await seed.ensureOpen();
  return seed;
}

Future<int> _userVersion(QueryExecutor executor) async {
  final List<Map<String, Object?>> rows = await executor.runSelect('PRAGMA user_version', const <Object?>[]);
  final Object? value = rows.single.values.single;
  return value is int ? value : (value! as num).toInt();
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

Future<void> _expectSchemaMigrationFailed(AppDatabase db) async {
  try {
    await db.ensureOpen();
    fail('expected ForderungenException with code schemaMigrationFailed');
  } on ForderungenException catch (error) {
    expect(error.code, ForderungenErrorCode.schemaMigrationFailed);
  }
}

Future<void> _createLegacyPaymentTable(QueryExecutor executor) {
  return executor.runCustom(
    'CREATE TABLE forderung_zahlungen (id INTEGER PRIMARY KEY, forderung_id INTEGER, journal_id INTEGER, '
    'betrag NUMERIC, typ TEXT, datum TEXT, idempotency_key TEXT)',
  );
}

void main() {
  group('receivable request fingerprint migration (customer disclosure)', () {
    test('test_customer_data_disclosure_export_032_a_v7_lazy_table_migrates_without_changing_legacy', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
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
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await _createLegacyPaymentTable(seed.executor);
      await seed.executor.runInsert(
        'INSERT INTO forderung_zahlungen (id, forderung_id, journal_id, betrag, typ, datum, idempotency_key) '
        "VALUES (1, $forderungId, $journalId, '10.00', 'zahlung', '2026-01-05', 'legacy-1')",
        const <Object?>[],
      );
      await seed.executor.runCustom('PRAGMA user_version = 7');

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _userVersion(native), MigrationRunner.currentVersion);
      expect(
        await _columnNames(native, 'forderung_zahlungen'),
        containsAll(<String>['requested_betrag_cents', 'fingerprint_direction', 'fingerprint_date_policy']),
      );
      final List<Map<String, Object?>> rows = await native.runSelect(
        'SELECT id, forderung_id, journal_id, betrag, typ, datum, idempotency_key, requested_betrag_cents, '
        'fingerprint_direction, fingerprint_date_policy FROM forderung_zahlungen ORDER BY id',
        const <Object?>[],
      );
      expect(rows, hasLength(1));
      expect(num.parse(rows.single['betrag'].toString()), 10);
      expect(rows.single['typ'], 'zahlung');
      expect(rows.single['idempotency_key'], 'legacy-1');
      expect(rows.single['requested_betrag_cents'], isNull);
      expect(rows.single['fingerprint_direction'], isNull);
      expect(rows.single['fingerprint_date_policy'], isNull);
    });

    test('test_customer_data_disclosure_export_033_a_missing_v7_relation_table_is_created_safely', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await seed.executor.runCustom('PRAGMA user_version = 7');

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _tableExists(native, 'forderung_zahlungen'), isTrue);
      expect(await _foreignKeyTargets(native, 'forderung_zahlungen'), containsAll(<String>['forderungen', 'journal']));
      expect(
        await _indexNames(native, 'forderung_zahlungen'),
        containsAll(<String>['forderung_zahlungen_key_unique', 'forderung_zahlungen_journal_unique']),
      );
      expect(await _rowCount(native, 'forderung_zahlungen'), 0);
      expect(await _userVersion(native), MigrationRunner.currentVersion);
    });

    test('test_customer_data_disclosure_export_034_a_present_v7_relation_table_repairs_missing_cons', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
      final int forderungId = await seed.executor.runInsert(
        'INSERT INTO forderungen (betrag, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?)',
        <Object?>['20.00', 'rechnung', 'kunde', 1],
      );
      final int journalId = await seed.executor.runInsert(
        "INSERT INTO journal (datum, betrag, beschreibung) VALUES ('2026-01-05', '20.00', 'Alt')",
        const <Object?>[],
      );
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await _createLegacyPaymentTable(seed.executor);
      await seed.executor.runInsert(
        'INSERT INTO forderung_zahlungen (id, forderung_id, journal_id, betrag, typ, datum, idempotency_key) '
        "VALUES (1, $forderungId, $journalId, '20.00', 'zahlung', '2026-01-05', 'constraint-1')",
        const <Object?>[],
      );
      await seed.executor.runCustom('PRAGMA user_version = 7');

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _indexNames(native, 'forderung_zahlungen'), contains('forderung_zahlungen_journal_unique'));
      expect(await _foreignKeyTargets(native, 'forderung_zahlungen'), containsAll(<String>['forderungen', 'journal']));
      final List<Map<String, Object?>> rows = await native.runSelect(
        'SELECT forderung_id, journal_id, betrag, idempotency_key FROM forderung_zahlungen',
        const <Object?>[],
      );
      expect(rows, hasLength(1));
      expect(rows.single['idempotency_key'], 'constraint-1');
      expect(await _allTableCount(native), AppDatabase.allTableNames.length + 10);
      for (final String table in AppDatabase.allTableNames) {
        expect(await _tableExists(native, table), isTrue, reason: 'base table $table preserved');
      }
    });

    test('test_customer_data_disclosure_export_035_a_duplicate_legacy_key_rolls_the_migration_back', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await _createLegacyPaymentTable(seed.executor);
      await seed.executor.runInsert(
        "INSERT INTO forderung_zahlungen (id, betrag, typ, datum, idempotency_key) VALUES (1, '1.00', 'zahlung', '2026-01-05', 'doppelt')",
        const <Object?>[],
      );
      await seed.executor.runInsert(
        "INSERT INTO forderung_zahlungen (id, betrag, typ, datum, idempotency_key) VALUES (2, '2.00', 'zahlung', '2026-01-06', 'doppelt')",
        const <Object?>[],
      );
      await seed.executor.runCustom('PRAGMA user_version = 7');

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await _expectSchemaMigrationFailed(db);

      expect(await _userVersion(native), 7);
      expect(await _columnNames(native, 'forderung_zahlungen'), isNot(contains('requested_betrag_cents')));
      expect(await _rowCount(native, 'forderung_zahlungen'), 2);
      expect(await _indexNames(native, 'forderung_zahlungen'), isNot(contains('forderung_zahlungen_key_unique')));
    });

    test('test_customer_data_disclosure_export_036_a_migration_failure_preserves_the_base_table_cou', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
      final int tablesBefore = await _allTableCount(native);
      await seed.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Bestand', 'S', '1', 'B', 'DE')",
        const <Object?>[],
      );
      await seed.executor.runCustom('PRAGMA user_version = 7');

      final AppDatabase db = AppDatabase.forTesting(
        native,
        afterFeatureSchemaDdl: (QueryExecutor executor) async => throw StateError('forced migration failure'),
      );
      addTearDown(db.close);
      await _expectSchemaMigrationFailed(db);

      expect(await _userVersion(native), 7);
      expect(await _allTableCount(native), tablesBefore);
      final List<Map<String, Object?>> keeper = await native.runSelect('SELECT name FROM kunden', const <Object?>[]);
      expect(keeper.single['name'], 'Bestand');
      expect(db.isOpen, isFalse);
      expect(() => db.kundenRepository, throwsA(isA<StateError>()));
    });

    test('test_customer_data_disclosure_export_037_appdatabase_post_ddl_failure_rolls_back_before_s', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
      final int triggersBefore = await _triggerCount(native);
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await seed.executor.runCustom('PRAGMA user_version = 7');
      final int tablesBefore = await _allTableCount(native);

      bool sawFeatureTable = false;
      final AppDatabase db = AppDatabase.forTesting(
        native,
        afterFeatureSchemaDdl: (QueryExecutor executor) async {
          sawFeatureTable = await _tableExists(executor, 'forderung_zahlungen');
          throw StateError('forced post-DDL failure');
        },
      );
      addTearDown(db.close);
      await _expectSchemaMigrationFailed(db);

      expect(sawFeatureTable, isTrue, reason: 'callback observes feature DDL before failure');
      expect(await _triggerCount(native), triggersBefore);
      expect(await _allTableCount(native), tablesBefore);
      expect(await _userVersion(native), 7);
      expect(await _tableExists(native, 'forderung_zahlungen'), isFalse);
      expect(db.isOpen, isFalse);
      expect(() => db.kundenRepository, throwsA(isA<StateError>()));
    });

    test('test_customer_data_disclosure_export_038_a_current_v8_profile_repairs_a_missing_feature_t', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await seed.executor.runCustom('PRAGMA user_version = 8');

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await _expectSchemaMigrationFailed(db);

      expect(await _userVersion(native), 8);
      expect(await _tableExists(native, 'forderung_zahlungen'), isFalse);
      expect(db.isOpen, isFalse);
      expect(() => db.kundenRepository, throwsA(isA<StateError>()));
    });

    test('test_customer_data_disclosure_export_039_a_current_version_repair_preserves_a_present_pay', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
      final int forderungId = await seed.executor.runInsert(
        'INSERT INTO forderungen (betrag, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?)',
        <Object?>['30.00', 'rechnung', 'kunde', 1],
      );
      final int journalId = await seed.executor.runInsert(
        "INSERT INTO journal (datum, betrag, beschreibung) VALUES ('2026-01-05', '30.00', 'Alt')",
        const <Object?>[],
      );
      await seed.executor.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum, idempotency_key) '
        "VALUES (?, ?, '30.00', 'zahlung', '2026-01-05', 'repair-39')",
        <Object?>[forderungId, journalId],
      );
      await seed.executor.runCustom('DROP INDEX forderung_zahlungen_key_unique');

      final AppDatabase db = AppDatabase.forTesting(native);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _indexNames(native, 'forderung_zahlungen'), contains('forderung_zahlungen_key_unique'));
      final List<Map<String, Object?>> rows = await native.runSelect(
        'SELECT forderung_id, journal_id, betrag, idempotency_key FROM forderung_zahlungen',
        const <Object?>[],
      );
      expect(rows, hasLength(1));
      expect(rows.single['idempotency_key'], 'repair-39');
      expect(num.parse(rows.single['betrag'].toString()), 30);
    });

    test('test_customer_data_disclosure_export_040_fresh_startup_schema_upgrade_current_v8_repair_a', () async {
      // Fresh startup uses the shared raw-BEGIN path and commits.
      final drift_native.NativeDatabase freshNative = drift_native.NativeDatabase.memory();
      addTearDown(freshNative.close);
      final List<String> freshStatements = <String>[];
      final AppDatabase fresh = AppDatabase.forTesting(_RecordingExecutor(freshNative, freshStatements));
      addTearDown(fresh.close);
      await fresh.ensureOpen();
      expect(freshStatements, contains('BEGIN'));
      expect(freshStatements, contains('COMMIT'));
      expect(freshStatements, isNot(contains('BEGIN IMMEDIATE')));
      expect(freshStatements.indexOf('BEGIN'), lessThan(freshStatements.indexOf('COMMIT')));
      expect(fresh.isOpen, isTrue);

      // Schema upgrade (v7 without the feature table) shares the same path.
      final drift_native.NativeDatabase upgradeNative = drift_native.NativeDatabase.memory();
      addTearDown(upgradeNative.close);
      final AppDatabase upgradeSeed = await _seedCurrent(upgradeNative);
      addTearDown(upgradeSeed.close);
      await upgradeSeed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await upgradeSeed.executor.runCustom('PRAGMA user_version = 7');
      final List<String> upgradeStatements = <String>[];
      final AppDatabase upgraded = AppDatabase.forTesting(_RecordingExecutor(upgradeNative, upgradeStatements));
      addTearDown(upgraded.close);
      await upgraded.ensureOpen();
      expect(upgradeStatements, contains('BEGIN'));
      expect(upgradeStatements, contains('COMMIT'));
      expect(
        upgradeStatements.indexOf('BEGIN'),
        greaterThan(upgradeStatements.indexOf('PRAGMA LEGACY_ALTER_TABLE = ON')),
      );
      expect(
        upgradeStatements.indexOf('BEGIN'),
        lessThan(upgradeStatements.indexWhere((String statement) => statement.startsWith('CREATE TABLE'))),
      );
      expect(await _tableExists(upgradeNative, 'forderung_zahlungen'), isTrue);

      // Current-version repair of a present table shares the path as well.
      final drift_native.NativeDatabase repairNative = drift_native.NativeDatabase.memory();
      addTearDown(repairNative.close);
      final AppDatabase repairSeed = await _seedCurrent(repairNative);
      addTearDown(repairSeed.close);
      await repairSeed.executor.runCustom('DROP INDEX forderung_zahlungen_key_unique');
      final List<String> repairStatements = <String>[];
      final AppDatabase repaired = AppDatabase.forTesting(_RecordingExecutor(repairNative, repairStatements));
      addTearDown(repaired.close);
      await repaired.ensureOpen();
      expect(repairStatements, contains('BEGIN'));
      expect(repairStatements, contains('COMMIT'));
      expect(await _indexNames(repairNative, 'forderung_zahlungen'), contains('forderung_zahlungen_key_unique'));

      // A v8-or-later profile with the table missing stops before repair DDL.
      final drift_native.NativeDatabase missingNative = drift_native.NativeDatabase.memory();
      addTearDown(missingNative.close);
      final AppDatabase missingSeed = await _seedCurrent(missingNative);
      addTearDown(missingSeed.close);
      await missingSeed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await missingSeed.executor.runCustom('PRAGMA user_version = 8');
      final List<String> missingStatements = <String>[];
      final AppDatabase missing = AppDatabase.forTesting(_RecordingExecutor(missingNative, missingStatements));
      addTearDown(missing.close);
      await _expectSchemaMigrationFailed(missing);
      expect(missingStatements, isNot(contains('BEGIN')));
      expect(await _tableExists(missingNative, 'forderung_zahlungen'), isFalse);
      expect(await _userVersion(missingNative), 8);

      // Rollback after DDL uses raw BEGIN followed by ROLLBACK, never COMMIT.
      final drift_native.NativeDatabase failNative = drift_native.NativeDatabase.memory();
      addTearDown(failNative.close);
      final AppDatabase failSeed = await _seedCurrent(failNative);
      addTearDown(failSeed.close);
      await failSeed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await failSeed.executor.runCustom('PRAGMA user_version = 7');
      final List<String> failStatements = <String>[];
      final AppDatabase failing = AppDatabase.forTesting(
        _RecordingExecutor(failNative, failStatements),
        afterFeatureSchemaDdl: (QueryExecutor executor) async => throw StateError('forced rollback check'),
      );
      addTearDown(failing.close);
      await _expectSchemaMigrationFailed(failing);
      expect(failStatements, contains('BEGIN'));
      expect(failStatements, contains('ROLLBACK'));
      expect(failStatements, isNot(contains('COMMIT')));
    });

    test('test_customer_data_disclosure_export_041_a_request_cannot_claim_a_legacy_key', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = await _seedCurrent(native);
      final ForderungenRepository repo = ForderungenRepository(seed.executor);
      final int partnerId = await seed.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Legacy Key', 'A', '10115', 'Berlin', 'DE')",
        const <Object?>[],
      );
      final Forderung created = await repo.create(
        typ: 'rechnung',
        betrag: 100,
        partnerTyp: 'kunde',
        partnerId: partnerId,
      );
      final int journalId = await seed.executor.runInsert(
        "INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES ('2026-06-05', 'legacy key', '10.00', 'zahlung', NULL, CURRENT_TIMESTAMP)",
        const <Object?>[],
      );
      await seed.executor.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum, idempotency_key) '
        "VALUES (?, ?, '10.00', 'zahlung', '2026-06-05', 'legacy-1')",
        <Object?>[created.id, journalId],
      );
      final int journalCountBefore = await _rowCount(native, 'journal');
      final int relationCountBefore = await _rowCount(native, 'forderung_zahlungen');
      final Forderung? before = await repo.findById(created.id);

      final ForderungenUseCases useCases = ForderungenUseCases(repo);
      try {
        await useCases.zahlungBuchen(forderungId: created.id, betrag: 10, idempotencyKey: 'legacy-1');
        fail('expected ForderungenException with code legacyFingerprintUnknown');
      } on ForderungenException catch (error) {
        expect(error.code, ForderungenErrorCode.legacyFingerprintUnknown);
      }

      expect(await _rowCount(native, 'journal'), journalCountBefore);
      expect(await _rowCount(native, 'forderung_zahlungen'), relationCountBefore);
      final Forderung? after = await repo.findById(created.id);
      expect(after?.betrag, before?.betrag);
      expect(after?.status, before?.status);
    });
  });
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
