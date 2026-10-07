import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';

class BankTransactionSelection {
  const BankTransactionSelection({
    required this.id,
    required this.date,
    required this.amount,
    required this.purpose,
    required this.counterpartyAccount,
    required this.counterpartyName,
    required this.status,
  });

  final int id;
  final String date;
  final num amount;
  final String purpose;
  final String counterpartyAccount;
  final String counterpartyName;
  final String status;
}

class BankTransactionSelectionRepository {
  const BankTransactionSelectionRepository(this.executor);

  final QueryExecutor executor;

  Future<BankTransactionSelection?> findById(int id) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, datum, betrag, verwendungszweck, gegenkonto, gegenkonto_name, status '
      'FROM bank_transaktionen WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    final Map<String, Object?> row = rows.single;
    final Object? rawId = row['id'];
    final Object? rawAmount = row['betrag'];
    final int? transactionId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final num? amount = rawAmount is num ? rawAmount : num.tryParse(rawAmount?.toString() ?? '');
    if (transactionId == null || transactionId <= 0 || amount == null) {
      throw StateError('Invalid typed bank transaction projection');
    }
    return BankTransactionSelection(
      id: transactionId,
      date: _text(row['datum']),
      amount: amount,
      purpose: _text(row['verwendungszweck']),
      counterpartyAccount: _text(row['gegenkonto']),
      counterpartyName: _text(row['gegenkonto_name']),
      status: _text(row['status']),
    );
  }

  String _text(Object? value) => value?.toString().trim() ?? '';
}

final bankTransactionSelectionRepositoryProvider = Provider<BankTransactionSelectionRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return BankTransactionSelectionRepository(db.executor);
});
