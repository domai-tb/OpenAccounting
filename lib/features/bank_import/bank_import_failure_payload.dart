import 'dart:convert';

/// Versioned bank-import failure payloads per
/// bank-import-confidence-and-rule-workspace (design decision 6).
///
/// Row envelope: `{ "schema": "openaccounting.bank-import-failures",
/// "version": 1, "kind": "rows", "rows": [...] }`. File-rejection envelope:
/// same schema/version with `kind: "file_rejection"`, `diagnostic_codes`,
/// and no rows. Legacy JSON arrays, plain strings, and message-only objects
/// decode as invalid (visible as sanitized diagnostics, never retryable).
class BankImportFailurePayload {
  static const String schema = 'openaccounting.bank-import-failures';
  static const int version = 1;

  static const Set<String> rowKinds = <String>{'rows', 'file_rejection'};

  /// Stable row diagnostic codes (never localized text).
  static const Set<String> rowCodes = <String>{
    'invalid_date',
    'invalid_amount',
    'missing_required_data',
    'database_write_failed',
    'unknown_row_failure',
  };

  /// Stable file-rejection codes.
  static const Set<String> fileCodes = <String>{
    'empty_file',
    'unsupported_format',
    'invalid_xml',
    'missing_header',
    'no_matching_template',
    'no_transactions',
    'unknown_file_rejection',
  };

  /// Category provenance per payload row.
  static const Set<String> quellen = <String>{'keine', 'regel_vorschlag', 'benutzerentscheidung'};

  static String encodeRows(List<Map<String, Object?>> rows) {
    return jsonEncode(<String, Object?>{'schema': schema, 'version': version, 'kind': 'rows', 'rows': rows});
  }

  static String encodeFileRejection(List<String> codes) {
    final valid = codes.where(fileCodes.contains).toList(growable: false);
    return jsonEncode(<String, Object?>{
      'schema': schema,
      'version': version,
      'kind': 'file_rejection',
      'diagnostic_codes': valid.isEmpty ? <String>['unknown_file_rejection'] : valid,
    });
  }

  /// Strictly validates [raw]. Returns the decoded envelope map.
  /// Throws [BankImportPayloadException] for anything non-retryable-shaped.
  static Map<String, Object?> decodeValidated(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const BankImportPayloadException('unparseable payload');
    }
    if (decoded is! Map<String, Object?> && decoded is! Map) {
      throw const BankImportPayloadException('unsupported payload shape');
    }
    final map = Map<String, Object?>.from(decoded as Map);
    if (map['schema'] != schema || map['version'] != version) {
      throw const BankImportPayloadException('unknown payload version');
    }
    if (map['kind'] == 'rows') {
      _validateRows(map['rows']);
      return map;
    }
    if (map['kind'] == 'file_rejection') {
      final codes = map['diagnostic_codes'];
      if (codes is! List || codes.isEmpty) throw const BankImportPayloadException('invalid file rejection');
      return map;
    }
    throw const BankImportPayloadException('unknown payload kind');
  }

  static void _validateRows(Object? rows) {
    if (rows is! List || rows.isEmpty) throw const BankImportPayloadException('no retryable rows');
    for (final row in rows) {
      if (row is! Map) throw const BankImportPayloadException('invalid row');
      final m = Map<String, Object?>.from(row);
      _positiveInt(m['row']);
      _positiveInt(m['source_row']);
      if (m['datum'] != null && m['datum'] is! String) throw const BankImportPayloadException('invalid datum');
      for (final key in <String>['raw_datum', 'betrag', 'raw_betrag', 'partner', 'verwendungszweck']) {
        if (m[key] is! String) throw BankImportPayloadException('missing $key');
      }
      if (m['gegenkonto'] != null && m['gegenkonto'] is! String) {
        throw const BankImportPayloadException('invalid gegenkonto');
      }
      if (m['kategorie_id'] != null) _positiveInt(m['kategorie_id']);
      if (m['journal_id'] != null) _positiveInt(m['journal_id']);
      if (!quellen.contains(m['kategorie_quelle'])) throw const BankImportPayloadException('invalid kategorie_quelle');
      final codes = m['diagnostic_codes'];
      if (codes is! List || codes.isEmpty || !codes.every((c) => c is String && rowCodes.contains(c))) {
        throw const BankImportPayloadException('invalid diagnostic codes');
      }
    }
  }

  static void _positiveInt(Object? v) {
    if (v is! int || v <= 0) {
      if (v is num && v.toInt() == v && v.toInt() > 0) return;
      throw const BankImportPayloadException('invalid id');
    }
  }
}

class BankImportPayloadException implements Exception {
  const BankImportPayloadException(this.message);
  final String message;
  @override
  String toString() => message;
}
