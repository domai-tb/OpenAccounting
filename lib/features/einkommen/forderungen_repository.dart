import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class Forderung {
  const Forderung({
    required this.id,
    required this.typ,
    required this.status,
    required this.betrag,
    required this.partnerTyp,
    required this.partnerId,
    this.rechnungId,
    this.journalId,
    this.ausgleichJournalId,
    required this.erstelltAm,
    required this.aktualisiertAm,
  });

  final int id;
  final String typ;
  final String status;
  final num betrag;
  final String partnerTyp;
  final int partnerId;
  final int? rechnungId;
  final int? journalId;
  final int? ausgleichJournalId;
  final String erstelltAm;
  final String aktualisiertAm;
}

class ForderungenException implements Exception {
  const ForderungenException(this.message);
  final String message;
  @override
  String toString() => message;
}

class KontokorrentEintrag {
  const KontokorrentEintrag({
    required this.datum,
    required this.typ,
    required this.betrag,
    required this.saldo,
    this.beschreibung,
  });

  final String datum;
  final String typ; // rechnung, zahlung, ueberzahlung, ausbuchen
  final num betrag;
  final num saldo;
  final String? beschreibung;
}

/// Repository für Forderungen — raw SQL via drift executor, GoBD via triggers.
/// Überzahlung split + Kontokorrent + Ausbuchen per einkommen spec.
class ForderungenRepository {
  ForderungenRepository(this.executor);

  final QueryExecutor executor;

  static const Set<String> _typSet = {'rechnung', 'rechnung_eingang', 'journal'};
  static const Set<String> _statusSet = {'offen', 'teilbezahlt', 'bezahlt', 'ausgebucht'};
  static const Set<String> _partnerSet = {'kunde', 'lieferant'};

