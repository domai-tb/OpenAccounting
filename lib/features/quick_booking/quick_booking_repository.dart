import 'package:drift/drift.dart';

class QuickBookingException implements Exception {
  const QuickBookingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Transaction direction of a quick-booking preset.
enum QuickBookingDirection {
  einnahme('einnahme'),
  ausgabe('ausgabe');

  const QuickBookingDirection(this.db);
  final String db;

  static QuickBookingDirection? fromDb(Object? v) {
    for (final d in QuickBookingDirection.values) {
      if (d.db == v) return d;
    }
    return null;
  }
}

/// Amount basis of a quick-booking preset.
enum QuickBookingModus {
  netto('netto'),
  brutto('brutto');

  const QuickBookingModus(this.db);
  final String db;

  static QuickBookingModus? fromDb(Object? v) {
    for (final m in QuickBookingModus.values) {
      if (m.db == v) return m;
    }
    return null;
  }
}

/// Reusable transaction preset with explicit execution semantics.
class QuickBookingPreset {
  const QuickBookingPreset({
    required this.id,
    required this.name,
    required this.beschreibung,
    this.direction,
    this.kontoId,
    this.kategorieId,
    this.ustSatzId,
    this.modus,
    this.betrag,
    this.hasInvalidReferences = false,
  });
  final int id;
  final String name;
  final String? beschreibung;
  final QuickBookingDirection? direction;
  final int? kontoId;
  final int? kategorieId;
  final int? ustSatzId;
  final QuickBookingModus? modus;
  final String? betrag;
  final bool hasInvalidReferences;

  /// Legacy/incomplete presets stay unchanged and need review; nothing is inferred.
  bool get needsReview => hasInvalidReferences || direction == null || ustSatzId == null || modus == null;
}

/// Typed preset lifecycle per quick-booking-workspace. Reads/writes only
/// through this boundary; never inserts into `journal`.
class QuickBookingRepository {
  QuickBookingRepository(this.executor);
  final QueryExecutor executor;

  static const String _select =
      'SELECT id, name, beschreibung, art, konto_id, kategorie_id, ust_satz_id, eingabemodus, betrag, '
      'CASE WHEN '
      '(konto_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM konten WHERE konten.id = schnellbuchungen.konto_id)) '
      'OR (kategorie_id IS NOT NULL AND NOT EXISTS '
      '(SELECT 1 FROM kategorien WHERE kategorien.id = schnellbuchungen.kategorie_id '
      'AND COALESCE(kategorien.aktiv, 0) <> 0)) '
      'OR (ust_satz_id IS NOT NULL AND NOT EXISTS '
      '(SELECT 1 FROM ust_saetze WHERE ust_saetze.id = schnellbuchungen.ust_satz_id)) '
      'THEN 1 ELSE 0 END AS has_invalid_references FROM schnellbuchungen';

