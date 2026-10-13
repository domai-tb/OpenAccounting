/// Typed lifecycle relationship between persisted documents.
///
/// A relationship always names its [kind] (storno, gutschrift, ersatz,
/// konvertierung), the other document's [documentId], and a short human
/// readable [label] such as the document number. When the target row is
/// missing, [available] is false and the stored [documentId] is still
/// exposed so the UI can show an explicit unavailable state instead of
/// fabricating an unrelated document.
class RechnungBeziehung {
  const RechnungBeziehung({required this.kind, required this.documentId, required this.label, required this.available});

  final String kind;
  final int documentId;
  final String label;
  final bool available;
}

class RechnungPositionItem {
  const RechnungPositionItem({
    required this.bezeichnung,
    required this.menge,
    required this.einzelpreis,
    required this.gesamt,
    this.ustSatz = 19,
    this.artikelId,
    this.position,
    this.id,
    this.rabattProzent,
  });

  final int? id;
  final int? artikelId;
  final String bezeichnung;
  final num menge;
  final num einzelpreis;
  final num gesamt;
  final num ustSatz;
  final int? position;
  final num? rabattProzent;
}

class RechnungItem {
  RechnungItem({
    required this.id,
    required this.rechnungsnummer,
    required this.typ,
    required this.status,
    required this.istEntwurf,
    required this.eingabemodus,
    required this.datum,
    this.kundeName,
    this.kundeFirma,
    this.kundeStrasse,
    this.kundePlz,
    this.kundeOrt,
    this.originalPdfPath,
    this.rabattProzent,
    this.rabattBetrag,
    this.ausgabeformat,
    this.kundeId,
    this.lieferantId,
    this.belegId,
    this.faelligkeit,
    this.fremdRechnungsnummer,
    required List<RechnungPositionItem> positionen,
    List<RechnungBeziehung> beziehungen = const <RechnungBeziehung>[],
  }) : positionen = List<RechnungPositionItem>.unmodifiable(positionen),
       beziehungen = List<RechnungBeziehung>.unmodifiable(beziehungen);

  final int id;
  final String? rechnungsnummer;
  final String typ;
  final String status;
  final bool istEntwurf;
  final String eingabemodus;
  final String datum;
  final String? kundeName;
  final String? kundeFirma;
  final String? kundeStrasse;
  final String? kundePlz;
  final String? kundeOrt;
  final String? originalPdfPath;
  final num? rabattProzent;
  final num? rabattBetrag;

  /// Linked customer/supplier rows. Null for walk-in documents.
  final int? kundeId;
  final int? lieferantId;
  final int? belegId;
  final String? faelligkeit;
  final String? fremdRechnungsnummer;

  /// Explicit per-invoice output choice persisted at finalization
  /// (`pdf`, `zugferd`, or `xrechnung`). Null for legacy rows and drafts.
  final String? ausgabeformat;
  final List<RechnungPositionItem> positionen;

  /// Typed source/target references (storno, gutschrift, ersatz,
  /// konvertierung). Empty when the document has no persisted links.
  final List<RechnungBeziehung> beziehungen;

  bool get istStorniert => status.toLowerCase() == 'storniert';
  bool get istEntwurfDokument => istEntwurf || status.toLowerCase() == 'entwurf';

  /// Effective output format. Legacy finalized rows and drafts without a
  /// saved choice resolve to PDF; the customer's current preference is never
  /// consulted for finalized invoices.
  String get effektivesAusgabeformat {
    final String normalized = ausgabeformat?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'zugferd' => 'zugferd',
      'xrechnung' => 'xrechnung',
      _ => 'pdf',
    };
  }
}
