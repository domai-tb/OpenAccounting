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
  });

  final int? id;
  final int? artikelId;
  final String bezeichnung;
  final num menge;
  final num einzelpreis;
  final num gesamt;
  final num ustSatz;
  final int? position;
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
    required List<RechnungPositionItem> positionen,
  }) : positionen = List<RechnungPositionItem>.unmodifiable(positionen);

  final int id;
  final String? rechnungsnummer;
  final String typ;
  final String status;
  final bool istEntwurf;
  final String eingabemodus;
  final String datum;
  final List<RechnungPositionItem> positionen;
}
