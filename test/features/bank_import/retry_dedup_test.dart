import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';

void main() {
  group('Bank import retry deduplication', () {
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
              statement.contains('INSERT INTO bank_transaktionen') &&
              args.length > 4 &&
              args[4] == 'Reject on first pass',
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('retry after correction keeps persisted rows deduplicated', () async {
      final RawTx alreadyPersisted = _testTransaction(purpose: 'Already persisted');
      final RawTx initiallyRejected = _testTransaction(purpose: 'Reject on first pass');

      final ImportResult first = await service.importTransactions(
        kontoId: 1,
        rawTxs: <RawTx>[alreadyPersisted, initiallyRejected],
        dateiname: 'partial-import.csv',
      );
      expect(first.imported, 1);

      service = BankImportService(db.executor);
      final ImportResult retry = await service.importTransactions(
        kontoId: 1,
        rawTxs: <RawTx>[
          alreadyPersisted,
          _testTransaction(purpose: 'Corrected row'),
        ],
        dateiname: 'partial-import-retry.csv',
      );

      expect(retry.imported, 1);
      expect(retry.duplicatesSkipped, 1);

      final List<Map<String, Object?>> persisted = await db.executor.runSelect(
        'SELECT verwendungszweck, dedupe_hash FROM bank_transaktionen ORDER BY id',
        const <Object?>[],
      );
      expect(persisted, hasLength(2));
      expect(
        persisted.map((row) => row['verwendungszweck']),
        containsAll(<String>['Already persisted', 'Corrected row']),
      );
      expect(persisted[0]['dedupe_hash'], isNot(equals(persisted[1]['dedupe_hash'])));

      final List<Map<String, Object?>> history = await db.executor.runSelect(
        'SELECT anzahl_transaktionen, duplikate FROM bank_imports ORDER BY id',
        const <Object?>[],
      );
      expect(history, hasLength(2));
      expect((history[1]['anzahl_transaktionen']! as num).toInt(), 1);
      expect((history[1]['duplikate']! as num).toInt(), 1);
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
