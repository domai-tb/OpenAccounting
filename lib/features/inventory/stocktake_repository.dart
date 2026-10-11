import 'package:drift/drift.dart';

import 'package:openaccounting/features/inventory/stocktake_entity.dart';

/// Typed failure for the stocktake workflow. Messages stay technical;
/// user-facing copy lives in the ARB catalogs.
class StocktakeException implements Exception {
  const StocktakeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Recording was refused because at least one count is still missing.
class StocktakeMissingCountException extends StocktakeException {
  const StocktakeMissingCountException() : super('missing-count');
}

/// Inventory is disabled: no new drafts or edits; history stays readable.
class StocktakeUnavailableException extends StocktakeException {
  const StocktakeUnavailableException() : super('inventory-disabled');
}

/// No inventory-enabled article can be snapshotted; no empty draft is made.
class StocktakeNoCountableArticlesException extends StocktakeException {
  const StocktakeNoCountableArticlesException() : super('no-countable-articles');
}

/// Recorded evidence is immutable; corrections need a new stocktake.
class StocktakeImmutableException extends StocktakeException {
  const StocktakeImmutableException() : super('recorded-immutable');
}

/// Valuation has no reviewed policy: fail closed without side effects.
class StocktakeValuationUnavailableException extends StocktakeException {
  const StocktakeValuationUnavailableException() : super('valuation-unavailable');
}

/// Count-evidence persistence below the UI. SQL stays here; the UI resolves
/// services through AppServices or the stocktake providers.
/// Writes touch only `inventuren`/`inventur_positionen`: never `artikel`
/// stock, `inventarbewegungen`, documents, or accounting records.
class StocktakeRepository {
  StocktakeRepository(this.executor);

  final QueryExecutor executor;

  /// Idempotent DDL hook for repaired profiles. The ordered v18 migration owns
  /// creation; this never rewrites stored values.
  Future<void> ensureSchema() async {
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS inventuren (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stichtag TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'entwurf' CHECK (status IN ('entwurf', 'erfasst')),
  erstellt_am TEXT NOT NULL
)''');
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS inventur_positionen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  inventur_id INTEGER NOT NULL REFERENCES inventuren(id) ON DELETE RESTRICT,
  artikel_id INTEGER NOT NULL,
  bezeichnung_snapshot TEXT NOT NULL CHECK (trim(bezeichnung_snapshot) <> ''),
  einheit_snapshot TEXT NOT NULL CHECK (trim(einheit_snapshot) <> ''),
  menge_gezaehlt NUMERIC(10,3) CHECK (menge_gezaehlt IS NULL OR menge_gezaehlt >= 0),
  UNIQUE (inventur_id, artikel_id)
)''');
  }

  /// Starts a draft for [stichtag] (ISO `YYYY-MM-DD`) and snapshots every
  /// currently inventory-enabled article once. Throws when no article can be
  /// snapshotted; no empty draft is created.
  Future<Stocktake> createDraft({required String stichtag}) async {
    _validateStichtag(stichtag);
    await executor.ensureOpen(_StocktakeNoopUser());
    final List<Map<String, Object?>> articles = await executor.runSelect(
      'SELECT id, bezeichnung, einheit FROM artikel WHERE lager_aktiv = 1 ORDER BY id',
      const <Object?>[],
    );
    if (articles.isEmpty) throw const StocktakeNoCountableArticlesException();
    final String now = DateTime.now().toUtc().toIso8601String();
    final TransactionExecutor t = executor.beginTransaction();
    try {
      await t.ensureOpen(_StocktakeNoopUser());
      final int id = await t.runInsert(
        'INSERT INTO inventuren (stichtag, status, erstellt_am) VALUES (?, ?, ?)',
        <Object?>[stichtag, 'entwurf', now],
      );
      for (final Map<String, Object?> article in articles) {
        final Object? rawId = article['id'];
        final int artikelId = rawId is num ? rawId.toInt() : int.parse(rawId.toString());
        final String bezeichnung = (article['bezeichnung']?.toString() ?? '').trim();
        if (bezeichnung.isEmpty) throw const StocktakeException('snapshot-bezeichnung-missing');
        final String einheit = (article['einheit']?.toString() ?? '').trim();
        final String snapshotEinheit = einheit.isEmpty ? 'Stk' : einheit;
        await t.runInsert(
          'INSERT INTO inventur_positionen (inventur_id, artikel_id, bezeichnung_snapshot,'
          ' einheit_snapshot, menge_gezaehlt) VALUES (?, ?, ?, ?, NULL)',
          <Object?>[id, artikelId, bezeichnung, snapshotEinheit],
        );
      }
      await t.send();
      final Stocktake? created = await findById(id);
      if (created == null) throw const StocktakeException('draft-not-persisted');
      return created;
    } catch (e, s) {
      try {
        await t.rollback();
      } catch (_) {}
      Error.throwWithStackTrace(e, s);
    }
  }

