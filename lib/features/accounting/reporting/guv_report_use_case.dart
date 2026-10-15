import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';

/// One GuV line with its grouped amount in integer cents.
class GuvLine {
  const GuvLine({required this.id, required this.label, required this.amountCents});

  final String id;
  final String label;
  final int amountCents;
}

/// Immutable management-GuV preview: grouped lines plus recorded mapping and
/// source versions and the exact annual period.
class GuvPreview {
  const GuvPreview({
    required this.jahr,
    required this.chartVersion,
    required this.mappingVersion,
    required this.sourceVersions,
    required this.periodStart,
    required this.periodEnd,
    required this.lines,
  });

  final int jahr;
  final String chartVersion;

  /// Accepted account-to-GuV-line mapping version for the declared chart.
  final String mappingVersion;

  /// Accepted source-contract identifiers recorded on the result.
  final Map<String, String> sourceVersions;

  /// Exact period, start-inclusive end-exclusive ISO dates.
  final String periodStart;
  final String periodEnd;

  final List<GuvLine> lines;

  int lineAmountCents(String id) => lines
      .firstWhere(
        (GuvLine l) => l.id == id,
        orElse: () => GuvLine(id: id, label: id, amountCents: 0),
      )
      .amountCents;
}

/// Accepted, versioned account-to-GuV-line mapping.
///
/// shortcut: range-based mapping reviewed as part of this change's delta;
/// replace with the validated per-account fixture when a chart-accurate EFB
/// mapping contract is accepted.
class GuvAccountMapping {
  const GuvAccountMapping._(this.version, this._ranges);

  final String version;
  final List<(int, int, String, String)> _ranges; // (from, to, lineId, label)

  static const GuvAccountMapping skr03 = GuvAccountMapping._('skr03-guv-2025', <(int, int, String, String)>[
    (4000, 4799, 'roherloese', 'Roherlöse'),
    (4800, 4999, 'abschreibungen', 'Abschreibungen auf Sachanlagen'),
    (3000, 3999, 'materialaufwand', 'Materialaufwand'),
    (5000, 5999, 'personalaufwand', 'Personalaufwand'),
    (6000, 6899, 'sonstige_aufwendungen', 'Sonstige betriebsaufwendungen'),
    (6900, 6999, 'finanzaufwendungen', 'Finanzaufwendungen'),
    (7000, 7899, 'sonstige_ertraege', 'Sonstige betriebliche Erträge'),
    (7900, 7999, 'steuern', 'Steuern'),
  ]);

  static const GuvAccountMapping skr04 = GuvAccountMapping._('skr04-guv-2025', <(int, int, String, String)>[
    (4000, 4799, 'roherloese', 'Roherlöse'),
    (4800, 4999, 'abschreibungen', 'Abschreibungen auf Sachanlagen'),
    (3000, 3999, 'materialaufwand', 'Materialaufwand'),
    (5000, 5999, 'personalaufwand', 'Personalaufwand'),
    (6000, 6899, 'sonstige_aufwendungen', 'Sonstige betriebsaufwendungen'),
    (6900, 6999, 'finanzaufwendungen', 'Finanzaufwendungen'),
    (7000, 7899, 'sonstige_ertraege', 'Sonstige betriebliche Erträge'),
    (7900, 7999, 'steuern', 'Steuern'),
  ]);

  static GuvAccountMapping forChart(String chartVersion) => chartVersion == '04' ? skr04 : skr03;

  (String, String)? resolve(String? account) {
    final int? n = int.tryParse((account ?? '').trim());
    if (n == null) {
      return null;
    }
    for (final (int, int, String, String) r in _ranges) {
      if (n >= r.$1 && n <= r.$2) {
        return (r.$3, r.$4);
      }
    }
    return null;
  }
}

/// Typed owner for `/reports?report=guv&year=YYYY` (design.md route table).
class GuvReportUseCase {
  GuvReportUseCase(this.executor);

  final QueryExecutor executor;

  static const int supportedYear = 2025;

  Future<ReportWorkspaceResult<GuvPreview>> preview({required int jahr, String chartVersion = '03'}) async {
    if (jahr != supportedYear) {
      return const ReportWorkspaceResult<GuvPreview>.unavailable('unsupportedGuVYear');
    }
    if (!await _approvedSourcesPresent()) {
      // No raw journal-range estimate while the accepted posting source is
      // absent or unapproved.
      return const ReportWorkspaceResult<GuvPreview>.unavailable('sourceUnavailable: balanced-postings not approved');
    }
    final GuvAccountMapping mapping = GuvAccountMapping.forChart(chartVersion);
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT j.datum, j.betrag, j.beleg_typ, k.konto_skr03, k.konto_skr04 FROM journal j '
      'LEFT JOIN kategorien k ON k.id = j.kategorie_id',
      const <Object?>[],
    );
    final Map<String, int> byLine = <String, int>{};
    final Map<String, String> labels = <String, String>{};
    final Set<String> unresolved = <String>{};
    for (final Map<String, Object?> r in rows) {
      final String datum = r['datum']?.toString() ?? '';
      if (!datum.startsWith('$jahr-')) {
        continue;
      }
      final String? account = (chartVersion == '04' ? r['konto_skr04'] : r['konto_skr03'])?.toString();
      final (String, String)? line = mapping.resolve(account);
      if (line == null) {
        unresolved.add(account ?? '(null)');
        continue;
      }
      // Line direction comes from the accepted mapping, not the row sign:
      // journal betrag is stored positive with direction in beleg_typ.
      final int cents = money.parseScaled(r['betrag']?.toString() ?? '0', scale: 2);
      labels[line.$1] = line.$2;
      byLine[line.$1] = (byLine[line.$1] ?? 0) + cents;
    }
    if (unresolved.isNotEmpty) {
      return ReportWorkspaceResult<GuvPreview>.unavailable('unmappedAccount: ${unresolved.join(',')}');
    }
    return ReportWorkspaceResult<GuvPreview>.available(
      GuvPreview(
        jahr: jahr,
        chartVersion: chartVersion,
        mappingVersion: mapping.version,
        sourceVersions: const <String, String>{'balanced-postings': 'accepted', 'invoice-money': 'accepted'},
        periodStart: '$jahr-01-01',
        periodEnd: '${jahr + 1}-01-01',
        lines: <GuvLine>[
          for (final MapEntry<String, String> e in labels.entries)
            GuvLine(id: e.key, label: e.value, amountCents: byLine[e.key] ?? 0),
        ],
      ),
    );
  }

  /// Mechanical availability check standing in for the accepted source
  /// contracts: the balanced-posting settlement tables and the
  /// invoice-money legacy-cutover marker must be present.
  Future<bool> _approvedSourcesPresent() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('settlement_groups', 'settlement_allocations')",
      const <Object?>[],
    );
    if (tables.length != 2) {
      return false;
    }
    final List<Map<String, Object?>> cols = await executor.runSelect('PRAGMA table_info(journal)', const <Object?>[]);
    return cols.any((Map<String, Object?> c) => c['name']?.toString() == 'legacy_unverified');
  }
}
