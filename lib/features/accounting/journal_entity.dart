/// Immutable journal entry per spec §Journal Entries.
/// ponytail: minimal fields, String betrag keeps NUMERIC(12,2) precision.
/// ponytail: gruppe_id deferred — storno_von chain covers Buchungsgruppe
/// (Original→Storno) without extra table/FK; add `gruppe_id INTEGER
/// REFERENCES journal(id)` + population if multi-entry groups required.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.datum,
    required this.bezeichnung,
    required this.kategorieId,
    required this.betrag,
    required this.art,
    required this.immutable,
    this.kontoSkr03,
    this.kontoSkr04,
    this.ustSatzId,
    this.belegNr,
    this.stornoVon,
    this.kontoId,
    this.gruppeId,
  });

  final int id;
  final DateTime datum;
  final String bezeichnung;
  final int kategorieId;
  final String betrag;
  final String art;
  final bool immutable;
  final String? kontoSkr03;
  final String? kontoSkr04;
  final int? ustSatzId;
  final String? belegNr;
  final int? stornoVon;
  final int? kontoId;
  final int? gruppeId;

  /// DB column is `beschreibung` — alias for `bezeichnung` for spec/DB compatibility.
  String get beschreibung => bezeichnung;
}

class JournalException implements Exception {
  const JournalException(this.message);

  final String message;

  @override
  String toString() => message;
}
