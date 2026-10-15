import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/reporting/datev_export_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/euer_report_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/guv_report_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/ustva_report_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/zm_preview_use_case.dart';

/// Canonical report selection parsed from the documented `/reports` and
/// `/taxes` query shapes (design.md route matrix).
enum ReportKind { euer, eks, guv, ustva, zm, datev }

class ReportSelection {
  const ReportSelection.euer({required this.jahr})
    : kind = ReportKind.euer,
      month = null,
      monatOrQuartal = null,
      rhythmus = null,
      datevConfig = null;

  const ReportSelection.eks()
    : kind = ReportKind.eks,
      jahr = null,
      month = null,
      monatOrQuartal = null,
      rhythmus = null,
      datevConfig = null;

  const ReportSelection.guv({required this.jahr})
    : kind = ReportKind.guv,
      month = null,
      monatOrQuartal = null,
      rhythmus = null,
      datevConfig = null;

  const ReportSelection.ustva({required this.jahr, required this.monatOrQuartal, required this.rhythmus})
    : kind = ReportKind.ustva,
      month = null,
      datevConfig = null;

  const ReportSelection.zm({required this.month})
    : kind = ReportKind.zm,
      jahr = null,
      monatOrQuartal = null,
      rhythmus = null,
      datevConfig = null;

  const ReportSelection.datev({required this.month, required this.datevConfig})
    : kind = ReportKind.datev,
      jahr = null,
      monatOrQuartal = null,
      rhythmus = null;

  final ReportKind kind;
  final int? jahr;
  final String? month;
  final int? monatOrQuartal;
  final String? rhythmus;
  final DatevExportConfig? datevConfig;
}

/// Immutable typed report value with exact period and recorded source
/// versions; pages render this and never query tables or calculate totals.
sealed class ReportWorkspaceValue {
  const ReportWorkspaceValue({required this.periodStart, required this.periodEnd, required this.sourceVersions});

  final String periodStart;
  final String periodEnd;

  /// Calculation/form/interface version recorded on the result.
  final Map<String, String> sourceVersions;
}

class EuerWorkspaceValue extends ReportWorkspaceValue {
  const EuerWorkspaceValue({
    required super.periodStart,
    required super.periodEnd,
    required super.sourceVersions,
    required this.preview,
  });

  final EuerPreview preview;
}

class GuvWorkspaceValue extends ReportWorkspaceValue {
  const GuvWorkspaceValue({
    required super.periodStart,
    required super.periodEnd,
    required super.sourceVersions,
    required this.preview,
  });

  final GuvPreview preview;
}

class UstvaWorkspaceValue extends ReportWorkspaceValue {
  const UstvaWorkspaceValue({
    required super.periodStart,
    required super.periodEnd,
    required super.sourceVersions,
    required this.preview,
  });

  final UstvaPreview preview;
}

class ZmWorkspaceValue extends ReportWorkspaceValue {
  const ZmWorkspaceValue({
    required super.periodStart,
    required super.periodEnd,
    required super.sourceVersions,
    required this.preview,
  });

  final ZmPreview preview;
}

class DatevWorkspaceValue extends ReportWorkspaceValue {
  const DatevWorkspaceValue({
    required super.periodStart,
    required super.periodEnd,
    required super.sourceVersions,
    required this.artifact,
  });

  final DatevExportArtifact artifact;
}

/// Composed dispatcher from a typed `ReportSelection` to the named report
/// use case (design.md route matrix). Financial summaries require both
/// accepted source contracts; every result names its versions and period.
class ReportingWorkspaceUseCase {
  ReportingWorkspaceUseCase(this.executor);

  final QueryExecutor executor;

