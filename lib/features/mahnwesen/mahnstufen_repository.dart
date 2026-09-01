import 'package:drift/drift.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_exception.dart';

class MahnstufenRepository {
  MahnstufenRepository(this.executor);

  final QueryExecutor executor;

  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= _doInit();

  Future<void> _doInit() async {
    await _ensureMahnwesenColumns();
    await _ensureFourLevels();
  }

  Future<void> _ensureMahnwesenColumns() async {
    // ponytail: additive migration — idempotent ALTER, no rebuild.
    final cols = await executor.runSelect('PRAGMA table_info(mahnstufen)', const <Object?>[]);
    final names = <String>{for (final r in cols) (r['name'] as String?) ?? ''};
    if (!names.contains('multiplier')) {
      try {
        await executor.runCustom('ALTER TABLE mahnstufen ADD COLUMN multiplier INTEGER DEFAULT 0');
      } catch (_) {}
    }
    // Ensure base columns exist if older DB missing them (defensive).
    if (!names.contains('system_stufe')) {
      try {
        await executor.runCustom('ALTER TABLE mahnstufen ADD COLUMN system_stufe INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (!names.contains('tage_nach_faelligkeit')) {
      try {
        await executor.runCustom('ALTER TABLE mahnstufen ADD COLUMN tage_nach_faelligkeit INTEGER DEFAULT 0');
      } catch (_) {}
    }
  }

  Future<void> _ensureFourLevels() async {
    // Ensure 4 system levels idempotent — matches spec Four Dunning Levels.
    // ponytail: tage 7/21/35/49 per docs/05-mahnwesen.md (review fix; task text 7/14/21/28 is ponytail deviation from spec weekly steps).
    const standards = <_StdLevel>[
      _StdLevel(stufe: 1, bezeichnung: 'Mahnung 1', tage: 7, gebuehr: '5.00', zinssatz: '0.00'),
      _StdLevel(stufe: 2, bezeichnung: 'Mahnung 2', tage: 21, gebuehr: '10.00', zinssatz: '5.00'),
      _StdLevel(stufe: 3, bezeichnung: 'Mahnung 3', tage: 35, gebuehr: '15.00', zinssatz: '8.00'),
      _StdLevel(stufe: 4, bezeichnung: 'Letzte Mahnung vor Inkasso', tage: 49, gebuehr: '25.00', zinssatz: '8.00'),
    ];
    for (final s in standards) {
      final existing = await executor.runSelect(
        'SELECT id FROM mahnstufen WHERE bezeichnung = ? AND system_stufe = 1 LIMIT 1',
        <Object?>[s.bezeichnung],
      );
      if (existing.isNotEmpty) continue;
      // Also check by stufe system to avoid duplicate stufe with different name.
      final byStufe = await executor.runSelect(
        'SELECT id FROM mahnstufen WHERE stufe = ? AND system_stufe = 1 LIMIT 1',
        <Object?>[s.stufe],
      );
      if (byStufe.isNotEmpty) continue;
      await executor.runInsert(
        'INSERT INTO mahnstufen (stufe, bezeichnung, tage_nach_faelligkeit, gebuehr, zinssatz, system_stufe, multiplier) VALUES (?, ?, ?, ?, ?, 1, 0)',
        <Object?>[s.stufe, s.bezeichnung, s.tage, s.gebuehr, s.zinssatz],
      );
    }
  }

  Future<List<Mahnstufe>> list() async {
    await _ensureInitialized();
    final rows = await executor.runSelect(
      'SELECT id, stufe, bezeichnung, tage_nach_faelligkeit, gebuehr, zinssatz, system_stufe, multiplier FROM mahnstufen ORDER BY stufe ASC, id ASC',
      const <Object?>[],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Mahnstufe?> getById(int id) async {
    await _ensureInitialized();
    final rows = await executor.runSelect(
      'SELECT id, stufe, bezeichnung, tage_nach_faelligkeit, gebuehr, zinssatz, system_stufe, multiplier FROM mahnstufen WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<Mahnstufe> create({
    required int stufe,
    required String bezeichnung,
    String gebuehr = '0.00',
    String zinssatz = '0.00',
    int tageNachFaelligkeit = 0,
    bool systemStufe = false,
    bool multiplier = false,
  }) async {
    await _ensureInitialized();
    if (systemStufe) throw const MahnstufeException('Systemstufe kann nicht manuell erstellt werden');
    _validateStufe(stufe);
    _validateBezeichnung(bezeichnung);
    final g = _normalizeMoney(gebuehr, 'Gebühr');
    final z = _normalizeMoney(zinssatz, 'Zinssatz');
    _validateTage(tageNachFaelligkeit);
    final id = await executor.runInsert(
      'INSERT INTO mahnstufen (stufe, bezeichnung, tage_nach_faelligkeit, gebuehr, zinssatz, system_stufe, multiplier) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        stufe,
        bezeichnung.trim(),
        tageNachFaelligkeit,
        g,
        z,
        if (systemStufe) 1 else 0,
        if (multiplier) 1 else 0,
      ],
    );
    final created = await getById(id);
    if (created == null) throw const MahnstufeException('Mahnstufe konnte nicht erstellt werden');
    return created;
  }

  Future<Mahnstufe> update(
    int id, {
    String? bezeichnung,
    String? gebuehr,
    String? zinssatz,
    int? tageNachFaelligkeit,
    bool? multiplier,
    int? stufe,
  }) async {
    await _ensureInitialized();
    final current = await getById(id);
    if (current == null) throw const MahnstufeException('Mahnstufe nicht gefunden');
    final assignments = <String, Object?>{};
    if (bezeichnung != null) {
      _validateBezeichnung(bezeichnung);
      assignments['bezeichnung'] = bezeichnung.trim();
    }
    if (gebuehr != null) {
      assignments['gebuehr'] = _normalizeMoney(gebuehr, 'Gebühr');
    }
    if (zinssatz != null) {
      assignments['zinssatz'] = _normalizeMoney(zinssatz, 'Zinssatz');
    }
    if (tageNachFaelligkeit != null) {
      _validateTage(tageNachFaelligkeit);
      assignments['tage_nach_faelligkeit'] = tageNachFaelligkeit;
    }
    if (multiplier != null) {
      assignments['multiplier'] = multiplier ? 1 : 0;
    }
    if (stufe != null) {
      _validateStufe(stufe);
      assignments['stufe'] = stufe;
    }
    if (assignments.isEmpty) return current;
    final setClause = assignments.keys.map((k) => '$k = ?').join(', ');
    final values = <Object?>[...assignments.values, id];
    await executor.runUpdate('UPDATE mahnstufen SET $setClause WHERE id = ?', values);
    final updated = await getById(id);
    if (updated == null) throw const MahnstufeException('Mahnstufe konnte nicht aktualisiert werden');
    return updated;
  }

  Future<void> delete(int id) async {
    await _ensureInitialized();
    final rows = await executor.runSelect('SELECT system_stufe FROM mahnstufen WHERE id = ? LIMIT 1', <Object?>[id]);
    if (rows.isEmpty) throw const MahnstufeException('Mahnstufe nicht gefunden');
    final isSystem = _asBool(rows.single['system_stufe']);
    if (isSystem) throw const MahnstufeException('Systemstufe geschützt');
    await executor.runDelete('DELETE FROM mahnstufen WHERE id = ?', <Object?>[id]);
  }

  Future<String> effektiveGebuehr(int id) async {
    await _ensureInitialized();
    final rows = await executor.runSelect(
      'SELECT stufe, gebuehr, multiplier FROM mahnstufen WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) throw const MahnstufeException('Mahnstufe nicht gefunden');
    final ownStr = _asMoneyString(rows.single['gebuehr']);
    final own = _parseMoney(ownStr);
    final isMultiplier = _asBool(rows.single['multiplier']);
    if (!isMultiplier) return _formatMoney(own);
    final stufe = _asInt(rows.single['stufe']) ?? 0;
    if (stufe <= 1) return _formatMoney(own);
    // ponytail: multiplier = immediate predecessor sum, not full history — minimal correct per spec scenario.
    final prior = await executor.runSelect(
      'SELECT gebuehr FROM mahnstufen WHERE stufe = ? ORDER BY stufe DESC LIMIT 1',
      <Object?>[stufe - 1],
    );
    if (prior.isEmpty) return _formatMoney(own);
    final priorMoney = _parseMoney(_asMoneyString(prior.single['gebuehr']));
    return _formatMoney(own + priorMoney);
  }

  // Helpers

  Mahnstufe _fromRow(Map<String, Object?> r) {
    return Mahnstufe(
      id: _asInt(r['id']) ?? 0,
      stufe: _asInt(r['stufe']) ?? 0,
      bezeichnung: _asString(r['bezeichnung']) ?? '',
      tageNachFaelligkeit: _asInt(r['tage_nach_faelligkeit']) ?? 0,
      gebuehr: _asMoneyString(r['gebuehr']),
      zinssatz: _asMoneyString(r['zinssatz']),
      systemStufe: _asBool(r['system_stufe']),
      multiplier: _asBool(r['multiplier']),
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
    if (n == null) throw MahnstufeException('$field ungültig');
    if (n < 0) throw MahnstufeException('$field darf nicht negativ sein');
    // Ensure max 2 decimals — round to cents.
    final cents = (n * 100).round();
    return (cents / 100).toStringAsFixed(2);
  }

  static num _parseMoney(String v) => num.tryParse(v) ?? 0;

  static String _formatMoney(num v) => v.toStringAsFixed(2);

  static void _validateBezeichnung(String v) {
    if (v.trim().isEmpty) throw const MahnstufeException('Bezeichnung ist Pflicht');
  }

  static void _validateStufe(int v) {
    if (v <= 0) throw const MahnstufeException('Stufe muss > 0 sein');
  }

  static void _validateTage(int v) {
    if (v < 0) throw const MahnstufeException('Tage darf nicht negativ sein');
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
    return v == '1' || v == 'true' || v == 1;
  }
}

class _StdLevel {
  const _StdLevel({
    required this.stufe,
    required this.bezeichnung,
    required this.tage,
    required this.gebuehr,
    required this.zinssatz,
  });

  final int stufe;
  final String bezeichnung;
  final int tage;
  final String gebuehr;
  final String zinssatz;
}
