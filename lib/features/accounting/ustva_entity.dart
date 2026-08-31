/// UStVA result per spec §UStVA — KZ map String->String money.
/// ponytail: immutable, string money keeps NUMERIC(12,2) precision, pure map.
class UstvaResult {
  const UstvaResult({required this.jahr, required this.monatOrQuartal, required this.rhythmus, required this.kz});

  final int jahr;
  final int monatOrQuartal;
  final String rhythmus;

  /// KZ → Betrag '0.00' (cents string, 2 decimals).
  final Map<String, String> kz;

  String kzValue(String key) => kz[key] ?? '0.00';

  String get kz1 => kz['1'] ?? '0.00';
  String get kz3 => kz['3'] ?? '0.00';
  String get kz4 => kz['4'] ?? '0.00';
  String get kz18 => kz['18'] ?? '0.00';
  String get kz61 => kz['61'] ?? '0.00';
  String get kz66 => kz['66'] ?? '0.00';
  String get kz81 => kz['81'] ?? '0.00';
  String get kz83 => kz['83'] ?? '0.00';
  String get kz89 => kz['89'] ?? '0.00';
  String get kz93 => kz['93'] ?? '0.00';
}
