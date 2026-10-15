import 'dart:io';

import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/reporting/datev_export_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';
import 'package:openaccounting/features/accounting/reporting/reporting_workspace_use_case.dart';

/// Outcome of a successful DATEV file export through the maintained artifact
/// lifecycle: written, reopened, validated, and recorded in history.
class ReportExportOutcome {
  const ReportExportOutcome({
    required this.path,
    required this.exportLogId,
    required this.bookingRowCount,
    required this.validated,
  });

  final String path;

  /// `datev_export_log` row of the recorded export.
  final int exportLogId;
  final int bookingRowCount;

  /// True only after the written file was reopened and validated.
  final bool validated;
}

/// Typed owner for report file output (design.md). DATEV v13 CSV is the only
/// supported export in this change: preview-only reports offer no file-export
/// action, and any other format stays unavailable with the missing contract
/// named. No file is written and no successful export is recorded unless the
/// reopened artifact validates.
class ReportExportUseCase {
  ReportExportUseCase(this.executor);

  final QueryExecutor executor;

  Future<ReportWorkspaceResult<ReportExportOutcome>> export({
    required ReportSelection selection,
    required String format,
    required String destinationPath,
    DateTime? generatedAt,
  }) async {
    if (format.trim().toLowerCase() != 'csv') {
      return ReportWorkspaceResult<ReportExportOutcome>.unavailable(
        'unsupportedExportFormat: no accepted file-format contract for $format in this change',
      );
    }
    if (selection.kind != ReportKind.datev) {
      return const ReportWorkspaceResult<ReportExportOutcome>.unavailable(
        'previewOnlyReport: no file export offered for this report type',
      );
    }

    final ReportWorkspaceResult<DatevExportArtifact> artifact = await DatevExportUseCase(executor)
        .create(month: selection.month!, config: selection.datevConfig!, generatedAt: generatedAt);
    if (artifact.availability != ReportAvailability.available) {
      return ReportWorkspaceResult<ReportExportOutcome>.unavailable(artifact.reasonCode ?? 'sourceUnavailable');
    }
    final DatevExportArtifact a = artifact.value!;

    final String dest = destinationPath.trim();
    if (dest.isEmpty || !Uri.file(dest).isAbsolute) {
      return const ReportWorkspaceResult<ReportExportOutcome>.unavailable('invalidExportDestination: absolute path');
    }
    final Directory parent = File(dest).parent;
    if (!parent.existsSync()) {
      return const ReportWorkspaceResult<ReportExportOutcome>.unavailable(
        'invalidExportDestination: destination folder',
      );
    }

    final File target = File(dest);
    final File temporary = File('$dest.tmp-${DateTime.now().microsecondsSinceEpoch}');
    try {
      await temporary.writeAsString(a.csv, flush: true);
      await temporary.rename(target.path);
    } catch (_) {
      try {
        if (temporary.existsSync()) {
          temporary.deleteSync();
        }
      } catch (_) {
        // Best-effort cleanup; the export still fails below.
      }
      return const ReportWorkspaceResult<ReportExportOutcome>.unavailable('invalidExportDestination: write failed');
    }

    // Reopen and validate before any success: exact content round-trip, the
    // pinned v13 header, and the row count of the generated artifact.
    bool valid = false;
    try {
      final String reopened = await target.readAsString();
      final List<String> lines = reopened.split('\r\n');
      final List<String> header = lines.first.split(';');
      valid =
          reopened == a.csv &&
          header.sublist(0, 5).join('|') == 'EXTF|700|21|Buchungsstapel|13' &&
          lines.length - 1 == a.bookingRowCount;
    } on FileSystemException {
      valid = false;
    }
    if (!valid) {
      try {
        if (target.existsSync()) {
          target.deleteSync();
        }
      } catch (_) {
        // Best-effort cleanup; validation failure is reported either way.
      }
      return const ReportWorkspaceResult<ReportExportOutcome>.unavailable('datevArtifactValidationFailed');
    }

    int exportLogId;
    try {
      final int y = int.parse(a.month.substring(0, 4));
      final int m = int.parse(a.month.substring(5, 7));
      final DateTime from = DateTime(y, m);
      final DateTime to = DateTime(y, m + 1, 0);
      final List<Map<String, Object?>> u = await executor.runSelect(
        'SELECT id FROM unternehmen LIMIT 1',
        const <Object?>[],
      );
      final int? unternehmenId = u.isEmpty ? null : (u.first['id']! as num).toInt();
      exportLogId = await executor.runInsert(
        'INSERT INTO datev_export_log '
        '(datum, zeitraum_von, zeitraum_bis, anzahl_buchungen, datei_pfad, unternehmen_id, status) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          (generatedAt ?? DateTime.now()).toIso8601String(),
          from.toIso8601String().substring(0, 10),
          to.toIso8601String().substring(0, 10),
          a.bookingRowCount,
          dest,
          unternehmenId,
          'erfolg',
        ],
      );
    } catch (_) {
      return const ReportWorkspaceResult<ReportExportOutcome>.unavailable(
        'datevHistoryUnavailable: validated artifact exists but history could not be recorded',
      );
    }

    return ReportWorkspaceResult<ReportExportOutcome>.available(
      ReportExportOutcome(path: dest, exportLogId: exportLogId, bookingRowCount: a.bookingRowCount, validated: true),
    );
  }
}
