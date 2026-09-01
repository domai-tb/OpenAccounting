import 'package:drift/drift.dart';

import 'package:openaccounting/features/mahnwesen/mahnwesen_einstellungen.dart';

class MahnwesenEinstellungenRepository {
  MahnwesenEinstellungenRepository(this.executor);

  final QueryExecutor executor;

  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= _doInit();

  Future<void> _doInit() async {
    await _ensureColumns();
  }

  Future<void> _ensureColumns() async {
    try {
      final cols = await executor.runSelect('PRAGMA table_info(mahnwesen_einstellungen)', const <Object?>[]);
      final names = <String>{for (final r in cols) (r['name'] as String?) ?? ''};
      if (!names.contains('grace_tage')) {
        try {
          await executor.runCustom('ALTER TABLE mahnwesen_einstellungen ADD COLUMN grace_tage INTEGER DEFAULT 0');
        } catch (_) {}
      }
      if (!names.contains('email_template')) {
        try {
          await executor.runCustom('ALTER TABLE mahnwesen_einstellungen ADD COLUMN email_template TEXT');
        } catch (_) {}
      }
      if (!names.contains('zinssatz_default')) {
        try {
          await executor.runCustom(
            'ALTER TABLE mahnwesen_einstellungen ADD COLUMN zinssatz_default NUMERIC(12,2) DEFAULT 0',
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<MahnwesenEinstellungen> get() async {
    await _ensureInitialized();
    final rows = await executor.runSelect(
      'SELECT id, schwelle_warnung, schwelle_sperrung, aktiv, unternehmen_id, '
      'COALESCE(grace_tage, 0) AS grace_tage '
      'FROM mahnwesen_einstellungen ORDER BY id ASC LIMIT 1',
      const <Object?>[],
    );
    if (rows.isEmpty) {
      // ponytail: singleton default per spec §Default settings.
      try {
        final id = await executor.runInsert(
          'INSERT INTO mahnwesen_einstellungen (schwelle_warnung, schwelle_sperrung, aktiv, grace_tage) VALUES (?, ?, ?, ?)',
          const <Object?>[2, 3, 0, 0],
        );
        return await _fetchById(id);
      } catch (_) {
        // fallback if grace_tage column missing on very old DB — insert without it.
        final id = await executor.runInsert(
          'INSERT INTO mahnwesen_einstellungen (schwelle_warnung, schwelle_sperrung, aktiv) VALUES (?, ?, ?)',
          const <Object?>[2, 3, 0],
        );
        return await _fetchById(id);
      }
    }
    return _fromRow(rows.single);
  }

  Future<MahnwesenEinstellungen> getOrCreate() => get();

  Future<MahnwesenEinstellungen> setSchwellen({required int warnung, required int sperrung}) async {
    return update(schwelleWarnung: warnung, schwelleSperrung: sperrung);
  }

  Future<MahnwesenEinstellungen> update({
    int? schwelleWarnung,
    int? schwelleSperrung,
    bool? aktiv,
    int? graceTage,
    int? unternehmenId,
  }) async {
    await _ensureInitialized();
    final current = await get();
    final assignments = <String, Object?>{};
    if (schwelleWarnung != null) {
      if (schwelleWarnung < 1) {
        throw ArgumentError('schwelleWarnung muss >=1 sein');
      }
      assignments['schwelle_warnung'] = schwelleWarnung;
    }
    if (schwelleSperrung != null) {
      if (schwelleSperrung < 1) {
        throw ArgumentError('schwelleSperrung muss >=1 sein');
      }
      assignments['schwelle_sperrung'] = schwelleSperrung;
    }
    if (aktiv != null) {
      assignments['aktiv'] = aktiv ? 1 : 0;
    }
    if (graceTage != null) {
      assignments['grace_tage'] = graceTage;
    }
    if (unternehmenId != null) {
      assignments['unternehmen_id'] = unternehmenId;
    }
    if (assignments.isEmpty) return current;
    final setClause = assignments.keys.map((k) => '$k = ?').join(', ');
    final values = <Object?>[...assignments.values, current.id];
    try {
      await executor.runUpdate('UPDATE mahnwesen_einstellungen SET $setClause WHERE id = ?', values);
    } catch (e) {
      // ponytail: fallback if grace_tage column missing — retry without it.
      if (assignments.containsKey('grace_tage')) {
        final filtered = Map<String, Object?>.from(assignments)..remove('grace_tage');
        if (filtered.isEmpty) return current;
        final clause2 = filtered.keys.map((k) => '$k = ?').join(', ');
        final values2 = <Object?>[...filtered.values, current.id];
        await executor.runUpdate('UPDATE mahnwesen_einstellungen SET $clause2 WHERE id = ?', values2);
      } else {
        rethrow;
      }
    }
    return _fetchById(current.id);
  }

  Future<MahnwesenEinstellungen> _fetchById(int id) async {
    final rows = await executor.runSelect(
      'SELECT id, schwelle_warnung, schwelle_sperrung, aktiv, unternehmen_id, '
      'COALESCE(grace_tage, 0) AS grace_tage '
      'FROM mahnwesen_einstellungen WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      // fallback without grace_tage.
      final fallback = await executor.runSelect(
        'SELECT id, schwelle_warnung, schwelle_sperrung, aktiv, unternehmen_id '
        'FROM mahnwesen_einstellungen WHERE id = ? LIMIT 1',
        <Object?>[id],
      );
      if (fallback.isEmpty) throw StateError('MahnwesenEinstellungen nicht gefunden');
      final r = fallback.single;
      return MahnwesenEinstellungen(
        id: _asInt(r['id']) ?? id,
        schwelleWarnung: _asInt(r['schwelle_warnung']) ?? 2,
        schwelleSperrung: _asInt(r['schwelle_sperrung']) ?? 3,
        aktiv: _asBool(r['aktiv']),
        unternehmenId: _asInt(r['unternehmen_id']),
        graceTage: 0,
      );
    }
    return _fromRow(rows.single);
  }

  MahnwesenEinstellungen _fromRow(Map<String, Object?> r) {
    return MahnwesenEinstellungen(
      id: _asInt(r['id']) ?? 0,
      schwelleWarnung: _asInt(r['schwelle_warnung']) ?? 2,
      schwelleSperrung: _asInt(r['schwelle_sperrung']) ?? 3,
      aktiv: _asBool(r['aktiv']),
      unternehmenId: _asInt(r['unternehmen_id']),
      graceTage: _asInt(r['grace_tage']) ?? 0,
    );
  }

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
}
