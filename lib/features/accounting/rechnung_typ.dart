// ponytail: single canonical type + helper — replaces scattered string literals.
class RechnungTyp {
  const RechnungTyp._();

  static const String rechnung = 'rechnung';
  static const String eingang = 'rechnung_eingang';

  /// Legacy value still found in dashboard queries/routes.
  static const String eingangLegacy = 'eingangsrechnung';

  static const Set<String> allowed = <String>{rechnung, eingang};

  /// Canonicalize both legacy and current incoming values to single `eingang`.
  static String canonicalize(String raw) {
    final String v = raw.trim().toLowerCase();
    if (v == eingang || v == eingangLegacy || v == 'eingang') return eingang;
    return v;
  }

  static bool isEingang(String? raw) => raw != null && canonicalize(raw) == eingang;

  static bool isInvoice(String? raw) => raw != null && allowed.contains(canonicalize(raw));

  static bool isIncomingInvoice(String? raw, {int? lieferantId}) =>
      isInvoice(raw) && (isEingang(raw) || lieferantId != null);

  // — Posting rules helper: single source for beleg/forderung derivation (no bypass of snapshot/immutable).

  /// Derive journal beleg_typ from rechnung typ + lieferant linkage.
  static String belegTypFor({required String typ, int? lieferantId}) =>
      isIncomingInvoice(typ, lieferantId: lieferantId) ? 'Ausgabe' : 'Einnahme';

  static String forderungTypFor({required String typ, int? lieferantId}) =>
      isIncomingInvoice(typ, lieferantId: lieferantId) ? eingang : rechnung;
}
