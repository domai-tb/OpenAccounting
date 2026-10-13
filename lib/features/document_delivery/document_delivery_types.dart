// Shared document-email value types: single source for supported types,
// placeholder allowlist, mailbox/header validation, and typed failures.
class DocumentDeliveryException implements Exception {
  const DocumentDeliveryException(this.message, {this.code = 'unbekannt'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// First-release document types with a production detail route and a
/// persisted generated artifact provider.
class DocumentEmailType {
  const DocumentEmailType._();

  static const String rechnung = 'rechnung';
  static const String angebot = 'angebot';
  static const String auftrag = 'auftrag';
  static const String proforma = 'proforma';

  /// Deferred: no first-release send or template action.
  static const String lieferschein = 'lieferschein';
  static const String mahnung = 'mahnung';

  static const Set<String> supported = <String>{rechnung, angebot, auftrag, proforma};

  static const Set<String> deferred = <String>{lieferschein, mahnung};

  static bool isSupported(String raw) => supported.contains(raw.trim().toLowerCase());

  static bool isDeferred(String raw) => deferred.contains(raw.trim().toLowerCase());
}

/// Finite template placeholder allowlist. Each token resolves only from a
/// typed source value; unknown or unavailable tokens block send preparation.
class EmailPlaceholders {
  const EmailPlaceholders._();

  static const String dokumentnummer = '{dokumentnummer}';
  static const String betrag = '{betrag}';
  static const String faelligkeit = '{faelligkeit}';
  static const String firma = '{firma}';

  static const Set<String> allowed = <String>{dokumentnummer, betrag, faelligkeit, firma};

  static final RegExp tokenPattern = RegExp(r'\{[A-Za-zäöüÄÖÜß]+\}');
}

/// Outcome of one user-confirmed send attempt. `accepted` means the SMTP
/// server returned its successful final response; it never means delivered.
class EmailAttemptOutcome {
  const EmailAttemptOutcome._();

  static const String submitting = 'submitting';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String unknown = 'unknown';
}

/// Safe SMTP failure categories: never include credentials or bodies.
class SmtpFailureKind {
  const SmtpFailureKind._();

  static const String hostUnreachable = 'host_unreachable';
  static const String tls = 'tls';
  static const String auth = 'auth';
  static const String rejected = 'rejected';
  static const String ambiguous = 'ambiguous';
}

/// Parses exactly one mailbox; rejects CR/LF, lists, and malformed values
/// before any MIME header is constructed.
String parseSingleMailbox(String raw, {required String field}) {
  final String value = raw.trim();
  if (value.isEmpty) {
    throw DocumentDeliveryException('$field ist Pflicht', code: 'adresse_leer');
  }
  if (value.contains('\r') || value.contains('\n')) {
    throw DocumentDeliveryException('$field darf keinen Zeilenumbruch enthalten', code: 'kopfzeilenumbruch');
  }
  if (value.contains(',') || value.contains(';')) {
    throw DocumentDeliveryException('$field muss genau eine Adresse enthalten', code: 'adresse_mehrfach');
  }
  final List<String> parts = value.split(' ');
  if (parts.length != 1 || !_mailboxPattern.hasMatch(value)) {
    throw DocumentDeliveryException('$field ist keine gültige E-Mail-Adresse', code: 'adresse_ungueltig');
  }
  return value;
}

final RegExp _mailboxPattern = RegExp(r"^[^\s@',;]+@[^\s@',;]+\.[^\s@',;]+$");

/// Rejects CR/LF in header-bound values; body newlines stay plain text.
String requireHeaderLine(String raw, {required String field}) {
  if (raw.contains('\r') || raw.contains('\n')) {
    throw DocumentDeliveryException('$field darf keinen Zeilenumbruch enthalten', code: 'kopfzeilenumbruch');
  }
  return raw;
}
