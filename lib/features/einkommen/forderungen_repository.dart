import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/rechnung_typ.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

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
  final String? partnerTyp;
  final int partnerId;
  final int? rechnungId;
  final int? journalId;
  final int? ausgleichJournalId;
  final num? ursprungsBetrag;
  final String erstelltAm;
  final String aktualisiertAm;
}

enum ForderungenErrorCode {
  invalidRequest,
  amountScale,
  dateFormat,
  unknownDirection,
  idempotencyConflict,
  legacyFingerprintUnknown,
  alreadyClosed,
  concurrentWriteConflict,
  schemaMigrationFailed,
}

enum ForderungenMismatchField { requestedCents, forderungTarget, direction, datePolicy, effectiveDate }

const Map<ForderungenErrorCode, String> forderungenErrorCodeWireValues = <ForderungenErrorCode, String>{
  ForderungenErrorCode.invalidRequest: 'invalid_request',
  ForderungenErrorCode.amountScale: 'amount_scale',
  ForderungenErrorCode.dateFormat: 'date_format',
  ForderungenErrorCode.unknownDirection: 'unknown_direction',
  ForderungenErrorCode.idempotencyConflict: 'idempotency_conflict',
  ForderungenErrorCode.legacyFingerprintUnknown: 'legacy_fingerprint_unknown',
  ForderungenErrorCode.alreadyClosed: 'already_closed',
  ForderungenErrorCode.concurrentWriteConflict: 'concurrent_write_conflict',
  ForderungenErrorCode.schemaMigrationFailed: 'schema_migration_failed',
};

const Map<ForderungenMismatchField, String> forderungenMismatchFieldWireValues = <ForderungenMismatchField, String>{
  ForderungenMismatchField.requestedCents: 'requested_cents',
  ForderungenMismatchField.forderungTarget: 'forderung_target',
  ForderungenMismatchField.direction: 'direction',
  ForderungenMismatchField.datePolicy: 'date_policy',
  ForderungenMismatchField.effectiveDate: 'effective_date',
};

class ForderungenException implements Exception {
  ForderungenException(
    this.message, {
    this.code = ForderungenErrorCode.invalidRequest,
    List<ForderungenMismatchField> mismatchFields = const <ForderungenMismatchField>[],
    this.cause,
  }) : mismatchFields = List<ForderungenMismatchField>.unmodifiable(mismatchFields);

  final String message;
  final ForderungenErrorCode code;
  final List<ForderungenMismatchField> mismatchFields;
  final Object? cause;

  @override
  String toString() => message;
}

enum ForderungenTransactionKind { payment, writeoff }

abstract interface class ForderungenTransactionFactory {
  Future<T> run<T>({
    required ForderungenTransactionKind kind,
    required int attempt,
    required QueryExecutor executor,
    required Future<T> Function(QueryExecutor transaction) action,
  });
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
  ForderungenRepository(
    this.executor, {
    @visibleForTesting this.nowUtc,
    @visibleForTesting this.transactionFactory,
    @visibleForTesting this.onPaymentTransactionAttempt,
    @visibleForTesting this.onWriteoffTransactionAttempt,
    @visibleForTesting this.afterFingerprintMissBeforeInsert,
    @visibleForTesting this.afterPaymentStateReadBeforeConditionalUpdate,
  });

  final QueryExecutor executor;
  final DateTime Function()? nowUtc;
  final ForderungenTransactionFactory? transactionFactory;
  final void Function(int attempt)? onPaymentTransactionAttempt;
  final void Function(int attempt)? onWriteoffTransactionAttempt;
  final Future<void> Function(String idempotencyKey)? afterFingerprintMissBeforeInsert;
  final Future<void> Function(int forderungId, String observedStatus, int observedBalanceCents)?
  afterPaymentStateReadBeforeConditionalUpdate;
  bool _schemaReady = false;
  Future<void>? _schemaPreparation;

