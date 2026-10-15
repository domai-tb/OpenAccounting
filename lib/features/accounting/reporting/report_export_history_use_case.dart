import 'package:drift/drift.dart';

class ReportExportHistoryEntry {
  const ReportExportHistoryEntry({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.path,
    required this.status,
  });

  final int id;
  final String periodStart;
  final String periodEnd;
  final String path;
  final String status;
}

class ReportExportHistoryUseCase {
  ReportExportHistoryUseCase(this.executor);

  final QueryExecutor executor;

  Future<List<ReportExportHistoryEntry>> list() async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, zeitraum_von, zeitraum_bis, datei_pfad, status '
      'FROM datev_export_log WHERE status = ? AND datei_pfad IS NOT NULL '
      'AND LENGTH(TRIM(datei_pfad)) > 0 ORDER BY id DESC',
      const <Object?>['erfolg'],
    );
    return rows
        .map(
          (Map<String, Object?> row) => ReportExportHistoryEntry(
            id: (row['id']! as num).toInt(),
            periodStart: row['zeitraum_von']?.toString() ?? '',
            periodEnd: row['zeitraum_bis']?.toString() ?? '',
            path: row['datei_pfad']! as String,
            status: row['status']! as String,
          ),
        )
        .toList(growable: false);
  }
}
