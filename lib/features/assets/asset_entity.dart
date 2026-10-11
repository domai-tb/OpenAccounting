/// Canonical fixed-asset inputs per the maintained accounting contract.
///
/// New records use these contract names and units. Legacy columns
/// (`anschaffungskosten`, `nutzungsdauer`, `privatanteil`) are preserved for
/// review and are never reinterpreted as canonical inputs.
enum AssetTyp {
  kfz('KFZ'),
  edv('EDV'),
  sonstig('sonstig');

  const AssetTyp(this.db);

  final String db;

  static AssetTyp? fromDb(Object? value) {
    final String text = value?.toString().trim() ?? '';
    for (final AssetTyp type in AssetTyp.values) {
      if (type.db == text) return type;
    }
    return null;
  }
}

/// Calculation/rule version stamped on every persisted schedule snapshot.
const String assetRegelVersion = 'afa-linear-v1';

/// Thrown when new asset inputs violate the maintained contract.
class AssetValidationException implements Exception {
  const AssetValidationException(this.field, this.message);

  /// Contract field that failed validation (e.g. `bezeichnung`).
  final String field;
  final String message;

  @override
  String toString() => 'AssetValidationException($field): $message';
}

/// Thrown when hard deletion is refused because schedule history exists.
class AssetInUseException implements Exception {
  const AssetInUseException(this.message);

  final String message;

  @override
  String toString() => 'AssetInUseException: $message';
}

/// Thrown when a requested financial effect has no accepted posting contract.
class AssetPostingUnavailable implements Exception {
  const AssetPostingUnavailable(this.message);

  final String message;

  @override
  String toString() => 'AssetPostingUnavailable: $message';
}

/// A fixed-asset register record with canonical inputs and legacy review values.
class FixedAsset {
  const FixedAsset({
    required this.id,
    required this.bezeichnung,
    required this.anschaffungsdatum,
    required this.status,
    this.assetTyp,
    this.kaufpreisNetto,
    this.nutzungsdauerJahre,
    this.afaMethode,
    this.privatAnteilProzent,
    this.kategorieId,
    this.unternehmenId,
    this.verkauftAm,
    this.legacyAnschaffungskosten,
    this.legacyNutzungsdauer,
    this.legacyPrivatanteil,
  });

  final int id;
  final String bezeichnung;
  final AssetTyp? assetTyp;
  final String anschaffungsdatum;
  final String? kaufpreisNetto;
  final int? nutzungsdauerJahre;
  final String? afaMethode;
  final String? privatAnteilProzent;
  final int? kategorieId;
  final int? unternehmenId;
  final String? verkauftAm;
  final String status;
  final String? legacyAnschaffungskosten;
  final int? legacyNutzungsdauer;
  final String? legacyPrivatanteil;

  /// True when every canonical schedule input maps to the maintained contract.
  bool get hasCanonicalInputs {
    return assetTyp != null &&
        kaufpreisNetto != null &&
        nutzungsdauerJahre != null &&
        afaMethode == 'linear' &&
        anschaffungsdatum.trim().isNotEmpty &&
        DateTime.tryParse(anschaffungsdatum.trim().substring(0, 10)) != null;
  }

  /// Legacy values kept for review that were never mapped to canonical inputs.
  bool get hasUnresolvedLegacy {
    if (kaufpreisNetto != null) return false;
    return (legacyAnschaffungskosten != null && legacyAnschaffungskosten!.trim().isNotEmpty) ||
        legacyNutzungsdauer != null ||
        (legacyPrivatanteil != null && legacyPrivatanteil!.trim().isNotEmpty);
  }
}

/// Validates new-asset inputs against the maintained contract.
///
/// Returns the field name of the first invalid field, or null when valid.
String? validateNewAssetInputs({
  required String bezeichnung,
  required String? assetTyp,
  required String anschaffungsdatum,
  required String? kaufpreisNetto,
  required int? nutzungsdauerJahre,
  required String? afaMethode,
  required String? privatAnteilProzent,
}) {
  if (bezeichnung.trim().isEmpty) return 'bezeichnung';
  if (AssetTyp.fromDb(assetTyp) == null) return 'asset_typ';
  final String date = anschaffungsdatum.trim();
  final DateTime? parsed = DateTime.tryParse(date.length >= 10 ? date.substring(0, 10) : date);
  if (parsed == null || date.length < 10) return 'anschaffungsdatum';
  final double? price = double.tryParse((kaufpreisNetto ?? '').trim().replaceAll(',', '.'));
  if (price == null || price < 0) return 'kaufpreis_netto';
  if (nutzungsdauerJahre == null || nutzungsdauerJahre <= 0) return 'nutzungsdauer_jahre';
  if ((afaMethode ?? '').trim() != 'linear') return 'afa_methode';
  final double? privat = double.tryParse((privatAnteilProzent ?? '0').trim().replaceAll(',', '.'));
  if (privat == null || privat < 0 || privat > 100) return 'privat_anteil_prozent';
  final AssetTyp? type = AssetTyp.fromDb(assetTyp);
  if (type != AssetTyp.kfz && privat != 0) return 'privat_anteil_prozent';
  return null;
}
