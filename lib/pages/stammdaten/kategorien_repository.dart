import 'package:drift/drift.dart';

class KategorieException implements Exception {
  const KategorieException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Kategorie {
  const Kategorie({
    required this.id,
    required this.bezeichnung,
    this.beschreibung,
    this.art,
    this.kontoSkr03,
    this.kontoSkr04,
    this.kontoUstSkr03,
    this.kontoUstSkr04,
    this.euerZeile,
    this.eksKategorie,
    required this.aktiv,
    this.typ,
  });
  final int id;
  final String bezeichnung;
  final String? beschreibung;
  final String? art;
  final String? kontoSkr03;
  final String? kontoSkr04;
  final String? kontoUstSkr03;
  final String? kontoUstSkr04;
  final int? euerZeile;
  final String? eksKategorie;
  final bool aktiv;
  final String? typ;
}

class KategorienRepository {
  KategorienRepository(this.executor);
  final QueryExecutor executor;
  Future<void>? _schemaReady;
  Future<void> ensureSchema() => _schemaReady ??= _ensureSchema(executor);

  static const List<_ColumnDefinition> _kategorienColumns = <_ColumnDefinition>[
    _ColumnDefinition('konto_ust_skr03', 'TEXT'),
    _ColumnDefinition('konto_ust_skr04', 'TEXT'),
    _ColumnDefinition('art', 'TEXT'),
    _ColumnDefinition('typ', 'TEXT'),
    _ColumnDefinition('eks_kategorie', 'TEXT'),
    _ColumnDefinition('euer_zeile', 'INTEGER'),
    _ColumnDefinition('aktiv', 'INTEGER DEFAULT 1'),
    _ColumnDefinition('beschreibung', 'TEXT'),
  ];

  static const String _select = '''
SELECT id, bezeichnung, beschreibung, art, typ, konto_skr03, konto_skr04, konto_ust_skr03, konto_ust_skr04, euer_zeile, eks_kategorie, aktiv
FROM kategorien
''';

  Future<Kategorie> create({
    required String bezeichnung,
    String? beschreibung,
    String? art,
    String? kontoSkr03,
    String? kontoSkr04,
    String? kontoUstSkr03,
    String? kontoUstSkr04,
    int? euerZeile,
    String? eksKategorie,
    bool aktiv = true,
    String? typ,
  }) async {
    if (bezeichnung.trim().isEmpty) throw const KategorieException('Bezeichnung ist Pflicht');
    await ensureSchema();
    final id = await executor.runInsert(
      'INSERT INTO kategorien (bezeichnung, beschreibung, art, typ, konto_skr03, konto_skr04, konto_ust_skr03, konto_ust_skr04, euer_zeile, eks_kategorie, aktiv) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        bezeichnung,
        beschreibung,
        art,
        typ,
        kontoSkr03,
        kontoSkr04,
        kontoUstSkr03,
        kontoUstSkr04,
        euerZeile,
        eksKategorie,
        aktiv ? 1 : 0,
      ],
    );
    final stored = await findById(id);
    if (stored == null) throw const KategorieException('Kategorie konnte nicht gespeichert werden');
    return stored;
  }

