import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

/// BankImportService — upload step only (parse, no DB import).
/// ponytail ultra: stdlib split + regex ceiling, no csv package.
class BankImportService {
  BankImportService(this.executor);

  final QueryExecutor executor;

  /// Predefined templates via in-code map + DB fallback.
  List<BankTemplate> get predefinedTemplates => BankTemplate.predefined;

  Future<List<BankTemplate>> loadTemplates() async {
    final List<BankTemplate> merged = <BankTemplate>[...BankTemplate.predefined];
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id, name, typ, konfiguration FROM bank_templates ORDER BY id',
        const <Object?>[],
      );
      for (final row in rows) {
        final BankTemplate tpl = BankTemplate.fromRow(row);
        final int idx = merged.indexWhere((t) => t.typ.toLowerCase() == tpl.typ.toLowerCase());
        if (idx >= 0) {
          merged[idx] = tpl;
        } else {
          merged.add(tpl);
        }
      }
    } catch (_) {
      // ponytail: DB missing — fallback to in-code map.
    }
    return merged;
  }

  /// Parse CSV into RawTx — delimiter from template or auto-detect.
  /// Throws [BankImportException] on invalid file / no template match.
  List<RawTx> parseCsv({required String csv, BankTemplate? template}) {
    final String trimmed = csv.trim();
    if (trimmed.isEmpty) {
      throw const BankImportException('Datei ist leer');
    }
    // Normalize BOM.
    String normalized = csv;
    if (normalized.isNotEmpty && normalized.codeUnitAt(0) == 0xFEFF) {
      normalized = normalized.substring(1);
    }
    final List<String> rawLines = normalized.split(RegExp(r'\r?\n'));
    // Find first non-empty line as header.
    int headerIdx = -1;
    String? headerLine;
    for (int i = 0; i < rawLines.length; i++) {
      final String line = rawLines[i].trim();
      if (line.isEmpty) continue;
      headerIdx = i;
      headerLine = rawLines[i];
      break;
    }
    if (headerIdx == -1 || headerLine == null) {
      throw const BankImportException('Datei enthält keine Kopfzeile');
    }
    // Header must not be BOM-only.
    headerLine = headerLine.trim();
    if (headerLine.startsWith('\uFEFF')) {
      headerLine = headerLine.substring(1);
    }
    final String delimiter = template?.delimiter ?? _detectDelimiter(headerLine);
    final List<String> headerCols = _splitCsvLine(headerLine, delimiter);
    if (headerCols.isEmpty || headerCols.every((c) => c.trim().isEmpty)) {
      throw const BankImportException('Datei enthält keine Kopfzeile');
    }

    // Build column index map via template mapping + alias fallback.
    final Map<String, String> mapping = template?.fieldMapping ?? const <String, String>{};

    final int? idxDatum = _findIdx(headerCols, 'datum', mapping);
    final int? idxBetrag = _findIdx(headerCols, 'betrag', mapping);
    final int? idxVerwend = _findIdx(headerCols, 'verwendungszweck', mapping);
    final int? idxPartner = _findIdx(headerCols, 'partner', mapping);
    final int? idxGegen = _findIdx(headerCols, 'gegenkonto', mapping);

    if (idxDatum == null || idxBetrag == null) {
      throw const BankImportException('Kein passendes Template gefunden. Bitte wählen Sie ein Template.');
    }

    final List<RawTx> out = <RawTx>[];
    for (int i = headerIdx + 1; i < rawLines.length; i++) {
      final String line = rawLines[i];
      if (line.trim().isEmpty) continue;
      final List<String> cols = _splitCsvLine(line, delimiter);
      // Skip rows where all cols empty.
      if (cols.every((c) => c.trim().isEmpty)) continue;
      // If row has fewer columns than header, pad with empty.
      // If more, truncate to header length — preserve logical idx access.
      final String datumRaw = idxDatum < cols.length ? cols[idxDatum].trim() : '';
      final String betragRaw = idxBetrag < cols.length ? cols[idxBetrag].trim() : '';
      if (datumRaw.isEmpty && betragRaw.isEmpty) continue;
      if (datumRaw.isEmpty) {
        throw BankImportException('Datum fehlt in Zeile ${i + 1}');
      }
      if (betragRaw.isEmpty) {
        throw BankImportException('Betrag fehlt in Zeile ${i + 1}');
      }
      final DateTime datum = _parseDate(datumRaw, template?.dateFormat);
      final String betrag = _parseBetrag(betragRaw);

      String verwendungszweck = '';
      if (idxVerwend != null && idxVerwend < cols.length) {
        verwendungszweck = cols[idxVerwend].trim();
      }
      String partner = '';
      if (idxPartner != null && idxPartner < cols.length) {
        partner = cols[idxPartner].trim();
      }
      String? gegenkonto;
      if (idxGegen != null && idxGegen < cols.length) {
        final String g = cols[idxGegen].trim();
        if (g.isNotEmpty) gegenkonto = g;
      }

      out.add(
        RawTx(
          datum: datum,
          betrag: betrag,
          verwendungszweck: verwendungszweck,
          partner: partner,
          gegenkonto: gegenkonto,
        ),
      );
    }

    if (out.isEmpty) {
      // ponytail: empty file after header — treat as invalid for upload step.
      // Spec zero-transaction summary belongs to import step, not upload parse.
      // For upload, surface as template/parse error to block advancement.
      throw const BankImportException(
        'Keine Transaktionen gefunden. Kein passendes Template gefunden. Bitte wählen Sie ein Template.',
      );
    }
    return out;
  }

  String _detectDelimiter(String headerLine) {
    final int semicolon = _countOutsideQuotes(headerLine, ';');
    final int comma = _countOutsideQuotes(headerLine, ',');
    if (semicolon == 0 && comma == 0) {
      throw const BankImportException('Kein passendes Template gefunden. Bitte wählen Sie ein Template.');
    }
    return semicolon >= comma ? ';' : ',';
  }

  int _countOutsideQuotes(String line, String delimiter) {
    int count = 0;
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final String ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delimiter && !inQuotes) {
        count++;
      }
    }
    return count;
  }

  // ponytail: regex ceiling — alias map covers Sparkasse/PayPal/N26 etc without xml dep.
  static const Map<String, List<String>> _aliases = <String, List<String>>{
    'datum': <String>['datum', 'buchungstag', 'valuta', 'date', 'buchung', 'wertstellung', 'datum valuta'],
    'betrag': <String>['betrag', 'amount', 'summe', 'umsatz', 'value', 'betrag (eur)'],
    'verwendungszweck': <String>[
      'verwendungszweck',
      'zweck',
      'reference',
      'description',
      'notiz',
      'memo',
      'buchungstext',
      'verwendung',
      'verwendungszweck ',
    ],
    'partner': <String>[
      'partner',
      'empfänger',
      'empfaenger',
      'auftraggeber',
      'begünstigter',
      'beguenstigter',
      'zahlungspflichtiger',
      'name',
      'recipient',
      'payer',
      'auftraggeber/empfänger',
      'begünstigter/zahlungspflichtiger',
      'partner name',
    ],
    'gegenkonto': <String>['gegenkonto', 'konto', 'iban', 'gegenkonto/iban', 'kontonummer'],
  };

  int? _findIdx(List<String> headers, String logical, Map<String, String> mapping) {
    final String? mapped = mapping[logical];
    if (mapped != null && mapped.trim().isNotEmpty) {
      final String lowerMapped = mapped.toLowerCase().trim();
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].toLowerCase().trim() == lowerMapped) return i;
      }
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].toLowerCase().contains(lowerMapped)) return i;
      }
    }
    final List<String> aliases = _aliases[logical] ?? <String>[];
    // Exact alias match first.
    for (int i = 0; i < headers.length; i++) {
      final String h = headers[i].toLowerCase().trim();
      for (final alias in aliases) {
        if (h == alias) return i;
      }
    }
    // Contains alias match.
    for (int i = 0; i < headers.length; i++) {
      final String h = headers[i].toLowerCase().trim();
      for (final alias in aliases) {
        if (h.contains(alias)) return i;
      }
    }
    return null;
  }

  List<String> _splitCsvLine(String line, String delimiter) {
    final List<String> result = <String>[];
    final StringBuffer cur = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final String ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delimiter && !inQuotes) {
        result.add(_unquote(cur.toString()));
        cur.clear();
      } else {
        cur.write(ch);
      }
    }
    result.add(_unquote(cur.toString()));
    return result;
  }

  String _unquote(String raw) {
    String t = raw.trim();
    if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) {
      t = t.substring(1, t.length - 1).replaceAll('""', '"');
    }
    return t.trim();
  }

  DateTime _parseDate(String raw, String? templateFormat) {
    String t = raw.trim();
    // Strip time part if present.
    if (t.contains('T')) t = t.split('T').first.trim();
    if (t.contains(' ')) t = t.split(' ').first.trim();
    // Remove surrounding quotes already done.
    // Prefer templateFormat hint.
    if (templateFormat != null) {
      final String fmt = templateFormat.toLowerCase();
      if (fmt.contains('dd.mm.yyyy') || fmt.contains('dd.mm.yyy')) {
        final DateTime? d = _tryDdMmYyyy(t);
        if (d != null) return d;
      }
      if (fmt.contains('yyyy-mm-dd')) {
        final DateTime? d = _tryIso(t);
        if (d != null) return d;
      }
    }
    // Fallback: try all parsers.
    DateTime? d = _tryDdMmYyyy(t);
    if (d != null) return d;
    d = _tryIso(t);
    if (d != null) return d;
    d = _trySlash(t);
    if (d != null) return d;
    // Last resort: DateTime.tryParse handles yyyy-mm-dd
    final DateTime? parsed = DateTime.tryParse(t);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
    throw BankImportException('Datum ungültig: $raw');
  }

  DateTime? _tryDdMmYyyy(String t) {
    // Supports DD.MM.YYYY or D.M.YYYY or DD.MM.YY
    if (!t.contains('.')) return null;
    final List<String> parts = t.split('.');
    if (parts.length != 3) return null;
    final String dRaw = parts[0].trim();
    final String mRaw = parts[1].trim();
    final String yRaw = parts[2].trim();
    if (dRaw.isEmpty || mRaw.isEmpty || yRaw.isEmpty) return null;
    final int? d = int.tryParse(dRaw);
    final int? m = int.tryParse(mRaw);
    int? y = int.tryParse(yRaw);
    if (d == null || m == null || y == null) return null;
    if (y < 100) y += 2000;
    if (y < 1000 || y > 9999) return null;
    if (m < 1 || m > 12) return null;
    if (d < 1 || d > 31) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  DateTime? _tryIso(String t) {
    if (!t.contains('-')) return null;
    final List<String> parts = t.split('-');
    if (parts.length != 3) return null;
    // Heuristic: first part 4 digits => yyyy-mm-dd
    if (parts[0].length != 4) return null;
    final int? y = int.tryParse(parts[0].trim());
    final int? m = int.tryParse(parts[1].trim());
    final int? d = int.tryParse(parts[2].trim());
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  DateTime? _trySlash(String t) {
    if (!t.contains('/')) return null;
    final List<String> parts = t.split('/');
    if (parts.length != 3) return null;
    // Assume DD/MM/YYYY if first <=31 and second <=12, else MM/DD/YYYY fallback
    final int? a = int.tryParse(parts[0].trim());
    final int? b = int.tryParse(parts[1].trim());
    final int? y = int.tryParse(parts[2].trim());
    if (a == null || b == null || y == null) return null;
    int d, m;
    if (a <= 31 && b <= 12) {
      // Ambiguous — prefer DD/MM if alias? Use DD/MM.
      d = a;
      m = b;
    } else {
      d = b;
      m = a;
    }
    int yy = y;
    if (yy < 100) yy += 2000;
    try {
      return DateTime(yy, m, d);
    } catch (_) {
      return null;
    }
  }

  String _parseBetrag(String raw) {
    String t = raw.trim();
    // Remove common currency noise.
    t = t.replaceAll('€', '').replaceAll('EUR', '').replaceAll('eur', '').trim();
    t = t.replaceAll('\u00A0', '').replaceAll(' ', '').replaceAll("'", '').trim();
    if (t.isEmpty) throw const BankImportException('Betrag fehlt');
    final bool isNeg = t.startsWith('-');
    final bool isPos = t.startsWith('+');
    String unsigned = t;
    if (isNeg || isPos) unsigned = t.substring(1);
    if (unsigned.isEmpty) throw BankImportException('Betrag ungültig: $raw');
    // Normalize thousand/decimal.
    if (unsigned.contains('.') && unsigned.contains(',')) {
      final int lastDot = unsigned.lastIndexOf('.');
      final int lastComma = unsigned.lastIndexOf(',');
      if (lastComma > lastDot) {
        unsigned = unsigned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        unsigned = unsigned.replaceAll(',', '');
      }
    } else if (unsigned.contains(',')) {
      unsigned = unsigned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Only dots or none.
      if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(unsigned)) {
        unsigned = unsigned.replaceAll('.', '');
      }
    }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(unsigned)) {
      throw BankImportException('Betrag ungültig: $raw');
    }
    final String normalized = isNeg ? '-$unsigned' : unsigned;
    // Range check before cents conversion: integer part <=10 digits, < 10^10.
    final List<String> parts = normalized.replaceFirst('-', '').split('.');
    final String intRaw = parts[0].isEmpty ? '0' : parts[0];
    final String intNoLead = intRaw.replaceFirst(RegExp('^0+'), '');
    final String effInt = intNoLead.isEmpty ? '0' : intNoLead;
    if (effInt.length > 10) {
      throw BankImportException('Betrag außerhalb NUMERIC(12,2): $raw');
    }
    if (effInt.length == 10 && effInt.compareTo('9999999999') > 0) {
      throw BankImportException('Betrag außerhalb NUMERIC(12,2): $raw');
    }
    // Use money helpers for cents truncation/padding to 2 decimals.
    final int cents = money.toCents(normalized);
    return money.fromCents(cents);
  }
}
