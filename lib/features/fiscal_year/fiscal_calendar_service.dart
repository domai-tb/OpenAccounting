/// Shared fiscal-calendar boundaries per fiscal-year-calendar.
///
/// Resolves business dates, fiscal months/quarters, and fiscal-year labels to
/// immutable labels with half-open `[start, endExclusive)` calendar-date
/// ranges from the configured company start month. Fiscal month 1 begins at
/// the start month; quarters hold three consecutive fiscal months. A
/// fiscal-year label is the calendar year its fiscal year starts in. Invalid
/// indexes return typed invalid-period results instead of substituted periods.
class FiscalPeriod {
  const FiscalPeriod({required this.label, required this.start, required this.endExclusive});

  /// Human label, e.g. `2026`, `2026-M04`, `2026-Q1`.
  final String label;

  /// Inclusive calendar start date (`yyyy-MM-dd`, no time zone).
  final String start;

  /// Exclusive calendar end date (`yyyy-MM-dd`, no time zone).
  final String endExclusive;
}

class FiscalInvalidPeriod implements Exception {
  const FiscalInvalidPeriod(this.message);
  final String message;
  @override
  String toString() => message;
}

class FiscalCalendarService {
  const FiscalCalendarService({required this.startMonth});

  /// Company fiscal-year start month, 1–12.
  final int startMonth;

  static String _iso(int year, int month, int day) {
    final String y = year.toString().padLeft(4, '0');
    final String m = month.toString().padLeft(2, '0');
    final String d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Fiscal year containing [date]: label, inclusive start, exclusive end.
  FiscalPeriod fiscalYearFor(DateTime date) {
    _requireMonth();
    final int label = date.month >= startMonth ? date.year : date.year - 1;
    return FiscalPeriod(
      label: '$label',
      start: _iso(label, startMonth, 1),
      endExclusive: _iso(label + 1, startMonth, 1),
    );
  }

  /// Fiscal month [index] (1–12) of fiscal year [fiscalYearLabel].
  FiscalPeriod fiscalMonth({required int fiscalYearLabel, required int index}) {
    _requireMonth();
    if (index < 1 || index > 12) {
      throw FiscalInvalidPeriod('Fiskalmonat muss zwischen 1 und 12 liegen: $index');
    }
    final int month = ((startMonth - 1 + index - 1) % 12) + 1;
    final int year = fiscalYearLabel + ((startMonth - 1 + index - 1) ~/ 12);
    return FiscalPeriod(
      label: '$fiscalYearLabel-M${month.toString().padLeft(2, '0')}',
      start: _iso(year, month, 1),
      endExclusive: month == 12 ? _iso(year + 1, 1, 1) : _iso(year, month + 1, 1),
    );
  }

  /// Fiscal quarter [index] (1–4) of fiscal year [fiscalYearLabel].
  FiscalPeriod fiscalQuarter({required int fiscalYearLabel, required int index}) {
    _requireMonth();
    if (index < 1 || index > 4) {
      throw FiscalInvalidPeriod('Fiskalquartal muss zwischen 1 und 4 liegen: $index');
    }
    final FiscalPeriod first = fiscalMonth(fiscalYearLabel: fiscalYearLabel, index: (index - 1) * 3 + 1);
    final FiscalPeriod third = fiscalMonth(fiscalYearLabel: fiscalYearLabel, index: (index - 1) * 3 + 3);
    return FiscalPeriod(label: '$fiscalYearLabel-Q$index', start: first.start, endExclusive: third.endExclusive);
  }

  void _requireMonth() {
    if (startMonth < 1 || startMonth > 12) {
      throw FiscalInvalidPeriod('Startmonat muss zwischen 1 und 12 liegen: $startMonth');
    }
  }
}