  Future<Kategorie?> findById(int id) async {
    await ensureSchema();
    final rows = await executor.runSelect('$_select WHERE id = ?', <Object?>[id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<Kategorie>> list({bool onlyActive = false}) async {
    await ensureSchema();
    final sql = onlyActive ? '$_select WHERE aktiv = 1 ORDER BY id' : '$_select ORDER BY id';
    final rows = await executor.runSelect(sql, const <Object?>[]);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Kategorie> update(int id, Map<String, dynamic> values) async {
    await ensureSchema();
    final current = await findById(id);
    if (current == null) throw const KategorieException('Kategorie nicht gefunden');
    if (values.isEmpty) return current;
    final map = <String, String>{
      'bezeichnung': 'bezeichnung',
      'beschreibung': 'beschreibung',
      'art': 'art',
      'typ': 'typ',
      'kontoSkr03': 'konto_skr03',
      'konto_skr03': 'konto_skr03',
      'kontoSkr04': 'konto_skr04',
      'konto_skr04': 'konto_skr04',
      'kontoUstSkr03': 'konto_ust_skr03',
      'konto_ust_skr03': 'konto_ust_skr03',
      'kontoUstSkr04': 'konto_ust_skr04',
      'konto_ust_skr04': 'konto_ust_skr04',
      'euerZeile': 'euer_zeile',
      'euer_zeile': 'euer_zeile',
      'eksKategorie': 'eks_kategorie',
      'eks_kategorie': 'eks_kategorie',
      'aktiv': 'aktiv',
    };
    final assignments = <String, Object?>{};
    for (final e in values.entries) {
      final col = map[e.key];
      if (col == null) throw KategorieException('Unbekanntes Kategoriefeld: ${e.key}');
      assignments[col] = e.value is bool ? ((e.value as bool) ? 1 : 0) : e.value;
    }
    final sql = assignments.keys.map((c) => '$c = ?').join(', ');
    await executor.runUpdate('UPDATE kategorien SET $sql WHERE id = ?', <Object?>[...assignments.values, id]);
    return (await findById(id))!;
  }

  Future<void> delete(int id) async {
    await ensureSchema();
    final refs = await executor.runSelect('SELECT id FROM journal WHERE kategorie_id = ? LIMIT 1', <Object?>[id]);
    if (refs.isNotEmpty) {
      throw KategorieException('Kategorie wird von ${refs.length} Journalbuchungen verwendet');
    }
    // also check if still more than 5? mimic spec: show count
    final countRows = await executor.runSelect('SELECT COUNT(*) as c FROM journal WHERE kategorie_id = ?', <Object?>[
      id,
    ]);
    final count = _asInt(countRows.single['c']) ?? 0;
    if (count > 0) {
      throw KategorieException('Kategorie wird von $count Journalbuchungen verwendet');
    }
    final deleted = await executor.runDelete('DELETE FROM kategorien WHERE id = ?', <Object?>[id]);
    if (deleted == 0) throw const KategorieException('Kategorie nicht gefunden');
  }

  String kontoForSkr(Kategorie k, String skr) {
    if (skr == 'SKR04') return k.kontoSkr04 ?? k.kontoSkr03 ?? '';
    return k.kontoSkr03 ?? k.kontoSkr04 ?? '';
  }

  Kategorie _fromRow(Map<String, Object?> r) {
    return Kategorie(
      id: _asInt(r['id']) ?? 0,
      bezeichnung: _asString(r['bezeichnung']) ?? '',
      beschreibung: _asString(r['beschreibung']),
      art: _asString(r['art']),
      typ: _asString(r['typ']),
      kontoSkr03: _asString(r['konto_skr03']),
      kontoSkr04: _asString(r['konto_skr04']),
      kontoUstSkr03: _asString(r['konto_ust_skr03']),
      kontoUstSkr04: _asString(r['konto_ust_skr04']),
      euerZeile: _asInt(r['euer_zeile']),
      eksKategorie: _asString(r['eks_kategorie']),
      aktiv: _asBool(r['aktiv']),
    );
  }

  static Future<void> _ensureSchema(QueryExecutor executor) async {
    await executor.ensureOpen(_NoopUser());
    final t = executor.beginTransaction();
    try {
      await t.ensureOpen(_NoopUser());
      await _addMissing(t, 'kategorien', _kategorienColumns);
      await t.send();
    } catch (e, s) {
      try {
        await t.rollback();
      } catch (_) {}
      Error.throwWithStackTrace(e, s);
    }
  }

  static Future<void> _addMissing(QueryExecutor ex, String table, List<_ColumnDefinition> defs) async {
    final rows = await ex.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    final existing = <String>{
      for (final r in rows)
        if (r['name'] is String) r['name']! as String,
    };
    for (final d in defs) {
      if (!existing.contains(d.name)) {
        await ex.runCustom('ALTER TABLE $table ADD COLUMN ${d.name} ${d.definition}');
      }
    }
  }

  static String? _asString(Object? v) => v is String ? v : v?.toString();
  static int? _asInt(Object? v) => v is int
      ? v
      : v is num
      ? v.toInt()
      : v is String
      ? int.tryParse(v)
      : null;
  static bool _asBool(Object? v) => v is bool
      ? v
      : v is num
      ? v != 0
      : v == '1' || v == 'true';
}

class _ColumnDefinition {
  const _ColumnDefinition(this.name, this.definition);
  final String name;
  final String definition;
}

class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
