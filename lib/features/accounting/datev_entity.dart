/// DATEV EXTF entity per spec §DATEV EXTF Export.
/// ponytail: minimal exception, string money keeps NUMERIC(12,2) precision.
class DatevException implements Exception {
  const DatevException(
    this.message, [
    this.affectedJournalIds = const <int>[],
    this.affectedCategoryIds = const <int>[],
    this.unresolvedSlot,
  ]);

  final String message;

  /// Journal entries that blocked generation (unresolved account slot).
  final List<int> affectedJournalIds;

  /// Categories that blocked generation (unresolved account slot).
  final List<int> affectedCategoryIds;

  /// 'Konto' or 'Gegenkonto' when a single slot could not be resolved.
  final String? unresolvedSlot;

  @override
  String toString() => message;
}

/// Preview/metadata for a DATEV export. User-confirmed mappings are identified
/// as user-configured, not source-verified; [slotSnapshots] is the version-1
/// JSON-ready provenance persisted with the export log.
class DatevExportResult {
  const DatevExportResult({
    required this.csv,
    required this.userConfirmedCategoryIds,
    required this.catalogSources,
    required this.slotSnapshots,
    required this.exportLogId,
  });

  final String csv;
  final List<int> userConfirmedCategoryIds;
  final Map<String, String> catalogSources;
  final Map<String, Object?> slotSnapshots;
  final int exportLogId;
}
