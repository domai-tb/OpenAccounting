import 'dart:convert';

import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';

/// Bounded local CSV parser. No delimiter/header guessing: the caller selects
/// comma, semicolon, or tab and whether the first row is a header.
/// Accepts UTF-8 with optional BOM; preserves inert cell values as-is.
class MasterDataCsvParser {
  static const int maxBytes = 20 * 1024 * 1024;
  static const int maxDataRows = 50000;

  static String delimiterChar(CsvImportDelimiter delimiter) {
    switch (delimiter) {
      case CsvImportDelimiter.comma:
        return ',';
      case CsvImportDelimiter.semicolon:
        return ';';
      case CsvImportDelimiter.tab:
        return '\t';
    }
  }

  /// Parses selected file bytes. Throws [MasterDataCsvParseException] for
  /// size, row, encoding, quoting, or column-count failures.
  static MasterDataParsedCsv parseBytes(
    List<int> bytes, {
    required CsvImportDelimiter delimiter,
    required bool hasHeader,
  }) {
    if (bytes.length > maxBytes) {
      throw const MasterDataCsvParseException('Datei überschreitet 20 MiB; kein Datensatz wurde geschrieben.');
    }
    late final String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      throw const MasterDataCsvParseException('Nicht unterstützte Kodierung; nur UTF-8 wird unterstützt.');
    }
    return parseText(text, delimiter: delimiter, hasHeader: hasHeader);
  }

  static MasterDataParsedCsv parseText(String text, {required CsvImportDelimiter delimiter, required bool hasHeader}) {
    String normalized = text;
    if (normalized.isNotEmpty && normalized.codeUnitAt(0) == 0xFEFF) {
      normalized = normalized.substring(1);
    }
    if (normalized.trim().isEmpty) {
      throw const MasterDataCsvParseException('Datei ist leer; kein Datensatz wurde geschrieben.');
    }
    final String sep = delimiterChar(delimiter);
    final List<List<String>> records = _parseRecords(normalized, sep);
    if (records.isEmpty || records.every((r) => r.every((c) => c.trim().isEmpty))) {
      throw const MasterDataCsvParseException('Datei ist leer; kein Datensatz wurde geschrieben.');
    }
    // Column-count check: every non-empty record must share the first
    // non-empty record width; otherwise the column mapping is ambiguous.
    int? width;
    for (final List<String> record in records) {
      if (record.every((c) => c.trim().isEmpty)) continue;
      if (width == null) {
        width = record.length;
      } else if (record.length != width) {
        throw const MasterDataCsvParseException('Uneinheitliche Spaltenzahl; kein Datensatz wurde geschrieben.');
      }
    }
    final List<List<String>> nonEmpty = <List<String>>[
      for (final List<String> r in records)
        if (r.any((c) => c.trim().isNotEmpty)) r,
    ];
    List<String>? header;
    int dataStart = 0;
    if (hasHeader) {
      header = nonEmpty.first;
      dataStart = 1;
    }
    final List<MasterDataCsvRow> rows = <MasterDataCsvRow>[];
    // Preserve original 1-based file row numbers across quoted line breaks:
    // track record start lines while scanning.
    final List<int> recordStartLines = _recordStartLines(normalized, sep);
    // recordStartLines aligns with `records` including empty ones; rebuild
    // mapping for non-empty records only.
    final List<int> nonEmptyStartLines = <int>[];
    for (int i = 0; i < records.length; i++) {
      if (records[i].any((c) => c.trim().isNotEmpty)) {
        nonEmptyStartLines.add(i < recordStartLines.length ? recordStartLines[i] : i + 1);
      }
    }
    for (int i = dataStart; i < nonEmpty.length; i++) {
      final int fileRow = i < nonEmptyStartLines.length ? nonEmptyStartLines[i] : i + 1;
      rows.add(MasterDataCsvRow(sourceRowNumber: fileRow, cells: nonEmpty[i]));
    }
    if (rows.length > maxDataRows) {
      throw const MasterDataCsvParseException('Datei überschreitet 50.000 Zeilen; kein Datensatz wurde geschrieben.');
    }
    return MasterDataParsedCsv(header: header, rows: rows, totalDataRows: rows.length);
  }

  /// Standard quoted-field grammar: quoted delimiters, escaped "" quotes,
  /// and quoted line breaks. Bare quotes inside unquoted cells and unterminated
  /// quotes are malformed.
  static List<List<String>> _parseRecords(String text, String sep) {
    final List<List<String>> records = <List<String>>[];
    List<String> current = <String>[];
    final StringBuffer cell = StringBuffer();
    bool inQuotes = false;
    bool cellQuoted = false;
    bool cellHasContent = false;
    bool justClosedQuote = false;
    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
            justClosedQuote = true;
          }
        } else {
          cell.write(ch);
        }
        continue;
      }
      if (justClosedQuote) {
        // After a closing quote only the delimiter, a line break, or EOF
        // may follow; anything else is malformed quoting.
        if (ch == sep || ch == '\r' || ch == '\n') {
          justClosedQuote = false;
        } else {
          throw const MasterDataCsvParseException('Fehlerhafte Anführungszeichen; kein Datensatz wurde geschrieben.');
        }
      }
      if (ch == '"') {
        if (!cellHasContent && cell.isEmpty) {
          inQuotes = true;
          cellQuoted = true;
        } else {
          throw const MasterDataCsvParseException('Fehlerhafte Anführungszeichen; kein Datensatz wurde geschrieben.');
        }
        cellHasContent = true;
        continue;
      }
      if (ch == sep) {
        current.add(cell.toString());
        cell.clear();
        cellQuoted = false;
        cellHasContent = false;
        continue;
      }
      if (ch == '\r' || ch == '\n') {
        // CRLF counts once.
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        current.add(cell.toString());
        cell.clear();
        cellQuoted = false;
        cellHasContent = false;
        records.add(current);
        current = <String>[];
        continue;
      }
      cell.write(ch);
      if (ch.trim().isNotEmpty) cellHasContent = true;
    }
    if (inQuotes) {
      throw const MasterDataCsvParseException('Fehlerhafte Anführungszeichen; kein Datensatz wurde geschrieben.');
    }
    // Trailing content without a line break still forms a record.
    if (cell.isNotEmpty || cellQuoted || current.isNotEmpty) {
      current.add(cell.toString());
      records.add(current);
    }
    return records;
  }

  static List<int> _recordStartLines(String text, String sep) {
    final List<int> starts = <int>[];
    int line = 1;
    bool inQuotes = false;
    bool atRecordStart = true;
    for (int i = 0; i < text.length; i++) {
      if (atRecordStart) {
        starts.add(line);
        atRecordStart = false;
      }
      final String ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            i++;
          } else {
            inQuotes = false;
          }
        } else if (ch == '\n') {
          line++;
        } else if (ch == '\r') {
          line++;
          if (i + 1 < text.length && text[i + 1] == '\n') i++;
        }
        continue;
      }
      if (ch == '"') {
        inQuotes = true;
        continue;
      }
      if (ch == '\r' || ch == '\n') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        line++;
        atRecordStart = true;
      }
    }
    return starts;
  }
}

