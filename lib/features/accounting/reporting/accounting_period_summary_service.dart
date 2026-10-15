import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/reporting/euer_report_use_case.dart';

/// One month's trend values of the annual summary.
class AccountingPeriodMonth {
  const AccountingPeriodMonth({required this.month, required this.incomeCents, required this.expenseCents});

  /// 'YYYY-MM'.
  final String month;
  final int incomeCents;
  final int expenseCents;
}

/// One distribution grouping (expense by category, journaled amounts by tax
/// rate) built from journaled source facts.
class AccountingPeriodDistribution {
  const AccountingPeriodDistribution({required this.key, required this.amountCents});

  final String key;
  final int amountCents;
}

/// Immutable canonical annual summary: exact period, totals matching the
/// EÜR result, monthly series, distributions, source versions, and the
/// unresolved-record count. Never exposed as complete while any required
/// source or period result is unavailable.
class AccountingPeriodSummary {
  const AccountingPeriodSummary({
    required this.jahr,
    required this.periodStart,
    required this.periodEnd,
    required this.incomeCents,
    required this.expenseCents,
    required this.profitCents,
    required this.marginPercent,
    required this.monthlyTrend,
    required this.expenseDistribution,
    required this.taxDistribution,
    required this.sourceVersions,
    required this.unresolvedCount,
  });

  final int jahr;

  /// Start-inclusive January 1, end-exclusive January 1 of the next year.
  final String periodStart;
  final String periodEnd;

  final int incomeCents;
  final int expenseCents;

  /// Equals the matching EÜR result's gewinn for the same year/form version.
  final int profitCents;

  /// profit / income * 100; null (unavailable) when income is not positive.
  final double? marginPercent;

  /// Exactly twelve entries for the summary year.
  final List<AccountingPeriodMonth> monthlyTrend;

  final List<AccountingPeriodDistribution> expenseDistribution;
  final List<AccountingPeriodDistribution> taxDistribution;

  /// EÜR form version plus the accepted source-contract versions.
  final Map<String, String> sourceVersions;

  /// Journal records missing required mapping, reported not replaced.
  final int unresolvedCount;
}

/// Canonical annual accounting period summary service (spec
/// §Annual accounting period summary). One supported calendar year only;
/// month and quarter summaries do not exist.
class AccountingPeriodSummaryService {
  AccountingPeriodSummaryService(this.executor);

  final QueryExecutor executor;

  /// shortcut: only the year with an accepted EÜR form contract (2025);
  /// extend when another year's form mapping is accepted.
  static const int supportedYear = 2025;

  Future<ReportWorkspaceResult<AccountingPeriodSummary>> summary({required int jahr}) async {
    if (jahr != supportedYear) {
      return const ReportWorkspaceResult<AccountingPeriodSummary>.unavailable(
        'unsupportedAnnualPeriod: missingEuerFormVersion',
      );
    }
    final String? blocked = await _financialPrerequisiteBlocker();
    if (blocked != null) {
      return ReportWorkspaceResult<AccountingPeriodSummary>.unavailable(blocked);
    }
    final ReportWorkspaceResult<EuerPreview> euer = await EuerReportUseCase(executor).preview(jahr: jahr);
    if (euer.availability != ReportAvailability.available) {
      return ReportWorkspaceResult<AccountingPeriodSummary>.unavailable(euer.reasonCode ?? 'sourceUnavailable');
    }
    final EuerPreview preview = euer.value!;

    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT j.datum, j.betrag, j.beleg_typ, j.ust_satz, j.kategorie_id, k.bezeichnung AS kat_name FROM journal j '
      'LEFT JOIN kategorien k ON k.id = j.kategorie_id '
      "WHERE j.datum LIKE '$jahr-%' ORDER BY j.datum",
      const <Object?>[],
    );

    int income = 0;
    int expense = 0;
    int unresolved = 0;
    final List<int> monthIncome = List<int>.filled(12, 0);
    final List<int> monthExpense = List<int>.filled(12, 0);
    final Map<String, int> byCategory = <String, int>{};
    final Map<String, int> byTaxRate = <String, int>{};
    for (final Map<String, Object?> r in rows) {
      final int cents = money.parseScaled(r['betrag']?.toString() ?? '0', scale: 2, allowNegative: false);
      final String datum = r['datum']?.toString() ?? '';
      if (r['kategorie_id'] == null) {
        unresolved += 1;
      }
      final String art = r['beleg_typ']?.toString().toLowerCase() ?? '';
      final int monthIndex = datum.length >= 7 ? (int.tryParse(datum.substring(5, 7)) ?? 1) : 1;
      if (art == 'einnahme') {
        income += cents;
        monthIncome[monthIndex - 1] += cents;
      } else if (art == 'ausgabe') {
        expense += cents;
        monthExpense[monthIndex - 1] += cents;
        final String kat = r['kat_name']?.toString() ?? '(ohne Kategorie)';
        byCategory[kat] = (byCategory[kat] ?? 0) + cents;
      }
      final String? rate = r['ust_satz']?.toString();
      if (rate != null && rate.isNotEmpty) {
        byTaxRate[rate] = (byTaxRate[rate] ?? 0) + cents;
      }
    }

    final int profit = money.parseScaled(preview.gewinn, scale: 2);
    return ReportWorkspaceResult<AccountingPeriodSummary>.available(
      AccountingPeriodSummary(
        jahr: jahr,
        periodStart: '$jahr-01-01',
        periodEnd: '${jahr + 1}-01-01',
        incomeCents: income,
        expenseCents: expense,
        profitCents: profit,
        marginPercent: income > 0 ? profit / income * 100 : null,
        monthlyTrend: List<AccountingPeriodMonth>.generate(
          12,
          (int i) => AccountingPeriodMonth(
            month: '$jahr-${(i + 1).toString().padLeft(2, '0')}',
            incomeCents: monthIncome[i],
            expenseCents: monthExpense[i],
          ),
        ),
        expenseDistribution: <AccountingPeriodDistribution>[
          for (final MapEntry<String, int> e in byCategory.entries)
            AccountingPeriodDistribution(key: e.key, amountCents: e.value),
        ],
        taxDistribution: <AccountingPeriodDistribution>[
          for (final MapEntry<String, int> e in byTaxRate.entries)
            AccountingPeriodDistribution(key: e.key, amountCents: e.value),
        ],
        sourceVersions: <String, String>{
          'euerFormVersion': preview.formVersion,
          'balanced-postings': 'accepted',
          'invoice-money': 'accepted',
        },
        unresolvedCount: unresolved,
      ),
    );
  }

  /// Mechanical check for the two independently accepted source contracts.
  Future<String?> _financialPrerequisiteBlocker() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('settlement_groups', 'settlement_allocations')",
      const <Object?>[],
    );
    final List<Map<String, Object?>> cols = await executor.runSelect('PRAGMA table_info(journal)', const <Object?>[]);
    final bool moneyMarker = cols.any((Map<String, Object?> c) => c['name']?.toString() == 'legacy_unverified');
    if (tables.length != 2 || !moneyMarker) {
      return 'unapprovedPrerequisite: balanced-journal-postings-and-settlement-events, invoice-money-contract';
    }
    return null;
  }
}
