import 'dart:convert';

class Mahnung {
  const Mahnung({
    required this.id,
    required this.rechnungId,
    this.kundeId,
    this.stufeId,
    required this.datum,
    required this.betrag,
    required this.gebuehr,
    required this.zinsen,
    required this.status,
    this.snapshot,
    required this.gebuehrBezahlt,
    required this.gebuehrUnbezahlt,
    required this.zinsenBezahlt,
    required this.zinsenUnbezahlt,
    required this.uebernommeneGebuehr,
    required this.uebernommeneZinsen,
    this.versendetAm,
  });

  final int id;
  final int rechnungId;
  final int? kundeId;
  final int? stufeId;
  final String datum;
  final String betrag;
  final String gebuehr;
  final String zinsen;
  final String status;
  final String? snapshot;
  final String gebuehrBezahlt;
  final String gebuehrUnbezahlt;
  final String zinsenBezahlt;
  final String zinsenUnbezahlt;
  final String uebernommeneGebuehr;
  final String uebernommeneZinsen;
  final String? versendetAm;

  /// Parsed snapshot json if present.
  Map<String, dynamic>? get snapshotData {
    final s = snapshot;
    if (s == null || s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Total carried amount (geführt über vorherige Mahnungen).
  String get carriedTotal {
    // ponytail: minimal compute, reuse money helpers via toCents if needed — caller can sum.
    // Kept as string sum for test convenience without extra import.
    final g = num.tryParse(uebernommeneGebuehr) ?? 0;
    final z = num.tryParse(uebernommeneZinsen) ?? 0;
    return (g + z).toStringAsFixed(2);
  }
}
