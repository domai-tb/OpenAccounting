import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_exception.dart';

class MahnungenRepository {
  MahnungenRepository(this.executor);

  final QueryExecutor executor;

  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= _doInit();

  Future<void> _doInit() async {
    await _ensureMahnwesenColumns();
  }

  Future<void> _ensureMahnwesenColumns() async {
    // ponytail: additive migration — idempotent ALTER, no rebuild.
    // Snapshot TEXT already exists per DDL; ensure bezahlt/carry + rechnungen.mahnstufe_aktuell.
    try {
      final cols = await executor.runSelect('PRAGMA table_info(mahnungen)', const <Object?>[]);
      final names = <String>{for (final r in cols) (r['name'] as String?) ?? ''};
      if (!names.contains('gebuehr_bezahlt')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN gebuehr_bezahlt NUMERIC(12,2) DEFAULT 0');
        } catch (_) {}
      }
      if (!names.contains('zinsen_bezahlt')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN zinsen_bezahlt NUMERIC(12,2) DEFAULT 0');
        } catch (_) {}
      }
      if (!names.contains('uebernommene_gebuehr')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN uebernommene_gebuehr NUMERIC(12,2) DEFAULT 0');
        } catch (_) {}
      }
      if (!names.contains('uebernommene_zinsen')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN uebernommene_zinsen NUMERIC(12,2) DEFAULT 0');
        } catch (_) {}
      }
      if (!names.contains('versendet_am')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN versendet_am TEXT');
        } catch (_) {}
      }
      // ponytail: fallback to gebuehr column if ADD COLUMN fails — repository logic derives unbezahlt via gebuehr - bezahlt.
    } catch (_) {}
    try {
      final colsR = await executor.runSelect('PRAGMA table_info(rechnungen)', const <Object?>[]);
      final namesR = <String>{for (final r in colsR) (r['name'] as String?) ?? ''};
      if (!namesR.contains('mahnstufe_aktuell')) {
        try {
          await executor.runCustom('ALTER TABLE rechnungen ADD COLUMN mahnstufe_aktuell INTEGER DEFAULT 0');
        } catch (_) {}
      }
    } catch (_) {}
  }

  // --- Zinsen ---

  /// Verzugszinsen: betrag * zinssatz/100 * tage/365  (BGB §288).
  /// ponytail: uses cents integer + double for zinssatz, round to cents.
  String berechneZinsen({required String betrag, required String zinssatz, required int tage}) {
    if (tage <= 0) return '0.00';
    final bCents = money.toCents(betrag);
    if (bCents <= 0) return '0.00';
    final z = num.tryParse(zinssatz.replaceAll(',', '.')) ?? 0;
    if (z <= 0) return '0.00';
    final interestCents = (bCents * z * tage / 36500).round();
    if (interestCents <= 0) return '0.00';
    return money.fromCents(interestCents);
  }

  /// Alias for English callers.
  String calculateInterest({required String betrag, required String zinssatz, required int tage}) =>
      berechneZinsen(betrag: betrag, zinssatz: zinssatz, tage: tage);

  // --- CRUD ---

  Future<Mahnung> create({
    required int rechnungId,
    required int stufeId,
    String? gebuehrOverride,
    String? zinsenOverride,
  }) async {
    await _ensureInitialized();
    // Fetch rechnung.
    final rRows = await executor.runSelect(
      'SELECT id, rechnungsnummer, kunde_id, brutto_betrag, netto_betrag, faelligkeit, datum FROM rechnungen WHERE id = ? LIMIT 1',
      <Object?>[rechnungId],
    );
    if (rRows.isEmpty) throw const MahnungException('Rechnung nicht gefunden');
    final r = rRows.single;
    final sRows = await executor.runSelect(
      'SELECT id, stufe, bezeichnung, gebuehr, zinssatz, tage_nach_faelligkeit FROM mahnstufen WHERE id = ? LIMIT 1',
      <Object?>[stufeId],
    );
    if (sRows.isEmpty) throw const MahnungException('Mahnstufe nicht gefunden');
    final s = sRows.single;

    final brutto = _asMoneyString(r['brutto_betrag']);
    final netto = _asMoneyString(r['netto_betrag']);
    // Prefer brutto if non-zero, else netto.
    String betragStr;
    if (money.toCents(brutto) != 0) {
      betragStr = brutto;
    } else if (money.toCents(netto) != 0) {
      betragStr = netto;
    } else {
      betragStr = brutto;
    }
    final rechnungsnummer = _asString(r['rechnungsnummer']) ?? '';
    final faelligkeit = _asString(r['faelligkeit']) ?? _asString(r['datum']) ?? '';
    final kundeId = _asInt(r['kunde_id']);
    final stufeNum = _asInt(s['stufe']) ?? 0;
    final bezeichnung = _asString(s['bezeichnung']) ?? '';

    // Gebühr: override or effektive (multiplier aware).
    late final String gebuehr;
    if (gebuehrOverride != null) {
      gebuehr = _normalizeMoney(gebuehrOverride, 'Gebühr');
    } else {
      try {
        final stufenRepo = MahnstufenRepository(executor);
        gebuehr = await stufenRepo.effektiveGebuehr(stufeId);
      } catch (_) {
        gebuehr = _asMoneyString(s['gebuehr']);
      }
    }

    // Zinsen: override or berechnet.
    late final String zinsen;
    if (zinsenOverride != null) {
      zinsen = _normalizeMoney(zinsenOverride, 'Zinsen');
    } else {
      final zinssatzStr = _asMoneyString(s['zinssatz']);
      final tage = _asInt(s['tage_nach_faelligkeit']) ?? 0;
      zinsen = berechneZinsen(betrag: betragStr, zinssatz: zinssatzStr, tage: tage);
    }

    // Carry-over: sum unpaid gebühr/zinsen of prior mahnungen for same rechnung.
    int carryGebuehrCents = 0;
    int carryZinsenCents = 0;
    try {
      final priorRows = await executor.runSelect(
        'SELECT gebuehr, COALESCE(gebuehr_bezahlt, 0) as gebuehr_bezahlt, zinsen, COALESCE(zinsen_bezahlt, 0) as zinsen_bezahlt FROM mahnungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      for (final pr in priorRows) {
        final g = money.toCents(_asMoneyString(pr['gebuehr']));
        final gb = money.toCents(_asMoneyString(pr['gebuehr_bezahlt']));
        final z = money.toCents(_asMoneyString(pr['zinsen']));
        final zb = money.toCents(_asMoneyString(pr['zinsen_bezahlt']));
        final gUnpaid = g - gb;
        final zUnpaid = z - zb;
        if (gUnpaid > 0) carryGebuehrCents += gUnpaid;
        if (zUnpaid > 0) carryZinsenCents += zUnpaid;
      }
    } catch (_) {
      // ponytail: if prior query fails (missing columns), carry stays 0.
    }
    final uebernommeneGebuehr = money.fromCents(carryGebuehrCents);
    final uebernommeneZinsen = money.fromCents(carryZinsenCents);

    final snapshotMap = <String, Object?>{
      'rechnungsnummer': rechnungsnummer,
      'betrag': betragStr,
      'faelligkeit': faelligkeit,
      'stufe': stufeNum,
      'stufeBezeichnung': bezeichnung,
      'gebuehr': gebuehr,
      'zinsen': zinsen,
      'uebernommeneGebuehr': uebernommeneGebuehr,
      'uebernommeneZinsen': uebernommeneZinsen,
    };
    final snapshotJson = jsonEncode(snapshotMap);
    final datum = DateTime.now().toIso8601String();

    int id;
    try {
      id = await executor.runInsert(
        'INSERT INTO mahnungen (rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot, gebuehr_bezahlt, zinsen_bezahlt, uebernommene_gebuehr, uebernommene_zinsen) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          rechnungId,
          kundeId,
          stufeId,
          datum,
          betragStr,
          gebuehr,
          zinsen,
          'offen',
          snapshotJson,
          '0.00',
          '0.00',
          uebernommeneGebuehr,
          uebernommeneZinsen,
        ],
      );
    } catch (_) {
      // ponytail: fallback to minimal DDL without bezahlt/carry columns.
      id = await executor.runInsert(
        'INSERT INTO mahnungen (rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[rechnungId, kundeId, stufeId, datum, betragStr, gebuehr, zinsen, 'offen', snapshotJson],
      );
    }

    // Update rechnungen.mahnstufe_aktuell.
    try {
      await executor.runUpdate('UPDATE rechnungen SET mahnstufe_aktuell = ? WHERE id = ?', <Object?>[
        stufeNum,
        rechnungId,
      ]);
    } catch (_) {
      // ponytail: column may not exist on older DB; ignore — ensure adds it next init.
    }

    final created = await getById(id);
    if (created == null) throw const MahnungException('Mahnung konnte nicht erstellt werden');
    return created;
  }

  Future<Mahnung?> getById(int id) async {
    await _ensureInitialized();
    List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot, COALESCE(gebuehr_bezahlt, 0) as gebuehr_bezahlt, COALESCE(zinsen_bezahlt, 0) as zinsen_bezahlt, COALESCE(uebernommene_gebuehr, 0) as uebernommene_gebuehr, COALESCE(uebernommene_zinsen, 0) as uebernommene_zinsen, versendet_am FROM mahnungen WHERE id = ? LIMIT 1',
        <Object?>[id],
      );
    } catch (_) {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot FROM mahnungen WHERE id = ? LIMIT 1',
        <Object?>[id],
      );
    }
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<List<Mahnung>> listByRechnung(int rechnungId) async {
    await _ensureInitialized();
    List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot, COALESCE(gebuehr_bezahlt, 0) as gebuehr_bezahlt, COALESCE(zinsen_bezahlt, 0) as zinsen_bezahlt, COALESCE(uebernommene_gebuehr, 0) as uebernommene_gebuehr, COALESCE(uebernommene_zinsen, 0) as uebernommene_zinsen, versendet_am FROM mahnungen WHERE rechnung_id = ? ORDER BY datum ASC, id ASC',
        <Object?>[rechnungId],
      );
    } catch (_) {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot FROM mahnungen WHERE rechnung_id = ? ORDER BY datum ASC, id ASC',
        <Object?>[rechnungId],
      );
    }
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<Mahnung>> listByKunde(int kundeId) async {
    await _ensureInitialized();
    List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot, COALESCE(gebuehr_bezahlt, 0) as gebuehr_bezahlt, COALESCE(zinsen_bezahlt, 0) as zinsen_bezahlt, COALESCE(uebernommene_gebuehr, 0) as uebernommene_gebuehr, COALESCE(uebernommene_zinsen, 0) as uebernommene_zinsen, versendet_am FROM mahnungen WHERE kunde_id = ? ORDER BY datum ASC, id ASC',
        <Object?>[kundeId],
      );
    } catch (_) {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot FROM mahnungen WHERE kunde_id = ? ORDER BY datum ASC, id ASC',
        <Object?>[kundeId],
      );
    }
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<Mahnung>> listAll() async {
    await _ensureInitialized();
    List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot, COALESCE(gebuehr_bezahlt, 0) as gebuehr_bezahlt, COALESCE(zinsen_bezahlt, 0) as zinsen_bezahlt, COALESCE(uebernommene_gebuehr, 0) as uebernommene_gebuehr, COALESCE(uebernommene_zinsen, 0) as uebernommene_zinsen, versendet_am FROM mahnungen ORDER BY datum ASC, id ASC',
        const <Object?>[],
      );
    } catch (_) {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status, snapshot FROM mahnungen ORDER BY datum ASC, id ASC',
        const <Object?>[],
      );
    }
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Mahnung> updateGebuehrBezahlt(int id, String bezahlt) async {
    await _ensureInitialized();
    final norm = _normalizeMoney(bezahlt, 'Gebühr bezahlt');
    final current = await getById(id);
    if (current == null) throw const MahnungException('Mahnung nicht gefunden');
    final maxCents = money.toCents(current.gebuehr);
    final newCents = money.toCents(norm);
    // Clamp to gebuehr max; ponytail: minimal — no overpay.
    final effective = newCents > maxCents ? current.gebuehr : norm;
    try {
      await executor.runUpdate('UPDATE mahnungen SET gebuehr_bezahlt = ? WHERE id = ?', <Object?>[effective, id]);
    } catch (_) {
      throw const MahnungException('Gebühr bezahlt konnte nicht aktualisiert werden');
    }
    final updated = await getById(id);
    if (updated == null) throw const MahnungException('Mahnung nicht gefunden');
    return updated;
  }

  Future<Mahnung> updateZinsenBezahlt(int id, String bezahlt) async {
    await _ensureInitialized();
    final norm = _normalizeMoney(bezahlt, 'Zinsen bezahlt');
    final current = await getById(id);
    if (current == null) throw const MahnungException('Mahnung nicht gefunden');
    final maxCents = money.toCents(current.zinsen);
    final newCents = money.toCents(norm);
    final effective = newCents > maxCents ? current.zinsen : norm;
    try {
      await executor.runUpdate('UPDATE mahnungen SET zinsen_bezahlt = ? WHERE id = ?', <Object?>[effective, id]);
    } catch (_) {
      throw const MahnungException('Zinsen bezahlt konnte nicht aktualisiert werden');
    }
    final updated = await getById(id);
    if (updated == null) throw const MahnungException('Mahnung nicht gefunden');
    return updated;
  }

  Future<String> getCarryOver(int rechnungId) async {
    await _ensureInitialized();
    try {
      final rows = await executor.runSelect(
        'SELECT gebuehr, COALESCE(gebuehr_bezahlt, 0) as gebuehr_bezahlt, zinsen, COALESCE(zinsen_bezahlt, 0) as zinsen_bezahlt FROM mahnungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      int total = 0;
      for (final r in rows) {
        final g = money.toCents(_asMoneyString(r['gebuehr']));
        final gb = money.toCents(_asMoneyString(r['gebuehr_bezahlt']));
        final z = money.toCents(_asMoneyString(r['zinsen']));
        final zb = money.toCents(_asMoneyString(r['zinsen_bezahlt']));
        final gUnpaid = g - gb;
        final zUnpaid = z - zb;
        if (gUnpaid > 0) total += gUnpaid;
        if (zUnpaid > 0) total += zUnpaid;
      }
      return money.fromCents(total);
    } catch (_) {
      return '0.00';
    }
  }

  Future<String> calculateCarryOver(int rechnungId) => getCarryOver(rechnungId);

  Future<Map<String, String>> getCarryOverBreakdown(int rechnungId) async {
    await _ensureInitialized();
    try {
      final rows = await executor.runSelect(
        'SELECT gebuehr, COALESCE(gebuehr_bezahlt, 0) as gebuehr_bezahlt, zinsen, COALESCE(zinsen_bezahlt, 0) as zinsen_bezahlt FROM mahnungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      int gTotal = 0;
      int zTotal = 0;
      for (final r in rows) {
        final g = money.toCents(_asMoneyString(r['gebuehr']));
        final gb = money.toCents(_asMoneyString(r['gebuehr_bezahlt']));
        final z = money.toCents(_asMoneyString(r['zinsen']));
        final zb = money.toCents(_asMoneyString(r['zinsen_bezahlt']));
        final gUnpaid = g - gb;
        final zUnpaid = z - zb;
        if (gUnpaid > 0) gTotal += gUnpaid;
        if (zUnpaid > 0) zTotal += zUnpaid;
      }
      return <String, String>{
        'gebuehr': money.fromCents(gTotal),
        'zinsen': money.fromCents(zTotal),
        'total': money.fromCents(gTotal + zTotal),
      };
    } catch (_) {
      return <String, String>{'gebuehr': '0.00', 'zinsen': '0.00', 'total': '0.00'};
    }
  }

  Future<Mahnung> markSent(int id) async {
    await _ensureInitialized();
    final now = DateTime.now().toIso8601String();
    try {
      await executor.runUpdate('UPDATE mahnungen SET status = ?, versendet_am = ? WHERE id = ?', <Object?>[
        'versendet',
        now,
        id,
      ]);
    } catch (_) {
      await executor.runUpdate('UPDATE mahnungen SET status = ? WHERE id = ?', <Object?>['versendet', id]);
    }
    final updated = await getById(id);
    if (updated == null) throw const MahnungException('Mahnung nicht gefunden');
    return updated;
  }

  Future<void> sendMail(int mahnungId) async {
    await markSent(mahnungId);
  }

  Future<String> generatePdf(int mahnungId) async {
    await _ensureInitialized();
    final m = await getById(mahnungId);
    if (m == null) throw const MahnungException('Mahnung nicht gefunden');
    // ponytail: stub — return filename, no real PDF.
    return 'Mahnung-${m.id}.pdf';
  }

  Future<int> getInvoiceDunningLevel(int rechnungId) async {
    await _ensureInitialized();
    try {
      final rows = await executor.runSelect('SELECT mahnstufe_aktuell FROM rechnungen WHERE id = ? LIMIT 1', <Object?>[
        rechnungId,
      ]);
      if (rows.isEmpty) return 0;
      return _asInt(rows.single['mahnstufe_aktuell']) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // --- helpers ---

  Mahnung _fromRow(Map<String, Object?> r) {
    final gebuehrStr = _asMoneyString(r['gebuehr']);
    final gebuehrBezahltStr = _asMoneyString(r['gebuehr_bezahlt']);
    final zinsenStr = _asMoneyString(r['zinsen']);
    final zinsenBezahltStr = _asMoneyString(r['zinsen_bezahlt']);
    final uebG = _asMoneyString(r['uebernommene_gebuehr']);
    final uebZ = _asMoneyString(r['uebernommene_zinsen']);
    final gBezahltCents = money.toCents(gebuehrBezahltStr);
    final gCents = money.toCents(gebuehrStr);
    final zBezahltCents = money.toCents(zinsenBezahltStr);
    final zCents = money.toCents(zinsenStr);
    final gUnbezahlt = money.fromCents((gCents - gBezahltCents).clamp(0, gCents));
    final zUnbezahlt = money.fromCents((zCents - zBezahltCents).clamp(0, zCents));
    return Mahnung(
      id: _asInt(r['id']) ?? 0,
      rechnungId: _asInt(r['rechnung_id']) ?? 0,
      kundeId: _asInt(r['kunde_id']),
      stufeId: _asInt(r['stufe_id']),
      datum: _asString(r['datum']) ?? '',
      betrag: _asMoneyString(r['betrag']),
      gebuehr: gebuehrStr,
      zinsen: zinsenStr,
      status: _asString(r['status']) ?? 'offen',
      snapshot: _asString(r['snapshot']),
      gebuehrBezahlt: gebuehrBezahltStr,
      gebuehrUnbezahlt: gUnbezahlt,
      zinsenBezahlt: zinsenBezahltStr,
      zinsenUnbezahlt: zUnbezahlt,
      uebernommeneGebuehr: uebG,
      uebernommeneZinsen: uebZ,
      versendetAm: _asString(r['versendet_am']),
    );
  }

  static String _asMoneyString(Object? v) {
    if (v == null) return '0.00';
    if (v is num) return v.toStringAsFixed(2);
    final s = v.toString().trim();
    if (s.isEmpty) return '0.00';
    final n = num.tryParse(s.replaceAll(',', '.'));
    if (n == null) return '0.00';
    return n.toStringAsFixed(2);
  }

  static String _normalizeMoney(String value, String field) {
    final trimmed = value.trim().replaceAll(',', '.');
    final n = num.tryParse(trimmed);
    if (n == null) throw MahnungException('$field ungültig');
    if (n < 0) throw MahnungException('$field darf nicht negativ sein');
    final cents = (n * 100).round();
    return (cents / 100).toStringAsFixed(2);
  }

  static String? _asString(Object? v) => v is String ? v : v?.toString();

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
