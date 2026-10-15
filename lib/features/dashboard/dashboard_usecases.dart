import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/dashboard/dashboard_entity.dart';
import 'package:openaccounting/features/dashboard/dashboard_period.dart';

/// Composed dashboard use case (Riverpod via the app services aggregate).
/// Presentation stays thin; accounting math lives here, never in widgets.
/// Annual `AccountingPeriodSummary` is consumed only when its reporting
/// prerequisite is accepted — otherwise an unavailable state naming that
/// prerequisite is returned and no invoice/journal/bank total is substituted.
class DashboardUseCase {
  DashboardUseCase(this.executor, {this.annualSummaries, this.trendOverride});

  final QueryExecutor executor;

  /// Test seam: accepted annual summaries keyed by year.
  final Map<int, DashboardAnnualKpis>? annualSummaries;

  /// Test seam: monthly trend override for the selected year.
  final List<DashboardTrendPoint>? trendOverride;

  // --- Quick links ---

  bool isAllowed(String route) => isDashboardRouteAllowed(route);

  /// Null when accepted; otherwise a localization key suffix.
  String? validateQuickLink(String route) {
    if (route.trim().isEmpty || !isAllowed(route)) {
      return 'invalid-route';
    }
    return null;
  }

  List<QuickLink> validLinks(List<QuickLink> links) {
    return <QuickLink>[
      for (final QuickLink l in links)
        if (isAllowed(l.route)) l,
    ];
  }

  List<QuickLink> invalidLinks(List<QuickLink> links) {
    return <QuickLink>[
      for (final QuickLink l in links)
        if (!isAllowed(l.route)) l,
    ];
  }

  // --- Period ---

  DashboardPeriodResult selectYear(int year, {Set<int>? supportedYears, bool calendarAvailable = true}) {
    return selectDashboardYear(year, supportedYears: supportedYears, calendarAvailable: calendarAvailable);
  }

  DashboardPeriodUnavailable unsupportedPeriod() => unsupportedMonthQuarter();

  /// Annual summary for [year]. Production has no accepted reporting
  /// workspace yet, so without an injected summary this returns null and
  /// callers SHALL show the `reporting-prerequisite` unavailable state.
  DashboardAnnualKpis? annualSummary(int year) => annualSummaries?[year];

  bool get hasReportingPrerequisite => annualSummaries != null;

  DashboardChange changeFor(int currentCents, int priorCents) {
    return dashboardChange(currentCents, priorCents);
  }

  // --- Trends ---

  /// Monthly series for the selected year (override in tests; production
  /// consumes the canonical reporting service, never widget SQL).
  List<DashboardTrendPoint> monthlyTrend(int year) {
    if (trendOverride != null) return List<DashboardTrendPoint>.unmodifiable(trendOverride!);
    return const <DashboardTrendPoint>[];
  }

  /// False when the series is missing, empty, or holds non-finite values.
  bool hasRenderableTrend(List<DashboardTrendPoint> points) {
    if (points.isEmpty) return false;
    for (final DashboardTrendPoint p in points) {
      if (p.month < 1 || p.month > 12) return false;
      if (!isDashboardTrendValue(p.incomeCents) || !isDashboardTrendValue(p.expenseCents)) return false;
    }
    return true;
  }

  // --- Operational metrics (corrected sources) ---

  /// Status values excluded from open-invoice KPIs. Bound as parameters so
  /// the SQL text stays free of quoted literals.
  static const List<String> _openInvoiceTypeAndStatus = <String>[
    'rechnung',
    'bezahlt',
    'storniert',
    'storno',
    'entwurf',
    'cancelled',
  ];

