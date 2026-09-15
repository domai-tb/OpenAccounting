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
    required List<RechnungPositionItem> positionen,
  }) : positionen = List<RechnungPositionItem>.unmodifiable(positionen);

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
  final List<RechnungPositionItem> positionen;
}