/// Strict decimal grammar per spec: after outer trim, one or more ASCII
/// digits with an optional single selected separator between non-empty digit
/// runs. Integers are valid under either convention. No grouping, exponents,
/// signs, alternate separators, inner whitespace, or partial numbers.
class MasterDataNumericParser {
  static final RegExp _point = RegExp(r'^[0-9]+(?:[.][0-9]+)?$');
  static final RegExp _comma = RegExp(r'^[0-9]+(?:,[0-9]+)?$');

  /// Returns the normalized dot-decimal string, or null when invalid.
  /// Empty/blank input is null (caller decides required vs. preserve-on-blank).
  static String? tryNormalize(String raw, CsvDecimalConvention convention) {
    final String token = raw.trim();
    if (token.isEmpty) return null;
    final bool ok = convention == CsvDecimalConvention.point ? _point.hasMatch(token) : _comma.hasMatch(token);
    if (!ok) return null;
    if (convention == CsvDecimalConvention.comma) return token.replaceAll(',', '.');
    return token;
  }

  static num? tryParse(String raw, CsvDecimalConvention convention) {
    final String? normalized = tryNormalize(raw, convention);
    if (normalized == null) return null;
    return num.tryParse(normalized);
  }

  /// Exact duplicate comparison for numeric values under one convention.
  /// Returns null when either side is not a valid token under [convention].
  static bool? exactEquals(String a, String b, CsvDecimalConvention convention) {
    final String? na = tryNormalize(a, convention);
    final String? nb = tryNormalize(b, convention);
    if (na == null || nb == null) return null;
    final num? pa = num.tryParse(na);
    final num? pb = num.tryParse(nb);
    if (pa == null || pb == null) return null;
    return pa == pb;
  }
}
