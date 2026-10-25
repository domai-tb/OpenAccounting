import 'package:openaccounting/features/cashbook/account_date_balance.dart';

class TagesabschlussCreation {
  const TagesabschlussCreation();

  TagesabschlussDraft? prepare(CashbookBalanceResult balance) {
    final int? expectedBalanceCents = balance.balanceCents;
    if (!balance.complete || expectedBalanceCents == null) return null;

    return TagesabschlussDraft(
      companyId: balance.companyId,
      accountId: balance.accountId,
      asOfDate: balance.asOfDate,
      expectedBalanceCents: expectedBalanceCents,
      currencyCode: balance.currencyCode,
      sourceReference: balance.sourceReference,
      complete: balance.complete,
    );
  }
}

class TagesabschlussDraft {
  const TagesabschlussDraft({
    required this.companyId,
    required this.accountId,
    required this.asOfDate,
    required this.expectedBalanceCents,
    required this.currencyCode,
    required this.sourceReference,
    required this.complete,
  });

  final String companyId;
  final String accountId;
  final DateTime asOfDate;
  final int expectedBalanceCents;
  final String currencyCode;
  final String sourceReference;
  final bool complete;
}
