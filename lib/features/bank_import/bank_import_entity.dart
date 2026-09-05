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

  /// Creates a reviewed copy without changing the parsed source row.
  ///
  /// Review screens can use this to apply a category, journal match, or text
  /// correction before calling the import service. Null values keep the
  /// existing optional value for backwards-compatible call sites.
  RawTx copyWith({
    DateTime? datum,
    String? betrag,
    String? verwendungszweck,
    String? partner,
    String? gegenkonto,
    int? kategorieId,
    int? journalId,
    String? dedupeHash,
  }) {
    return RawTx(
      datum: datum ?? this.datum,
      betrag: betrag ?? this.betrag,
      verwendungszweck: verwendungszweck ?? this.verwendungszweck,
      partner: partner ?? this.partner,
      gegenkonto: gegenkonto ?? this.gegenkonto,
      kategorieId: kategorieId ?? this.kategorieId,
      journalId: journalId ?? this.journalId,
      dedupeHash: dedupeHash ?? this.dedupeHash,
    );
  }
}

/// A row that could not be persisted during a partial import.
class ImportRowFailure {
  const ImportRowFailure({required this.rowNumber, required this.transaction, required this.error});

  /// One-based row number within the confirmed import batch.
  final int rowNumber;

  /// The reviewed row as it was presented to persistence.
  final RawTx transaction;

  /// Database or validation error associated with [transaction].
  final String error;

  /// Zero-based counterpart for callers that address a list by index.
  int get rowIndex => rowNumber - 1;

  /// Alias useful to review/retry clients.
  RawTx get row => transaction;

  /// Alias useful to clients that display an error message.
  String get message => error;

  String toDiagnostic() => 'Zeile $rowNumber: $error';

  Map<String, Object?> toJson() => <String, Object?>{
    'row': rowNumber,
    'datum': transaction.datum.toIso8601String(),
    'betrag': transaction.betrag,
    'verwendungszweck': transaction.verwendungszweck,
    'partner': transaction.partner,
    'error': error,
  };

  @override
  String toString() => toDiagnostic();
}

/// Result of dedup + rule + score import.
class ImportResult {
  const ImportResult({
    required this.imported,
    required this.duplicatesSkipped,
    required this.autoCategorized,
    required this.manualReview,
    this.failed = 0,
    this.status = 'importiert',
    this.diagnostics = const <String>[],
    this.failedRows = const <ImportRowFailure>[],
    this.importId,
    this.historyUpdated = true,
  });

  final int imported;
  final int duplicatesSkipped;
  final int autoCategorized;
  final int manualReview;

  /// Number of confirmed rows that were not persisted.
  final int failed;

  /// Final import status: `importiert`, `teilweise`, or `fehlgeschlagen`.
  final String status;

  /// Human-readable diagnostics suitable for a review/retry surface.
  final List<String> diagnostics;

  /// Structured failed rows, retained so callers can correct and retry them.
  final List<ImportRowFailure> failedRows;

  /// History row id when history persistence succeeded.
  final int? importId;

  /// False only when the database could not finalize the history row.
  final bool historyUpdated;

  /// Retry-ready rows from this result.
  List<RawTx> get retryableRows => failedRows.map((failure) => failure.transaction).toList(growable: false);

  /// Alias for clients that call failures rather than failed rows.
  List<ImportRowFailure> get failures => failedRows;

  bool get isPartial => status == 'teilweise';

  bool get isFailed => status == 'fehlgeschlagen';
}

/// Thrown when CSV cannot be parsed or no template matches.
class BankImportException implements Exception {
  const BankImportException(this.message, {this.rowNumber, this.recoveryAction});

  final String message;

  /// One-based source row when parsing identified a specific row.
  final int? rowNumber;

  /// Optional user-facing recovery guidance.
  final String? recoveryAction;

  @override
  String toString() => message;
}