  /// Enters (or clears with null) one draft count. Recorded rows stay
  /// untouched; the database guard rejects recorded mutations as well.
  Future<Stocktake> setCount({required int inventurId, required int artikelId, required num? menge}) {
    return saveCounts(inventurId: inventurId, counts: <int, num?>{artikelId: menge});
  }

  /// Saves draft counts atomically, optionally recording the stocktake in the
  /// same transaction. Any failed count write leaves every prior count intact.
  Future<Stocktake> saveCounts({required int inventurId, required Map<int, num?> counts, bool record = false}) async {
    for (final num? menge in counts.values) {
      if (menge != null) _validateCount(menge);
    }

    await executor.ensureOpen(_StocktakeNoopUser());
    final TransactionExecutor t = executor.beginTransaction();
    try {
      await t.ensureOpen(_StocktakeNoopUser());
      final List<Map<String, Object?>> headers = await t.runSelect(
        'SELECT status FROM inventuren WHERE id = ?',
        <Object?>[inventurId],
      );
      if (headers.isEmpty) throw const StocktakeException('stocktake-not-found');
      if (headers.single['status'] != 'entwurf') throw const StocktakeImmutableException();

      final List<Map<String, Object?>> rows = await t.runSelect(
        'SELECT artikel_id FROM inventur_positionen WHERE inventur_id = ?',
        <Object?>[inventurId],
      );
      final Set<int> positionIds = <int>{
        for (final Map<String, Object?> row in rows)
          if (row['artikel_id'] is num)
            (row['artikel_id']! as num).toInt()
          else
            int.parse(row['artikel_id'].toString()),
      };
      if (!positionIds.containsAll(counts.keys)) throw const StocktakeException('position-not-found');

      for (final MapEntry<int, num?> entry in counts.entries) {
        final int changed = await t.runUpdate(
          'UPDATE inventur_positionen SET menge_gezaehlt = ? WHERE inventur_id = ? AND artikel_id = ?',
          <Object?>[entry.value, inventurId, entry.key],
        );
        if (changed == 0) throw const StocktakeException('position-not-found');
      }

      if (record) {
        final List<Map<String, Object?>> missing = await t.runSelect(
          'SELECT id FROM inventur_positionen WHERE inventur_id = ? AND menge_gezaehlt IS NULL LIMIT 1',
          <Object?>[inventurId],
        );
        if (positionIds.isEmpty || missing.isNotEmpty) throw const StocktakeMissingCountException();

        final int changed = await t.runUpdate(
          "UPDATE inventuren SET status = 'erfasst' WHERE id = ? AND status = 'entwurf'",
          <Object?>[inventurId],
        );
        if (changed == 0) throw const StocktakeImmutableException();
      }

      await t.send();
    } catch (e, s) {
      try {
        await t.rollback();
      } catch (_) {}
      Error.throwWithStackTrace(e, s);
    }

    final Stocktake? updated = await findById(inventurId);
    if (updated == null) throw const StocktakeException('stocktake-not-found');
    return updated;
  }

  /// Records a draft atomically. Requires a count for every position; the
  /// draft stays editable when validation fails. Never writes movements,
  /// stock, documents, or journal rows.
  Future<Stocktake> record(int inventurId) async {
    await executor.ensureOpen(_StocktakeNoopUser());
    final Stocktake? current = await findById(inventurId);
    if (current == null) throw const StocktakeException('stocktake-not-found');
    if (current.isRecorded) throw const StocktakeImmutableException();
    if (current.positionen.isEmpty || current.positionen.any((StocktakePosition p) => p.mengeGezaehlt == null)) {
      throw const StocktakeMissingCountException();
    }
    await executor.runUpdate("UPDATE inventuren SET status = 'erfasst' WHERE id = ? AND status = 'entwurf'", <Object?>[
      inventurId,
    ]);
    final Stocktake? recorded = await findById(inventurId);
    if (recorded == null || !recorded.isRecorded) throw const StocktakeMissingCountException();
    return recorded;
  }

