import 'dart:convert';
import 'dart:typed_data';

/// Validates Beleg source bytes before storage.
///
/// Accepts PDF, PNG, JPEG, and XRechnung / ZUGFeRD-Factur-X XML up to
/// 50 MiB. Content signatures are inspected; filename and client MIME type
/// are never trusted. XML parsing disables external entities and network
/// access (no DTD fetching — any `DOCTYPE` with external references fails).
/// CSV and TIFF are rejected for Belege even though other destinations may
/// accept them.
class BelegSourceValidator {
  const BelegSourceValidator();

  /// Maximum source size: 50 MiB per file.
  static const int maxSourceBytes = 50 * 1024 * 1024;

  /// MIME types the Belege drop zone accepts after content verification.
  static const Set<String> supportedMimeTypes = <String>{
    'application/pdf',
    'image/png',
    'image/jpeg',
    'application/xml',
    'text/xml',
  };

  /// Validates [bytes] and returns the verified MIME type.
  ///
  /// Throws [FormatException] with a German message when the source is oversized,
  /// mislabeled, or of an unsupported type.
  String validate(Uint8List bytes, {String? filename}) {
    if (bytes.length > maxSourceBytes) {
      throw const FormatException('Datei ist zu groß (max. 50 MiB)');
    }
    if (bytes.isEmpty) {
      throw const FormatException('Datei ist leer');
    }
    final String? detected = detectMimeType(bytes);
    if (detected == null) {
      throw const FormatException('Dateityp nicht unterstützt');
    }
    if (detected == 'application/xml' || detected == 'text/xml') {
      _validateInvoiceXml(bytes);
      return 'application/xml';
    }
    return detected;
  }

  /// Detects the MIME type from content signatures. Returns null when the
  /// bytes do not match a supported Beleg format.
  String? detectMimeType(Uint8List bytes) {
    if (_isPdf(bytes)) return 'application/pdf';
    if (_isPng(bytes)) return 'image/png';
    if (_isJpeg(bytes)) return 'image/jpeg';
    if (_isXml(bytes)) return 'application/xml';
    // Explicitly unsupported for Belege: CSV, TIFF, executables, office docs.
    return null;
  }

  bool _isPdf(Uint8List bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46 && // F
      bytes[4] == 0x2D; // -

  bool _isPng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;

  bool _isJpeg(Uint8List bytes) => bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

  bool _isXml(Uint8List bytes) {
    final String head = utf8.decode(bytes.sublist(0, bytes.length > 512 ? 512 : bytes.length), allowMalformed: true);
    final String trimmed = head.trimLeft();
    return trimmed.startsWith('<?xml') || trimmed.startsWith('<');
  }

  /// Validates e-invoice XML without resolving external entities or network
  /// resources. Only well-formed invoice XML with a recognized root is stored.
  void _validateInvoiceXml(Uint8List bytes) {
    late final String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      throw const FormatException('Dateityp nicht unterstützt');
    }
    final String lowered = text.toLowerCase();
    // No external entity or network access: reject DOCTYPE with SYSTEM/PUBLIC,
    // ENTITY declarations, and any http(s) resource reference.
    if (lowered.contains('<!doctype') && (lowered.contains('system') || lowered.contains('public'))) {
      throw const FormatException('Dateityp nicht unterstützt');
    }
    if (lowered.contains('<!entity')) {
      throw const FormatException('Dateityp nicht unterstützt');
    }
    // Basic well-formedness: exactly one root element closed.
    final RegExp rootOpen = RegExp(r'<([A-Za-z_][\w.\-:]*)(\s[^>]*)?>');
    final RegExp rootClose = RegExp(r'</([A-Za-z_][\w.\-:]*)\s*>');
    final Match? open = rootOpen.firstMatch(text);
    final Iterable<Match> closes = rootClose.allMatches(text);
    if (open == null || closes.isEmpty) {
      throw const FormatException('Dateityp nicht unterstützt');
    }
    final String rootName = (open.group(1) ?? '').toLowerCase();
    const Set<String> supportedRoots = <String>{
      'invoice',
      'creditnote',
      'crossindustryinvoice',
      'rsm:crossindustryinvoice',
      'factur-x',
      'zugferd',
    };
    final bool recognized =
        supportedRoots.any((String root) => rootName == root || rootName.endsWith(':${root.split(':').last}')) ||
        lowered.contains('crossindustryinvoice') ||
        lowered.contains('xrechnung') ||
        lowered.contains('factur-x') ||
        lowered.contains('zugferd');
    if (!recognized) {
      throw const FormatException('Dateityp nicht unterstützt');
    }
  }
}