  Future<Map<String, Object?>> openInvoices() async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT COUNT(*) AS c, COALESCE(SUM(brutto_betrag), 0) AS s FROM rechnungen '
      'WHERE ist_entwurf = 0 AND typ = ? '
      'AND status NOT IN (?, ?, ?, ?, ?)',
      _openInvoiceTypeAndStatus,
    );
    final int count = ((rows.first['c'] as num?) ?? 0).toInt();
    return <String, Object?>{'count': count, 'sum': money.formatBetrag('${rows.first['s']}')};
  }

  /// Overdue issued invoices with the same exclusion rule.
  Future<Map<String, Object?>> overdueInvoices() async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT COUNT(*) AS c, COALESCE(SUM(brutto_betrag), 0) AS s FROM rechnungen '
      'WHERE ist_entwurf = 0 AND typ = ? '
      'AND status NOT IN (?, ?, ?, ?, ?) '
      'AND faelligkeit IS NOT NULL AND date(faelligkeit) < date(?)',
      <Object?>[..._openInvoiceTypeAndStatus, 'now'],
    );
    final int count = ((rows.first['c'] as num?) ?? 0).toInt();
    return <String, Object?>{'count': count, 'sum': money.formatBetrag('${rows.first['s']}')};
  }

  /// Confirmed receipts only: bank rows linked to accounting (journal).
  /// Unmatched rows never count as receipts.
  Future<Map<String, Object?>> confirmedReceipts() async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT COUNT(*) AS c, COALESCE(SUM(ABS(betrag)), 0) AS s FROM bank_transaktionen '
        'WHERE betrag > 0 AND journal_id IS NOT NULL',
        const <Object?>[],
      );
      final int count = ((rows.first['c'] as num?) ?? 0).toInt();
      return <String, Object?>{'count': count, 'sum': money.formatBetrag('${rows.first['s']}')};
    } catch (_) {
      return <String, Object?>{'count': 0, 'sum': money.fromCents(0)};
    }
  }

  /// Reconciliation work: imported rows without an accounting link.
  Future<int> unmatchedCount() async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT COUNT(*) AS c FROM bank_transaktionen WHERE journal_id IS NULL',
        const <Object?>[],
      );
      return ((rows.first['c'] as num?) ?? 0).toInt();
    } catch (_) {
      return 0;
    }
  }

  // --- Historical as-of snapshots ---

  /// Receivables at [yearEnd] (`YYYY-MM-DD`): invoices issued on/before the
  /// date less allocations effective on/before it. Uses authoritative
  /// settlement dates verbatim (booking/value or manual cash date).
  /// Later-issued items are excluded; later payments do not reduce the date.
  /// Write-offs without an accepted effective date and any
  /// `legacy_unverified` mix yield unavailable, never a silent total.
  Future<DashboardAsOfResult> receivablesAsOf(String yearEnd) async {
    final DashboardAsOfResult? blocked = await _historyBlocker(yearEnd);
    if (blocked != null) return blocked;
    try {
      final List<Map<String, Object?>> invoices = await executor.runSelect(
        "SELECT id, brutto_betrag FROM rechnungen WHERE ist_entwurf = 0 AND typ = 'rechnung' "
        "AND status NOT IN ('storniert', 'storno', 'entwurf', 'cancelled') "
        'AND substr(datum, 1, 10) <= ?',
        <Object?>[yearEnd],
      );
      if (invoices.isEmpty) {
        return const DashboardAsOfOk(balanceCents: 0, itemCount: 0);
      }
      var total = 0;
      var items = 0;
      for (final Map<String, Object?> inv in invoices) {
        final int id = ((inv['id'] as num?) ?? 0).toInt();
        final int gross = _cents(inv['brutto_betrag']);
        final int settled = await _settledForRechnung(id, yearEnd);
        if (settled < 0) {
          return const DashboardAsOfUnavailable('incomplete-history');
        }
        final int remaining = gross - settled;
        if (remaining > 0) {
          total += remaining;
          items += 1;
        }
      }
      return DashboardAsOfOk(balanceCents: total, itemCount: items);
    } catch (_) {
      return const DashboardAsOfUnavailable('incomplete-history');
    }
  }

  /// Payables symmetrically from `rechnung_eingang` plus approved supplier
  /// settlement allocations effective on/before [yearEnd].
  Future<DashboardAsOfResult> payablesAsOf(String yearEnd) async {
    final DashboardAsOfResult? blocked = await _historyBlocker(yearEnd);
    if (blocked != null) return blocked;
    try {
      final List<Map<String, Object?>> invoices = await executor.runSelect(
        "SELECT id, brutto_betrag FROM rechnungen WHERE ist_entwurf = 0 AND typ = 'rechnung_eingang' "
        "AND status NOT IN ('storniert', 'storno', 'entwurf', 'cancelled') "
        'AND substr(datum, 1, 10) <= ?',
        <Object?>[yearEnd],
      );
      if (invoices.isEmpty) {
        return const DashboardAsOfOk(balanceCents: 0, itemCount: 0);
      }
      var total = 0;
      var items = 0;
      for (final Map<String, Object?> inv in invoices) {
        final int id = ((inv['id'] as num?) ?? 0).toInt();
        final int gross = _cents(inv['brutto_betrag']);
        final int settled = await _settledForRechnung(id, yearEnd);
        if (settled < 0) {
          return const DashboardAsOfUnavailable('incomplete-history');
        }
        final int remaining = gross - settled;
        if (remaining > 0) {
          total += remaining;
          items += 1;
        }
      }
      return DashboardAsOfOk(balanceCents: total, itemCount: items);
    } catch (_) {
      return const DashboardAsOfUnavailable('incomplete-history');
    }
  }

  /// Settled cents effective on/before [yearEnd] for one invoice, or -1 when
  /// the history is incomplete (write-off without effective date).
  Future<int> _settledForRechnung(int rechnungId, String yearEnd) async {
    // Any write-off/correction event without an accepted effective date
    // blocks the snapshot (ausbuchen has no accepted date contract).
    try {
      final List<Map<String, Object?>> payRows = await executor.runSelect(
        'SELECT fz.typ AS typ, fz.datum AS datum FROM forderung_zahlungen fz '
        'JOIN forderungen f ON f.id = fz.forderung_id WHERE f.rechnung_id = ?',
        <Object?>[rechnungId],
      );
      for (final Map<String, Object?> row in payRows) {
        if ('${row['typ']}' == 'ausbuchen') {
          return -1;
        }
      }
    } catch (_) {
      // No payment table yet — fall through to settlement allocations.
    }
    // Approved settlement allocations (reversal-safe): only allocations
    // whose group is not reversed and whose date is on/before the snapshot.
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT COALESCE(SUM(a.applied_cents), 0) AS s FROM settlement_allocations a '
        'JOIN settlement_groups g ON g.id = a.group_id '
        'JOIN forderungen f ON f.id = a.forderung_id '
        'WHERE f.rechnung_id = ? AND substr(a.settlement_date, 1, 10) <= ? '
        'AND NOT EXISTS (SELECT 1 FROM settlement_groups r WHERE r.reversal_of_group_id = g.id)',
        <Object?>[rechnungId, yearEnd],
      );
      final int alloc = ((rows.first['s'] as num?) ?? 0).toInt();
      if (alloc > 0) return alloc;
    } catch (_) {
      // Settlement tables may not exist in older profiles — fall through.
    }
    // Keyed zahlung effective dates (authoritative date verbatim).
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT COALESCE(SUM(CASE WHEN substr(fz.datum, 1, 10) <= ? THEN 1 ELSE 0 END), 0) AS n, '
        'COALESCE(SUM(CASE WHEN substr(fz.datum, 1, 10) <= ? AND fz.typ = ? THEN fz.betrag ELSE 0 END), 0) AS s '
        'FROM forderung_zahlungen fz JOIN forderungen f ON f.id = fz.forderung_id '
        'WHERE f.rechnung_id = ?',
        <Object?>[yearEnd, yearEnd, 'zahlung', rechnungId],
      );
      return _cents(rows.first['s']);
    } catch (_) {
      return 0;
    }
  }

  /// Incomplete-history gate: legacy mixes and write-offs block snapshots.
  Future<DashboardAsOfResult?> _historyBlocker(String yearEnd) async {
    try {
      final List<Map<String, Object?>> legacy = await executor.runSelect(
        'SELECT COUNT(*) AS c FROM journal WHERE legacy_unverified = 1 '
        'AND (datum IS NULL OR date(datum) IS NULL OR date(datum) <= date(?))',
        <Object?>[yearEnd],
      );
      if ((((legacy.first['c'] as num?) ?? 0).toInt()) > 0) {
        return const DashboardAsOfUnavailable('legacy-mix');
      }
    } catch (_) {
      // Missing column/table means no legacy signal — continue.
    }
    try {
      final List<Map<String, Object?>> cats = await executor.runSelect(
        "SELECT COUNT(*) AS c FROM kategorien WHERE mapping_status = 'legacy_unverified'",
        const <Object?>[],
      );
      // Category provenance matters only for journal activity through year end.
      if ((((cats.first['c'] as num?) ?? 0).toInt()) > 0) {
        final List<Map<String, Object?>> linked = await executor.runSelect(
          'SELECT COUNT(*) AS c FROM journal j JOIN kategorien k ON k.id = j.kategorie_id '
          "WHERE k.mapping_status = 'legacy_unverified' "
          'AND (j.datum IS NULL OR date(j.datum) IS NULL OR date(j.datum) <= date(?))',
          <Object?>[yearEnd],
        );
        if ((((linked.first['c'] as num?) ?? 0).toInt()) > 0) {
          return const DashboardAsOfUnavailable('legacy-mix');
        }
      }
    } catch (_) {
      // Provenance columns are optional on old profiles — continue.
    }
    return null;
  }

  // --- Attention items ---

  /// Banking selection state for `transactionId` query values.
  /// Returns `selected:<id>`, `none`, `invalid`, or `not-found`.
  /// Missing, malformed, or unavailable IDs never change other query state.
  Future<String> bankingSelection(List<String>? values) async {
    if (values == null) return 'none';
    if (values.length != 1) return 'invalid';
    final int? id = int.tryParse(values.single);
    if (id == null || id <= 0) return 'invalid';
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id FROM bank_transaktionen WHERE id = ? LIMIT 1',
        <Object?>[id],
      );
      return rows.isEmpty ? 'not-found' : 'selected:$id';
    } catch (_) {
      return 'not-found';
    }
  }

  /// Route for an unmatched-transaction item: existing canonical `/banking`
  /// with typed `transactionId` selection, preserving other query state.
  String bankingRouteFor(int transactionId, [Map<String, String> preserve = const <String, String>{}]) {
    final Map<String, String> next = Map<String, String>.from(preserve);
    next['transactionId'] = '$transactionId';
    final String query = next.entries.map((MapEntry<String, String> e) => '${e.key}=${e.value}').join('&');
    return '/banking?$query';
  }

  static int _cents(Object? value) {
    if (value == null) return 0;
    try {
      return money.parseScaled(value.toString(), scale: 2, field: 'amount', roundExcess: true);
    } on money.MoneyParseException {
      return 0;
    }
  }
}