  static const Set<String> _typSet = {'rechnung', 'rechnung_eingang', 'journal'};
  static const Set<String> _statusSet = {'offen', 'teilbezahlt', 'bezahlt', 'ausgebucht'};
  static const Set<String> _partnerSet = {'kunde', 'lieferant'};

  // ponytail: O(n) scan, cache by version if needed
  Future<void> ensureSchema() async {
    final Future<void>? activePreparation = _schemaPreparation;
    if (activePreparation != null) {
      await activePreparation;
      return;
    }
    final Future<void> preparation = _ensureSchema();
    _schemaPreparation = preparation;
    try {
      await preparation;
    } finally {
      if (identical(_schemaPreparation, preparation)) _schemaPreparation = null;
    }
  }

  Future<void> _ensureSchema() async {
    try {
      if (_schemaReady && await _schemaIsCurrent()) return;
      _schemaReady = false;
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
        if (columns.contains(entry.key)) continue;
        try {
          await executor.runCustom('ALTER TABLE forderungen ADD COLUMN ${entry.key} ${entry.value}');
        } catch (error) {
          // Concurrent ALTER can win on another repository instance.
          if (!error.toString().toLowerCase().contains('duplicate')) rethrow;
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
      await _ensurePaymentTable();
      await executor.runCustom(
        'CREATE UNIQUE INDEX IF NOT EXISTS forderungen_rechnung_unique ON forderungen(rechnung_id) WHERE rechnung_id IS NOT NULL',
      );
      await executor.runCustom('UPDATE forderungen SET anfangsbetrag = betrag WHERE anfangsbetrag IS NULL');
      _schemaReady = true;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ForderungenException(
          'Forderungen-Schema konnte nicht vorbereitet werden',
          code: ForderungenErrorCode.schemaMigrationFailed,
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Future<bool> _schemaIsCurrent() async {
    final List<Map<String, Object?>> forderungRows = await executor.runSelect(
      'PRAGMA table_info(forderungen)',
      const <Object?>[],
    );
    const Set<String> requiredForderungColumns = <String>{
      'typ',
      'partner_typ',
      'partner_id',
      'journal_id',
      'ausgleich_journal_id',
      'erstellt_am',
      'aktualisiert_am',
      'anfangsbetrag',
    };
    final Set<String> forderungColumns = <String>{
      for (final Map<String, Object?> row in forderungRows) row['name'].toString(),
    };
    if (!requiredForderungColumns.every(forderungColumns.contains)) return false;

    final List<Map<String, Object?>> paymentRows = await executor.runSelect(
      'PRAGMA table_info(forderung_zahlungen)',
      const <Object?>[],
    );
    const Set<String> requiredPaymentColumns = <String>{
      'id',
      'forderung_id',
      'journal_id',
      'betrag',
      'typ',
      'datum',
      'idempotency_key',
      'requested_betrag_cents',
      'fingerprint_direction',
      'fingerprint_date_policy',
    };
    final Set<String> paymentColumns = <String>{
      for (final Map<String, Object?> row in paymentRows) row['name'].toString(),
    };
    return requiredPaymentColumns.every(paymentColumns.contains);
  }

  Future<void> _ensurePaymentTable() async {
    final tableRows = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
      const <Object?>[],
    );
    if (tableRows.isEmpty) {
      await executor.runCustom(_paymentTableSql);
      return;
    }
    final rows = await executor.runSelect('PRAGMA table_info(forderung_zahlungen)', const <Object?>[]);
    final columns = <String>{for (final row in rows) row['name'].toString()};
    const additions = <String, String>{
      'requested_betrag_cents': 'INTEGER',
      'fingerprint_direction': 'TEXT',
      'fingerprint_date_policy': 'TEXT',
    };
    for (final entry in additions.entries) {
      if (!columns.contains(entry.key)) {
        await executor.runCustom('ALTER TABLE forderung_zahlungen ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
    await executor.runCustom(
      'CREATE UNIQUE INDEX IF NOT EXISTS forderung_zahlungen_key_unique '
      'ON forderung_zahlungen(idempotency_key) WHERE idempotency_key IS NOT NULL',
    );
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
    if (!_typSet.contains(typ)) throw ForderungenException('Ungültiger Typ');
    if (!_statusSet.contains(status)) throw ForderungenException('Ungültiger Status');
    if (!_partnerSet.contains(partnerTyp)) throw ForderungenException('Ungültiger Partner-Typ');
    if (partnerId <= 0) throw ForderungenException('Partner-ID ist Pflicht');
    if (betrag.isNaN || !betrag.isFinite) throw ForderungenException('Betrag ungültig');
    final int cents = _toCents(betrag);
    if (cents < 0) throw ForderungenException('Betrag darf nicht negativ sein');

    // Duplicate guard for rechnung-linked forderungen
    if (rechnungId != null) {
      final dup = await executor.runSelect('SELECT id FROM forderungen WHERE rechnung_id = ? LIMIT 1', [rechnungId]);
      if (dup.isNotEmpty) throw ForderungenException('Forderung für diese Rechnung existiert bereits');
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
        Error.throwWithStackTrace(ForderungenException('Forderung für diese Rechnung existiert bereits'), stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    final f = await findById(id);
    if (f == null) throw ForderungenException('Forderung konnte nicht gespeichert werden');
    return f;
  }

  /// Auto-create on invoice finalization per spec. Idempotent.
  Future<Forderung?> createForRechnung(int rechnungId) async {
    await ensureSchema();
    final rows = await executor.runSelect(
      'SELECT id, typ, kunde_id, lieferant_id, brutto_betrag, ist_entwurf FROM rechnungen WHERE id = ?',
      [rechnungId],
    );
    if (rows.isEmpty) throw ForderungenException('Rechnung nicht gefunden');
    final r = rows.single;
    if (((r['ist_entwurf'] as num?) ?? 1).toInt() != 0) {
      throw ForderungenException('Nur finalisierte Rechnungen erzeugen eine Forderung');
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
  /// Atomic via an immediate SQLite transaction — orphan journal never persists without the conditional update.
  Future<Forderung> zahlungBuchen({
    required int forderungId,
    required num betrag,
    String? datum,
    String? idempotencyKey,
  }) async {
    await ensureSchema();
    final String? key = idempotencyKey?.trim();
    if (idempotencyKey != null && key!.isEmpty) {
      throw ForderungenException('Idempotency-Key darf nicht leer sein');
    }
    if (forderungId <= 0) {
      throw ForderungenException('Forderung-ID ist Pflicht');
    }
    final _CanonicalAmount amount = _canonicalAmount(betrag);
    final _CanonicalDate requestDate = _canonicalDate(datum);
    for (int attempt = 1; attempt <= _maxTransactionAttempts; attempt++) {
      onPaymentTransactionAttempt?.call(attempt);
      try {
        return await _runTransaction<Forderung>(
          kind: ForderungenTransactionKind.payment,
          attempt: attempt,
          action: (QueryExecutor transaction) => _zahlungInTransaction(
            transaction,
            forderungId: forderungId,
            amount: amount,
            requestDate: requestDate,
            key: key,
          ),
        );
      } catch (error, stackTrace) {
        if (key != null && (_isUniqueViolation(error) || _isBusySnapshot(error))) {
          final Forderung? replay = await _reloadKeyedPayment(key, forderungId, amount, requestDate);
          if (replay != null) return replay;
        }
        if (!_isRetryableLock(error)) Error.throwWithStackTrace(error, stackTrace);
        if (attempt == _maxTransactionAttempts) {
          throw ForderungenException(
            'Zahlung konnte wegen einer konkurrierenden Änderung nicht gespeichert werden',
            code: ForderungenErrorCode.concurrentWriteConflict,
            cause: error,
          );
        }
        await _backoff(attempt);
      }
    }
    throw StateError('Unreachable payment retry state');
  }

  /// Write-off (Forderungsausfall) with Grund required. Atomic via drift transaction.
  Future<Forderung> ausbuchen({required int forderungId, required String grund}) async {
    await ensureSchema();
    final String reason = grund.trim();
    if (reason.isEmpty) throw ForderungenException('Grund ist Pflicht');
    if (forderungId <= 0) throw ForderungenException('Forderung-ID ist Pflicht');
    final String now = _dateOnly(_nowUtc().toIso8601String());
    for (int attempt = 1; attempt <= _maxTransactionAttempts; attempt++) {
      onWriteoffTransactionAttempt?.call(attempt);
      try {
        return await _runTransaction<Forderung>(
          kind: ForderungenTransactionKind.writeoff,
          attempt: attempt,
          action: (QueryExecutor transaction) =>
              _ausbuchenInTransaction(transaction, forderungId: forderungId, reason: reason, datum: now),
        );
      } catch (error, stackTrace) {
        if (!_isRetryableLock(error)) Error.throwWithStackTrace(error, stackTrace);
        if (attempt == _maxTransactionAttempts) {
          throw ForderungenException(
            'Forderungsausbuchung konnte wegen einer konkurrierenden Änderung nicht gespeichert werden',
            code: ForderungenErrorCode.concurrentWriteConflict,
            cause: error,
          );
        }
        await _backoff(attempt);
      }
    }
    throw StateError('Unreachable write-off retry state');
  }

  Future<Forderung> _zahlungInTransaction(
    QueryExecutor transaction, {
    required int forderungId,
    required _CanonicalAmount amount,
    required _CanonicalDate requestDate,
    required String? key,
  }) async {
    final Forderung? f = await _readForderung(transaction, forderungId);
    if (f == null) throw ForderungenException('Forderung nicht gefunden');
    final String? direction = _directionFromRaw(f.partnerTyp);
    if (direction == null) {
      throw ForderungenException('Partner-Richtung unbekannt', code: ForderungenErrorCode.unknownDirection);
    }
    final _Fingerprint fingerprint = _Fingerprint(
      requestedCents: amount.cents,
      forderungId: forderungId,
      direction: direction,
      datePolicy: requestDate.policy,
      effectiveDate: requestDate.date,
    );

    if (key != null) {
      final existingRows = await transaction.runSelect(
        'SELECT * FROM forderung_zahlungen WHERE idempotency_key = ? LIMIT 1',
        <Object?>[key],
      );
      if (existingRows.isNotEmpty) {
        final Map<String, Object?> existing = existingRows.single;
        if (existing['requested_betrag_cents'] == null ||
            existing['fingerprint_direction'] == null ||
            existing['fingerprint_date_policy'] == null) {
          throw ForderungenException(
            'Der vorhandene Idempotency-Key hat keinen vollständigen Fingerabdruck',
            code: ForderungenErrorCode.legacyFingerprintUnknown,
          );
        }
        _throwIfFingerprintMismatch(existing, fingerprint);
        return f;
      }
      await afterFingerprintMissBeforeInsert?.call(key);
    }

    final int observedCents = _toCents(f.betrag);
    if (f.status != 'offen' && f.status != 'teilbezahlt' || observedCents <= 0) {
      throw ForderungenException('Forderung bereits ausgeglichen', code: ForderungenErrorCode.alreadyClosed);
    }
    await afterPaymentStateReadBeforeConditionalUpdate?.call(forderungId, f.status, observedCents);

    final int appliedCents = amount.cents < observedCents ? amount.cents : observedCents;
    final int paymentJournalId = await transaction.runInsert(
      'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) '
      'VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
      <Object?>[
        requestDate.date,
        'Zahlung Forderung #$forderungId',
        _fmtCents(appliedCents),
        BelegTyp.zahlung,
        f.rechnungId,
      ],
    );
    await transaction.runInsert(
      'INSERT INTO forderung_zahlungen '
      '(forderung_id, journal_id, betrag, typ, datum, idempotency_key, requested_betrag_cents, fingerprint_direction, fingerprint_date_policy) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        forderungId,
        paymentJournalId,
        _fmtCents(appliedCents),
        'zahlung',
        requestDate.date,
        key,
        if (key == null) null else amount.cents,
        if (key == null) null else direction,
        if (key == null) null else requestDate.policy,
      ],
    );

    if (amount.cents > observedCents) {
      final int excessCents = amount.cents - observedCents;
      final int excessJournalId = await transaction.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) '
        'VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
        <Object?>[
          requestDate.date,
          'Überzahlung Forderung #$forderungId',
          _fmtCents(excessCents),
          BelegTyp.ueberzahlung,
          f.rechnungId,
        ],
      );
      await transaction.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, ?, ?)',
        <Object?>[forderungId, excessJournalId, _fmtCents(excessCents), 'ueberzahlung', requestDate.date],
      );
    }

    final String nextStatus = amount.cents < observedCents ? 'teilbezahlt' : 'bezahlt';
    final String nextBalance = _fmtCents(observedCents - appliedCents);
    final int updated = await transaction.runUpdate(
      'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP '
      'WHERE id = ? AND status = ? AND betrag = ?',
      <Object?>[nextBalance, nextStatus, paymentJournalId, forderungId, f.status, _fmtCents(observedCents)],
    );
    if (updated == 0) {
      throw ForderungenException('Forderung wurde bereits geschlossen', code: ForderungenErrorCode.alreadyClosed);
    }
    if (updated != 1) {
      throw ForderungenException(
        'Forderungsstatus konnte nicht eindeutig aktualisiert werden',
        code: ForderungenErrorCode.schemaMigrationFailed,
      );
    }
    final Forderung? updatedForderung = await _readForderung(transaction, forderungId);
    if (updatedForderung == null) throw ForderungenException('Forderung konnte nach Zahlung nicht gelesen werden');
    return updatedForderung;
  }

  Future<Forderung> _ausbuchenInTransaction(
    QueryExecutor transaction, {
    required int forderungId,
    required String reason,
    required String datum,
  }) async {
    final Forderung? f = await _readForderung(transaction, forderungId);
    if (f == null) throw ForderungenException('Forderung nicht gefunden');
    final int observedCents = _toCents(f.betrag);
    if ((f.status != 'offen' && f.status != 'teilbezahlt') || observedCents <= 0) {
      final String message = f.status == 'bezahlt'
          ? 'Forderung bereits beglichen'
          : f.status == 'ausgebucht'
          ? 'Forderung bereits ausgebucht'
          : 'Forderung bereits geschlossen';
      throw ForderungenException(message, code: ForderungenErrorCode.alreadyClosed);
    }
    final int journalId = await transaction.runInsert(
      'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) '
      'VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
      <Object?>[datum, 'Forderungsausfall: $reason', _fmtCents(observedCents), BelegTyp.ausbuchung, f.rechnungId],
    );
    await transaction.runInsert(
      'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, ?, ?)',
      <Object?>[forderungId, journalId, _fmtCents(observedCents), 'ausbuchen', datum],
    );
    final int updated = await transaction.runUpdate(
      'UPDATE forderungen SET betrag = ?, status = ?, ausgleich_journal_id = ?, aktualisiert_am = CURRENT_TIMESTAMP '
      'WHERE id = ? AND status = ? AND betrag = ?',
      <Object?>['0.00', 'ausgebucht', journalId, forderungId, f.status, _fmtCents(observedCents)],
    );
    if (updated == 0) {
      throw ForderungenException('Forderung wurde bereits geschlossen', code: ForderungenErrorCode.alreadyClosed);
    }
    if (updated != 1) {
      throw ForderungenException(
        'Forderungsstatus konnte nicht eindeutig aktualisiert werden',
        code: ForderungenErrorCode.schemaMigrationFailed,
      );
    }
    final Forderung? result = await _readForderung(transaction, forderungId);
    if (result == null) throw ForderungenException('Forderung konnte nach Ausbuchung nicht gelesen werden');
    return result;
  }

  Future<Forderung?> _reloadKeyedPayment(
    String key,
    int forderungId,
    _CanonicalAmount amount,
    _CanonicalDate requestDate,
  ) async {
    return _runTransaction<Forderung?>(
      kind: ForderungenTransactionKind.payment,
      attempt: 1,
      useFactory: false,
      action: (QueryExecutor transaction) async {
        final rows = await transaction.runSelect(
          'SELECT * FROM forderung_zahlungen WHERE idempotency_key = ? LIMIT 1',
          <Object?>[key],
        );
        if (rows.isEmpty) return null;
        final row = rows.single;
        if (row['requested_betrag_cents'] == null ||
            row['fingerprint_direction'] == null ||
            row['fingerprint_date_policy'] == null) {
          throw ForderungenException(
            'Der vorhandene Idempotency-Key hat keinen vollständigen Fingerabdruck',
            code: ForderungenErrorCode.legacyFingerprintUnknown,
          );
        }
        final Forderung? requestedForderung = await _readForderung(transaction, forderungId);
        if (requestedForderung == null) throw ForderungenException('Forderung nicht gefunden');
        final String? requestedDirection = _directionFromRaw(requestedForderung.partnerTyp);
        if (requestedDirection == null) {
          throw ForderungenException('Partner-Richtung unbekannt', code: ForderungenErrorCode.unknownDirection);
        }
        final int targetId = _asNum(row['forderung_id'])?.toInt() ?? 0;
        final _Fingerprint fingerprint = _Fingerprint(
          requestedCents: amount.cents,
          forderungId: forderungId,
          direction: requestedDirection,
          datePolicy: requestDate.policy,
          effectiveDate: requestDate.date,
        );
        _throwIfFingerprintMismatch(row, fingerprint);
        return _readForderung(transaction, targetId);
      },
    );
  }

  Future<T> _runTransaction<T>({
    required ForderungenTransactionKind kind,
    required int attempt,
    required Future<T> Function(QueryExecutor transaction) action,
    bool useFactory = true,
  }) async {
    if (useFactory && transactionFactory != null) {
      return transactionFactory!.run<T>(kind: kind, attempt: attempt, executor: executor, action: action);
    }
    final TransactionExecutor transaction = executor.beginTransaction();
    await transaction.ensureOpen(_NoopTransactionUser());
    try {
      final T result = await action(transaction);
      await transaction.send();
      return result;
    } catch (error, stackTrace) {
      try {
        await transaction.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Forderung?> _readForderung(QueryExecutor source, int id) async {
    final rows = await source.runSelect('SELECT * FROM forderungen WHERE id = ? LIMIT 1', <Object?>[id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  void _throwIfFingerprintMismatch(Map<String, Object?> row, _Fingerprint requested) {
    final actual = _Fingerprint(
      requestedCents: _asNum(row['requested_betrag_cents'])?.toInt() ?? -1,
      forderungId: _asNum(row['forderung_id'])?.toInt() ?? -1,
      direction: row['fingerprint_direction']?.toString() ?? '',
      datePolicy: row['fingerprint_date_policy']?.toString() ?? '',
      effectiveDate: row['datum']?.toString() ?? '',
    );
    final fields = <ForderungenMismatchField>[];
    if (actual.requestedCents != requested.requestedCents) fields.add(ForderungenMismatchField.requestedCents);
    if (actual.forderungId != requested.forderungId) fields.add(ForderungenMismatchField.forderungTarget);
    if (actual.direction != requested.direction) fields.add(ForderungenMismatchField.direction);
    if (actual.datePolicy != requested.datePolicy) fields.add(ForderungenMismatchField.datePolicy);
    if (actual.effectiveDate != requested.effectiveDate) fields.add(ForderungenMismatchField.effectiveDate);
    if (fields.isNotEmpty) {
      throw ForderungenException(
        'Idempotency-Key wurde mit einem anderen Zahlungsauftrag verwendet',
        code: ForderungenErrorCode.idempotencyConflict,
        mismatchFields: fields,
      );
    }
  }

  _CanonicalAmount _canonicalAmount(num value) {
    if (!value.isFinite) throw ForderungenException('Zahlbetrag ungültig');
    final String text = value.toString();
    try {
      final int cents = money.parseScaled(text, scale: 2, field: 'Zahlbetrag');
      if (cents <= 0) throw ForderungenException('Zahlbetrag muss mindestens einen Cent betragen');
      return _CanonicalAmount(cents);
    } on money.MoneyParseException catch (error) {
      if (error.message.contains('more than 2 decimal')) {
        throw ForderungenException(error.message, code: ForderungenErrorCode.amountScale, cause: error);
      }
      throw ForderungenException('Zahlbetrag ungültig', cause: error);
    }
  }

  _CanonicalDate _canonicalDate(String? value) {
    if (value == null) {
      final DateTime now = _nowUtc();
      return _CanonicalDate(_formatDate(now), 'request-day');
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw ForderungenException('Datum muss im Format YYYY-MM-DD vorliegen', code: ForderungenErrorCode.dateFormat);
    }
    final List<String> parts = value.split('-');
    final int year = int.parse(parts[0]);
    final int month = int.parse(parts[1]);
    final int day = int.parse(parts[2]);
    final DateTime parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw ForderungenException('Datum ist kein gültiger Kalendertag', code: ForderungenErrorCode.dateFormat);
    }
    return _CanonicalDate(value, 'explicit');
  }

  DateTime _nowUtc() => (nowUtc?.call() ?? DateTime.now()).toUtc();

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String? _directionFromRaw(String? partnerTyp) {
    if (partnerTyp == 'kunde') return 'incoming';
    if (partnerTyp == 'lieferant') return 'outgoing';
    return null;
  }

  static const int _maxTransactionAttempts = 3;

  static Future<void> _backoff(int attempt) => Future<void>.delayed(Duration(milliseconds: attempt == 1 ? 10 : 25));

  static bool _isBusySnapshot(Object error) => error is SqliteException && error.extendedResultCode == 517;

  static bool _isRetryableLock(Object error) {
    if (error is SqliteException) return error.resultCode == 5 || error.resultCode == 6;
    final String message = error.toString().toLowerCase();
    return message.contains('database is locked') ||
        message.contains('database table is locked') ||
        message.contains('busy_snapshot') ||
        message.contains('sqlite_busy');
  }

  static bool _isUniqueViolation(Object error) {
    if (error is SqliteException) return error.resultCode == 19;
    return error.toString().toUpperCase().contains('UNIQUE') || error.toString().toUpperCase().contains('CONSTRAINT');
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
      // Preserve a null legacy partner type; payment validation maps it to
      // typed unknownDirection instead of guessing kunde.
      partnerTyp: r['partner_typ'] as String?,
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

class _CanonicalAmount {
  const _CanonicalAmount(this.cents);
  final int cents;
}

class _CanonicalDate {
  const _CanonicalDate(this.date, this.policy);
  final String date;
  final String policy;
}

class _Fingerprint {
  const _Fingerprint({
    required this.requestedCents,
    required this.forderungId,
    required this.direction,
    required this.datePolicy,
    required this.effectiveDate,
  });

  final int requestedCents;
  final int forderungId;
  final String direction;
  final String datePolicy;
  final String effectiveDate;
}

const String _paymentTableSql = '''
CREATE TABLE IF NOT EXISTS forderung_zahlungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  forderung_id INTEGER NOT NULL REFERENCES forderungen(id),
  journal_id INTEGER NOT NULL UNIQUE REFERENCES journal(id),
  betrag NUMERIC(12,2) NOT NULL,
  typ TEXT NOT NULL CHECK (typ IN ('zahlung','ueberzahlung','ausbuchen')),
  datum TEXT NOT NULL,
  idempotency_key TEXT UNIQUE,
  requested_betrag_cents INTEGER,
  fingerprint_direction TEXT,
  fingerprint_date_policy TEXT
)''';

String _dateOnly(String raw) => raw.length >= 10 ? raw.substring(0, 10) : raw;

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
