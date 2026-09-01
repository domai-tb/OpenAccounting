class MahnwesenEinstellungen {
  const MahnwesenEinstellungen({
    required this.id,
    required this.schwelleWarnung,
    required this.schwelleSperrung,
    required this.aktiv,
    this.unternehmenId,
    this.graceTage = 0,
  });

  final int id;
  final int schwelleWarnung;
  final int schwelleSperrung;
  final bool aktiv;
  final int? unternehmenId;
  final int graceTage;

  MahnwesenEinstellungen copyWith({
    int? schwelleWarnung,
    int? schwelleSperrung,
    bool? aktiv,
    int? graceTage,
    int? unternehmenId,
  }) {
    return MahnwesenEinstellungen(
      id: id,
      schwelleWarnung: schwelleWarnung ?? this.schwelleWarnung,
      schwelleSperrung: schwelleSperrung ?? this.schwelleSperrung,
      aktiv: aktiv ?? this.aktiv,
      unternehmenId: unternehmenId ?? this.unternehmenId,
      graceTage: graceTage ?? this.graceTage,
    );
  }
}