  Future<ReportWorkspaceResult<ReportWorkspaceValue>> resolve(ReportSelection selection) async {
    switch (selection.kind) {
      case ReportKind.eks:
        // No accepted form version or Bewilligungszeitraum contract exists;
        // a calendar-year surrogate is never presented.
        return const ReportWorkspaceResult<ReportWorkspaceValue>.unavailable(
          'unacceptedEksContract: formVersion, Bewilligungszeitraum',
        );
      case ReportKind.zm:
        final ReportWorkspaceResult<ZmPreview> r = await ZmPreviewUseCase(executor).preview(month: selection.month!);
        return _wrap<ZmPreview, ZmWorkspaceValue>(
          r,
          (ZmPreview p) => ZmWorkspaceValue(
            periodStart: p.periodStart,
            periodEnd: p.periodEnd,
            sourceVersions: <String, String>{'§18a-ustg': p.sourceContractVersion},
            preview: p,
          ),
        );
      case ReportKind.euer:
      case ReportKind.guv:
      case ReportKind.ustva:
      case ReportKind.datev:
        final String? blocked = await _financialPrerequisiteBlocker();
        if (blocked != null) {
          return ReportWorkspaceResult<ReportWorkspaceValue>.unavailable(blocked);
        }
        switch (selection.kind) {
          case ReportKind.euer:
            final ReportWorkspaceResult<EuerPreview> r = await EuerReportUseCase(executor)
                .preview(jahr: selection.jahr!);
            return _wrap<EuerPreview, EuerWorkspaceValue>(
              r,
              (EuerPreview p) => EuerWorkspaceValue(
                periodStart: '${p.jahr}-01-01',
                periodEnd: '${p.jahr + 1}-01-01',
                sourceVersions: <String, String>{'formVersion': p.formVersion, ...p.sourceVersions},
                preview: p,
              ),
            );
          case ReportKind.guv:
            final ReportWorkspaceResult<GuvPreview> r = await GuvReportUseCase(executor).preview(jahr: selection.jahr!);
            return _wrap<GuvPreview, GuvWorkspaceValue>(
              r,
              (GuvPreview p) => GuvWorkspaceValue(
                periodStart: p.periodStart,
                periodEnd: p.periodEnd,
                sourceVersions: <String, String>{'mappingVersion': p.mappingVersion, ...p.sourceVersions},
                preview: p,
              ),
            );
          case ReportKind.ustva:
            final ReportWorkspaceResult<UstvaPreview> r = await UstvaReportUseCase(
              executor,
            ).preview(jahr: selection.jahr!, monatOrQuartal: selection.monatOrQuartal!, rhythmus: selection.rhythmus!);
            return _wrap<UstvaPreview, UstvaWorkspaceValue>(
              r,
              (UstvaPreview p) => UstvaWorkspaceValue(
                periodStart: p.periodStart,
                periodEnd: p.periodEnd,
                sourceVersions: <String, String>{'kennzahlMap': p.mapVersion},
                preview: p,
              ),
            );
          case ReportKind.datev:
            final ReportWorkspaceResult<DatevExportArtifact> r = await DatevExportUseCase(executor)
                .create(month: selection.month!, config: selection.datevConfig!);
            return _wrap<DatevExportArtifact, DatevWorkspaceValue>(
              r,
              (DatevExportArtifact a) => DatevWorkspaceValue(
                periodStart: '${a.month}-01',
                periodEnd: _monthEndExclusive(a.month),
                sourceVersions: <String, String>{
                  'datevHeaderVersion': '${a.headerVersion}',
                  'datevFormatVersion': '${a.formatVersion}',
                },
                artifact: a,
              ),
            );
          case ReportKind.zm:
          case ReportKind.eks:
            throw StateError('handled above');
        }
    }
  }

  static String _monthEndExclusive(String month) {
    final int y = int.parse(month.substring(0, 4));
    final int m = int.parse(month.substring(5, 7));
    final DateTime endExclusive = DateTime(y, m + 1);
    final String mm = endExclusive.month.toString().padLeft(2, '0');
    final String dd = endExclusive.day.toString().padLeft(2, '0');
    return '${endExclusive.year}-$mm-$dd';
  }

  static ReportWorkspaceResult<V> _wrap<T, V>(ReportWorkspaceResult<T> r, V Function(T) wrap) {
    switch (r.availability) {
      case ReportAvailability.available:
        return ReportWorkspaceResult<V>.available(wrap(r.value as T));
      case ReportAvailability.unavailable:
        return ReportWorkspaceResult<V>.unavailable(r.reasonCode);
      case ReportAvailability.invalidSelection:
        return ReportWorkspaceResult<V>.invalidSelection(r.reasonCode);
    }
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
