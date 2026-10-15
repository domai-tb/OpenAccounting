import 'package:flutter/material.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/reporting/accounting_period_summary_service.dart';

/// Localized labels for the annual summary card.
///
/// shortcut: labels are injected rather than read from the shared ARB until
/// the reporting l10n keys are merged; move to context.l10n afterwards.
class AccountingPeriodSummaryStrings {
  const AccountingPeriodSummaryStrings({
    required this.income,
    required this.expense,
    required this.profit,
    required this.margin,
    required this.marginUnavailable,
    required this.period,
    required this.sourceVersion,
    required this.unresolvedCount,
    required this.unavailable,
  });

  final String income;
  final String expense;
  final String profit;
  final String margin;
  final String marginUnavailable;
  final String period;
  final String sourceVersion;
  final String unresolvedCount;
  final String unavailable;
}

/// Dashboard annual summary card consuming the canonical
/// `AccountingPeriodSummary`: values, year boundaries, source version and
/// unresolved count are displayed from the result as-is. No totals are ever
/// recalculated or substituted; without a summary only the unavailable reason
/// and period are shown.
class AccountingPeriodSummaryCard extends StatelessWidget {
  const AccountingPeriodSummaryCard({
    super.key,
    required this.strings,
    required this.summary,
    required this.unavailableReason,
    this.unavailablePeriod,
  });

  final AccountingPeriodSummaryStrings strings;

  /// Canonical result; null when the reporting service is unavailable.
  final AccountingPeriodSummary? summary;

  /// Blocking reason when [summary] is null.
  final String? unavailableReason;

  /// Requested period shown alongside the unavailable reason.
  final String? unavailablePeriod;

  @override
  Widget build(BuildContext context) {
    final AccountingPeriodSummary? s = summary;
    if (s == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(strings.unavailable, style: Theme.of(context).textTheme.titleSmall),
              if (unavailablePeriod != null) Text('${strings.period}: $unavailablePeriod'),
              if (unavailableReason != null) Text(unavailableReason!),
            ],
          ),
        ),
      );
    }
    final double? margin = s.marginPercent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${strings.period}: ${s.periodStart} bis ${s.periodEnd}'),
            _row(strings.income, _german(s.incomeCents)),
            _row(strings.expense, _german(s.expenseCents)),
            _row(strings.profit, _german(s.profitCents)),
            _row(strings.margin, margin == null ? strings.marginUnavailable : '${margin.toStringAsFixed(1)} %'),
            _row(strings.sourceVersion, s.sourceVersions.values.join(', ')),
            _row(strings.unresolvedCount, '${s.unresolvedCount}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[Text(label), Text(value)]),
    );
  }

  /// Integer cents → German decimal ('2.300,00'), matching NUMERIC(12,2).
  static String _german(int cents) {
    final String ascii = money.fromCents(cents);
    final bool negative = ascii.startsWith('-');
    final String body = negative ? ascii.substring(1) : ascii;
    final List<String> parts = body.split('.');
    final String intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (Match m) => '.');
    return '${negative ? '-' : ''}$intPart,${parts[1]}';
  }
}
