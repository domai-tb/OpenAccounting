import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:openaccounting/features/mahnwesen/kunden_sperrung_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnwesen_einstellungen_repository.dart';

/// Customer blocking service per spec §Kundensperrung + Mahnsperre.
/// ponytail ultra: one executor, string dates YYYY-MM-DD, cents-free.
class SperrungService {
  SperrungService(this.executor) : einstellungenRepo = MahnwesenEinstellungenRepository(executor);

  final QueryExecutor executor;
  final MahnwesenEinstellungenRepository einstellungenRepo;

  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= _doInit();

  Future<void> _doInit() async {
    await _ensureSperrungColumns();
    // Touch einstellungen to ensure singleton exists and columns.
    try {
      await einstellungenRepo.get();
    } catch (_) {}
  }

  Future<void> _ensureSperrungColumns() async {
    // ponytail: additive idempotent — ensure kunden + mahnwesen_einstellungen
    // columns exist for pre-existing DBs.
    try {
      final kCols = await executor.runSelect('PRAGMA table_info(kunden)', const <Object?>[]);
      final kNames = <String>{for (final r in kCols) (r['name'] as String?) ?? ''};
      if (!kNames.contains('mahngesperrt')) {
        try {
          await executor.runCustom('ALTER TABLE kunden ADD COLUMN mahngesperrt INTEGER NOT NULL DEFAULT 0');
        } catch (e) {
          debugPrint('sperrung: ALTER mahngesperrt failed: $e');
        }
      }
      if (!kNames.contains('mahngesperrt_bis')) {
        try {
          await executor.runCustom('ALTER TABLE kunden ADD COLUMN mahngesperrt_bis TEXT');
        } catch (e) {
          debugPrint('sperrung: ALTER mahngesperrt_bis failed: $e');
        }
      }
      if (!kNames.contains('mahngesperrt_grund')) {
        try {
          await executor.runCustom('ALTER TABLE kunden ADD COLUMN mahngesperrt_grund TEXT');
        } catch (e) {
          debugPrint('sperrung: ALTER mahngesperrt_grund failed: $e');
        }
      }
    } catch (e) {
      debugPrint('sperrung: _ensureSperrungColumns kunden failed: $e');
    }
    try {
      final eCols = await executor.runSelect('PRAGMA table_info(mahnwesen_einstellungen)', const <Object?>[]);
      final eNames = <String>{for (final r in eCols) (r['name'] as String?) ?? ''};
      if (!eNames.contains('schwelle_warnung')) {
        try {
          await executor.runCustom('ALTER TABLE mahnwesen_einstellungen ADD COLUMN schwelle_warnung INTEGER DEFAULT 2');
        } catch (e) {
          debugPrint('sperrung: ALTER schwelle_warnung failed: $e');
        }
      }
      if (!eNames.contains('schwelle_sperrung')) {
        try {
          await executor.runCustom(
            'ALTER TABLE mahnwesen_einstellungen ADD COLUMN schwelle_sperrung INTEGER DEFAULT 3',
          );
        } catch (e) {
          debugPrint('sperrung: ALTER schwelle_sperrung failed: $e');
        }
      }
    } catch (e) {
      debugPrint('sperrung: _ensureSperrungColumns einstellungen failed: $e');
    }
  }

  Future<int?> _maxStufeForKunde(int kundeId) async {
    await _ensureInitialized();
    // Prefer mahnungen.kunde_id, fallback via rechnungen join.
    int? maxStufe;
    try {
      final rows = await executor.runSelect(
        'SELECT MAX(ms.stufe) AS max_stufe '
        'FROM mahnungen m '
        'JOIN mahnstufen ms ON ms.id = m.stufe_id '
        'WHERE m.kunde_id = ?',
        <Object?>[kundeId],
      );
      final v = rows.isNotEmpty ? rows.single['max_stufe'] : null;
      maxStufe = _asInt(v);
    } catch (e) {
      debugPrint('sperrung: _maxStufeForKunde direct failed: $e');
    }
    if (maxStufe != null) return maxStufe;
    // Fallback via rechnungen.kunde_id when mahnungen.kunde_id null/empty.
    try {
      final rows2 = await executor.runSelect(
        'SELECT MAX(ms.stufe) AS max_stufe '
        'FROM mahnungen m '
        'JOIN mahnstufen ms ON ms.id = m.stufe_id '
        'JOIN rechnungen r ON r.id = m.rechnung_id '
        'WHERE r.kunde_id = ?',
        <Object?>[kundeId],
      );
      final v2 = rows2.isNotEmpty ? rows2.single['max_stufe'] : null;
      return _asInt(v2);
    } catch (e) {
      debugPrint('sperrung: _maxStufeForKunde fallback failed: $e');
      return null;
    }
  }

