/// Immutable EÜR result per spec §EÜR — 60+ Zeilen 12–107.
/// ponytail: string betrag keeps NUMERIC(12,2) precision, map 12..107 covers 60+ Zeilen minimal.
class EuerResult {
  const EuerResult({
    required this.jahr,
    required this.zeilen,
    required this.hinweise,
    required this.vorsteuerBetrag,
    required this.gewinn,
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

  /// Convenience: Betrag für Zeile oder '0.00'.
  String zeile(int n) => zeilen[n] ?? '0.00';

  bool get isVerlust => gewinn.startsWith('-');
}
