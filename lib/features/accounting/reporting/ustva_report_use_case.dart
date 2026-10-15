import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';
import 'package:openaccounting/features/accounting/ustva_entity.dart';
import 'package:openaccounting/features/accounting/ustva_service.dart';

/// Immutable UStVA preview: resolved Kennzahl amounts, the accepted map
/// version, exact period endpoints, and preview-only semantics.
class UstvaPreview {
  UstvaPreview({
    required this.jahr,
    required this.monatOrQuartal,
    required this.rhythmus,
    required this.kz,
    required this.mapVersion,
    required this.periodStart,
    required this.periodEnd,
    required this.noEligibleEvents,
  });

  final int jahr;
  final int monatOrQuartal;
  final String rhythmus;

  /// KZ → Betrag '0.00' (string money, 2 decimals).
  final Map<String, String> kz;

  /// Accepted year-specific Kennzahl map version.
  final String mapVersion;

  /// Exact period, start-inclusive end-exclusive ISO dates.
  final String periodStart;
  final String periodEnd;

  /// True when every key holds the map's zero representation: the complete
  /// period contains no eligible events.
  final bool noEligibleEvents;

  String kzValue(String key) => kz[key] ?? '0.00';

  /// An UStVA preview is never an official filing artifact or submission.
  bool get isFilingArtifact => false;
}

/// Typed owner for `/taxes?report=ustva&period=YYYY-MM` (design.md route table).
/// shortcut: one accepted Kennzahl map year (2025); add a per-year registry
/// when a later UStVA map contract is accepted.
class UstvaReportUseCase {
  UstvaReportUseCase(this.executor) : _service = UstvaService(executor);

  final QueryExecutor executor;
  final UstvaService _service;

  static const String supportedMapVersion = 'de-ustva-2025';
  static const int supportedMapYear = 2025;

  Future<ReportWorkspaceResult<UstvaPreview>> preview({
    required int jahr,
    required int monatOrQuartal,
    required String rhythmus,
  }) async {
    if (jahr != supportedMapYear) {
      return const ReportWorkspaceResult<UstvaPreview>.unavailable('missingYearSpecificMap');
    }
    final String norm = rhythmus.trim().toLowerCase();
    final bool isMonthly = norm == 'monatlich' || norm == 'monthly' || norm == 'monat';
    final bool isQuarter = norm == 'quartal' || norm == 'quarterly' || norm == 'quartalsweise' || norm == 'q';
    if (!isMonthly && !isQuarter) {
      return const ReportWorkspaceResult<UstvaPreview>.invalidSelection('missingFilingRhythm');
    }
    if ((isMonthly && (monatOrQuartal < 1 || monatOrQuartal > 12)) ||
        (isQuarter && (monatOrQuartal < 1 || monatOrQuartal > 4))) {
      return const ReportWorkspaceResult<UstvaPreview>.invalidSelection('invalidPeriod');
    }
    try {
      final UstvaResult result = await _service.compute(jahr: jahr, monatOrQuartal: monatOrQuartal, rhythmus: rhythmus);
      return ReportWorkspaceResult<UstvaPreview>.available(
        UstvaPreview(
          jahr: jahr,
          monatOrQuartal: monatOrQuartal,
          rhythmus: result.rhythmus,
          kz: result.kz,
          mapVersion: supportedMapVersion,
          periodStart: _periodStart(jahr, monatOrQuartal, isMonthly),
          periodEnd: _periodEnd(jahr, monatOrQuartal, isMonthly),
          noEligibleEvents: result.kz.values.every((String v) => double.tryParse(v) == 0),
        ),
      );
    } on UstvaException catch (e) {
      return ReportWorkspaceResult<UstvaPreview>.unavailable('sourceUnavailable: ${e.message}');
    }
  }

  static String _periodStart(int jahr, int monatOrQuartal, bool isMonthly) {
    final int month = isMonthly ? monatOrQuartal : (monatOrQuartal - 1) * 3 + 1;
    return '$jahr-${month.toString().padLeft(2, '0')}-01';
  }

  static String _periodEnd(int jahr, int monatOrQuartal, bool isMonthly) {
    final int startMonth = isMonthly ? monatOrQuartal : (monatOrQuartal - 1) * 3 + 1;
    final int endMonth = startMonth + 3 - (isMonthly ? 2 : 0);
    if (endMonth > 12) {
      return '${jahr + 1}-01-01';
    }
    return '$jahr-${endMonth.toString().padLeft(2, '0')}-01';
  }
}