  Future<Stocktake?> findById(int id) async {
    await executor.ensureOpen(_StocktakeNoopUser());
    final List<Map<String, Object?>> headers = await executor.runSelect(
      'SELECT id, stichtag, status, erstellt_am FROM inventuren WHERE id = ?',
      <Object?>[id],
    );
    if (headers.isEmpty) return null;
    return _fromRows(headers.single, await _positions(id));
  }

  /// Recorded history, newest first. Readable even when inventory is disabled.
  Future<List<Stocktake>> recordedHistory() async {
    await executor.ensureOpen(_StocktakeNoopUser());
    final List<Map<String, Object?>> headers = await executor.runSelect(
      "SELECT id, stichtag, status, erstellt_am FROM inventuren WHERE status = 'erfasst'"
      ' ORDER BY stichtag DESC, id DESC',
      const <Object?>[],
    );
    final List<Stocktake> out = <Stocktake>[];
    for (final Map<String, Object?> header in headers) {
      final Object? rawId = header['id'];
      out.add(_fromRows(header, await _positions(rawId is num ? rawId.toInt() : int.parse(rawId.toString()))));
    }
    return out;
  }

  /// Open drafts, newest first.
  Future<List<Stocktake>> openDrafts() async {
    await executor.ensureOpen(_StocktakeNoopUser());
    final List<Map<String, Object?>> headers = await executor.runSelect(
      "SELECT id, stichtag, status, erstellt_am FROM inventuren WHERE status = 'entwurf' ORDER BY id DESC",
      const <Object?>[],
    );
    final List<Stocktake> out = <Stocktake>[];
    for (final Map<String, Object?> header in headers) {
      final Object? rawId = header['id'];
      out.add(_fromRows(header, await _positions(rawId is num ? rawId.toInt() : int.parse(rawId.toString()))));
    }
    return out;
  }

  Future<List<StocktakePosition>> _positions(int inventurId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, inventur_id, artikel_id, bezeichnung_snapshot, einheit_snapshot, menge_gezaehlt'
      ' FROM inventur_positionen WHERE inventur_id = ? ORDER BY id',
      <Object?>[inventurId],
    );
    return rows.map(_positionFromRow).toList(growable: false);
  }

  Stocktake _fromRows(Map<String, Object?> header, List<StocktakePosition> positionen) {
    final Object? rawId = header['id'];
    return Stocktake(
      id: rawId is num ? rawId.toInt() : int.parse(rawId.toString()),
      stichtag: header['stichtag'].toString(),
      status: header['status'] == 'erfasst' ? StocktakeStatus.erfasst : StocktakeStatus.entwurf,
      erstelltAm: header['erstellt_am'].toString(),
      positionen: positionen,
    );
  }

  StocktakePosition _positionFromRow(Map<String, Object?> row) {
    int asInt(Object? v) => v is num ? v.toInt() : int.parse(v.toString());
    num? asNum(Object? v) => v == null
        ? null
        : v is num
        ? v
        : num.tryParse(v.toString());
    return StocktakePosition(
      id: asInt(row['id']),
      inventurId: asInt(row['inventur_id']),
      artikelId: asInt(row['artikel_id']),
      bezeichnungSnapshot: row['bezeichnung_snapshot'].toString(),
      einheitSnapshot: row['einheit_snapshot'].toString(),
      mengeGezaehlt: asNum(row['menge_gezaehlt']),
    );
  }

  static void _validateStichtag(String stichtag) {
    final DateTime? parsed = DateTime.tryParse(stichtag);
    if (parsed == null || stichtag.length != 10 || parsed.toIso8601String().substring(0, 10) != stichtag) {
      throw const StocktakeException('invalid-stichtag');
    }
  }

  /// Three-decimal stock precision; zero counts, never negative.
  static void _validateCount(num menge) {
    if (!menge.isFinite) throw const StocktakeException('count-not-finite');
    if (menge < 0) throw const StocktakeException('count-negative');
    final double scaled = menge * 1000;
    if (!scaled.isFinite || (scaled - scaled.round()).abs() > 1e-9) {
      throw const StocktakeException('count-precision');
    }
  }
}

class _StocktakeNoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
