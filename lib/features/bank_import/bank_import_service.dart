import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

/// BankImportService — upload + dedup + auto-rules + score.
/// ponytail ultra: stdlib split + crypto SHA256 + string money, no csv/xml deps.
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

  // ── Dedup ──────────────────────────────────────────────────────────

  /// SHA-256 hex of Datum|Betrag|Partner|Verwendungszweck.
  /// Datum formatted YYYY-MM-DD, betrag trimmed, partner/verwendung trimmed.
  String computeDedupeHash(DateTime datum, String betrag, String partner, String verwendungszweck) {
    final String dateStr =
        '${datum.year.toString().padLeft(4, '0')}-'
        '${datum.month.toString().padLeft(2, '0')}-'
        '${datum.day.toString().padLeft(2, '0')}';
    final String input = '$dateStr|${betrag.trim()}|${partner.trim()}|${verwendungszweck.trim()}';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Auto-categorization: first active rule whose muster is substring of
  /// verwendungszweck (case-insensitive), ordered by prioritaet DESC.
  Future<int?> applyRules(String verwendungszweck) async {
    final String trimmed = verwendungszweck.trim();
    if (trimmed.isEmpty) return null;
    final String lower = trimmed.toLowerCase();
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT muster, kategorie_id FROM auto_filter_regeln WHERE aktiv = 1 ORDER BY prioritaet DESC, id ASC',
        const <Object?>[],
      );
      for (final row in rows) {
        final String muster = (row['muster'] as String? ?? '').trim();
        if (muster.isEmpty) continue;
        if (lower.contains(muster.toLowerCase())) {
          final Object? kid = row['kategorie_id'];
          if (kid == null) continue;
          return (kid as num).toInt();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  // ── Score ──────────────────────────────────────────────────────────

  /// Score 0..100 between [tx] and a journal row.
  /// Discrete 40/30/30: amount within 0.01 => 40, date within 7d => 30, partner similarity >80% => 30.
  /// Threshold 90 requires all three (ponytail: no partial auto-book, conservative by design).
  int computeScore(RawTx tx, Map<String, Object?> journalRow) {
    final String jBetragRaw = _journalBetrag(journalRow);
    final DateTime? jDatum = _journalDatum(journalRow);
    final String jPartner = _journalPartner(journalRow);

    int score = 0;

    // Amount: within 0.01 => 40 (string money via money.toCents)
    try {
      final int txCents = money.toCents(tx.betrag);
      final int jCents = money.toCents(jBetragRaw);
      if ((txCents - jCents).abs() <= 1) {
        score += 40;
      }
    } catch (_) {}

    // Date: within 7 days => 30
    if (jDatum != null) {
      final int diffDays = tx.datum.difference(jDatum).inDays.abs();
      if (diffDays <= 7) score += 30;
    }

    // Partner: similarity >80% => 30
    final double sim = _partnerSimilarity(tx.partner, jPartner);
    if (sim > 0.80) score += 30;

    return score.clamp(0, 100);
  }

  String _journalBetrag(Map<String, Object?> row) {
    final Object? v = row['betrag'];
    if (v == null) return '0.00';
    if (v is num) return v.toStringAsFixed(2);
    final String s = v.toString().trim();
    if (s.isEmpty) return '0.00';
    // Normalize via money helpers if possible
    try {
      return money.fromCents(money.toCents(s));
    } catch (_) {
      return s;
    }
  }

  DateTime? _journalDatum(Map<String, Object?> row) {
    final Object? v = row['datum'];
    if (v == null) return null;
    final String s = v.toString().trim();
    if (s.isEmpty) return null;
    // Try ISO YYYY-MM-DD or full iso
    final DateTime? d = DateTime.tryParse(s);
    if (d != null) return DateTime(d.year, d.month, d.day);
    // Try DD.MM.YYYY fallback
    if (s.contains('.')) {
      final List<String> p = s.split('.');
      if (p.length == 3) {
        final int? day = int.tryParse(p[0].trim());
        final int? mon = int.tryParse(p[1].trim());
        final int? yr = int.tryParse(p[2].trim());
        if (day != null && mon != null && yr != null) {
          try {
            return DateTime(yr, mon, day);
          } catch (_) {}
        }
      }
    }
    return null;
  }

  String _journalPartner(Map<String, Object?> row) {
    // Prefer beschreibung, fallback name-like fields
    for (final String k in <String>['beschreibung', 'partner', 'name', 'empfaenger', 'beleg_nr']) {
      final Object? v = row[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  double _partnerSimilarity(String a, String b) {
    final String la = a.trim().toLowerCase();
    final String lb = b.trim().toLowerCase();
    if (la.isEmpty || lb.isEmpty) return 0;
    if (la == lb) return 1;
    if (la.contains(lb) || lb.contains(la)) return 0.90;
    final int maxLen = la.length > lb.length ? la.length : lb.length;
    if (maxLen == 0) return 0;
    final int dist = _levenshtein(la, lb);
    return (maxLen - dist) / maxLen;
  }

  int _levenshtein(String s, String t) {
    final int m = s.length;
    final int n = t.length;
    if (m == 0) return n;
    if (n == 0) return m;
    List<int> prev = List<int>.generate(n + 1, (i) => i);
    List<int> curr = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final int cost = s.codeUnitAt(i - 1) == t.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = _min3(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost);
      }
      final List<int> tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  int _min3(int a, int b, int c) {
    final int m = a < b ? a : b;
    return m < c ? m : c;
  }

  // ── Import ─────────────────────────────────────────────────────────

  static const String _historyInProgressStatus = 'in_bearbeitung';
  static const String _historyImportedStatus = 'importiert';
  static const String _historyPartialStatus = 'teilweise';
  static const String _historyFailedStatus = 'fehlgeschlagen';

  /// Import [rawTxs] for [kontoId] with dedup + auto-rules + score.
  /// [mode] = 'manuell' | 'automatisch' — automatisch auto-books high-score matches.
  /// When [allowDuplicateOverride] true, duplicate hash is suffixed to make unique.
  ///
  /// The service deliberately uses an explicit partial-import policy: every
  /// valid row is attempted independently, failed rows are returned with
  /// diagnostics, and history is finalized with the persisted counts.
  Future<ImportResult> importTransactions({
    required int kontoId,
    required List<RawTx> rawTxs,
    String mode = 'manuell',
    bool allowDuplicateOverride = false,
    String dateiname = 'import.csv',
    BankTemplate? template,
  }) async {
    _validateImport(kontoId: kontoId, rawTxs: rawTxs);

    int imported = 0;
    int duplicates = 0;
    int autoCat = 0;
    int manualReview = 0;
    final List<ImportRowFailure> failures = <ImportRowFailure>[];

    // History first: obtain importId before child rows so every persisted row
    // remains linked to an auditable import. Do not import without history.
    final int importId = await _createHistory(kontoId: kontoId, dateiname: dateiname, template: template);

    // Preload journals for scoring (ponytail: full scan ceiling — indexed per-konto if scale matters)
    List<Map<String, Object?>> journals = <Map<String, Object?>>[];
    try {
      journals = await executor.runSelect('SELECT * FROM journal', const <Object?>[]);
    } catch (_) {
      journals = <Map<String, Object?>>[];
    }

    for (int index = 0; index < rawTxs.length; index++) {
      final RawTx tx = rawTxs[index];
      final int rowNumber = index + 1;

      try {
        // String money: normalize betrag via money helper to 2 decimals for hash + storage.
        final String normBetrag = _normalizeBetragForStorage(tx.betrag);
        String hash = _hashFor(tx, normBetrag);

        final bool isDuplicate = await _hasDuplicate(kontoId: kontoId, hash: hash);
        if (isDuplicate && !allowDuplicateOverride) {
          duplicates++;
          continue;
        }

        if (isDuplicate && allowDuplicateOverride) {
          hash = await _uniqueOverrideHash(kontoId: kontoId, hash: hash);
        }

        // A reviewed category is authoritative. Only a rule result contributes
        // to auto-categorized counts; both counts are updated after insertion.
        final bool hasReviewedCategory = tx.kategorieId != null;
        final int? kategorieId = tx.kategorieId ?? await applyRules(tx.verwendungszweck);
        final bool wasAutoCategorized = !hasReviewedCategory && kategorieId != null;

        // Score match against journals — pick best >=90 (requires all three 40+30+30).
        int? matchedJournalId = tx.journalId;
        if (matchedJournalId == null && journals.isNotEmpty) {
          int bestScore = -1;
          int? bestId;
          for (final j in journals) {
            final int score = computeScore(tx, j);
            if (score > bestScore) {
              bestScore = score;
              final Object? journalId = j['id'];
              bestId = journalId == null ? null : (journalId as num).toInt();
            }
          }
          if (bestScore < 90 || mode.toLowerCase() != 'automatisch') {
            bestId = null;
          }
          matchedJournalId = bestId;
        }

        final String datumStr = _formatDate(tx.datum);
        final String status = matchedJournalId != null ? 'gebucht' : 'neu';

        await executor.runInsert(
          'INSERT INTO bank_transaktionen (konto_id, import_id, datum, betrag, verwendungszweck, '
          'gegenkonto, gegenkonto_name, kategorie_id, journal_id, dedupe_hash, status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            kontoId,
            importId,
            datumStr,
            normBetrag,
            tx.verwendungszweck,
            tx.gegenkonto,
            tx.partner,
            kategorieId,
            matchedJournalId,
            hash,
            status,
          ],
        );
        imported++;
        if (wasAutoCategorized) {
          autoCat++;
        } else {
          manualReview++;
        }
      } catch (error, stackTrace) {
        // A unique-index race is a duplicate outcome, not a failed row.
        bool becameDuplicate = false;
        try {
          final String normalized = _normalizeBetragForStorage(tx.betrag);
          becameDuplicate = await _hasDuplicate(kontoId: kontoId, hash: _hashFor(tx, normalized));
        } catch (_) {
          // Keep the original insert failure as the actionable diagnostic.
        }
        if (becameDuplicate && !allowDuplicateOverride) {
          duplicates++;
          continue;
        }

        final ImportRowFailure failure = ImportRowFailure(
          rowNumber: rowNumber,
          transaction: tx,
          error: _errorMessage(error),
        );
        failures.add(failure);
        debugPrint('bank_import row ${failure.rowNumber} insert failed: ${failure.error}');
        // Preserve the original stack in logs while allowing other rows to be
        // persisted and the caller to retry this row.
        debugPrint('$stackTrace');
      }
    }

    final String status = _statusFor(imported: imported, failed: failures.length);
    final List<String> diagnostics = failures.map((failure) => failure.toDiagnostic()).toList();
    final bool historyUpdated = await _finalizeHistory(
      importId: importId,
      imported: imported,
      duplicates: duplicates,
      autoCategorized: autoCat,
      manualReview: manualReview,
      failures: failures,
      template: template,
      status: status,
    );
    if (!historyUpdated) {
      diagnostics.add('Importhistorie konnte nicht abschließend gespeichert werden.');
    }

    return ImportResult(
      imported: imported,
      duplicatesSkipped: duplicates,
      autoCategorized: autoCat,
      manualReview: manualReview,
      failed: failures.length,
      status: status,
      diagnostics: diagnostics,
      failedRows: failures,
      importId: importId,
      historyUpdated: historyUpdated,
    );
  }

  /// Records a rejected file without creating a bank transaction row.
  ///
  /// This is useful when the upload/parser step has a source filename and
  /// account context available. It leaves an auditable failed history entry
  /// while keeping unsupported or malformed input out of persistence.
  Future<ImportResult> recordRejectedImport({
    required int kontoId,
    required String diagnostic,
    String dateiname = 'import.csv',
    BankTemplate? template,
  }) async {
    final String message = diagnostic.trim();
    if (message.isEmpty) {
      throw const BankImportException(
        'Ungültiger Import: Es wurde keine Fehlerdiagnose angegeben.',
        recoveryAction: 'Prüfen Sie Datei und Template und versuchen Sie es erneut.',
      );
    }
    if (kontoId <= 0) {
      throw const BankImportException(
        'Ungültiger Import: Kein gültiges Bankkonto ausgewählt.',
        recoveryAction: 'Wählen Sie ein gültiges Bankkonto und versuchen Sie es erneut.',
      );
    }

    final int importId = await _createHistory(kontoId: kontoId, dateiname: dateiname, template: template);
    final List<ImportRowFailure> noFailedRows = <ImportRowFailure>[];
    final List<String> diagnostics = <String>[message];
    final bool historyUpdated = await _finalizeHistory(
      importId: importId,
      imported: 0,
      duplicates: 0,
      autoCategorized: 0,
      manualReview: 0,
      failures: noFailedRows,
      template: template,
      status: _historyFailedStatus,
      diagnosticsOverride: diagnostics,
    );
    if (!historyUpdated) {
      diagnostics.add('Importhistorie konnte nicht abschließend gespeichert werden.');
    }
    return ImportResult(
      imported: 0,
      duplicatesSkipped: 0,
      autoCategorized: 0,
      manualReview: 0,
      status: _historyFailedStatus,
      diagnostics: diagnostics,
      importId: importId,
      historyUpdated: historyUpdated,
    );
  }

  void _validateImport({required int kontoId, required List<RawTx> rawTxs}) {
    if (kontoId <= 0) {
      throw const BankImportException(
        'Ungültiger Import: Kein gültiges Bankkonto ausgewählt.',
        recoveryAction: 'Wählen Sie ein gültiges Bankkonto und versuchen Sie es erneut.',
      );
    }
    if (rawTxs.isEmpty) {
      throw const BankImportException(
        'Keine Transaktionen zum Importieren.',
        recoveryAction: 'Wählen Sie eine unterstützte Datei mit mindestens einer Transaktion.',
      );
    }
    for (int index = 0; index < rawTxs.length; index++) {
      final RawTx tx = rawTxs[index];
      final int rowNumber = index + 1;
      if (!_isValidDate(tx.datum)) {
        throw BankImportException(
          'Zeile $rowNumber: Datum ungültig.',
          rowNumber: rowNumber,
          recoveryAction: 'Korrigieren Sie die Zeile und versuchen Sie den Import erneut.',
        );
      }
      try {
        _normalizeBetragForStorage(tx.betrag);
      } catch (error) {
        throw BankImportException(
          'Zeile $rowNumber: ${_errorMessage(error)}',
          rowNumber: rowNumber,
          recoveryAction: 'Korrigieren Sie den Betrag und versuchen Sie den Import erneut.',
        );
      }
    }
  }

  Future<int> _createHistory({required int kontoId, required String dateiname, required BankTemplate? template}) async {
    final String now = DateTime.now().toIso8601String();
    try {
      return await executor.runInsert(
        'INSERT INTO bank_imports (konto_id, dateiname, datum, anzahl_transaktionen, duplikate, template_typ, '
        'anzahl_importiert, anzahl_auto_kategorisiert, anzahl_manuelle_pruefung, anzahl_fehlgeschlagen, '
        'fehler_details, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[kontoId, dateiname, now, 0, 0, template?.typ, 0, 0, 0, 0, null, _historyInProgressStatus],
      );
    } catch (error) {
      debugPrint('bank_import extended history insert unavailable: $error');
      try {
        return await executor.runInsert(
          'INSERT INTO bank_imports (konto_id, dateiname, datum, anzahl_transaktionen, duplikate, '
          'template_typ, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>[kontoId, dateiname, now, 0, 0, template?.typ, _historyInProgressStatus],
        );
      } catch (legacyError) {
        debugPrint('bank_import history insert failed: $legacyError');
        try {
          return await executor.runInsert(
            'INSERT INTO bank_imports (konto_id, dateiname, datum, anzahl_transaktionen, status) '
            'VALUES (?, ?, ?, ?, ?)',
            <Object?>[kontoId, dateiname, now, 0, _historyInProgressStatus],
          );
        } catch (minimalError, minimalStackTrace) {
          Error.throwWithStackTrace(
            BankImportException(
              'Importhistorie konnte nicht angelegt werden: ${_errorMessage(minimalError)}',
              recoveryAction: 'Beheben Sie das Datenbankproblem und versuchen Sie es erneut.',
            ),
            minimalStackTrace,
          );
        }
      }
    }
  }

  Future<bool> _finalizeHistory({
    required int importId,
    required int imported,
    required int duplicates,
    required int autoCategorized,
    required int manualReview,
    required List<ImportRowFailure> failures,
    required BankTemplate? template,
    required String status,
    List<String>? diagnosticsOverride,
  }) async {
    final List<String> diagnostics =
        diagnosticsOverride ?? failures.map((failure) => failure.toDiagnostic()).toList(growable: false);
    final String? details = diagnostics.isEmpty
        ? null
        : jsonEncode(diagnostics.map((diagnostic) => <String, Object?>{'message': diagnostic}).toList(growable: false));
    try {
      await executor.runUpdate(
        'UPDATE bank_imports SET anzahl_transaktionen = ?, duplikate = ?, template_typ = ?, '
        'anzahl_importiert = ?, anzahl_auto_kategorisiert = ?, anzahl_manuelle_pruefung = ?, '
        'anzahl_fehlgeschlagen = ?, fehler_details = ?, status = ? WHERE id = ?',
        <Object?>[
          imported,
          duplicates,
          template?.typ,
          imported,
          autoCategorized,
          manualReview,
          failures.length,
          details,
          status,
          importId,
        ],
      );
      return true;
    } catch (error) {
      debugPrint('bank_import extended history update unavailable: $error');
    }

    final String legacyStatus = _historyStatusWithDiagnostics(status, diagnostics);
    try {
      await executor.runUpdate(
        'UPDATE bank_imports SET anzahl_transaktionen = ?, duplikate = ?, template_typ = ?, status = ? WHERE id = ?',
        <Object?>[imported, duplicates, template?.typ, legacyStatus, importId],
      );
      return true;
    } catch (error) {
      debugPrint('bank_import history compatibility update unavailable: $error');
    }

    try {
      await executor.runUpdate('UPDATE bank_imports SET anzahl_transaktionen = ?, status = ? WHERE id = ?', <Object?>[
        imported,
        legacyStatus,
        importId,
      ]);
      return true;
    } catch (error) {
      debugPrint('bank_import minimal history update failed: $error');
      return false;
    }
  }

  Future<bool> _hasDuplicate({required int kontoId, required String hash}) async {
    final List<Map<String, Object?>> existing = await executor.runSelect(
      'SELECT id FROM bank_transaktionen WHERE konto_id = ? AND dedupe_hash = ? LIMIT 1',
      <Object?>[kontoId, hash],
    );
    return existing.isNotEmpty;
  }

  Future<String> _uniqueOverrideHash({required int kontoId, required String hash}) async {
    for (int suffix = 1; suffix <= 100; suffix++) {
      final String candidate = '$hash-$suffix';
      if (!await _hasDuplicate(kontoId: kontoId, hash: candidate)) return candidate;
    }
    throw const BankImportException(
      'Duplicate override limit reached (100) — manual cleanup required',
      recoveryAction: 'Prüfen Sie die vorhandenen Duplikate und versuchen Sie es erneut.',
    );
  }

  String _hashFor(RawTx tx, String normalizedAmount) {
    final String? supplied = tx.dedupeHash?.trim();
    if (supplied != null && supplied.isNotEmpty) return supplied;
    return computeDedupeHash(tx.datum, normalizedAmount, tx.partner, tx.verwendungszweck);
  }

  String _statusFor({required int imported, required int failed}) {
    if (failed == 0) return _historyImportedStatus;
    return imported == 0 ? _historyFailedStatus : _historyPartialStatus;
  }

  String _historyStatusWithDiagnostics(String status, List<String> diagnostics) {
    if (diagnostics.isEmpty) return status;
    return '$status: ${diagnostics.join(' | ')}';
  }

  String _errorMessage(Object error) {
    final String message = error.toString().trim();
    return message.isEmpty ? 'Unbekannter Fehler' : message;
  }

  bool _isValidDate(DateTime value) {
    final DateTime dateOnly = DateTime(value.year, value.month, value.day);
    return dateOnly.year == value.year && dateOnly.month == value.month && dateOnly.day == value.day;
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _normalizeBetragForStorage(String raw) {
    return _parseBetrag(raw);
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
      final List<String> cols = _splitCsvLine(line, delimiter, rowNumber: i + 1);
      // Skip rows where all cols empty.
      if (cols.every((c) => c.trim().isEmpty)) continue;
      // If row has fewer columns than header, pad with empty.
      // If more, truncate to header length — preserve logical idx access.
      final String datumRaw = idxDatum < cols.length ? cols[idxDatum].trim() : '';
      final String betragRaw = idxBetrag < cols.length ? cols[idxBetrag].trim() : '';
      if (datumRaw.isEmpty && betragRaw.isEmpty) continue;
      if (datumRaw.isEmpty) {
        throw BankImportException(
          'Datum fehlt in Zeile ${i + 1}',
          rowNumber: i + 1,
          recoveryAction: 'Korrigieren Sie die Zeile und versuchen Sie den Import erneut.',
        );
      }
      if (betragRaw.isEmpty) {
        throw BankImportException(
          'Betrag fehlt in Zeile ${i + 1}',
          rowNumber: i + 1,
          recoveryAction: 'Korrigieren Sie die Zeile und versuchen Sie den Import erneut.',
        );
      }
      late final DateTime datum;
      try {
        datum = _parseDate(datumRaw, template?.dateFormat);
      } catch (error) {
        throw BankImportException(
          'Datum ungültig in Zeile ${i + 1}: ${_errorMessage(error)}',
          rowNumber: i + 1,
          recoveryAction: 'Korrigieren Sie das Datum und versuchen Sie den Import erneut.',
        );
      }
      late final String betrag;
      try {
        betrag = _parseBetrag(betragRaw);
      } catch (error) {
        throw BankImportException(
          'Betrag ungültig in Zeile ${i + 1}: ${_errorMessage(error)}',
          rowNumber: i + 1,
          recoveryAction: 'Korrigieren Sie den Betrag und versuchen Sie den Import erneut.',
        );
      }

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

  // ── CAMT XML ───────────────────────────────────────────────────────

  /// Parse CAMT.053 XML into [RawTx] via regex without xml package.
  /// ponytail: regex ceiling — `<Ntry>` blocks + `<Amt>`/`<Dt>`/`<Ustrd>`/`<Nm>`/`<IBAN>`.
  /// Handles comma/dot amounts and CdtDbtInd DBIT/CRDT. Throws [BankImportException]
  /// for non-CAMT (unsupported) or invalid/malformed XML.
  List<RawTx> parseCamtXml(String xml) {
    final String trimmed = xml.trim();
    if (trimmed.isEmpty) {
      throw const BankImportException('Datei ist leer');
    }
    if (!trimmed.contains('<') || !trimmed.contains('>')) {
      throw const BankImportException('Ungültiges XML: kein XML-Tag gefunden (invalid)');
    }
    if (!trimmed.contains('</')) {
      throw const BankImportException('Ungültiges XML: kein schliessendes Tag (invalid)');
    }

    final bool hasDocument = trimmed.contains('<Document') || trimmed.contains(':Document');
    final bool hasNtry = RegExp(r'<\s*(?:\w+:)?Ntry\b', caseSensitive: false).hasMatch(trimmed);
    final bool hasBkTo =
        trimmed.contains('BkToCstmrStmt') || trimmed.contains('BkToStmRpt') || trimmed.contains('BkToCstmr');
    final bool hasCamtNs =
        trimmed.toLowerCase().contains('camt') || trimmed.contains('iso:std:iso:20022') || trimmed.contains('iso20022');

    final bool isCamt = (hasDocument && hasNtry && hasBkTo) || (hasCamtNs && hasNtry);
    if (!isCamt) {
      throw const BankImportException('Unsupported XML format: Not CAMT');
    }

    if (hasDocument && !trimmed.contains('</Document') && !trimmed.contains('</document')) {
      throw const BankImportException('Ungültiges XML: Document nicht geschlossen (invalid)');
    }

    final RegExp ntryReg = RegExp(
      r'<\s*(?:\w+:)?Ntry\b[^>]*>(.*?)</\s*(?:\w+:)?Ntry\s*>',
      dotAll: true,
      caseSensitive: false,
    );
    final int openingNtries = RegExp(r'<\s*(?:\w+:)?Ntry\b[^>]*>', caseSensitive: false).allMatches(trimmed).length;
    final int closingNtries = RegExp(r'</\s*(?:\w+:)?Ntry\s*>', caseSensitive: false).allMatches(trimmed).length;
    if (openingNtries != closingNtries) {
      throw const BankImportException('Ungültiges XML: Ntry nicht geschlossen (invalid)');
    }

    final Iterable<RegExpMatch> matches = ntryReg.allMatches(trimmed);
    if (matches.isEmpty) {
      if (trimmed.contains('<Ntry') || trimmed.contains(':Ntry')) {
        throw const BankImportException('Ungültiges XML: Ntry nicht geschlossen (invalid)');
      }
      throw const BankImportException('Keine Transaktionen gefunden');
    }

    final List<RawTx> out = <RawTx>[];
    for (final RegExpMatch m in matches) {
      final String ntryOuter = m.group(0) ?? '';
      final String ntryContent = m.group(1) ?? '';

      // Amount — <Amt> with optional attributes
      final RegExp amtReg = RegExp(r'<\s*(?:\w+:)?Amt\b[^>]*>([^<]+)</\s*(?:\w+:)?Amt\s*>', caseSensitive: false);
      RegExpMatch? amtM = amtReg.firstMatch(ntryOuter);
      amtM ??= amtReg.firstMatch(ntryContent);
      if (amtM == null) {
        throw const BankImportException('Betrag fehlt in Ntry');
      }
      final String amtRaw = amtM.group(1)!.trim();

      // Credit/Debit indicator
      final RegExp cdtReg = RegExp(
        r'<\s*(?:\w+:)?CdtDbtInd\s*>([^<]+)</\s*(?:\w+:)?CdtDbtInd\s*>',
        caseSensitive: false,
      );
      final RegExpMatch? cdtM = cdtReg.firstMatch(ntryContent) ?? cdtReg.firstMatch(ntryOuter);
      final String? cdt = cdtM?.group(1)?.trim().toUpperCase();

      // Parse betrag with CdtDbtInd handling via _parseBetrag
      String betrag;
      try {
        final String stripped = amtRaw.replaceFirst(RegExp('^[+-]'), '').trim();
        final String effective;
        if (cdt == 'DBIT') {
          effective = '-$stripped';
        } else if (cdt == 'CRDT') {
          effective = stripped;
        } else {
          effective = amtRaw;
        }
        betrag = _parseBetrag(effective);
      } catch (e) {
        if (e is BankImportException) rethrow;
        throw BankImportException('Betrag ungültig: $amtRaw');
      }

      // Datum — prefer BookgDt/Dt, then ValDt/Dt, then generic Dt
      final RegExp bookgDtReg = RegExp(
        r'<\s*(?:\w+:)?BookgDt\s*>.*?<\s*(?:\w+:)?Dt\s*>([^<]+)</\s*(?:\w+:)?Dt\s*>',
        dotAll: true,
        caseSensitive: false,
      );
      final RegExp valDtReg = RegExp(
        r'<\s*(?:\w+:)?ValDt\s*>.*?<\s*(?:\w+:)?Dt\s*>([^<]+)</\s*(?:\w+:)?Dt\s*>',
        dotAll: true,
        caseSensitive: false,
      );
      final RegExp dtReg = RegExp(r'<\s*(?:\w+:)?Dt\s*>([^<]+)</\s*(?:\w+:)?Dt\s*>', caseSensitive: false);
      RegExpMatch? dtM = bookgDtReg.firstMatch(ntryContent);
      dtM ??= valDtReg.firstMatch(ntryContent);
      dtM ??= dtReg.firstMatch(ntryContent);
      dtM ??= bookgDtReg.firstMatch(ntryOuter);
      dtM ??= valDtReg.firstMatch(ntryOuter);
      dtM ??= dtReg.firstMatch(ntryOuter);
      if (dtM == null) {
        throw const BankImportException('Datum fehlt in Ntry');
      }
      final String dtRaw = dtM.group(1)!.trim();
      late final DateTime datum;
      try {
        datum = _parseDate(dtRaw, null);
      } catch (e) {
        if (e is BankImportException) rethrow;
        throw BankImportException('Datum ungültig: $dtRaw');
      }

      // Verwendungszweck — Ustrd + AddtlNtryInf
      final RegExp ustrdReg = RegExp(
        r'<\s*(?:\w+:)?Ustrd\s*>([^<]*?)</\s*(?:\w+:)?Ustrd\s*>',
        dotAll: true,
        caseSensitive: false,
      );
      final RegExp addtlReg = RegExp(
        r'<\s*(?:\w+:)?AddtlNtryInf\s*>([^<]*?)</\s*(?:\w+:)?AddtlNtryInf\s*>',
        dotAll: true,
        caseSensitive: false,
      );
      final List<String> parts = <String>[];
      for (final RegExpMatch um in ustrdReg.allMatches(ntryContent)) {
        final String v = um.group(1)!.trim();
        if (v.isNotEmpty) parts.add(v);
      }
      if (parts.isEmpty) {
        for (final RegExpMatch um in ustrdReg.allMatches(ntryOuter)) {
          final String v = um.group(1)!.trim();
          if (v.isNotEmpty) parts.add(v);
        }
      }
      for (final RegExpMatch am in addtlReg.allMatches(ntryContent)) {
        final String v = am.group(1)!.trim();
        if (v.isNotEmpty) parts.add(v);
      }
      final String verwendungszweck = parts.join(' ').trim();

      // Partner — first Nm in Ntry
      final RegExp nmReg = RegExp(r'<\s*(?:\w+:)?Nm\s*>([^<]+)</\s*(?:\w+:)?Nm\s*>', caseSensitive: false);
      final RegExpMatch? nmM = nmReg.firstMatch(ntryContent) ?? nmReg.firstMatch(ntryOuter);
      final String partner = nmM?.group(1)?.trim() ?? '';

      // Gegenkonto — IBAN
      final RegExp ibanReg = RegExp(r'<\s*(?:\w+:)?IBAN\s*>([^<]+)</\s*(?:\w+:)?IBAN\s*>', caseSensitive: false);
      final RegExpMatch? ibanM = ibanReg.firstMatch(ntryContent) ?? ibanReg.firstMatch(ntryOuter);
      final String? gegenkontoRaw = ibanM?.group(1)?.trim();
      final String? gegenkonto = (gegenkontoRaw == null || gegenkontoRaw.isEmpty) ? null : gegenkontoRaw;

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
      throw const BankImportException('Keine Transaktionen gefunden');
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

  List<String> _splitCsvLine(String line, String delimiter, {int? rowNumber}) {
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
    if (inQuotes) {
      final String suffix = rowNumber == null ? '' : ' in Zeile $rowNumber';
      throw BankImportException(
        'Ungültige CSV: Anführungszeichen nicht geschlossen$suffix',
        rowNumber: rowNumber,
        recoveryAction: 'Korrigieren Sie die CSV-Zeile und versuchen Sie den Import erneut.',
      );
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
    // Last resort is limited to formats without a separator. Known date
    // formats are parsed above with component checks so DateTime cannot
    // silently normalize an invalid day such as 31 February.
    if (!t.contains(RegExp(r'[.\-/]'))) {
      final DateTime? parsed = DateTime.tryParse(t);
      if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
    }
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
    return _exactDate(y, m, d);
  }

  DateTime? _tryIso(String t) {
    if (!t.contains('-')) return null;
    final List<String> parts = t.split('-');
    if (parts.length != 3) return null;
    // Heuristic: first part 4 digits => yyyy-mm-dd
    if (parts[0].trim().length != 4) return null;
    final int? y = int.tryParse(parts[0].trim());
    final int? m = int.tryParse(parts[1].trim());
    final int? d = int.tryParse(parts[2].trim());
    if (y == null || m == null || d == null) return null;
    return _exactDate(y, m, d);
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
    return _exactDate(yy, m, d);
  }

  DateTime? _exactDate(int year, int month, int day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1 || day > 31) return null;
    final DateTime value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) return null;
    return value;
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