  Future<bool> isWarnung(int kundeId) async {
    final settings = await einstellungenRepo.get();
    if (!settings.aktiv) return false;
    final max = await _maxStufeForKunde(kundeId);
    if (max == null) return false;
    return max >= settings.schwelleWarnung;
  }

  Future<bool> isSperrung(int kundeId) async {
    final settings = await einstellungenRepo.get();
    if (!settings.aktiv) return false;
    final max = await _maxStufeForKunde(kundeId);
    if (max == null) return false;
    return max >= settings.schwelleSperrung;
  }

  Future<bool> isMahngesperrt(int kundeId, {DateTime? asOf}) async {
    await _ensureInitialized();
    final rows = await executor.runSelect(
      'SELECT mahngesperrt, mahngesperrt_bis FROM kunden WHERE id = ? LIMIT 1',
      <Object?>[kundeId],
    );
    if (rows.isEmpty) return false;
    final row = rows.single;
    if (!_asBool(row['mahngesperrt'])) return false;
    final bis = _asString(row['mahngesperrt_bis']);
    if (bis == null || bis.trim().isEmpty) return true;
    final trimmed = bis.trim();
    if (trimmed.length < 10) {
      throw const KundenSperrungException('Datum ungültig: YYYY-MM-DD erwartet');
    }
    final bisStr = trimmed.substring(0, 10);
    final dateRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegExp.hasMatch(bisStr)) {
      throw const KundenSperrungException('Datum ungültig: YYYY-MM-DD erwartet');
    }
    final parsedBis = DateTime.tryParse(bisStr);
    if (parsedBis == null || _toDateString(parsedBis) != bisStr) {
      throw const KundenSperrungException('Datum ungültig: YYYY-MM-DD erwartet');
    }
    final todayStr = _toDateString(asOf ?? DateTime.now());
    // ponytail: lexical YYYY-MM-DD compare equals date compare.
    return bisStr.compareTo(todayStr) >= 0;
  }

  /// Combined check: blocks new invoices if Mahnsperre OR Sperrung threshold.
  Future<bool> canCreateInvoice(int kundeId, {DateTime? asOf}) async {
    if (await isMahngesperrt(kundeId, asOf: asOf)) return false;
    if (await isSperrung(kundeId)) return false;
    return true;
  }

  Future<void> assertCanCreateInvoice(int kundeId, {DateTime? asOf}) async {
    final mahn = await isMahngesperrt(kundeId, asOf: asOf);
    if (mahn) {
      throw const KundenSperrungException('Kunde ist mahngesperrt');
    }
    if (await isSperrung(kundeId)) {
      throw const KundenSperrungException('Kunde gesperrt: Mahnstufe erreicht');
    }
  }

  Future<void> setMahnsperre(int kundeId, String reason, {String? bis}) async {
    await _ensureInitialized();
    if (reason.trim().isEmpty) {
      throw const KundenSperrungException('Grund ist Pflicht');
    }
    String? bisNorm;
    if (bis != null) {
      final t = bis.trim();
      if (t.isNotEmpty) {
        if (t.length < 10) {
          throw const KundenSperrungException('Datum ungültig: YYYY-MM-DD erwartet');
        }
        final dateRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
        if (!dateRegExp.hasMatch(t)) {
          throw const KundenSperrungException('Datum ungültig: YYYY-MM-DD erwartet');
        }
        final parsed = DateTime.tryParse(t);
        if (parsed == null || _toDateString(parsed) != t) {
          throw const KundenSperrungException('Datum ungültig: YYYY-MM-DD erwartet');
        }
        bisNorm = t.substring(0, 10);
      }
    }
    await executor.runUpdate(
      'UPDATE kunden SET mahngesperrt = 1, mahngesperrt_grund = ?, mahngesperrt_bis = ? WHERE id = ?',
      <Object?>[reason.trim(), bisNorm, kundeId],
    );
  }

  Future<void> removeMahnsperre(int kundeId) async {
    await _ensureInitialized();
    await executor.runUpdate(
      'UPDATE kunden SET mahngesperrt = 0, mahngesperrt_grund = NULL, mahngesperrt_bis = NULL WHERE id = ?',
      <Object?>[kundeId],
    );
  }

  /// Audit trail: chronological list of Mahnungen for kunde.
  Future<List<Mahnung>> getHistory(int kundeId) async {
    await _ensureInitialized();
    // Try kunde_id direct first; fallback to rechnungen join if needed.
    List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT m.id, m.rechnung_id, m.kunde_id, m.stufe_id, m.datum, m.betrag, '
        'm.gebuehr, m.zinsen, m.status, m.snapshot, '
        'COALESCE(m.gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'COALESCE(m.zinsen_bezahlt, 0) AS zinsen_bezahlt, '
        'COALESCE(m.uebernommene_gebuehr, 0) AS uebernommene_gebuehr, '
        'COALESCE(m.uebernommene_zinsen, 0) AS uebernommene_zinsen, '
        'm.versendet_am '
        'FROM mahnungen m '
        'WHERE m.kunde_id = ? '
        'ORDER BY m.datum ASC, m.id ASC',
        <Object?>[kundeId],
      );
      if (rows.isNotEmpty) return rows.map(_fromMahnungRow).toList(growable: false);
      // fallback via rechnungen.kunde_id when direct empty (legacy data)
      rows = await executor.runSelect(
        'SELECT m.id, m.rechnung_id, m.kunde_id, m.stufe_id, m.datum, m.betrag, '
        'm.gebuehr, m.zinsen, m.status, m.snapshot, '
        'COALESCE(m.gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'COALESCE(m.zinsen_bezahlt, 0) AS zinsen_bezahlt, '
        'COALESCE(m.uebernommene_gebuehr, 0) AS uebernommene_gebuehr, '
        'COALESCE(m.uebernommene_zinsen, 0) AS uebernommene_zinsen, '
        'm.versendet_am '
        'FROM mahnungen m '
        'JOIN rechnungen r ON r.id = m.rechnung_id '
        'WHERE r.kunde_id = ? '
        'ORDER BY m.datum ASC, m.id ASC',
        <Object?>[kundeId],
      );
      return rows.map(_fromMahnungRow).toList(growable: false);
    } catch (_) {
      // minimal fallback without bezahlt columns
      try {
        rows = await executor.runSelect(
          'SELECT m.id, m.rechnung_id, m.kunde_id, m.stufe_id, m.datum, m.betrag, '
          'm.gebuehr, m.zinsen, m.status, m.snapshot '
          'FROM mahnungen m WHERE m.kunde_id = ? ORDER BY m.datum ASC, m.id ASC',
          <Object?>[kundeId],
        );
        return rows.map(_fromMahnungRow).toList(growable: false);
      } catch (_) {
        return <Mahnung>[];
      }
    }
  }

  /// Dashboard: customers in warn status.
  Future<List<int>> warnKunden() async {
    await _ensureInitialized();
    final settings = await einstellungenRepo.get();
    // Find kundIds whose max stufe >= warn and < sperr? but we return all >= warn.
    final rows = await executor.runSelect(
      'SELECT m.kunde_id AS kid, MAX(ms.stufe) AS max_stufe '
      'FROM mahnungen m JOIN mahnstufen ms ON ms.id = m.stufe_id '
      'WHERE m.kunde_id IS NOT NULL '
      'GROUP BY m.kunde_id HAVING max_stufe >= ?',
      <Object?>[settings.schwelleWarnung],
    );
    return <int>[
      for (final r in rows)
        if (_asInt(r['kid']) != null) _asInt(r['kid'])!,
    ];
  }

  /// Dashboard: overdue invoices grouped by Mahnstufe (counts per stufe).
  Future<Map<int, int>> overdueGrouped() async {
    await _ensureInitialized();
    try {
      final rows = await executor.runSelect(
        'SELECT ms.stufe AS stufe, COUNT(*) AS cnt '
        'FROM rechnungen r '
        'JOIN mahnstufen ms ON ms.stufe = r.mahnstufe_aktuell '
        'WHERE r.mahnstufe_aktuell IS NOT NULL AND r.mahnstufe_aktuell > 0 '
        'GROUP BY ms.stufe ORDER BY ms.stufe ASC',
        const <Object?>[],
      );
      final map = <int, int>{};
      for (final r in rows) {
        final stufe = _asInt(r['stufe']);
        final cnt = _asInt(r['cnt']);
        if (stufe != null && cnt != null) map[stufe] = cnt;
      }
      return map;
    } catch (_) {
      return <int, int>{};
    }
  }

  Future<KundenSperrungStatus> status(int kundeId, {DateTime? asOf}) async {
    final warn = await isWarnung(kundeId);
    final sperr = await isSperrung(kundeId);
    final mahn = await isMahngesperrt(kundeId, asOf: asOf);
    final can = !sperr && !mahn;
    return KundenSperrungStatus(isWarnung: warn, isSperrung: sperr, isMahngesperrt: mahn, canCreateInvoice: can);
  }

  static String _toDateString(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String? _asString(Object? v) => v is String ? v : v?.toString();

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool _asBool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return v == '1' || v == 'true';
  }

  Mahnung _fromMahnungRow(Map<String, Object?> r) {
    // ponytail: local asMoney/asInt duped from repos — variant uses money.toCents vs manual clamp,
    // not byte-identical; helper extraction overhead exceeds benefit.
    String asMoney(Object? v) {
      if (v == null) return '0.00';
      if (v is num) return v.toStringAsFixed(2);
      final s = v.toString().trim();
      if (s.isEmpty) return '0.00';
      final n = num.tryParse(s.replaceAll(',', '.'));
      if (n == null) return '0.00';
      return n.toStringAsFixed(2);
    }

    String? asString(Object? v) => v is String ? v : v?.toString();
    int? asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final gebuehrStr = asMoney(r['gebuehr']);
    final gebuehrBezahltStr = asMoney(r['gebuehr_bezahlt']);
    final zinsenStr = asMoney(r['zinsen']);
    final zinsenBezahltStr = asMoney(r['zinsen_bezahlt']);
    final uebG = asMoney(r['uebernommene_gebuehr']);
    final uebZ = asMoney(r['uebernommene_zinsen']);
    // derive unbezahlt via clamp for test convenience — entity holds bezahlt/unbezahlt.
    num toNum(String s) => num.tryParse(s) ?? 0;
    final gCents = (toNum(gebuehrStr) * 100).round();
    final gBezahltCents = (toNum(gebuehrBezahltStr) * 100).round();
    final zCents = (toNum(zinsenStr) * 100).round();
    final zBezahltCents = (toNum(zinsenBezahltStr) * 100).round();
    final gUnbezStr = ((gCents - gBezahltCents).clamp(0, gCents) / 100).toStringAsFixed(2);
    final zUnbezStr = ((zCents - zBezahltCents).clamp(0, zCents) / 100).toStringAsFixed(2);
    return Mahnung(
      id: asInt(r['id']) ?? 0,
      rechnungId: asInt(r['rechnung_id']) ?? 0,
      kundeId: asInt(r['kunde_id']),
      stufeId: asInt(r['stufe_id']),
      datum: asString(r['datum']) ?? '',
      betrag: asMoney(r['betrag']),
      gebuehr: gebuehrStr,
      zinsen: zinsenStr,
      status: asString(r['status']) ?? 'offen',
      snapshot: asString(r['snapshot']),
      gebuehrBezahlt: gebuehrBezahltStr,
      gebuehrUnbezahlt: gUnbezStr,
      zinsenBezahlt: zinsenBezahltStr,
      zinsenUnbezahlt: zUnbezStr,
      uebernommeneGebuehr: uebG,
      uebernommeneZinsen: uebZ,
      versendetAm: asString(r['versendet_am']),
    );
  }
}

/// Alias for task spec naming.
typedef KundenSperrungService = SperrungService;