  Future<void> ensureSchema() async {
    for (final col in <String>[
      "typ TEXT NOT NULL DEFAULT 'rechnung' CHECK (typ IN ('rechnung','rechnung_eingang','journal'))",
      "partner_typ TEXT NOT NULL DEFAULT 'kunde' CHECK (partner_typ IN ('kunde','lieferant'))",
      'partner_id INTEGER NOT NULL DEFAULT 0',
      'journal_id INTEGER REFERENCES journal(id)',
      'ausgleich_journal_id INTEGER REFERENCES journal(id)',
      'erstellt_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      'aktualisiert_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
    ]) {
      try {
        await executor.runCustom('ALTER TABLE forderungen ADD COLUMN $col');
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('duplicate column name') || msg.contains('already exists')) {
          debugPrint('Forderungen ensureSchema skip duplicate: $msg');
          continue;
        }
        debugPrint('Forderungen ensureSchema failed: $e');
        rethrow;
      }
    }
    try {
      await executor.runCustom(
        '''UPDATE forderungen SET partner_id = kunde_id WHERE (partner_id IS NULL OR partner_id = 0) AND kunde_id IS NOT NULL''',
      );
    } catch (e) {
      debugPrint('Forderungen ensureSchema migrate failed: $e');
      rethrow;
    }
  }

  Future<Forderung> create({
    required String typ,
    required num betrag,
    required String partnerTyp,
    required int partnerId,
    int? rechnungId,
    int? journalId,
    String status = 'offen',
  }) async {
    if (!_typSet.contains(typ)) throw const ForderungenException('Ungültiger Typ');
    if (!_statusSet.contains(status)) throw const ForderungenException('Ungültiger Status');
    if (!_partnerSet.contains(partnerTyp)) throw const ForderungenException('Ungültiger Partner-Typ');
    if (partnerId <= 0) throw const ForderungenException('Partner-ID ist Pflicht');
    if (betrag.isNaN || !betrag.isFinite) throw const ForderungenException('Betrag ungültig');
    final cents = _toCents(betrag);
    if (cents < 0) throw const ForderungenException('Betrag darf nicht negativ sein');

    // Duplicate guard for rechnung-linked forderungen
    if (rechnungId != null) {
      final dup = await executor.runSelect(
        "SELECT id FROM forderungen WHERE rechnung_id = ? AND status IN ('offen','teilbezahlt') LIMIT 1",
        [rechnungId],
      );
      if (dup.isNotEmpty) throw const ForderungenException('Forderung für diese Rechnung existiert bereits');
    }

    final now = DateTime.now().toIso8601String();
    final int? kundeId = partnerTyp == 'kunde' ? partnerId : null;
    final id = await executor.runInsert(
      'INSERT INTO forderungen (typ, status, betrag, partner_typ, partner_id, rechnung_id, journal_id, erstellt_am, aktualisiert_am, kunde_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [typ, status, _fmt(betrag), partnerTyp, partnerId, rechnungId, journalId, now, now, kundeId],
    );
    final f = await findById(id);
    if (f == null) throw const ForderungenException('Forderung konnte nicht gespeichert werden');
    return f;
  }

  /// Auto-create on invoice finalization per spec. Idempotent.
  Future<Forderung?> createForRechnung(int rechnungId) async {
    final rows = await executor.runSelect(
      'SELECT id, typ, kunde_id, lieferant_id, brutto_betrag FROM rechnungen WHERE id = ?',
      [rechnungId],
    );
    if (rows.isEmpty) throw const ForderungenException('Rechnung nicht gefunden');
    final r = rows.single;
    final typRaw = (r['typ'] as String?) ?? 'rechnung';
    final brutto = _asNum(r['brutto_betrag']) ?? 0;
    final isEingang = typRaw == 'rechnung_eingang' || r['lieferant_id'] != null;
    final typ = isEingang ? 'rechnung_eingang' : 'rechnung';
    final partnerTyp = isEingang ? 'lieferant' : 'kunde';
    final partnerId = isEingang ? (r['lieferant_id'] as int?) : (r['kunde_id'] as int?);
    if (partnerId == null) return null;

    final existing = await executor.runSelect(
      "SELECT id FROM forderungen WHERE rechnung_id = ? AND status IN ('offen','teilbezahlt') LIMIT 1",
      [rechnungId],
    );
    if (existing.isNotEmpty) return findById(_asNum(existing.single['id'])?.toInt() ?? 0);
    return create(typ: typ, betrag: brutto, partnerTyp: partnerTyp, partnerId: partnerId, rechnungId: rechnungId);
  }

  Future<Forderung?> findById(int id) async {
    final rows = await executor.runSelect('SELECT * FROM forderungen WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<Forderung?> findByRechnungId(int rechnungId) async {
    final rows = await executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ? ORDER BY id DESC LIMIT 1', [
      rechnungId,
    ]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<Forderung>> list({String? partnerTyp, int? partnerId, String? status}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (partnerTyp != null) {
      where.add('partner_typ = ?');
      args.add(partnerTyp);
    }
    if (partnerId != null) {
      where.add('partner_id = ?');
      args.add(partnerId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    final sql = 'SELECT * FROM forderungen ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY id';
    final rows = await executor.runSelect(sql, args);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<Forderung>> listOffene() async {
    final rows = await executor.runSelect(
      "SELECT * FROM forderungen WHERE status IN ('offen','teilbezahlt') ORDER BY id",
      const [],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Payment posting with overpayment split. Creates payment journal + optional overpayment journal.
  /// Atomic via drift transaction — orphan journal never persists without forderung update.
  Future<Forderung> zahlungBuchen({required int forderungId, required num betrag, String? datum}) async {
    if (betrag.isNaN || !betrag.isFinite || betrag <= 0) throw const ForderungenException('Zahlbetrag ungültig');
    final f = await findById(forderungId);
    if (f == null) throw const ForderungenException('Forderung nicht gefunden');
    if (f.status == 'bezahlt' || f.status == 'ausgebucht') {
      throw const ForderungenException('Forderung bereits ausgeglichen');
    }

    final centsBetrag = _toCents(betrag);
    final centsOffen = _toCents(f.betrag);
    final now = datum ?? DateTime.now().toIso8601String().substring(0, 10);

    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final payJournalId = await transaction.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
        [now, 'Zahlung Forderung #$forderungId', _fmt(betrag > f.betrag ? f.betrag : betrag), 'Einnahme', f.rechnungId],
      );

      if (centsBetrag < centsOffen) {
        final remaining = _fromCents(centsOffen - centsBetrag);
        await transaction.runUpdate(
          'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP WHERE id = ?',
          [_fmt(remaining), 'teilbezahlt', payJournalId, forderungId],
        );
      } else if (centsBetrag == centsOffen) {
        await transaction.runUpdate(
          'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP WHERE id = ?',
          ['0.00', 'bezahlt', payJournalId, forderungId],
        );
      } else {
        final excess = _fromCents(centsBetrag - centsOffen);
        await transaction.runInsert(
          'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
          [now, 'Überzahlung Forderung #$forderungId', _fmt(excess), 'Einnahme', f.rechnungId],
        );
        await transaction.runUpdate(
          'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP WHERE id = ?',
          ['0.00', 'bezahlt', payJournalId, forderungId],
        );
      }
      await transaction.send();
    } catch (e, st) {
      try {
        await transaction.rollback();
      } catch (_) {}
      Error.throwWithStackTrace(e, st);
    }
    final updated = await findById(forderungId);
    return updated!;
  }

  /// Write-off (Forderungsausfall) with Grund required. Atomic via drift transaction.
  Future<Forderung> ausbuchen({required int forderungId, required String grund}) async {
    if (grund.trim().isEmpty) throw const ForderungenException('Grund ist Pflicht');
    final f = await findById(forderungId);
    if (f == null) throw const ForderungenException('Forderung nicht gefunden');
    if (f.status == 'bezahlt') throw const ForderungenException('Forderung bereits beglichen');
    if (f.status == 'ausgebucht') throw const ForderungenException('Forderung bereits ausgebucht');
    if (_toCents(f.betrag) == 0) throw const ForderungenException('Forderung bereits ausgeglichen');

    final now = DateTime.now().toIso8601String().substring(0, 10);
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final journalId = await transaction.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
        [now, 'Forderungsausfall: ${grund.trim()}', _fmt(f.betrag), 'Ausgabe', f.rechnungId],
      );
      await transaction.runUpdate(
        'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP WHERE id = ?',
        ['0.00', 'ausgebucht', journalId, forderungId],
      );
      await transaction.send();
    } catch (e, st) {
      try {
        await transaction.rollback();
      } catch (_) {}
      Error.throwWithStackTrace(e, st);
    }
    return (await findById(forderungId))!;
  }

  /// Kontokorrent per spec — chronological entries with running Saldo.
  Future<List<KontokorrentEintrag>> kontokorrent({
    required String partnerTyp,
    required int partnerId,
    String? von,
    String? bis,
  }) async {
    final forderungen = await list(partnerTyp: partnerTyp, partnerId: partnerId);
    // Collect payment/overpayment journals linked via ausgleich_journal_id or rechnung_id
    final journalRows = await executor.runSelect(
      'SELECT id, datum, beschreibung, betrag, beleg_typ FROM journal ORDER BY datum, id',
      const [],
    );

    // Build entries: forderungen as Soll, payments as Haben
    final entries = <_RawEntry>[];
    for (final f in forderungen) {
      if (!_inRange(f.erstelltAm.substring(0, 10), von, bis)) continue;
      entries.add(
        _RawEntry(
          datum: f.erstelltAm.substring(0, 10),
          typ: f.typ,
          betrag: f.betrag,
          beschreibung: 'Rechnung ${f.rechnungId ?? f.id}',
        ),
      );
      // Find overpayment journals for this forderung (beschreibung contains Forderung #id)
      for (final j in journalRows) {
        final desc = (j['beschreibung'] as String?) ?? '';
        if (desc.contains('Überzahlung Forderung #${f.id}')) {
          final d = (j['datum'] as String?) ?? f.erstelltAm.substring(0, 10);
          if (!_inRange(d, von, bis)) continue;
          final b = _asNum(j['betrag']) ?? 0;
          entries.add(_RawEntry(datum: d, typ: 'ueberzahlung', betrag: b, beschreibung: desc));
        }
      }
    }
    // Also include payment journals via ausgleich
    for (final f in forderungen) {
      if (f.ausgleichJournalId == null) continue;
      for (final j in journalRows) {
        if (j['id'] == f.ausgleichJournalId) {
          final d = (j['datum'] as String?) ?? f.erstelltAm.substring(0, 10);
          if (!_inRange(d, von, bis)) continue;
          // Avoid double-adding overpayment already added
          final desc = (j['beschreibung'] as String?) ?? '';
          if (desc.contains('Überzahlung')) continue;
          entries.add(_RawEntry(datum: d, typ: 'zahlung', betrag: -(_asNum(j['betrag']) ?? 0), beschreibung: desc));
        }
      }
    }

    entries.sort((a, b) {
      final c = a.datum.compareTo(b.datum);
      return c != 0 ? c : a.typ.compareTo(b.typ);
    });

    // Running saldo
    var saldoCents = 0;
    // Opening balance from entries outside range not included — compute from all forderungen/journals before von
    if (von != null) {
      for (final f in forderungen) {
        final d = f.erstelltAm.substring(0, 10);
        if (d.compareTo(von) < 0) saldoCents += _toCents(f.betrag);
      }
    }

    final result = <KontokorrentEintrag>[];
    for (final e in entries) {
      saldoCents += _toCents(e.betrag);
      result.add(
        KontokorrentEintrag(
          datum: e.datum,
          typ: e.typ,
          betrag: e.betrag,
          saldo: _fromCents(saldoCents),
          beschreibung: e.beschreibung,
        ),
      );
    }
    return result;
  }

  Forderung _fromRow(Map<String, Object?> r) {
    return Forderung(
      id: (r['id'] as int?) ?? 0,
      typ: (r['typ'] as String?) ?? 'rechnung',
      status: (r['status'] as String?) ?? 'offen',
      betrag: _asNum(r['betrag']) ?? 0,
      partnerTyp: (r['partner_typ'] as String?) ?? (r['kunde_id'] != null ? 'kunde' : 'kunde'),
      partnerId: (r['partner_id'] as int?) ?? (r['kunde_id'] as int?) ?? 0,
      rechnungId: r['rechnung_id'] as int?,
      journalId: r['journal_id'] as int?,
      ausgleichJournalId: r['ausgleich_journal_id'] as int?,
      erstelltAm:
          (r['erstellt_am'] as String?) ?? (r['erstellungsdatum'] as String?) ?? DateTime.now().toIso8601String(),
      aktualisiertAm: (r['aktualisiert_am'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  static bool _inRange(String datum, String? von, String? bis) {
    if (von != null && datum.compareTo(von) < 0) return false;
    if (bis != null && datum.compareTo(bis) > 0) return false;
    return true;
  }

  static num? _asNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static int _toCents(num v) => (v * 100).round();
  static num _fromCents(int c) => c / 100.0;
  static String _fmt(num v) => v.toStringAsFixed(2);
}

class _RawEntry {
  _RawEntry({required this.datum, required this.typ, required this.betrag, this.beschreibung});
  final String datum;
  final String typ;
  final num betrag;
  final String? beschreibung;
}

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
