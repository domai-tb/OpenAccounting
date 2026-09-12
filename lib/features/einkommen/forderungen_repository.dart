import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/rechnung_typ.dart';

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
    this.ursprungsBetrag,
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
  final num? ursprungsBetrag;
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

  // ponytail: O(n) scan, cache by version if needed
  Future<void> ensureSchema() => _ensureSchema();

  Future<void> _ensureSchema() async {
    final List<Map<String, Object?>> columnRows = await executor.runSelect(
      'PRAGMA table_info(forderungen)',
      const <Object?>[],
    );
    final Set<String> columns = <String>{
      for (final Map<String, Object?> row in columnRows)
        if (row['name'] is String) row['name']! as String,
    };
    const Map<String, String> requiredColumns = <String, String>{
      'typ': "TEXT NOT NULL DEFAULT 'rechnung' CHECK (typ IN ('rechnung','rechnung_eingang','journal'))",
      'partner_typ': "TEXT NOT NULL DEFAULT 'kunde' CHECK (partner_typ IN ('kunde','lieferant'))",
      'partner_id': 'INTEGER NOT NULL DEFAULT 0',
      'journal_id': 'INTEGER REFERENCES journal(id)',
      'ausgleich_journal_id': 'INTEGER REFERENCES journal(id)',
      'erstellt_am': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      'aktualisiert_am': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      'anfangsbetrag': 'NUMERIC(12,2)',
    };
    for (final MapEntry<String, String> entry in requiredColumns.entries) {
      if (columns.contains(entry.key)) {
        continue;
      }
      try {
        await executor.runCustom('ALTER TABLE forderungen ADD COLUMN ${entry.key} ${entry.value}');
      } catch (error) {
        // concurrent ALTER raced — column may now exist
        final String msg = error.toString().toLowerCase();
        if (!msg.contains('duplicate')) {
          rethrow;
        }
      }
      final List<Map<String, Object?>> verifiedRows = await executor.runSelect(
        'PRAGMA table_info(forderungen)',
        const <Object?>[],
      );
      if (!verifiedRows.any((Map<String, Object?> row) => row['name'] == entry.key)) {
        throw StateError('Forderungen-Schema konnte Spalte ${entry.key} nicht verifizieren');
      }
      columns.add(entry.key);
    }
    await executor.runCustom(
      'UPDATE forderungen SET partner_id = kunde_id WHERE (partner_id IS NULL OR partner_id = 0) AND kunde_id IS NOT NULL',
    );
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS forderung_zahlungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  forderung_id INTEGER NOT NULL REFERENCES forderungen(id),
  journal_id INTEGER NOT NULL UNIQUE REFERENCES journal(id),
  betrag NUMERIC(12,2) NOT NULL,
  typ TEXT NOT NULL CHECK (typ IN ('zahlung','ueberzahlung','ausbuchen')),
  datum TEXT NOT NULL,
  idempotency_key TEXT UNIQUE
)''');
    await executor.runCustom(
      'CREATE UNIQUE INDEX IF NOT EXISTS forderungen_rechnung_unique ON forderungen(rechnung_id) WHERE rechnung_id IS NOT NULL',
    );
    await executor.runCustom('UPDATE forderungen SET anfangsbetrag = betrag WHERE anfangsbetrag IS NULL');
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
    await ensureSchema();
    if (!_typSet.contains(typ)) throw const ForderungenException('Ungültiger Typ');
    if (!_statusSet.contains(status)) throw const ForderungenException('Ungültiger Status');
    if (!_partnerSet.contains(partnerTyp)) throw const ForderungenException('Ungültiger Partner-Typ');
    if (partnerId <= 0) throw const ForderungenException('Partner-ID ist Pflicht');
    if (betrag.isNaN || !betrag.isFinite) throw const ForderungenException('Betrag ungültig');
    final int cents = _toCents(betrag);
    if (cents < 0) throw const ForderungenException('Betrag darf nicht negativ sein');

    // Duplicate guard for rechnung-linked forderungen
    if (rechnungId != null) {
      final dup = await executor.runSelect('SELECT id FROM forderungen WHERE rechnung_id = ? LIMIT 1', [rechnungId]);
      if (dup.isNotEmpty) throw const ForderungenException('Forderung für diese Rechnung existiert bereits');
    }

    final now = DateTime.now().toIso8601String();
    final int? kundeId = partnerTyp == 'kunde' ? partnerId : null;
    late final int id;
    try {
      id = await executor.runInsert(
        'INSERT INTO forderungen (typ, status, betrag, anfangsbetrag, partner_typ, partner_id, rechnung_id, journal_id, erstellt_am, aktualisiert_am, kunde_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          typ,
          status,
          _fmtCents(cents),
          _fmtCents(cents),
          partnerTyp,
          partnerId,
          rechnungId,
          journalId,
          now,
          now,
          kundeId,
        ],
      );
    } catch (error, stackTrace) {
      if (rechnungId != null && error.toString().toUpperCase().contains('UNIQUE')) {
        Error.throwWithStackTrace(
          const ForderungenException('Forderung für diese Rechnung existiert bereits'),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    final f = await findById(id);
    if (f == null) throw const ForderungenException('Forderung konnte nicht gespeichert werden');
    return f;
  }

  /// Auto-create on invoice finalization per spec. Idempotent.
  Future<Forderung?> createForRechnung(int rechnungId) async {
    await ensureSchema();
    final rows = await executor.runSelect(
      'SELECT id, typ, kunde_id, lieferant_id, brutto_betrag, ist_entwurf FROM rechnungen WHERE id = ?',
      [rechnungId],
    );
    if (rows.isEmpty) throw const ForderungenException('Rechnung nicht gefunden');
    final r = rows.single;
    if (((r['ist_entwurf'] as num?) ?? 1).toInt() != 0) {
      throw const ForderungenException('Nur finalisierte Rechnungen erzeugen eine Forderung');
    }
    final typRaw = (r['typ'] as String?) ?? 'rechnung';
    final brutto = _asNum(r['brutto_betrag']) ?? 0;
    final isEingang = RechnungTyp.isEingang(typRaw) || r['lieferant_id'] != null;
    final typ = RechnungTyp.forderungTypFor(typ: typRaw, lieferantId: r['lieferant_id'] as int?);
    final partnerTyp = isEingang ? 'lieferant' : 'kunde';
    final partnerId = isEingang ? (r['lieferant_id'] as int?) : (r['kunde_id'] as int?);
    if (partnerId == null) return null;

    final existing = await executor.runSelect('SELECT id FROM forderungen WHERE rechnung_id = ? LIMIT 1', [rechnungId]);
    if (existing.isNotEmpty) return findById(_asNum(existing.single['id'])?.toInt() ?? 0);
    try {
      return await create(
        typ: typ,
        betrag: brutto,
        partnerTyp: partnerTyp,
        partnerId: partnerId,
        rechnungId: rechnungId,
      );
    } catch (error, stackTrace) {
      if (error.toString().toUpperCase().contains('UNIQUE') ||
          (error is ForderungenException && error.message.contains('existiert bereits'))) {
        final retry = await executor.runSelect('SELECT id FROM forderungen WHERE rechnung_id = ? LIMIT 1', [
          rechnungId,
        ]);
        if (retry.isNotEmpty) {
          return findById(_asNum(retry.single['id'])?.toInt() ?? 0);
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Forderung?> findById(int id) async {
    await ensureSchema();
    final rows = await executor.runSelect('SELECT * FROM forderungen WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<Forderung?> findByRechnungId(int rechnungId) async {
    await ensureSchema();
    final rows = await executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ? ORDER BY id DESC LIMIT 1', [
      rechnungId,
    ]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<Forderung>> list({String? partnerTyp, int? partnerId, String? status}) async {
    await ensureSchema();
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
    await ensureSchema();
    final rows = await executor.runSelect(
      "SELECT * FROM forderungen WHERE status IN ('offen','teilbezahlt') ORDER BY id",
      const [],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Payment posting with overpayment split. Creates payment journal + optional overpayment journal.
  /// Atomic via drift transaction — orphan journal never persists without forderung update.
  Future<Forderung> zahlungBuchen({
    required int forderungId,
    required num betrag,
    String? datum,
    String? idempotencyKey,
  }) async {
    await ensureSchema();
    if (betrag.isNaN || !betrag.isFinite || betrag <= 0) {
      throw const ForderungenException('Zahlbetrag ungültig');
    }
    final String? key = idempotencyKey?.trim();
    if (idempotencyKey != null && key!.isEmpty) {
      throw const ForderungenException('Idempotency-Key darf nicht leer sein');
    }
    if (key != null) {
      final List<Map<String, Object?>> existing = await executor.runSelect(
        'SELECT forderung_id FROM forderung_zahlungen WHERE idempotency_key = ? LIMIT 1',
        <Object?>[key],
      );
      if (existing.isNotEmpty) {
        final int previousId = (existing.single['forderung_id'] as num?)?.toInt() ?? 0;
        final Forderung? previous = await findById(previousId);
        if (previous != null) {
          return previous;
        }
      }
    }

    final int centsBetrag = _toCents(betrag);
    if (centsBetrag <= 0) {
      throw const ForderungenException('Zahlbetrag muss mindestens einen Cent betragen');
    }
    final String now = datum ?? DateTime.now().toIso8601String().substring(0, 10);
    final TransactionExecutor transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final List<Map<String, Object?>> fRows = await transaction.runSelect(
        'SELECT * FROM forderungen WHERE id = ? LIMIT 1',
        <Object?>[forderungId],
      );
      if (fRows.isEmpty) {
        throw const ForderungenException('Forderung nicht gefunden');
      }
      final Forderung f = _fromRow(fRows.single);
      if (f.status == 'bezahlt' || f.status == 'ausgebucht') {
        throw const ForderungenException('Forderung bereits ausgeglichen');
      }
      final int centsOffen = _toCents(f.betrag);
      if (centsOffen <= 0) {
        throw const ForderungenException('Forderung bereits ausgeglichen');
      }
      final int paymentCents = centsBetrag < centsOffen ? centsBetrag : centsOffen;
      final int payJournalId = await transaction.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
        <Object?>[now, 'Zahlung Forderung #$forderungId', _fmtCents(paymentCents), BelegTyp.zahlung, f.rechnungId],
      );
      await transaction.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum, idempotency_key) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[forderungId, payJournalId, _fmtCents(paymentCents), 'zahlung', now, key],
      );

      if (centsBetrag < centsOffen) {
        await transaction.runUpdate(
          'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP WHERE id = ?',
          <Object?>[_fmtCents(centsOffen - centsBetrag), 'teilbezahlt', payJournalId, forderungId],
        );
      } else if (centsBetrag == centsOffen) {
        await transaction.runUpdate(
          'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP WHERE id = ?',
          <Object?>['0.00', 'bezahlt', payJournalId, forderungId],
        );
      } else {
        final int excessCents = centsBetrag - centsOffen;
        final int excessJournalId = await transaction.runInsert(
          'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
          <Object?>[
            now,
            'Überzahlung Forderung #$forderungId',
            _fmtCents(excessCents),
            BelegTyp.ueberzahlung,
            f.rechnungId,
          ],
        );
        await transaction.runInsert(
          'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, ?, ?)',
          <Object?>[forderungId, excessJournalId, _fmtCents(excessCents), 'ueberzahlung', now],
        );
        await transaction.runUpdate(
          'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP WHERE id = ?',
          <Object?>['0.00', 'bezahlt', payJournalId, forderungId],
        );
      }
      await transaction.send();
    } catch (error, stackTrace) {
      try {
        await transaction.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      if (key != null && error.toString().toUpperCase().contains('UNIQUE')) {
        final List<Map<String, Object?>> existing = await executor.runSelect(
          'SELECT forderung_id FROM forderung_zahlungen WHERE idempotency_key = ? LIMIT 1',
          <Object?>[key],
        );
        if (existing.isNotEmpty) {
          final int previousId = (existing.single['forderung_id'] as num?)?.toInt() ?? 0;
          final Forderung? previous = await findById(previousId);
          if (previous != null) {
            return previous;
          }
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    final Forderung? updated = await findById(forderungId);
    if (updated == null) {
      throw const ForderungenException('Forderung konnte nach Zahlung nicht gelesen werden');
    }
    return updated;
  }

  /// Write-off (Forderungsausfall) with Grund required. Atomic via drift transaction.
  Future<Forderung> ausbuchen({required int forderungId, required String grund}) async {
    await ensureSchema();
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
        <Object?>[
          now,
          'Forderungsausfall: ${grund.trim()}',
          _fmtCents(_toCents(f.betrag)),
          BelegTyp.ausbuchung,
          f.rechnungId,
        ],
      );
      await transaction.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, ?, ?)',
        <Object?>[forderungId, journalId, _fmtCents(_toCents(f.betrag)), 'ausbuchen', now],
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
    await ensureSchema();
    final forderungen = await list(partnerTyp: partnerTyp, partnerId: partnerId);
    if (forderungen.isEmpty) {
      return const <KontokorrentEintrag>[];
    }

    final String placeholders = List<String>.filled(forderungen.length, '?').join(', ');
    final List<Object?> ids = forderungen.map((Forderung f) => f.id).toList(growable: false);
    final List<Map<String, Object?>> paymentRows = await executor.runSelect(
      'SELECT forderung_id, betrag, typ, datum, journal_id FROM forderung_zahlungen '
      'WHERE forderung_id IN ($placeholders) ORDER BY datum, id',
      ids,
    );

    // Build one immutable invoice event and one event for every payment. The
    // relation table is the source of truth; descriptions and latest-link
    // columns are only compatibility fields.
    final List<_RawEntry> allEntries = <_RawEntry>[];
    for (final Forderung f in forderungen) {
      final int originalCents = _toCents(f.ursprungsBetrag ?? f.betrag);
      final String invoiceDate = _dateOnly(f.erstelltAm);
      allEntries.add(
        _RawEntry(
          datum: invoiceDate,
          typ: f.typ,
          betragCents: originalCents,
          beschreibung: 'Rechnung ${f.rechnungId ?? f.id}',
        ),
      );
      for (final Map<String, Object?> row in paymentRows) {
        if ((row['forderung_id'] as num?)?.toInt() != f.id) {
          continue;
        }
        final int amount = _toCents(row['betrag']);
        final String typ = row['typ']?.toString() ?? 'zahlung';
        allEntries.add(
          _RawEntry(
            datum: _dateOnly(row['datum']?.toString() ?? invoiceDate),
            typ: typ,
            betragCents: -amount,
            beschreibung: typ == 'zahlung' ? 'Zahlung Forderung #${f.id}' : '$typ Forderung #${f.id}',
          ),
        );
      }
    }

    const Map<String, int> typOrder = <String, int>{
      'rechnung': 0,
      'rechnung_eingang': 0,
      'journal': 0,
      'zahlung': 1,
      'ueberzahlung': 2,
      'ausbuchen': 3,
    };
    allEntries.sort((_RawEntry a, _RawEntry b) {
      final int dateOrder = a.datum.compareTo(b.datum);
      return dateOrder == 0 ? (typOrder[a.typ] ?? 99).compareTo(typOrder[b.typ] ?? 99) : dateOrder;
    });

    int openingCents = 0;
    final List<_RawEntry> inPeriod = <_RawEntry>[];
    for (final _RawEntry entry in allEntries) {
      if (von != null && entry.datum.compareTo(von) < 0) {
        openingCents += entry.betragCents;
      } else if (_inRange(entry.datum, von, bis)) {
        inPeriod.add(entry);
      }
    }

    var saldoCents = openingCents;
    final List<KontokorrentEintrag> result = <KontokorrentEintrag>[];
    for (final _RawEntry entry in inPeriod) {
      saldoCents += entry.betragCents;
      result.add(
        KontokorrentEintrag(
          datum: entry.datum,
          typ: entry.typ,
          betrag: _fromCents(entry.betragCents),
          saldo: _fromCents(saldoCents),
          beschreibung: entry.beschreibung,
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
      ursprungsBetrag: _asNum(r['anfangsbetrag']),
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

  static int _toCents(Object? value) {
    final String raw = value?.toString() ?? '0';
    try {
      return money.parseScaled(raw, scale: 2, field: 'amount', roundExcess: true);
    } on money.MoneyParseException catch (error) {
      throw ForderungenException(error.message);
    }
  }

  static num _fromCents(int c) => c / 100.0;
  static String _fmtCents(int cents) => money.fromCents(cents);
}

class _RawEntry {
  _RawEntry({required this.datum, required this.typ, required this.betragCents, this.beschreibung});
  final String datum;
  final String typ;
  final int betragCents;
  final String? beschreibung;
}

String _dateOnly(String raw) => raw.length >= 10 ? raw.substring(0, 10) : raw;

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