  Future<List<QuickBookingPreset>> list() async {
    final rows = await executor.runSelect('$_select ORDER BY name, id', const <Object?>[]);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<QuickBookingPreset?> findById(int id) async {
    final rows = await executor.runSelect('$_select WHERE id = ?', <Object?>[id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<QuickBookingPreset> create({
    required String name,
    QuickBookingDirection? direction,
    int? kontoId,
    int? kategorieId,
    int? ustSatzId,
    QuickBookingModus? modus,
    String? betrag,
    String? beschreibung,
  }) async {
    if (name.trim().isEmpty) throw const QuickBookingException('Name ist Pflicht');
    await _validateRefs(kontoId: kontoId, kategorieId: kategorieId, ustSatzId: ustSatzId);
    final String? cleanBetrag = _validateBetrag(betrag);
    final id = await executor.runInsert(
      'INSERT INTO schnellbuchungen (name, beschreibung, art, konto_id, kategorie_id, ust_satz_id, eingabemodus, betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[name.trim(), beschreibung, direction?.db, kontoId, kategorieId, ustSatzId, modus?.db, cleanBetrag],
    );
    final stored = await findById(id);
    if (stored == null) throw const QuickBookingException('Preset konnte nicht gespeichert werden');
    return stored;
  }

  Future<QuickBookingPreset> update(
    int id, {
    String? name,
    QuickBookingDirection? direction,
    bool clearDirection = false,
    int? kontoId,
    int? kategorieId,
    int? ustSatzId,
    QuickBookingModus? modus,
    String? betrag,
    String? beschreibung,
  }) async {
    final current = await findById(id);
    if (current == null) throw const QuickBookingException('Preset nicht gefunden');
    final String nextName = (name ?? current.name).trim();
    if (nextName.isEmpty) throw const QuickBookingException('Name ist Pflicht');
    final int? nextKonto = kontoId ?? current.kontoId;
    final int? nextKategorie = kategorieId ?? current.kategorieId;
    final int? nextUst = ustSatzId ?? current.ustSatzId;
    await _validateRefs(kontoId: nextKonto, kategorieId: nextKategorie, ustSatzId: nextUst);
    await executor.runUpdate(
      'UPDATE schnellbuchungen SET name = ?, beschreibung = ?, art = ?, konto_id = ?, kategorie_id = ?, ust_satz_id = ?, eingabemodus = ?, betrag = ? WHERE id = ?',
      <Object?>[
        nextName,
        beschreibung ?? current.beschreibung,
        if (clearDirection) null else (direction?.db ?? current.direction?.db),
        nextKonto,
        nextKategorie,
        nextUst,
        modus?.db ?? current.modus?.db,
        if (betrag == null) current.betrag else _validateBetrag(betrag),
        id,
      ],
    );
    return (await findById(id))!;
  }

  Future<void> delete(int id) async {
    final deleted = await executor.runDelete('DELETE FROM schnellbuchungen WHERE id = ?', <Object?>[id]);
    if (deleted == 0) throw const QuickBookingException('Preset nicht gefunden');
  }

  Future<void> _validateRefs({int? kontoId, int? kategorieId, int? ustSatzId}) async {
    if (kontoId != null) {
      final rows = await executor.runSelect('SELECT id FROM konten WHERE id = ?', <Object?>[kontoId]);
      if (rows.isEmpty) throw const QuickBookingException('Konto nicht gefunden');
    }
    if (kategorieId != null) {
      final rows = await executor.runSelect(
        'SELECT id FROM kategorien WHERE id = ? AND COALESCE(aktiv, 0) <> 0',
        <Object?>[kategorieId],
      );
      if (rows.isEmpty) throw const QuickBookingException('Kategorie nicht gefunden oder inaktiv');
    }
    if (ustSatzId != null) {
      final rows = await executor.runSelect('SELECT id FROM ust_saetze WHERE id = ?', <Object?>[ustSatzId]);
      if (rows.isEmpty) throw const QuickBookingException('Steuersatz nicht gefunden');
    }
  }

  static String? _validateBetrag(String? betrag) {
    if (betrag == null) return null;
    final String t = betrag.trim();
    if (t.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) {
      throw const QuickBookingException('Betrag ungültig: max 2 Dezimalstellen');
    }
    return t;
  }

  QuickBookingPreset _fromRow(Map<String, Object?> r) {
    return QuickBookingPreset(
      id: (r['id']! as num).toInt(),
      name: r['name']?.toString() ?? '',
      beschreibung: r['beschreibung']?.toString(),
      direction: QuickBookingDirection.fromDb(r['art']),
      kontoId: (r['konto_id'] as num?)?.toInt(),
      kategorieId: (r['kategorie_id'] as num?)?.toInt(),
      ustSatzId: (r['ust_satz_id'] as num?)?.toInt(),
      modus: QuickBookingModus.fromDb(r['eingabemodus']),
      betrag: r['betrag']?.toString(),
      hasInvalidReferences: ((r['has_invalid_references'] as num?)?.toInt() ?? 0) != 0,
    );
  }
}
