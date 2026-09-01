class KundenSperrungException implements Exception {
  const KundenSperrungException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KundenSperrungStatus {
  const KundenSperrungStatus({
    required this.isWarnung,
    required this.isSperrung,
    required this.isMahngesperrt,
    required this.canCreateInvoice,
  });

  final bool isWarnung;
  final bool isSperrung;
  final bool isMahngesperrt;
  final bool canCreateInvoice;
}
