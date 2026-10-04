/// Immutable EÜR result per spec §EÜR — 60+ Zeilen 12–107.
/// ponytail: string betrag keeps NUMERIC(12,2) precision, map 12..107 covers 60+ Zeilen minimal.
class EuerResult {
  const EuerResult({
    required this.jahr,
    required this.zeilen,
    required this.hinweise,
    required this.vorsteuerBetrag,
    required this.gewinn,
    this.userConfirmedCategoryIds = const <int>[],
    this.catalogSources = const <String, String>{},
    this.provenanceSnapshot = const <String, Object?>{},
  });

  final int jahr;

  /// Zeile → Betrag String '0.00' — 60+ entries (12..107).
  final Map<int, String> zeilen;

  /// Hinweiszeilen 106/107 without Gewinn impact — also present in [zeilen] for completeness.
  final Map<int, String> hinweise;

  /// Vorsteuer per Soll-Prinzip ab CUTOVER_DATUM, else Zahlungsprinzip.
  final String vorsteuerBetrag;

  /// Gewinn (positive) / Verlust (negative string) — Einnahmen minus Ausgaben.
  final String gewinn;

  /// Categories whose mappings are user-confirmed, not source-verified.
  /// Previews must identify them as user-configured.
  final List<int> userConfirmedCategoryIds;

  /// Catalog source reference → version for verified mappings in this result.
  final Map<String, String> catalogSources;

  /// Version-1 JSON-ready snapshot of the exact resolved mappings
  /// (journal/category/line/status/source/history-row bindings). Persist it
  /// verbatim as `euer_exporte.mapping_provenance_json`.
  final Map<String, Object?> provenanceSnapshot;

  /// Convenience: Betrag für Zeile oder '0.00'.
  String zeile(int n) => zeilen[n] ?? '0.00';

  bool get isVerlust => gewinn.startsWith('-');
}
