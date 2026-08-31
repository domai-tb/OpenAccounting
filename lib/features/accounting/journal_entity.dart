/// Immutable journal entry per spec §Journal Entries.
/// ponytail: minimal fields, String betrag keeps NUMERIC(12,2) precision.
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
    this.beschreibung,
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
  final String? beschreibung;

  /// Alias for spec compatibility.
  String get bezeichnungAlias => bezeichnung;
}

class JournalException implements Exception {
  const JournalException(this.message);

  final String message;

  @override
  String toString() => message;
}
