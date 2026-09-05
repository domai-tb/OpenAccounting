import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';

void main() {
  group('Bank import failure accounting', () {
    late AppDatabase db;
    late BankImportService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runInsert('INSERT INTO konten (id, name, iban, waehrung) VALUES (?, ?, ?, ?)', <Object?>[
        1,
        'Giro Sparkasse',
        'DE44500606000000000000',
        'EUR',
      ]);
      service = BankImportService(
        _FailingBankImportExecutor(
          db.executor,
          shouldFail: (String statement, List<Object?> args) =>
              statement.contains('INSERT INTO bank_transaktionen') && args.length > 4 && args[4] == 'Reject this row',
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('does not count an injected row failure as imported', () async {
      final ImportResult result = await service.importTransactions(
        kontoId: 1,
        rawTxs: <RawTx>[
          _testTransaction(purpose: 'Keep this row'),
          _testTransaction(purpose: 'Reject this row'),
        ],
        dateiname: 'failure-accounting.csv',
      );

      expect(result.imported, 1);
      expect(result.duplicatesSkipped, 0);
      expect(result.autoCategorized, 0);
      expect(result.manualReview, 1);

      final List<Map<String, Object?>> persisted = await db.executor.runSelect(
        'SELECT verwendungszweck FROM bank_transaktionen ORDER BY id',
        const <Object?>[],
      );
      expect(persisted, hasLength(1));
      expect(persisted.single['verwendungszweck'], 'Keep this row');

      final List<Map<String, Object?>> history = await db.executor.runSelect(
        'SELECT anzahl_transaktionen, duplikate FROM bank_imports ORDER BY id DESC LIMIT 1',
        const <Object?>[],
      );
      expect((history.single['anzahl_transaktionen']! as num).toInt(), 1);
      expect((history.single['duplikate']! as num).toInt(), 0);
    });

    test('records a partial or failed status when a row insert fails', () async {
      final ImportResult result = await service.importTransactions(
        kontoId: 1,
        rawTxs: <RawTx>[_testTransaction(purpose: 'Reject this row')],
        dateiname: 'failure-status.csv',
      );

      expect(result.failed, 1);
      expect(result.failedRows, hasLength(1));
      expect(result.failedRows.single.transaction.verwendungszweck, 'Reject this row');
      expect(result.failedRows.single.error, contains('Injected bank transaction insert failure'));

      final List<Map<String, Object?>> history = await db.executor.runSelect(
        'SELECT status FROM bank_imports ORDER BY id DESC LIMIT 1',
        const <Object?>[],
      );
      expect(
        history.single['status'],
        anyOf('partial', 'failed', 'teilweise', 'fehlgeschlagen'),
        reason: 'The OpenSpec contract requires a truthful recoverable status for a row failure.',
      );
    });
  });
}

RawTx _testTransaction({required String purpose}) {
  return RawTx(datum: DateTime(2026, 3, 15), betrag: '10.00', verwendungszweck: purpose, partner: 'Example Partner');
}

final class _FailingBankImportExecutor extends QueryExecutor {
  _FailingBankImportExecutor(this._delegate, {required this.shouldFail});

  final QueryExecutor _delegate;
  final bool Function(String statement, List<Object?> args) shouldFail;

  @override
  SqlDialect get dialect => _delegate.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _delegate.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) {
    return _delegate.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    if (shouldFail(statement, args)) {
      throw StateError('Injected bank transaction insert failure');
    }
    return _delegate.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    return _delegate.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    return _delegate.runDelete(statement, args);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _delegate.runCustom(statement, args);
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    return _delegate.runBatched(statements);
  }

  @override
  TransactionExecutor beginTransaction() => _delegate.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _delegate.beginExclusive();

  @override
  Future<void> close() => _delegate.close();
}
