class MahnstufeException implements Exception {
  const MahnstufeException(this.message);

  final String message;

  @override
  String toString() => message;
}
