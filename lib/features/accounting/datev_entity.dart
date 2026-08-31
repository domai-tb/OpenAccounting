/// DATEV EXTF entity per spec §DATEV EXTF Export.
/// ponytail: minimal exception, string money keeps NUMERIC(12,2) precision.
class DatevException implements Exception {
  const DatevException(this.message);

  final String message;

  @override
  String toString() => message;
}
