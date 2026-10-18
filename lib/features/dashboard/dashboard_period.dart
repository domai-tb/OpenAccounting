/// Annual period + KPI formulas for the dashboard.
/// Consumes the accepted annual `AccountingPeriodSummary` only; month/quarter
/// remain unavailable until the reporting workspace accepts them.
library;

/// Supported calendar-year period with exact boundaries.
class DashboardYear {
  const DashboardYear(this.year);

  final int year;

  String get start => '$year-01-01';

  String get endExclusive => '${year + 1}-01-01';

  String get yearEnd => '$year-12-31';

  String label() => '$year · $start – $yearEnd';
}

/// Result of selecting a reporting period.
sealed class DashboardPeriodResult {
  const DashboardPeriodResult();
}

class DashboardPeriodOk extends DashboardPeriodResult {
  const DashboardPeriodOk(this.period);

  final DashboardYear period;
}

class DashboardPeriodUnavailable extends DashboardPeriodResult {
  const DashboardPeriodUnavailable(this.code);

  /// `invalid-range`, `calendar-unavailable`, `unsupported-period`,
  /// `reporting-prerequisite`.
  final String code;
}

/// Annual KPI values in integer cents (money remainder rule: no doubles).
class DashboardAnnualKpis {
  const DashboardAnnualKpis({
    required this.year,
    required this.incomeCents,
    required this.expenseCents,
    required this.profitCents,
    this.marginPercent,
    this.vatReserveCents,
    this.vatReserveIsEstimate = false,
  });

  final int year;
  final int incomeCents;
  final int expenseCents;
  final int profitCents;
  final double? marginPercent;
  final int? vatReserveCents;
  final bool vatReserveIsEstimate;
}

/// Monthly trend point for one supported calendar year.
class DashboardTrendPoint {
  const DashboardTrendPoint({required this.month, required this.incomeCents, required this.expenseCents});

  /// 1–12.
  final int month;
  final int incomeCents;
  final int expenseCents;
}

/// Comparable change for one KPI.
class DashboardChange {
  const DashboardChange({required this.currentCents, required this.priorCents, this.percent});

  final int currentCents;
  final int priorCents;

  /// Null means "not comparable" (zero/unavailable baseline).
  final double? percent;

  int get absoluteCents => currentCents - priorCents;

  bool get comparable => percent != null;
}

/// As-of open-balance snapshot result.
sealed class DashboardAsOfResult {
  const DashboardAsOfResult();
}

class DashboardAsOfOk extends DashboardAsOfResult {
  const DashboardAsOfOk({required this.balanceCents, required this.itemCount});

  final int balanceCents;
  final int itemCount;
}

class DashboardAsOfUnavailable extends DashboardAsOfResult {
  const DashboardAsOfUnavailable(this.code);

  /// `incomplete-history`, `writeoff-effective-date-missing`, `legacy-mix`.
  final String code;
}

/// Attention item linking to a filtered workspace.
class DashboardAttentionItem {
  const DashboardAttentionItem({required this.kind, required this.title, required this.route, this.count = 1});

  /// `overdue-invoice`, `unmatched-transaction`, `tax-deadline`.
  final String kind;
  final String title;
  final String route;
  final int count;
}

/// Allowed quick-link / attention destinations (base paths, no new routes).
const Set<String> dashboardAllowedRoutes = <String>{
  '/',
  '/invoices',
  '/invoices/new',
  '/receipts',
  '/banking',
  '/mahnwesen',
  '/contacts',
  '/taxes',
  '/reports',
  '/assets',
  '/settings',
  '/help',
  '/inventory',
  '/recurring',
};

/// Base path of a route (strips query + fragment).
String dashboardRouteBase(String route) {
  final String trimmed = route.trim();
  if (trimmed.isEmpty) return '';
  final int q = trimmed.indexOf('?');
  final int h = trimmed.indexOf('#');
  var end = trimmed.length;
  if (q != -1 && q < end) end = q;
  if (h != -1 && h < end) end = h;
  var base = trimmed.substring(0, end);
  if (base.length > 1 && base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return base;
}

/// True when the route base is allowed or is an allowed nested detail route.
bool isDashboardRouteAllowed(String route) {
  final String base = dashboardRouteBase(route);
  if (base.isEmpty) return false;
  if (dashboardAllowedRoutes.contains(base)) return true;
  // Detail routes: /invoices/123, /contacts/1, /reports/5, /receipts/7.
  for (final String allowed in dashboardAllowedRoutes) {
    if (allowed == '/' || allowed.endsWith('/new')) continue;
    if (base.startsWith('$allowed/')) {
      final String rest = base.substring(allowed.length + 1);
      if (rest.isNotEmpty && !rest.contains('/')) return true;
    }
  }
  return false;
}

/// Percentage change uses the absolute prior amount as denominator.
/// Null when the baseline is zero (show absolute + "not comparable").
double? dashboardChangePercent(int current, int prior) {
  if (prior == 0) return null;
  if (!current.isFinite || !prior.isFinite) return null;
  return (current - prior) / prior.abs() * 100;
}

DashboardChange dashboardChange(int currentCents, int priorCents) {
  return DashboardChange(
    currentCents: currentCents,
    priorCents: priorCents,
    percent: dashboardChangePercent(currentCents, priorCents),
  );
}

/// True when a trend value is renderable (finite, non-null).
bool isDashboardTrendValue(num? value) => value != null && value.isFinite;

/// Selects an annual calendar-year period.
/// Only 4-digit years with an accepted form mapping are supported here;
/// month/quarter or unknown years yield `unsupported-period`.
DashboardPeriodResult selectDashboardYear(int year, {Set<int>? supportedYears, bool calendarAvailable = true}) {
  if (!calendarAvailable) {
    return const DashboardPeriodUnavailable('calendar-unavailable');
  }
  if (year < 1000 || year > 9999) {
    return const DashboardPeriodUnavailable('invalid-range');
  }
  if (supportedYears != null && !supportedYears.contains(year)) {
    return const DashboardPeriodUnavailable('unsupported-period');
  }
  return DashboardPeriodOk(DashboardYear(year));
}

/// Month/quarter requests always render the unavailable state.
DashboardPeriodUnavailable unsupportedMonthQuarter() {
  return const DashboardPeriodUnavailable('unsupported-period');
}
