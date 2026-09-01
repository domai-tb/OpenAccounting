/// Bank import entities — ponytail ultra minimal for upload step.
/// ponytail: RawTx keeps betrag as String 12,2 to avoid double drift.
class RawTx {
  const RawTx({
    required this.datum,
    required this.betrag,
    required this.verwendungszweck,
    required this.partner,
    this.gegenkonto,
    this.kategorieId,
    this.journalId,
    this.dedupeHash,
  });

  /// Transaction date — parsed from CSV via template dateFormat fallback.
  final DateTime datum;

  /// Amount as String 12,2 e.g. "1234.56", "-42.50" — NUMERIC(12,2) safe.
  final String betrag;

  /// Purpose / Verwendungszweck free text.
  final String verwendungszweck;

  /// Partner name — Empfänger/Auftraggeber/Begünstigter.
  final String partner;

  /// Gegenkonto IBAN if present.
  final String? gegenkonto;

  /// Auto-categorization result — filled later in dedup/rules step.
  final int? kategorieId;

  /// Matched journal id — filled later in score step.
  final int? journalId;

  /// SHA-256 dedupe hash — computed in dedup step, not upload.
  final String? dedupeHash;
}

/// Result of dedup + rule + score import.
class ImportResult {
  const ImportResult({
    required this.imported,
    required this.duplicatesSkipped,
    required this.autoCategorized,
    required this.manualReview,
  });

  final int imported;
  final int duplicatesSkipped;
  final int autoCategorized;
  final int manualReview;
}

/// Thrown when CSV cannot be parsed or no template matches.
class BankImportException implements Exception {
  const BankImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
