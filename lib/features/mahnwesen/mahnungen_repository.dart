import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_exception.dart';

class MahnungenRepository {
  MahnungenRepository(this.executor, {this.profileDir});

  final QueryExecutor executor;
  final String? profileDir;

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
        } catch (e) {
          debugPrint('mahnungen alter gebuehr_bezahlt: $e');
        }
      }
      if (!names.contains('zinsen_bezahlt')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN zinsen_bezahlt NUMERIC(12,2) DEFAULT 0');
        } catch (e) {
          debugPrint('mahnungen alter zinsen_bezahlt: $e');
        }
      }
      if (!names.contains('uebernommene_gebuehr')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN uebernommene_gebuehr NUMERIC(12,2) DEFAULT 0');
        } catch (e) {
          debugPrint('mahnungen alter uebernommene_gebuehr: $e');
        }
      }
      if (!names.contains('uebernommene_zinsen')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN uebernommene_zinsen NUMERIC(12,2) DEFAULT 0');
        } catch (e) {
          debugPrint('mahnungen alter uebernommene_zinsen: $e');
        }
      }
      if (!names.contains('versendet_am')) {
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN versendet_am TEXT');
        } catch (e) {
          debugPrint('mahnungen alter versendet_am: $e');
        }
      }
      // ponytail: fallback to gebuehr column if ADD COLUMN fails — repository logic derives unbezahlt via gebuehr - bezahlt.
    } catch (e) {
      debugPrint('mahnungen ensure mahnungen: $e');
    }
    try {
      final colsR = await executor.runSelect('PRAGMA table_info(rechnungen)', const <Object?>[]);
      final namesR = <String>{for (final r in colsR) (r['name'] as String?) ?? ''};
      if (!namesR.contains('mahnstufe_aktuell')) {
        try {
          await executor.runCustom('ALTER TABLE rechnungen ADD COLUMN mahnstufe_aktuell INTEGER DEFAULT 0');
        } catch (e) {
          debugPrint('mahnungen alter mahnstufe_aktuell: $e');
        }
      }
    } catch (e) {
      debugPrint('mahnungen ensure rechnungen: $e');
    }
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
      'SELECT id, rechnungsnummer, kunde_id, brutto_betrag, '
      'netto_betrag, faelligkeit, datum '
      'FROM rechnungen WHERE id = ? LIMIT 1',
      <Object?>[rechnungId],
    );
    if (rRows.isEmpty) throw const MahnungException('Rechnung nicht gefunden');
    final r = rRows.single;
    final sRows = await executor.runSelect(
      'SELECT id, stufe, bezeichnung, gebuehr, zinssatz, '
      'tage_nach_faelligkeit '
      'FROM mahnstufen WHERE id = ? LIMIT 1',
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
      } catch (e) {
        debugPrint('mahnungen effektiveGebuehr: $e');
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

    final datum = DateTime.now().toIso8601String();
    int id = 0;
    String uebernommeneGebuehr = '0.00';
    String uebernommeneZinsen = '0.00';

    // ponytail: atomic transaction for carry + insert + rechnung update.
    await executor.runCustom('BEGIN');
    try {
      int carryGebuehrCents = 0;
      int carryZinsenCents = 0;
      try {
        final priorRows = await executor.runSelect(
          'SELECT gebuehr, COALESCE(gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
          'zinsen, COALESCE(zinsen_bezahlt, 0) AS zinsen_bezahlt '
          'FROM mahnungen WHERE rechnung_id = ?',
          <Object?>[rechnungId],
        );
        carryGebuehrCents = _sumUnpaid(priorRows, 'gebuehr', 'gebuehr_bezahlt');
        carryZinsenCents = _sumUnpaid(priorRows, 'zinsen', 'zinsen_bezahlt');
      } catch (e) {
        debugPrint('mahnungen carry: $e');
      }
      uebernommeneGebuehr = money.fromCents(carryGebuehrCents);
      uebernommeneZinsen = money.fromCents(carryZinsenCents);

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

      try {
        id = await executor.runInsert(
          'INSERT INTO mahnungen (rechnung_id, kunde_id, stufe_id, datum, '
          'betrag, gebuehr, zinsen, status, snapshot, '
          'gebuehr_bezahlt, zinsen_bezahlt, uebernommene_gebuehr, '
          'uebernommene_zinsen) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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
      } catch (e) {
        debugPrint('mahnungen insert full: $e');
        // ponytail: fallback to minimal DDL without bezahlt/carry columns.
        id = await executor.runInsert(
          'INSERT INTO mahnungen (rechnung_id, kunde_id, stufe_id, datum, '
          'betrag, gebuehr, zinsen, status, snapshot) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[rechnungId, kundeId, stufeId, datum, betragStr, gebuehr, zinsen, 'offen', snapshotJson],
        );
      }

      // ponytail: kein Stufen-Update beim Entwurf — die Stufe schaltet erst
      // nach Transport-Annahme weiter (markTransportAccepted).

      await executor.runCustom('COMMIT');
    } catch (e) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (e2) {
        debugPrint('mahnungen rollback: $e2');
      }
      rethrow;
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
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot, '
        'COALESCE(gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'COALESCE(zinsen_bezahlt, 0) AS zinsen_bezahlt, '
        'COALESCE(uebernommene_gebuehr, 0) AS uebernommene_gebuehr, '
        'COALESCE(uebernommene_zinsen, 0) AS uebernommene_zinsen, '
        'versendet_am '
        'FROM mahnungen WHERE id = ? LIMIT 1',
        <Object?>[id],
      );
    } catch (e) {
      debugPrint('mahnungen getById fallback: $e');
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot '
        'FROM mahnungen WHERE id = ? LIMIT 1',
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
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot, '
        'COALESCE(gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'COALESCE(zinsen_bezahlt, 0) AS zinsen_bezahlt, '
        'COALESCE(uebernommene_gebuehr, 0) AS uebernommene_gebuehr, '
        'COALESCE(uebernommene_zinsen, 0) AS uebernommene_zinsen, '
        'versendet_am '
        'FROM mahnungen WHERE rechnung_id = ? ORDER BY datum ASC, id ASC',
        <Object?>[rechnungId],
      );
    } catch (e) {
      debugPrint('mahnungen listByRechnung fallback: $e');
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot '
        'FROM mahnungen WHERE rechnung_id = ? ORDER BY datum ASC, id ASC',
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
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot, '
        'COALESCE(gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'COALESCE(zinsen_bezahlt, 0) AS zinsen_bezahlt, '
        'COALESCE(uebernommene_gebuehr, 0) AS uebernommene_gebuehr, '
        'COALESCE(uebernommene_zinsen, 0) AS uebernommene_zinsen, '
        'versendet_am '
        'FROM mahnungen WHERE kunde_id = ? ORDER BY datum ASC, id ASC',
        <Object?>[kundeId],
      );
    } catch (e) {
      debugPrint('mahnungen listByKunde fallback: $e');
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot '
        'FROM mahnungen WHERE kunde_id = ? ORDER BY datum ASC, id ASC',
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
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot, '
        'COALESCE(gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'COALESCE(zinsen_bezahlt, 0) AS zinsen_bezahlt, '
        'COALESCE(uebernommene_gebuehr, 0) AS uebernommene_gebuehr, '
        'COALESCE(uebernommene_zinsen, 0) AS uebernommene_zinsen, '
        'versendet_am '
        'FROM mahnungen ORDER BY datum ASC, id ASC',
        const <Object?>[],
      );
    } catch (e) {
      debugPrint('mahnungen listAll fallback: $e');
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot '
        'FROM mahnungen ORDER BY datum ASC, id ASC',
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
    } catch (e) {
      debugPrint('mahnungen updateGebuehrBezahlt: $e');
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
    } catch (e) {
      debugPrint('mahnungen updateZinsenBezahlt: $e');
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
        'SELECT gebuehr, COALESCE(gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'zinsen, COALESCE(zinsen_bezahlt, 0) AS zinsen_bezahlt '
        'FROM mahnungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      int total = 0;
      total += _sumUnpaid(rows, 'gebuehr', 'gebuehr_bezahlt');
      total += _sumUnpaid(rows, 'zinsen', 'zinsen_bezahlt');
      return money.fromCents(total);
    } catch (e) {
      debugPrint('mahnungen getCarryOver: $e');
      return '0.00';
    }
  }

  Future<String> calculateCarryOver(int rechnungId) => getCarryOver(rechnungId);

  Future<Map<String, String>> getCarryOverBreakdown(int rechnungId) async {
    await _ensureInitialized();
    try {
      final rows = await executor.runSelect(
        'SELECT gebuehr, COALESCE(gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'zinsen, COALESCE(zinsen_bezahlt, 0) AS zinsen_bezahlt '
        'FROM mahnungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      final gTotal = _sumUnpaid(rows, 'gebuehr', 'gebuehr_bezahlt');
      final zTotal = _sumUnpaid(rows, 'zinsen', 'zinsen_bezahlt');
      return <String, String>{
        'gebuehr': money.fromCents(gTotal),
        'zinsen': money.fromCents(zTotal),
        'total': money.fromCents(gTotal + zTotal),
      };
    } catch (e) {
      debugPrint('mahnungen getCarryOverBreakdown: $e');
      return <String, String>{'gebuehr': '0.00', 'zinsen': '0.00', 'total': '0.00'};
    }
  }

  Future<Mahnung> markTransportAccepted(int id, {required int stufeNummer}) async {
    await _ensureInitialized();
    final now = DateTime.now().toIso8601String();
    final current = await getById(id);
    if (current == null) throw const MahnungException('Mahnung nicht gefunden');
    await executor.runCustom('BEGIN');
    try {
      try {
        await executor.runUpdate('UPDATE mahnungen SET status = ?, versendet_am = ? WHERE id = ?', <Object?>[
          'versendet',
          now,
          id,
        ]);
      } catch (e) {
        debugPrint('mahnungen markTransportAccepted: $e');
        await executor.runUpdate('UPDATE mahnungen SET status = ? WHERE id = ?', <Object?>['versendet', id]);
      }
      try {
        await executor.runUpdate('UPDATE rechnungen SET mahnstufe_aktuell = ? WHERE id = ?', <Object?>[
          stufeNummer,
          current.rechnungId,
        ]);
      } catch (e) {
        debugPrint('mahnungen update mahnstufe accepted: $e');
      }
      await executor.runCustom('COMMIT');
    } catch (e) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (e2) {
        debugPrint('mahnungen rollback accepted: $e2');
      }
      rethrow;
    }
    final updated = await getById(id);
    if (updated == null) throw const MahnungException('Mahnung nicht gefunden');
    return updated;
  }

  /// Höchste transport-akzeptierte Stufe einer Rechnung (0 = keine).
  Future<int> currentAcceptedLevel(int rechnungId) async {
    await _ensureInitialized();
    try {
      final rows = await executor.runSelect(
        'SELECT MAX(ms.stufe) AS max_stufe FROM mahnungen m '
        'JOIN mahnstufen ms ON ms.id = m.stufe_id '
        "WHERE m.rechnung_id = ? AND m.status = 'versendet'",
        <Object?>[rechnungId],
      );
      if (rows.isEmpty) return 0;
      return _asInt(rows.single['max_stufe']) ?? 0;
    } catch (e) {
      debugPrint('mahnungen currentAcceptedLevel: $e');
      return 0;
    }
  }

  Future<Mahnung?> findByRechnungAndStufe(int rechnungId, int stufeId) async {
    await _ensureInitialized();
    List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot, '
        'COALESCE(gebuehr_bezahlt, 0) AS gebuehr_bezahlt, '
        'COALESCE(zinsen_bezahlt, 0) AS zinsen_bezahlt, '
        'COALESCE(uebernommene_gebuehr, 0) AS uebernommene_gebuehr, '
        'COALESCE(uebernommene_zinsen, 0) AS uebernommene_zinsen, '
        'versendet_am '
        'FROM mahnungen WHERE rechnung_id = ? AND stufe_id = ? ORDER BY id ASC LIMIT 1',
        <Object?>[rechnungId, stufeId],
      );
    } catch (e) {
      debugPrint('mahnungen findByRechnungAndStufe fallback: $e');
      rows = await executor.runSelect(
        'SELECT id, rechnung_id, kunde_id, stufe_id, datum, betrag, '
        'gebuehr, zinsen, status, snapshot '
        'FROM mahnungen WHERE rechnung_id = ? AND stufe_id = ? ORDER BY id ASC LIMIT 1',
        <Object?>[rechnungId, stufeId],
      );
    }
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  /// Setzt die Stufe einer vollständig beglichenen Rechnung zurück.
  Future<void> clearInvoiceLevel(int rechnungId) async {
    await _ensureInitialized();
    try {
      await executor.runUpdate('UPDATE rechnungen SET mahnstufe_aktuell = 0 WHERE id = ?', <Object?>[rechnungId]);
    } catch (e) {
      debugPrint('mahnungen clearInvoiceLevel: $e');
    }
  }

  /// Kanonische Erstellung aus dem abgerechneten Saldo (DunningService-Pfad).
  ///
  /// Snapshotet Rechnungsnummer, Fälligkeit, Kunde, Stufe, offenen Saldo,
  /// effektive Gebühr, Zinssegmente, Zinssumme und übernommene Beträge.
  /// Erstellt keinen Brief ohne positiven Saldo und fasst keine Rechnungen
  /// zusammen. Ein Entwurf schaltet die Rechnungsstufe NICHT weiter.
  Future<Mahnung> createSettled({
    required int rechnungId,
    required int stufeId,
    required String rechnungsnummer,
    required String faelligkeit,
    required int? kundeId,
    required int stufeNummer,
    required String stufenBezeichnung,
    required String outstandingPrincipal,
    required String effektiveGebuehr,
    required String zinssumme,
    required String zinssegmenteJson,
    required String uebernommeneGebuehr,
    required String uebernommeneZinsen,
  }) async {
    await _ensureInitialized();
    if (money.toCents(outstandingPrincipal) <= 0) {
      throw const MahnungException('Ohne positiven Saldo keine Mahnung');
    }
    final datum = DateTime.now().toIso8601String();
    final snapshotMap = <String, Object?>{
      'rechnungsnummer': rechnungsnummer,
      'betrag': outstandingPrincipal,
      'faelligkeit': faelligkeit,
      'stufe': stufeNummer,
      'stufeBezeichnung': stufenBezeichnung,
      'gebuehr': effektiveGebuehr,
      'zinsen': zinssumme,
      'zinssegmente': zinssegmenteJson,
      'uebernommeneGebuehr': uebernommeneGebuehr,
      'uebernommeneZinsen': uebernommeneZinsen,
    };
    final snapshotJson = jsonEncode(snapshotMap);
    late final int id;
    await executor.runCustom('BEGIN');
    try {
      try {
        id = await executor.runInsert(
          'INSERT INTO mahnungen (rechnung_id, kunde_id, stufe_id, datum, '
          'betrag, gebuehr, zinsen, status, snapshot, '
          'gebuehr_bezahlt, zinsen_bezahlt, uebernommene_gebuehr, '
          'uebernommene_zinsen) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            rechnungId,
            kundeId,
            stufeId,
            datum,
            outstandingPrincipal,
            effektiveGebuehr,
            zinssumme,
            'offen',
            snapshotJson,
            '0.00',
            '0.00',
            uebernommeneGebuehr,
            uebernommeneZinsen,
          ],
        );
      } catch (e) {
        debugPrint('mahnungen insert settled full: $e');
        id = await executor.runInsert(
          'INSERT INTO mahnungen (rechnung_id, kunde_id, stufe_id, datum, '
          'betrag, gebuehr, zinsen, status, snapshot) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            rechnungId,
            kundeId,
            stufeId,
            datum,
            outstandingPrincipal,
            effektiveGebuehr,
            zinssumme,
            'offen',
            snapshotJson,
          ],
        );
      }
      await executor.runCustom('COMMIT');
    } catch (e) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (e2) {
        debugPrint('mahnungen rollback settled: $e2');
      }
      rethrow;
    }
    final created = await getById(id);
    if (created == null) throw const MahnungException('Mahnung konnte nicht erstellt werden');
    return created;
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
    } catch (e) {
      debugPrint('mahnungen markSent: $e');
      await executor.runUpdate('UPDATE mahnungen SET status = ? WHERE id = ?', <Object?>['versendet', id]);
    }
    final updated = await getById(id);
    if (updated == null) throw const MahnungException('Mahnung nicht gefunden');
    return updated;
  }

  /// Fail-closed: kennzeichnet nichts als versendet, ohne dass der Transport
  /// die Nachricht mit Anhang angenommen hat. Versand läuft ausschließlich
  /// über den konfigurierten SMTP-Transport (DunningSendService).
  Future<void> sendMail(int mahnungId) async {
    await _ensureInitialized();
    final existing = await getById(mahnungId);
    if (existing == null) throw const MahnungException('Mahnung nicht gefunden');
    throw const MahnungException('Versand erfordert einen konfigurierten SMTP-Transport');
  }

  /// Erzeugt das lesbare Mahn-PDF aus dem unveränderlichen Snapshot.
  ///
  /// Profile-lokal, atomar (tmp → prüfen → rename), mit echten
  /// Snapshot-Feldern statt Platzhalter. Das PDF einer transport-akzeptierten
  /// Mahnung ist unveränderlich und wird nicht neu erzeugt.
  Future<String> generatePdf(int mahnungId, {String? profileDirOverride}) async {
    await _ensureInitialized();
    final m = await getById(mahnungId);
    if (m == null) throw const MahnungException('Mahnung nicht gefunden');
    if (m.status == 'versendet') {
      throw const MahnungException('Transport-akzeptiertes PDF ist unveränderlich');
    }
    final effectiveDir = profileDirOverride ?? profileDir;
    if (effectiveDir == null) return 'Mahnung-${m.id}.pdf';
    final pdfDir = Directory('$effectiveDir/pdfs')..createSync(recursive: true);
    final pdfFile = File('${pdfDir.path}/Mahnung-${m.id}.pdf');
    final tmpFile = File('${pdfDir.path}/Mahnung-${m.id}.pdf.tmp');
    try {
      tmpFile.writeAsBytesSync(_renderPdf(m), flush: true);
      if (tmpFile.readAsBytesSync().isEmpty) {
        throw const MahnungException('Mahnung-PDF ist nicht lesbar');
      }
      if (pdfFile.existsSync()) pdfFile.deleteSync();
      tmpFile.renameSync(pdfFile.path);
    } catch (e) {
      try {
        if (tmpFile.existsSync()) tmpFile.deleteSync();
      } catch (_) {}
      if (e is MahnungException) rethrow;
      throw const MahnungException('Mahnung-PDF konnte nicht erzeugt werden');
    }
    return pdfFile.path;
  }

  /// Minimaler einseitiger PDF-Text aus Snapshot-Feldern (ASCII-sicher).
  static List<int> _renderPdf(Mahnung m) {
    final snap = m.snapshotData;
    final lines = <String>[
      'Mahnung Nr. M-${m.id}',
      'Rechnung: ${snap?['rechnungsnummer'] ?? ''}',
      'Faellig: ${snap?['faelligkeit'] ?? ''}',
      'Betrag: ${m.betrag}',
      'Mahngebuehr: ${m.gebuehr}',
      'Verzugszinsen: ${m.zinsen}',
      'Stufe: ${snap?['stufe'] ?? ''}',
    ];
    final content = StringBuffer('BT /F1 12 Tf 72 740 Td 14 TL ');
    for (final line in lines) {
      content.write('(${_pdfEscape(line)}) Tj T* ');
    }
    content.write('ET');
    final contentBytes = content.toString().codeUnits;
    const String pageObject =
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>';
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      pageObject,
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Length ${contentBytes.length} >>\nstream\n${content}endstream',
    ];
    final out = <int>[];
    void write(String s) => out.addAll(s.codeUnits);
    write('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xrefAt = out.length;
    write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets) {
      write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefAt\n%%EOF\n');
    return out;
  }

  static String _pdfEscape(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  Future<int> getInvoiceDunningLevel(int rechnungId) async {
    await _ensureInitialized();
    try {
      final rows = await executor.runSelect('SELECT mahnstufe_aktuell FROM rechnungen WHERE id = ? LIMIT 1', <Object?>[
        rechnungId,
      ]);
      if (rows.isEmpty) return 0;
      return _asInt(rows.single['mahnstufe_aktuell']) ?? 0;
    } catch (e) {
      debugPrint('mahnungen getInvoiceDunningLevel: $e');
      return 0;
    }
  }

  // --- helpers ---
  // ponytail: _asMoneyString duped with mahnstufen_repository — byte-identical 8 lines but _normalizeMoney
  // diverges (MahnstufeException vs MahnungException); shared file not justified for 3 repos.

  int _sumUnpaid(List<Map<String, Object?>> rows, String totalKey, String paidKey) {
    var sum = 0;
    for (final r in rows) {
      final total = money.toCents(_asMoneyString(r[totalKey]));
      final paid = money.toCents(_asMoneyString(r[paidKey]));
      final unpaid = total - paid;
      if (unpaid > 0) sum += unpaid;
    }
    return sum;
  }

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
