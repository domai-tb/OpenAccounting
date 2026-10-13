import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/posting_group_service.dart';

/// Confirmation boundary between bank reconciliation and accounting.
///
/// Confirming a bank transaction as a payment atomically creates the
/// settlement group and updates the open-item balance. Matching suggestions
/// alone never post: only this explicit confirmation writes postings. The
/// settlement date is the bank booking/value date preserved verbatim from
/// the bank row; the confirmation date never substitutes for it. One
/// confirmed bank transaction maps to exactly one settlement group —
/// repeating a confirmation returns the committed group without re-applying.
class SettlementConfirmationException implements Exception {
  const SettlementConfirmationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One requested allocation of a confirmed payment to an open item.
class ConfirmationAllocation {
  const ConfirmationAllocation({required this.forderungId, required this.appliedCents});

  final int forderungId;
  final int appliedCents;
}

class SettlementConfirmationService {
  SettlementConfirmationService(this.executor, {PostingGroupService? postings})
    : _postings = postings ?? PostingGroupService(executor);

  final QueryExecutor executor;
  final PostingGroupService _postings;

  Future<void> ensureSchema() => _postings.ensureSchema();

  /// Confirms [bankTransactionId] as a payment against the given open items.
  /// A positive bank row applies only to customer receivables, a negative
  /// row only to supplier payables. Partial payments keep the unapplied
  /// balance; overpayments retain the excess as a separately classified
  /// credit. Status moves `offen` → `teilbezahlt` → `bezahlt`, and a full
  /// customer payment clears the dunning trigger.
  Future<SettlementGroupSummary> confirm({
    required int bankTransactionId,
    required List<ConfirmationAllocation> allocations,
    required int bankKontoId,
    required int counterKontoId,
    int? creditKontoId,
    int? kategorieId,
    String? beschreibung,
  }) async {
    await ensureSchema();
    if (allocations.isEmpty) {
      throw const SettlementConfirmationException('Bestätigung braucht mindestens eine Zuordnung');
    }
    final Map<String, Object?> bank = await _requireBankRow(bankTransactionId);
    final int signedCents = money.toCents(money.formatBetrag(bank['betrag'].toString()));
    if (signedCents == 0) {
      throw const SettlementConfirmationException('Bankbuchung ohne Betrag kann nicht bestätigt werden');
    }
    // Stable identity per bank row: a repeated confirmation replays the
    // committed group instead of applying twice.
    final SettlementGroupSummary? replay = await _postings.findSettlementByBankRow(bankTransactionId);
    if (replay != null) {
      return replay;
    }
    final String settlementDate = _dateOnly(bank['datum'].toString());
    try {
      return await _postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: '$bankTransactionId',
        signedAmountCents: signedCents,
        settlementDate: settlementDate,
        bankKontoId: bankKontoId,
        counterKontoId: counterKontoId,
        creditKontoId: creditKontoId,
        allocations: <SettlementAllocationInput>[
          for (final ConfirmationAllocation allocation in allocations)
            SettlementAllocationInput(forderungId: allocation.forderungId, appliedCents: allocation.appliedCents),
        ],
        bankTransactionId: bankTransactionId,
        kategorieId: kategorieId,
        beschreibung: beschreibung ?? 'Bestätigte Zahlung #$bankTransactionId',
      );
    } on PostingException catch (error) {
      throw SettlementConfirmationException(error.message);
    }
  }

  /// Confirms a manual cash payment on [paymentDate] (no imported bank row).
  /// The manual payment date is the authoritative settlement date.
  Future<SettlementGroupSummary> confirmCash({
    required String cashKey,
    required int signedAmountCents,
    required String paymentDate,
    required List<ConfirmationAllocation> allocations,
    required int bankKontoId,
    required int counterKontoId,
    int? creditKontoId,
    int? kategorieId,
    String? beschreibung,
  }) async {
    await ensureSchema();
    if (cashKey.trim().isEmpty) {
      throw const SettlementConfirmationException('Barzahlung braucht einen stabilen Schlüssel');
    }
    if (allocations.isEmpty) {
      throw const SettlementConfirmationException('Bestätigung braucht mindestens eine Zuordnung');
    }
    try {
      return await _postings.postSettlement(
        sourceKind: PostingSource.cashPayment,
        sourceId: cashKey.trim(),
        signedAmountCents: signedAmountCents,
        settlementDate: paymentDate,
        bankKontoId: bankKontoId,
        counterKontoId: counterKontoId,
        creditKontoId: creditKontoId,
        allocations: <SettlementAllocationInput>[
          for (final ConfirmationAllocation allocation in allocations)
            SettlementAllocationInput(forderungId: allocation.forderungId, appliedCents: allocation.appliedCents),
        ],
        kategorieId: kategorieId,
        beschreibung: beschreibung ?? 'Barzahlung $cashKey',
      );
    } on PostingException catch (error) {
      throw SettlementConfirmationException(error.message);
    }
  }

  Future<Map<String, Object?>> _requireBankRow(int id) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, datum, betrag, status FROM bank_transaktionen WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      throw const SettlementConfirmationException('Banktransaktion nicht gefunden');
    }
    return rows.single;
  }

  String _dateOnly(String raw) => raw.length >= 10 ? raw.substring(0, 10) : raw;
}

/// Riverpod wiring for the confirmation boundary. No BLoC, no new GetIt wiring.
final settlementConfirmationServiceProvider = Provider<SettlementConfirmationService>((ref) {
  return SettlementConfirmationService(ref.watch(appDatabaseProvider).executor);
});
