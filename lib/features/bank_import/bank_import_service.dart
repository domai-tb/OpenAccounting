import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_failure_payload.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// BankImportService — upload + dedup + auto-rules + score.
/// ponytail ultra: stdlib split + crypto SHA256 + string money, no csv/xml deps.
class BankImportService {
  BankImportService(this.executor);

  final QueryExecutor executor;

  /// Resolves the catalog for an explicit BCP-47 style locale tag.
  AppLocalizations _l10nFor(String locale) => lookupAppLocalizations(Locale(locale.split('_').first));

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

  /// Loads eligible match candidates: journal rows with a valid persisted
  /// integer ID. Failures propagate so callers show an unavailable state
  /// instead of a fabricated no-match.
  Future<List<Map<String, Object?>>> loadMatchCandidates() async {
    final List<Map<String, Object?>> rows = await executor.runSelect('SELECT * FROM journal', const <Object?>[]);
    return rows.where((row) => (row['id'] as num?)?.toInt() != null).toList(growable: false);
  }

  /// Ranks candidates for [tx] by score descending, journal ID ascending.
  /// Review displays the top entry with its confidence label; the ranking is
  /// deterministic for tied scores.
  Future<List<MatchCandidate>> rankCandidates(RawTx tx) async {
    final List<Map<String, Object?>> journals = await loadMatchCandidates();
    final List<MatchCandidate> ranked = <MatchCandidate>[];
    for (final j in journals) {
      final int? id = (j['id'] as num?)?.toInt();
      if (id == null) continue;
      ranked.add(
        MatchCandidate(
          journalId: id,
          score: computeScore(tx, j),
          datum: j['datum']?.toString(),
          betrag: j['betrag']?.toString(),
          beschreibung: (j['beschreibung'] ?? j['bezeichnung'])?.toString(),
        ),
      );
    }
    ranked.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : a.journalId.compareTo(b.journalId));
    return ranked;
  }

  /// Localized confidence label: 90–100 high, 70–89 medium, 50–69 low, else none.
  String confidenceLabel(int score, AppLocalizations l10n) {
    if (score >= 90) return l10n.bankConfidenceHigh;
    if (score >= 70) return l10n.bankConfidenceMedium;
    if (score >= 50) return l10n.bankConfidenceLow;
    return l10n.bankConfidenceNone;
  }

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
    if (tx.datum != null && jDatum != null) {
      final int diffDays = tx.datum!.difference(jDatum).inDays.abs();
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
    required String locale,
  }) async {
    final AppLocalizations l10n = _l10nFor(locale);
    _validateImport(kontoId: kontoId, rawTxs: rawTxs, l10n: l10n);

    int imported = 0;
    int duplicates = 0;
    int autoCat = 0;
    int manualReview = 0;
    final List<ImportRowFailure> failures = <ImportRowFailure>[];

    // History first: obtain importId before child rows so every persisted row
    // remains linked to an auditable import. Do not import without history.
    final int importId = await _createHistory(kontoId: kontoId, dateiname: dateiname, template: template, l10n: l10n);

    // Preload journals for scoring (ponytail: full scan ceiling — indexed per-konto if scale matters).
    // A load failure is unavailable, never a no-match: automatic linking is
    // disabled for the whole import but the user may still proceed.
    List<Map<String, Object?>> journals = <Map<String, Object?>>[];
    bool candidatesUnavailable = false;
    try {
      journals = await loadMatchCandidates();
    } catch (_) {
      journals = <Map<String, Object?>>[];
      candidatesUnavailable = true;
    }

    for (int index = 0; index < rawTxs.length; index++) {
      final RawTx tx = rawTxs[index];
      final int rowNumber = index + 1;

      final RowOutcome outcome = await _persistRow(
        kontoId: kontoId,
        importId: importId,
        tx: tx,
        rowNumber: rowNumber,
        mode: mode,
        journals: journals,
        candidatesUnavailable: candidatesUnavailable,
        allowDuplicateOverride: allowDuplicateOverride,
        l10n: l10n,
      );
      if (outcome.failure != null) {
        failures.add(outcome.failure!);
      } else if (outcome.duplicate) {
        duplicates++;
      } else {
        imported++;
        if (outcome.autoCategorized) {
          autoCat++;
        } else {
          manualReview++;
        }
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
      diagnostics.add(l10n.bankHistoryNotFinalSaved);
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
      candidatesUnavailable: candidatesUnavailable,
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
    required String locale,
    List<String> diagnosticCodes = const <String>['unknown_file_rejection'],
  }) async {
    final AppLocalizations l10n = _l10nFor(locale);
    final String message = diagnostic.trim();
    if (message.isEmpty) {
      throw BankImportException(l10n.bankInvalidImportNoDiagnostic, recoveryAction: l10n.bankRecoveryCheckFileTemplate);
    }
    if (kontoId <= 0) {
      throw BankImportException(l10n.bankInvalidImportNoAccount, recoveryAction: l10n.bankRecoverySelectAccount);
    }

    final int importId = await _createHistory(kontoId: kontoId, dateiname: dateiname, template: template, l10n: l10n);
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
      fileRejectionCodes: diagnosticCodes,
    );
    if (!historyUpdated) {
      diagnostics.add(l10n.bankHistoryNotFinalSaved);
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

  /// Post-import review of one row. Confirming a category closes the row as
  /// `geprueft`; associating an existing journal entry closes it as `gebucht`
  /// (taking precedence). A row cannot leave `neu` without a category or an
  /// existing journal link. Creates no journal entry or payment.
  Future<void> reviewTransaction({required int id, int? kategorieId, int? journalId}) async {
    final rows = await executor.runSelect('SELECT status FROM bank_transaktionen WHERE id = ?', <Object?>[id]);
    if (rows.isEmpty) throw const BankImportException('Transaktion nicht gefunden');
    if (journalId != null) {
      final journals = await executor.runSelect('SELECT id FROM journal WHERE id = ?', <Object?>[journalId]);
      if (journals.isEmpty) throw const BankImportException('Journaleintrag nicht gefunden');
      await executor.runUpdate('UPDATE bank_transaktionen SET journal_id = ?, status = ? WHERE id = ?', <Object?>[
        journalId,
        'gebucht',
        id,
      ]);
      return;
    }
    if (kategorieId != null) {
      final cats = await executor.runSelect('SELECT id FROM kategorien WHERE id = ?', <Object?>[kategorieId]);
      if (cats.isEmpty) throw const BankImportException('Kategorie nicht gefunden');
      await executor.runUpdate('UPDATE bank_transaktionen SET kategorie_id = ?, status = ? WHERE id = ?', <Object?>[
        kategorieId,
        'geprueft',
        id,
      ]);
      return;
    }
    throw const BankImportException('Review braucht eine Kategorie oder einen Journaleintrag');
  }

  /// Rows awaiting explicit post-import review (`status = 'neu'`), optionally
  /// scoped to one import.
  Future<List<Map<String, Object?>>> unresolvedReviewRows({int? importId}) async {
    if (importId != null) {
      return executor.runSelect(
        "SELECT * FROM bank_transaktionen WHERE import_id = ? AND status = 'neu' ORDER BY id",
        <Object?>[importId],
      );
    }
    return executor.runSelect("SELECT * FROM bank_transaktionen WHERE status = 'neu' ORDER BY id", const <Object?>[]);
  }

  /// Retries an attempt's persisted failed rows under the original
  /// `bank_imports.id`. Only `teilweise`/`fehlgeschlagen` attempts with a
  /// valid version-1 row payload are retryable; rejected-file and legacy
  /// payloads throw. Successful child rows keep their IDs; duplicate-resolved
  /// rows leave the payload and bump the duplicate aggregate exactly once.
  /// Everything commits atomically; any failure rolls back to the prior
  /// attempt state.
  ///
  /// [corrected] optionally replaces payload rows (keyed by payload `row`
  /// number) with user-corrected transactions; row identity is preserved.
  Future<ImportResult> retryImport({
    required int importId,
    required String locale,
    String mode = 'manuell',
    Map<int, RawTx> corrected = const <int, RawTx>{},
  }) async {
    final AppLocalizations l10n = _l10nFor(locale);
    final attempts = await executor.runSelect('SELECT * FROM bank_imports WHERE id = ?', <Object?>[importId]);
    if (attempts.isEmpty) throw BankImportException(l10n.bankHistoryNotFinalSaved);
    final Map<String, Object?> attempt = attempts.single;
    final String status = (attempt['status']?.toString() ?? '').toLowerCase();
    if (status != 'teilweise' && status != 'fehlgeschlagen') {
      throw const BankImportException('Import ist nicht wiederholbar');
    }
    final Object? rawPayload = attempt['fehler_details'];
    if (rawPayload == null || rawPayload.toString().trim().isEmpty) {
      throw const BankImportException('Keine wiederholbaren Zeilen vorhanden');
    }
    final Map<String, Object?> envelope;
    try {
      envelope = BankImportFailurePayload.decodeValidated(rawPayload.toString());
    } on BankImportPayloadException catch (e) {
      throw BankImportException(e.message);
    }
    if (envelope['kind'] != 'rows') {
      throw const BankImportException('Dateiabweisung braucht einen neuen Import');
    }
    final List<Map<String, Object?>> payloadRows = (envelope['rows']! as List)
        .map((r) => Map<String, Object?>.from(r as Map))
        .toList(growable: false);
    final int kontoId = ((attempt['konto_id'] as num?) ?? 0).toInt();
    if (kontoId <= 0) throw BankImportException(l10n.bankInvalidImportNoAccount);

    List<Map<String, Object?>> journals = <Map<String, Object?>>[];
    bool candidatesUnavailable = false;
    try {
      journals = await loadMatchCandidates();
    } catch (_) {
      candidatesUnavailable = true;
    }

    int newDuplicates = 0;
    final List<Map<String, Object?>> remaining = <Map<String, Object?>>[];
    await executor.runCustom('BEGIN');
    try {
      for (final row in payloadRows) {
        final int payloadRow = (row['row']! as num).toInt();
        RawTx tx = _txFromPayloadRow(row);
        final RawTx? fix = corrected[payloadRow];
        if (fix != null) {
          tx = fix;
        }
        final RowOutcome outcome = await _persistRow(
          kontoId: kontoId,
          importId: importId,
          tx: tx,
          rowNumber: payloadRow,
          mode: mode,
          journals: journals,
          candidatesUnavailable: candidatesUnavailable,
          allowDuplicateOverride: false,
          l10n: l10n,
        );
        if (outcome.duplicate) {
          newDuplicates++;
        } else if (outcome.failure != null) {
          remaining.add(outcome.failure!.toPayloadJson());
        }
      }

      final int priorDuplicates = ((attempt['duplikate'] as num?) ?? 0).toInt();
      final int childRows = await _childRowCount(importId);
      final String nextStatus = remaining.isEmpty ? 'importiert' : (childRows > 0 ? 'teilweise' : 'fehlgeschlagen');
      final String? nextPayload = remaining.isEmpty ? null : BankImportFailurePayload.encodeRows(remaining);
      await executor.runUpdate(
        'UPDATE bank_imports SET duplikate = ?, anzahl_importiert = ?, anzahl_fehlgeschlagen = ?, '
        'fehler_details = ?, status = ? WHERE id = ?',
        <Object?>[priorDuplicates + newDuplicates, childRows, remaining.length, nextPayload, nextStatus, importId],
      );
      await executor.runCustom('COMMIT');
      return ImportResult(
        imported: childRows,
        duplicatesSkipped: priorDuplicates + newDuplicates,
        autoCategorized: 0,
        manualReview: 0,
        failed: remaining.length,
        status: nextStatus,
        importId: importId,
        candidatesUnavailable: candidatesUnavailable,
      );
    } catch (error, stackTrace) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (_) {}
      Error.throwWithStackTrace(
        error is BankImportException ? error : BankImportException(_errorMessage(error, _l10nFor(locale))),
        stackTrace,
      );
    }
  }

  /// Typed history query: case-insensitive filename/template/status search
  /// applied before stable pagination (newest first, ID descending on ties).
  Future<BankImportHistoryPage> queryHistory({String q = '', int page = 1, int pageSize = 50}) async {
    final String needle = '%${q.trim().toLowerCase()}%';
    final countRows = await executor.runSelect(
      "SELECT COUNT(*) AS c FROM bank_imports WHERE LOWER(COALESCE(dateiname, '')) LIKE ? "
      "OR LOWER(COALESCE(template_typ, '')) LIKE ? OR LOWER(COALESCE(status, '')) LIKE ?",
      <Object?>[needle, needle, needle],
    );
    final int total = (countRows.single['c']! as num).toInt();
    final int lastPage = total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;
    final int safePage = page < 1 ? 1 : (page > lastPage ? lastPage : page);
    final int offset = (safePage - 1) * pageSize;
    final rows = await executor.runSelect(
      "SELECT * FROM bank_imports WHERE LOWER(COALESCE(dateiname, '')) LIKE ? "
      "OR LOWER(COALESCE(template_typ, '')) LIKE ? OR LOWER(COALESCE(status, '')) LIKE ? "
      'ORDER BY datum DESC, id DESC LIMIT ? OFFSET ?',
      <Object?>[needle, needle, needle, pageSize, offset],
    );
    final List<BankImportHistoryAttempt> attempts = <BankImportHistoryAttempt>[];
    for (final row in rows) {
      final int id = (row['id']! as num).toInt();
      attempts.add(
        BankImportHistoryAttempt(
          id: id,
          dateiname: row['dateiname']?.toString() ?? '',
          datum: row['datum']?.toString() ?? '',
          status: row['status']?.toString() ?? '',
          imported: ((row['anzahl_importiert'] as num?) ?? 0).toInt(),
          duplicates: ((row['duplikate'] as num?) ?? 0).toInt(),
          failed: ((row['anzahl_fehlgeschlagen'] as num?) ?? 0).toInt(),
          templateTyp: row['template_typ']?.toString(),
          unresolvedNeu: await _unresolvedCount(id),
          retryable: _payloadRetryable(row['fehler_details'], row['status']?.toString()),
        ),
      );
    }
    return BankImportHistoryPage(attempts: attempts, total: total, page: safePage, hasMore: safePage < lastPage);
  }

  /// Typed detail for one attempt: metadata, safe diagnostics, unresolved
  /// count, and allowed actions. Raw bank values never appear in error text.
  Future<BankImportHistoryDetail> historyDetail(int importId, {required String locale}) async {
    final AppLocalizations l10n = _l10nFor(locale);
    final rows = await executor.runSelect('SELECT * FROM bank_imports WHERE id = ?', <Object?>[importId]);
    if (rows.isEmpty) throw const BankImportException('Importverlauf nicht gefunden');
    final Map<String, Object?> row = rows.single;
    final String status = row['status']?.toString() ?? '';
    final List<String> diagnostics = _safeDiagnostics(row['fehler_details'], l10n);
    final int unresolved = await _unresolvedCount(importId);
    final bool retryable = _payloadRetryable(row['fehler_details'], status);
    return BankImportHistoryDetail(
      id: importId,
      dateiname: row['dateiname']?.toString() ?? '',
      datum: row['datum']?.toString() ?? '',
      status: status,
      imported: ((row['anzahl_importiert'] as num?) ?? 0).toInt(),
      duplicates: ((row['duplikate'] as num?) ?? 0).toInt(),
      failed: ((row['anzahl_fehlgeschlagen'] as num?) ?? 0).toInt(),
      templateTyp: row['template_typ']?.toString(),
      diagnostics: diagnostics,
      unresolvedNeu: unresolved,
      retryable: retryable,
      reviewOffered: unresolved > 0,
    );
  }

  RawTx _txFromPayloadRow(Map<String, Object?> row) {
    DateTime? datum;
    final Object? rawDatum = row['datum'];
    if (rawDatum is String && rawDatum.isNotEmpty) {
      datum = DateTime.tryParse(rawDatum.length >= 10 ? rawDatum.substring(0, 10) : rawDatum);
    }
    int? asPositiveInt(Object? v) {
      if (v is int && v > 0) return v;
      if (v is num && v.toInt() == v && v.toInt() > 0) return v.toInt();
      return null;
    }

    return RawTx(
      datum: datum,
      betrag: row['betrag']?.toString() ?? '',
      verwendungszweck: row['verwendungszweck']?.toString() ?? '',
      partner: row['partner']?.toString() ?? '',
      gegenkonto: row['gegenkonto']?.toString(),
      kategorieId: asPositiveInt(row['kategorie_id']),
      journalId: asPositiveInt(row['journal_id']),
      rawDatum: row['raw_datum']?.toString(),
      rawBetrag: row['raw_betrag']?.toString(),
      sourceRowNumber: asPositiveInt(row['source_row']),
    );
  }

  Future<int> _childRowCount(int importId) async {
    final rows = await executor.runSelect('SELECT COUNT(*) AS c FROM bank_transaktionen WHERE import_id = ?', <Object?>[
      importId,
    ]);
    return (rows.single['c']! as num).toInt();
  }

  Future<int> _unresolvedCount(int importId) async {
    try {
      final rows = await executor.runSelect(
        "SELECT COUNT(*) AS c FROM bank_transaktionen WHERE import_id = ? AND status = 'neu'",
        <Object?>[importId],
      );
      return (rows.single['c']! as num).toInt();
    } catch (_) {
      return 0;
    }
  }

  bool _payloadRetryable(Object? raw, Object? status) {
    final String s = (status?.toString() ?? '').toLowerCase();
    if (s != 'teilweise' && s != 'fehlgeschlagen') return false;
    if (raw == null || raw.toString().trim().isEmpty) return false;
    try {
      final envelope = BankImportFailurePayload.decodeValidated(raw.toString());
      return envelope['kind'] == 'rows';
    } on BankImportPayloadException {
      return false;
    }
  }

  /// Safe display diagnostics: stable codes only, never raw bank values.
  List<String> _safeDiagnostics(Object? raw, AppLocalizations l10n) {
    if (raw == null || raw.toString().trim().isEmpty) return const <String>[];
    try {
      final Map<String, Object?> envelope = BankImportFailurePayload.decodeValidated(raw.toString());
      final Object? kind = envelope['kind'];
      if (kind == 'file_rejection') {
        final Object? codesRaw = envelope['diagnostic_codes'];
        final List<String> codes = <String>[for (final c in codesRaw! as List) c.toString()];
        return codes.map((String c) => '${l10n.bankDiagnosticFile}: $c').toList(growable: false);
      }
      final Object? rowsRaw = envelope['rows'];
      final List<String> lines = <String>[];
      for (final row in rowsRaw! as List) {
        final Map<String, Object?> entry = Map<String, Object?>.from(row as Map);
        final Object? entryCodes = entry['diagnostic_codes'];
        final String joined = (entryCodes! as List).join(', ');
        lines.add('${l10n.bankDiagnosticRow} ${entry['row']}: $joined');
      }
      return lines;
    } on BankImportPayloadException {
      return <String>[l10n.bankDetailsUnavailable];
    }
  }

  /// Action policy for a history row. Retry needs a validated retryable
  /// payload; review needs unresolved rows; otherwise a new file selection
  /// is offered instead of retry.
  BankImportHistoryActions historyActions({
    required String status,
    required bool retryable,
    required int unresolvedNeu,
  }) {
    final bool retry = (status == 'teilweise' || status == 'fehlgeschlagen') && retryable;
    return BankImportHistoryActions(retry: retry, review: unresolvedNeu > 0, newFile: !retry);
  }

  /// Persists one confirmed row: validate, dedup, categorize, score-link,
  /// insert. Shared by initial imports and history retries so both produce
  /// identical rows, statuses, and failure payloads.
  Future<RowOutcome> _persistRow({
    required int kontoId,
    required int importId,
    required RawTx tx,
    required int rowNumber,
    required String mode,
    required List<Map<String, Object?>> journals,
    required bool candidatesUnavailable,
    required bool allowDuplicateOverride,
    required AppLocalizations l10n,
  }) async {
    String rowQuelle = tx.kategorieId != null ? 'benutzerentscheidung' : 'keine';
    try {
      // String money: normalize betrag via money helper to 2 decimals for hash + storage.
      final ({List<String> diagnostics, List<String> codes, String? normalizedAmount}) validation = _validateRow(
        tx,
        l10n,
      );
      if (validation.diagnostics.isNotEmpty) {
        final RawTx failureTransaction = tx.sourceRowNumber == null ? tx.copyWith(sourceRowNumber: rowNumber) : tx;
        String quelle = tx.kategorieId != null ? 'benutzerentscheidung' : 'keine';
        if (quelle == 'keine' && await applyRules(tx.verwendungszweck) != null) {
          quelle = 'regel_vorschlag';
        }
        return (
          inserted: false,
          duplicate: false,
          autoCategorized: false,
          failure: ImportRowFailure(
            rowNumber: rowNumber,
            transaction: failureTransaction,
            diagnostics: validation.diagnostics,
            error: validation.diagnostics.join('; '),
            diagnosticCodes: validation.codes,
            kategorieQuelle: quelle,
          ),
        );
      }
      final String normBetrag = validation.normalizedAmount!;
      String hash = _hashFor(tx, normBetrag);

      final bool isDuplicate = await _hasDuplicate(kontoId: kontoId, hash: hash);
      if (isDuplicate && !allowDuplicateOverride) {
        return (inserted: false, duplicate: true, autoCategorized: false, failure: null);
      }

      if (isDuplicate && allowDuplicateOverride) {
        hash = await _uniqueOverrideHash(kontoId: kontoId, hash: hash, l10n: l10n);
      }

      // A reviewed category is authoritative. Only a rule result contributes
      // to auto-categorized counts; both counts are updated after insertion.
      final bool hasReviewedCategory = tx.kategorieId != null;
      final int? kategorieId = tx.kategorieId ?? await applyRules(tx.verwendungszweck);
      final bool wasAutoCategorized = !hasReviewedCategory && kategorieId != null;
      if (wasAutoCategorized) rowQuelle = 'regel_vorschlag';

      // Score match against journals — link only a unique top candidate
      // scoring at least 90 in automatic mode. Tied tops stay unlinked;
      // manual mode never links suggestions (explicit selection only).
      int? matchedJournalId = tx.journalId;
      if (matchedJournalId == null && !candidatesUnavailable && journals.isNotEmpty) {
        int bestScore = -1;
        int? bestId;
        int topCount = 0;
        for (final j in journals) {
          final int score = computeScore(tx, j);
          if (score > bestScore) {
            bestScore = score;
            final Object? journalId = j['id'];
            bestId = journalId == null ? null : (journalId as num).toInt();
            topCount = 1;
          } else if (score == bestScore) {
            topCount++;
          }
        }
        final bool uniqueTop = topCount == 1;
        if (!uniqueTop || bestScore < 90 || mode.toLowerCase() != 'automatisch') {
          bestId = null;
        }
        matchedJournalId = bestId;
      }

      // Review status from decisions: linked → gebucht; user-selected
      // category → geprueft; rule-assigned or none → neu. A rule suggestion
      // without explicit user decision never closes the row.
      final String datumStr = _formatDate(tx.datum!);
      final String status = matchedJournalId != null ? 'gebucht' : (hasReviewedCategory ? 'geprueft' : 'neu');

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
      return (inserted: true, duplicate: false, autoCategorized: wasAutoCategorized, failure: null);
    } catch (error, stackTrace) {
      // A unique-index race is a duplicate outcome, not a failed row.
      bool becameDuplicate = false;
      try {
        final String normalized = _normalizeBetragForStorage(tx.betrag, l10n);
        becameDuplicate = await _hasDuplicate(kontoId: kontoId, hash: _hashFor(tx, normalized));
      } catch (_) {
        // Keep the original insert failure as the actionable diagnostic.
      }
      if (becameDuplicate && !allowDuplicateOverride) {
        return (inserted: false, duplicate: true, autoCategorized: false, failure: null);
      }

      final RawTx failureTransaction = tx.sourceRowNumber == null ? tx.copyWith(sourceRowNumber: rowNumber) : tx;
      debugPrint('bank_import row $rowNumber insert failed: ${_errorMessage(error, l10n)}');
      // Preserve the original stack in logs while allowing other rows to be
      // persisted and the caller to retry this row.
      debugPrint('$stackTrace');
      return (
        inserted: false,
        duplicate: false,
        autoCategorized: false,
        failure: ImportRowFailure(
          rowNumber: rowNumber,
          transaction: failureTransaction,
          error: _errorMessage(error, l10n),
          diagnosticCodes: const <String>['database_write_failed'],
          kategorieQuelle: rowQuelle,
        ),
      );
    }
  }

  void _validateImport({required int kontoId, required List<RawTx> rawTxs, required AppLocalizations l10n}) {
    if (kontoId <= 0) {
      throw BankImportException(l10n.bankInvalidImportNoAccount, recoveryAction: l10n.bankRecoverySelectAccount);
    }
    if (rawTxs.isEmpty) {
      throw BankImportException(l10n.bankNoTransactionsToImport, recoveryAction: l10n.bankRecoverySelectSupportedFile);
    }
  }

  Future<int> _createHistory({
    required int kontoId,
    required String dateiname,
    required BankTemplate? template,
    required AppLocalizations l10n,
  }) async {
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
              l10n.bankHistoryCreateFailed(_errorMessage(minimalError, l10n)),
              recoveryAction: l10n.bankRecoveryFixDatabase,
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
    List<String>? fileRejectionCodes,
  }) async {
    final List<String> diagnostics =
        diagnosticsOverride ?? failures.map((failure) => failure.toDiagnostic()).toList(growable: false);
    final String? details;
    if (failures.isNotEmpty) {
      details = BankImportFailurePayload.encodeRows(
        failures.map((failure) => failure.toPayloadJson()).toList(growable: false),
      );
    } else if (fileRejectionCodes != null) {
      details = BankImportFailurePayload.encodeFileRejection(fileRejectionCodes);
    } else if (diagnostics.isNotEmpty) {
      details = jsonEncode(
        diagnostics.map((diagnostic) => <String, Object?>{'message': diagnostic}).toList(growable: false),
      );
    } else {
      details = null;
    }
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

  Future<String> _uniqueOverrideHash({
    required int kontoId,
    required String hash,
    required AppLocalizations l10n,
  }) async {
    for (int suffix = 1; suffix <= 100; suffix++) {
      final String candidate = '$hash-$suffix';
      if (!await _hasDuplicate(kontoId: kontoId, hash: candidate)) return candidate;
    }
    throw BankImportException(l10n.bankDuplicateOverrideLimit, recoveryAction: l10n.bankRecoveryCheckDuplicates);
  }

  String _hashFor(RawTx tx, String normalizedAmount) {
    final String? supplied = tx.dedupeHash?.trim();
    if (supplied != null && supplied.isNotEmpty) return supplied;
    return computeDedupeHash(tx.datum!, normalizedAmount, tx.partner, tx.verwendungszweck);
  }

  String _statusFor({required int imported, required int failed}) {
    if (failed == 0) return _historyImportedStatus;
    return imported == 0 ? _historyFailedStatus : _historyPartialStatus;
  }

  String _historyStatusWithDiagnostics(String status, List<String> diagnostics) {
    if (diagnostics.isEmpty) return status;
    return '$status: ${diagnostics.join(' | ')}';
  }

  String _errorMessage(Object error, AppLocalizations l10n) {
    final String message = error.toString().trim();
    return message.isEmpty ? l10n.bankUnknownError : message;
  }

  bool _isValidDate(DateTime value) {
    final DateTime dateOnly = DateTime(value.year, value.month, value.day);
    return dateOnly.year == value.year && dateOnly.month == value.month && dateOnly.day == value.day;
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _normalizeBetragForStorage(String raw, AppLocalizations l10n) {
    return _parseBetrag(raw, l10n);
  }

  ({List<String> diagnostics, List<String> codes, String? normalizedAmount}) _validateRow(
    RawTx tx,
    AppLocalizations l10n,
  ) {
    final List<String> diagnostics = <String>[];
    final List<String> codes = <String>[];
    if (tx.datum == null || !_isValidDate(tx.datum!)) {
      diagnostics.add(l10n.bankInvalidDate);
      codes.add('invalid_date');
    }

    String? normalizedAmount;
    try {
      normalizedAmount = _normalizeBetragForStorage(tx.betrag, l10n);
    } catch (_) {
      diagnostics.add(l10n.bankInvalidAmount);
      codes.add('invalid_amount');
    }
    if (diagnostics.isNotEmpty && codes.isEmpty) {
      codes.add('missing_required_data');
    }
    return (diagnostics: diagnostics, codes: codes, normalizedAmount: normalizedAmount);
  }

  /// Parse CSV into RawTx — delimiter from template or auto-detect.
  /// Throws [BankImportException] on invalid file / no template match.
  List<RawTx> parseCsv({required String csv, BankTemplate? template, required String locale}) {
    final AppLocalizations l10n = _l10nFor(locale);
    final String trimmed = csv.trim();
    if (trimmed.isEmpty) {
      throw BankImportException(l10n.bankEmptyFile);
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
      throw BankImportException(l10n.bankNoHeader);
    }
    // Header must not be BOM-only.
    headerLine = headerLine.trim();
    if (headerLine.startsWith('\uFEFF')) {
      headerLine = headerLine.substring(1);
    }
    final String delimiter = template?.delimiter ?? _detectDelimiter(headerLine, l10n);
    final List<String> headerCols = _splitCsvLine(headerLine, delimiter, l10n: l10n);
    if (headerCols.isEmpty || headerCols.every((c) => c.trim().isEmpty)) {
      throw BankImportException(l10n.bankNoHeader);
    }

    // Build column index map via template mapping + alias fallback.
    final Map<String, String> mapping = template?.fieldMapping ?? const <String, String>{};

    final int? idxDatum = _findIdx(headerCols, 'datum', mapping);
    final int? idxBetrag = _findIdx(headerCols, 'betrag', mapping);
    final int? idxVerwend = _findIdx(headerCols, 'verwendungszweck', mapping);
    final int? idxPartner = _findIdx(headerCols, 'partner', mapping);
    final int? idxGegen = _findIdx(headerCols, 'gegenkonto', mapping);

    if (idxDatum == null || idxBetrag == null) {
      throw BankImportException(l10n.bankNoTemplateFound);
    }

    final List<RawTx> out = <RawTx>[];
    for (int i = headerIdx + 1; i < rawLines.length; i++) {
      final String line = rawLines[i];
      if (line.trim().isEmpty) continue;
      final List<String> cols = _splitCsvLine(line, delimiter, rowNumber: i + 1, l10n: l10n);
      // Skip rows where all cols empty.
      if (cols.every((c) => c.trim().isEmpty)) continue;
      // If row has fewer columns than header, pad with empty.
      // If more, truncate to header length — preserve logical idx access.
      final String datumRaw = idxDatum < cols.length ? cols[idxDatum].trim() : '';
      final String betragRaw = idxBetrag < cols.length ? cols[idxBetrag].trim() : '';
      DateTime? datum;
      try {
        datum = _parseDate(datumRaw, template?.dateFormat, l10n);
      } catch (_) {
        datum = null;
      }
      String betrag = betragRaw;
      try {
        betrag = _parseBetrag(betragRaw, l10n);
      } catch (_) {}

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
          rawDatum: datumRaw,
          rawBetrag: betragRaw,
          sourceRowNumber: i + 1,
        ),
      );
    }

    if (out.isEmpty) {
      // ponytail: empty file after header — treat as invalid for upload step.
      // Spec zero-transaction summary belongs to import step, not upload parse.
      // For upload, surface as template/parse error to block advancement.
      throw BankImportException(l10n.bankNoTemplateFoundNoTransactions);
    }
    return out;
  }

  // ── CAMT XML ───────────────────────────────────────────────────────

  /// Parse CAMT.053 XML into [RawTx] via regex without xml package.
  /// ponytail: regex ceiling — `<Ntry>` blocks + `<Amt>`/`<Dt>`/`<Ustrd>`/`<Nm>`/`<IBAN>`.
  /// Handles comma/dot amounts and CdtDbtInd DBIT/CRDT. Throws [BankImportException]
  /// for non-CAMT (unsupported) or invalid/malformed XML.
  List<RawTx> parseCamtXml(String xml, {required String locale}) {
    final AppLocalizations l10n = _l10nFor(locale);
    final String trimmed = xml.trim();
    if (trimmed.isEmpty) {
      throw BankImportException(l10n.bankEmptyFile);
    }
    if (!trimmed.contains('<') || !trimmed.contains('>')) {
      throw BankImportException(l10n.bankInvalidXmlNoTag);
    }
    if (!trimmed.contains('</')) {
      throw BankImportException(l10n.bankInvalidXmlNoClosingTag);
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

    _validateCamtStructure(trimmed, l10n);

    if (hasDocument && !trimmed.contains('</Document') && !trimmed.contains('</document')) {
      throw BankImportException(l10n.bankInvalidXmlDocumentUnclosed);
    }

    final RegExp ntryReg = RegExp(
      r'<\s*(?:\w+:)?Ntry\b[^>]*>(.*?)</\s*(?:\w+:)?Ntry\s*>',
      dotAll: true,
      caseSensitive: false,
    );
    final int openingNtries = RegExp(r'<\s*(?:\w+:)?Ntry\b[^>]*>', caseSensitive: false).allMatches(trimmed).length;
    final int closingNtries = RegExp(r'</\s*(?:\w+:)?Ntry\s*>', caseSensitive: false).allMatches(trimmed).length;
    if (openingNtries != closingNtries) {
      throw BankImportException(l10n.bankInvalidXmlNtryUnclosed);
    }

    final Iterable<RegExpMatch> matches = ntryReg.allMatches(trimmed);
    if (matches.isEmpty) {
      if (trimmed.contains('<Ntry') || trimmed.contains(':Ntry')) {
        throw BankImportException(l10n.bankInvalidXmlNtryUnclosed);
      }
      throw BankImportException(l10n.bankNoTransactionsFound);
    }

    final List<RawTx> out = <RawTx>[];
    for (final RegExpMatch m in matches) {
      final String ntryOuter = m.group(0) ?? '';
      final String ntryContent = m.group(1) ?? '';

      // Amount — <Amt> with optional attributes
      final RegExp amtReg = RegExp(
        r'<\s*(?:\w+:)?Amt\b[^>]*>([^<]*)</\s*(?:\w+:)?Amt\s*>'
        r'|<\s*(?:\w+:)?Amt\b[^>]*/\s*>',
        caseSensitive: false,
      );
      RegExpMatch? amtM = amtReg.firstMatch(ntryOuter);
      amtM ??= amtReg.firstMatch(ntryContent);
      if (amtM == null) {
        throw BankImportException(l10n.bankAmountMissingNtry);
      }
      final String amtRaw = amtM.group(1)?.trim() ?? '';

      // Credit/Debit indicator
      final RegExp cdtReg = RegExp(
        r'<\s*(?:\w+:)?CdtDbtInd\s*>([^<]+)</\s*(?:\w+:)?CdtDbtInd\s*>',
        caseSensitive: false,
      );
      final RegExpMatch? cdtM = cdtReg.firstMatch(ntryContent) ?? cdtReg.firstMatch(ntryOuter);
      final String? cdt = cdtM?.group(1)?.trim().toUpperCase();

      // Parse betrag with CdtDbtInd handling via _parseBetrag
      String betrag = amtRaw;
      String effective = amtRaw;
      try {
        final String stripped = amtRaw.replaceFirst(RegExp('^[+-]'), '').trim();
        if (cdt == 'DBIT') {
          effective = '-$stripped';
        } else if (cdt == 'CRDT') {
          effective = stripped;
        }
        betrag = _parseBetrag(effective, l10n);
      } catch (_) {}

      // Datum — prefer BookgDt/Dt, then ValDt/Dt, then generic Dt. Present
      // self-closing Dt elements are empty values, not missing elements.
      final RegExp dtReg = _camtValueRegExp('Dt');
      String? dtRaw;
      for (final String source in <String>[ntryContent, ntryOuter]) {
        for (final String container in <String>['BookgDt', 'ValDt']) {
          final RegExp containerReg = RegExp(
            r'<\s*(?:\w+:)?' + container + r'\b[^>]*>(.*?)</\s*(?:\w+:)?' + container + r'\s*>',
            dotAll: true,
            caseSensitive: false,
          );
          final RegExpMatch? containerMatch = containerReg.firstMatch(source);
          final RegExpMatch? nestedDate = containerMatch == null
              ? null
              : dtReg.firstMatch(containerMatch.group(1) ?? '');
          if (nestedDate != null) {
            dtRaw = nestedDate.group(1)?.trim() ?? '';
            break;
          }
        }
        if (dtRaw == null) {
          final RegExpMatch? genericDate = dtReg.firstMatch(source);
          if (genericDate != null) {
            dtRaw = genericDate.group(1)?.trim() ?? '';
          }
        }
        if (dtRaw != null) break;
      }
      if (dtRaw == null) {
        throw BankImportException(l10n.bankDateMissingNtry);
      }
      DateTime? datum;
      try {
        datum = _parseDate(dtRaw, null, l10n);
      } catch (_) {
        datum = null;
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
          rawDatum: dtRaw,
          rawBetrag: amtRaw,
          sourceRowNumber: out.length + 1,
        ),
      );
    }

    if (out.isEmpty) {
      throw BankImportException(l10n.bankNoTransactionsFound);
    }
    return out;
  }

  void _validateCamtStructure(String xml, AppLocalizations l10n) {
    final String withoutComments = xml
        .replaceAll(RegExp('<!--.*?-->', dotAll: true), '')
        .replaceAll(RegExp(r'<\?.*?\?>', dotAll: true), '');
    final RegExp tagReg = RegExp(r'<\s*(/?)\s*([A-Za-z_][\w:.-]*)(?:\s[^>]*)?(\/?)\s*>', multiLine: true);
    final List<String> stack = <String>[];
    for (final RegExpMatch match in tagReg.allMatches(withoutComments)) {
      final String name = match.group(2)!.toLowerCase();
      final bool closing = match.group(1) == '/';
      final bool selfClosing = match.group(3) == '/' || RegExp(r'/\s*>$').hasMatch(match.group(0)!);
      if (closing) {
        if (stack.isEmpty || stack.removeLast() != name) {
          throw BankImportException(l10n.bankInvalidXmlMismatched);
        }
      } else if (!selfClosing) {
        stack.add(name);
      }
    }
    if (stack.isNotEmpty) {
      throw BankImportException(l10n.bankInvalidXmlTagUnclosed);
    }
  }

  RegExp _camtValueRegExp(String elementName) => RegExp(
    '<\\s*(?:\\w+:)?$elementName\\b[^>]*>([^<]*)</\\s*(?:\\w+:)?$elementName\\s*>'
    '|<\\s*(?:\\w+:)?$elementName\\b[^>]*/\\s*>',
    caseSensitive: false,
  );

  String _detectDelimiter(String headerLine, AppLocalizations l10n) {
    final int semicolon = _countOutsideQuotes(headerLine, ';');
    final int comma = _countOutsideQuotes(headerLine, ',');
    if (semicolon == 0 && comma == 0) {
      throw BankImportException(l10n.bankNoTemplateFound);
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

  List<String> _splitCsvLine(String line, String delimiter, {int? rowNumber, required AppLocalizations l10n}) {
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
      final String suffix = rowNumber == null ? '' : l10n.bankCsvRowSuffix(rowNumber);
      throw BankImportException(
        '${l10n.bankCsvUnclosedQuotes}$suffix',
        rowNumber: rowNumber,
        recoveryAction: l10n.bankRecoveryFixCsvRow,
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

  DateTime _parseDate(String raw, String? templateFormat, AppLocalizations l10n) {
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
    throw BankImportException(l10n.bankDateInvalidRaw(raw));
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

  String _parseBetrag(String raw, AppLocalizations l10n) {
    String t = raw.trim();
    // Remove common currency noise.
    t = t.replaceAll('€', '').replaceAll('EUR', '').replaceAll('eur', '').trim();
    t = t.replaceAll('\u00A0', '').replaceAll(' ', '').replaceAll("'", '').trim();
    if (t.isEmpty) throw BankImportException(l10n.bankAmountMissing);
    final bool isNeg = t.startsWith('-');
    final bool isPos = t.startsWith('+');
    String unsigned = t;
    if (isNeg || isPos) unsigned = t.substring(1);
    if (unsigned.isEmpty) throw BankImportException(l10n.bankAmountInvalidRaw(raw));
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
      throw BankImportException(l10n.bankAmountInvalidRaw(raw));
    }
    final String normalized = isNeg ? '-$unsigned' : unsigned;
    // Range check before cents conversion: integer part <=10 digits, < 10^10.
    final List<String> parts = normalized.replaceFirst('-', '').split('.');
    final String intRaw = parts[0].isEmpty ? '0' : parts[0];
    final String intNoLead = intRaw.replaceFirst(RegExp('^0+'), '');
    final String effInt = intNoLead.isEmpty ? '0' : intNoLead;
    if (effInt.length > 10) {
      throw BankImportException(l10n.bankAmountOutOfRange(raw));
    }
    if (effInt.length == 10 && effInt.compareTo('9999999999') > 0) {
      throw BankImportException(l10n.bankAmountOutOfRange(raw));
    }
    // Use money helpers for cents truncation/padding to 2 decimals.
    final int cents = money.toCents(normalized);
    return money.fromCents(cents);
  }
}
