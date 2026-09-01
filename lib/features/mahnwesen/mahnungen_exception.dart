class MahnungException implements Exception {
  const MahnungException(this.message);

  final String message;

  @override
  String toString() => message;
}
