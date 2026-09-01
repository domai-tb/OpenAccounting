class Mahnstufe {
  const Mahnstufe({
    required this.id,
    required this.stufe,
    required this.bezeichnung,
    required this.tageNachFaelligkeit,
    required this.gebuehr,
    required this.zinssatz,
    required this.systemStufe,
    required this.multiplier,
  });

  final int id;
  final int stufe;
  final String bezeichnung;
  final int tageNachFaelligkeit;
  final String gebuehr;
  final String zinssatz;
  final bool systemStufe;
  final bool multiplier;
}
