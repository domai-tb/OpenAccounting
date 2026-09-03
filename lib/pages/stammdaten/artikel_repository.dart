import 'package:drift/drift.dart';

class ArtikelException implements Exception {
  const ArtikelException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Artikel {
  const Artikel({
    required this.id,
    required this.bezeichnung,
    required this.typ,
    this.beschreibung,
    this.einheit,
    required this.vkNetto,
    required this.vkBrutto,
    required this.vkEingabe,
    this.ustSatzId,
    this.ustSatz,
    required this.differenzbesteuerung,
    this.ekNetto,
    required this.lagerAktiv,
    required this.bestandAktuell,
    required this.mindestbestand,
    required this.minusbestandErlaubt,
    this.lieferantId,
    this.lieferantenArtikelnr,
    this.gruppeId,
    this.artikelnummer,
    required this.aktiv,
  });

  final int id;
  final String bezeichnung;
  final String typ;
  final String? beschreibung;
  final String? einheit;
  final num vkNetto;
  final num vkBrutto;
  final String vkEingabe;
  final int? ustSatzId;
  final num? ustSatz;
  final bool differenzbesteuerung;
  final num? ekNetto;
  final bool lagerAktiv;
  final num bestandAktuell;
  final num mindestbestand;
  final bool minusbestandErlaubt;
  final int? lieferantId;
  final String? lieferantenArtikelnr;
  final int? gruppeId;
  final String? artikelnummer;
  final bool aktiv;
}

class ArtikelGruppe {
  const ArtikelGruppe({required this.id, required this.name, this.beschreibung, this.typ, required this.aktiv});
  final int id;
  final String name;
  final String? beschreibung;
  final String? typ;
  final bool aktiv;
}

class ArtikelRepository {
  ArtikelRepository(this.executor);
  final QueryExecutor executor;
  Future<void>? _schemaReady;
  Future<void> ensureSchema() => _schemaReady ??= _ensureSchema(executor);

  static const List<_ColumnDefinition> _artikelColumns = <_ColumnDefinition>[
    _ColumnDefinition('vk_brutto', 'NUMERIC(12,4) DEFAULT 0'),
    _ColumnDefinition('vk_eingabe', "TEXT DEFAULT 'brutto'"),
    _ColumnDefinition('differenzbesteuerung', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('ek_netto', 'NUMERIC(12,4)'),
    _ColumnDefinition('lager_aktiv', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('bestand_aktuell', 'NUMERIC(10,3) DEFAULT 0'),
    _ColumnDefinition('mindestbestand', 'NUMERIC(10,3) DEFAULT 0'),
    _ColumnDefinition('minusbestand_erlaubt', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('lieferant_id', 'INTEGER REFERENCES lieferanten(id)'),
    _ColumnDefinition('lieferanten_artikelnr', 'TEXT'),
    _ColumnDefinition('vk_netto', 'NUMERIC(12,4) DEFAULT 0'),
    _ColumnDefinition('ust_satz', 'NUMERIC(12,2)'),
    _ColumnDefinition('aktiv', 'INTEGER DEFAULT 1'),
  ];

  static const List<_ColumnDefinition> _gruppeColumns = <_ColumnDefinition>[
    _ColumnDefinition('typ', 'TEXT'),
    _ColumnDefinition('aktiv', 'INTEGER DEFAULT 1'),
  ];

  static const Set<String> _validTypes = <String>{'Artikel', 'Dienstleistung', 'Fremdleistung', 'Eigenleistung'};

  static const String _artikelSelect = '''
SELECT id, artikelnummer, bezeichnung, beschreibung, einheit, vk_netto, vk_brutto, vk_eingabe,
       ust_satz_id, ust_satz, differenzbesteuerung, ek_netto, lager_aktiv, bestand_aktuell,
       mindestbestand, minusbestand_erlaubt, lieferant_id, lieferanten_artikelnr, gruppe_id, aktiv, typ, bestand
FROM artikel
''';

  Future<Artikel> create({
    required String bezeichnung,
    String typ = 'Artikel',
    String? beschreibung,
    String einheit = 'Stk',
    num? vkNetto,
    num? vkBrutto,
    String vkEingabe = 'brutto',
    int? ustSatzId,
    num? ustSatz,
    bool differenzbesteuerung = false,
    num? ekNetto,
    bool lagerAktiv = false,
    num bestandAktuell = 0,
    num mindestbestand = 0,
    bool minusbestandErlaubt = false,
    int? lieferantId,
    String? lieferantenArtikelnr,
    int? gruppeId,
    String? artikelnummer,
    bool aktiv = true,
  }) async {
    if (bezeichnung.trim().isEmpty) throw const ArtikelException('Bezeichnung ist Pflicht');
    if (!_validTypes.contains(typ)) throw ArtikelException('Ungültiger Typ: $typ');
    await ensureSchema();
    // clear supplier link for Dienstleistung/Eigenleistung
    var resolvedLieferantId = lieferantId;
    var resolvedLieferantenArtikelnr = lieferantenArtikelnr;
    if (typ == 'Dienstleistung' || typ == 'Eigenleistung') {
      resolvedLieferantId = null;
      resolvedLieferantenArtikelnr = null;
    }
    // derive missing price
    final rate = await _resolveUstSatz(ustSatzId, ustSatz);
    late final num finalNetto;
    late final num finalBrutto;
    if (vkEingabe == 'brutto') {
      if (vkBrutto == null) throw const ArtikelException('vk_brutto ist Pflicht bei brutto Eingabe');
      finalNetto = vkBrutto / (1 + rate / 100);
      finalBrutto = vkBrutto;
    } else if (vkEingabe == 'netto') {
      if (vkNetto == null) throw const ArtikelException('vk_netto ist Pflicht bei netto Eingabe');
      finalBrutto = vkNetto * (1 + rate / 100);
      finalNetto = vkNetto;
    } else {
      throw const ArtikelException('vk_eingabe muss netto oder brutto sein');
    }

    final id = await executor.runInsert(
      '''
INSERT INTO artikel (
  bezeichnung, typ, beschreibung, einheit, vk_netto, vk_brutto, vk_eingabe,
  ust_satz_id, ust_satz, differenzbesteuerung, ek_netto, lager_aktiv, bestand_aktuell,
  mindestbestand, minusbestand_erlaubt, lieferant_id, lieferanten_artikelnr, gruppe_id, artikelnummer, aktiv, bestand
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      <Object?>[
        bezeichnung,
        typ,
        beschreibung,
        einheit,
        finalNetto,
        finalBrutto,
        vkEingabe,
        ustSatzId,
        ustSatz ?? rate,
        differenzbesteuerung ? 1 : 0,
        ekNetto,
        lagerAktiv ? 1 : 0,
        bestandAktuell,
        mindestbestand,
        minusbestandErlaubt ? 1 : 0,
        resolvedLieferantId,
        resolvedLieferantenArtikelnr,
        gruppeId,
        artikelnummer,
        aktiv ? 1 : 0,
        bestandAktuell.toInt(),
      ],
    );
    final stored = await findById(id);
    if (stored == null) throw const ArtikelException('Artikel konnte nicht gespeichert werden');
    return stored;
  }

  Future<Artikel?> findById(int id) async {
    await ensureSchema();
    final rows = await executor.runSelect('$_artikelSelect WHERE id = ?', <Object?>[id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<Artikel>> list() async {
    await ensureSchema();
    final rows = await executor.runSelect('$_artikelSelect ORDER BY id', const <Object?>[]);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Artikel> update(int id, Map<String, dynamic> values) async {
    await ensureSchema();
    final current = await findById(id);
    if (current == null) throw const ArtikelException('Artikel nicht gefunden');
    if (values.isEmpty) return current;
    // handle typ change clearing supplier
    if (values.containsKey('typ')) {
      final newTyp = values['typ'] as String;
      if (!_validTypes.contains(newTyp)) throw ArtikelException('Ungültiger Typ: $newTyp');
      if (newTyp == 'Dienstleistung' || newTyp == 'Eigenleistung') {
        values['lieferant_id'] = null;
        values['lieferanten_artikelnr'] = null;
      }
    }
    final allowed = <String, String>{
      'bezeichnung': 'bezeichnung',
      'typ': 'typ',
      'beschreibung': 'beschreibung',
      'einheit': 'einheit',
      'vk_netto': 'vk_netto',
      'vkNetto': 'vk_netto',
      'vk_brutto': 'vk_brutto',
      'vkBrutto': 'vk_brutto',
      'vk_eingabe': 'vk_eingabe',
      'vkEingabe': 'vk_eingabe',
      'ust_satz_id': 'ust_satz_id',
      'ustSatzId': 'ust_satz_id',
      'differenzbesteuerung': 'differenzbesteuerung',
      'ek_netto': 'ek_netto',
      'ekNetto': 'ek_netto',
      'lager_aktiv': 'lager_aktiv',
      'lagerAktiv': 'lager_aktiv',
      'bestand_aktuell': 'bestand_aktuell',
      'bestandAktuell': 'bestand_aktuell',
      'mindestbestand': 'mindestbestand',
      'minusbestand_erlaubt': 'minusbestand_erlaubt',
      'minusbestandErlaubt': 'minusbestand_erlaubt',
      'lieferant_id': 'lieferant_id',
      'lieferantId': 'lieferant_id',
      'lieferanten_artikelnr': 'lieferanten_artikelnr',
      'gruppe_id': 'gruppe_id',
      'gruppeId': 'gruppe_id',
      'artikelnummer': 'artikelnummer',
      'aktiv': 'aktiv',
    };
    final assignments = <String, Object?>{};
    for (final e in values.entries) {
      final col = allowed[e.key];
      if (col == null) throw ArtikelException('Unbekanntes Artikelfeld: ${e.key}');
      assignments[col] = e.value is bool ? ((e.value as bool) ? 1 : 0) : e.value;
    }
    if (assignments.isEmpty) return current;
    final sql = assignments.keys.map((c) => '$c = ?').join(', ');
    await executor.runUpdate('UPDATE artikel SET $sql WHERE id = ?', <Object?>[...assignments.values, id]);
    return (await findById(id))!;
  }

  Future<void> delete(int id) async {
    await ensureSchema();
    final refs = await executor.runSelect('SELECT id FROM rechnungspositionen WHERE artikel_id = ? LIMIT 1', <Object?>[
      id,
    ]);
    if (refs.isNotEmpty) {
      final ref = refs.single['id'];
      throw ArtikelException('Artikel wird von Rechnung #$ref verwendet');
    }
    final tmpl = await executor.runSelect(
      'SELECT id FROM rechnungsvorlagen WHERE vorlage_daten LIKE ? LIMIT 1',
      <Object?>['%$id%'],
    );
    // ponytail: simple template check via LIKE, strict FK not available
    if (tmpl.isNotEmpty) {
      throw ArtikelException('Artikel wird von Vorlage verwendet');
    }
    final deleted = await executor.runDelete('DELETE FROM artikel WHERE id = ?', <Object?>[id]);
    if (deleted == 0) throw const ArtikelException('Artikel nicht gefunden');
  }

  Future<List<ArtikelGruppe>> listGruppen({bool onlyActive = false}) async {
    await ensureSchema();
    final sql = onlyActive
        ? 'SELECT * FROM artikel_gruppen WHERE aktiv = 1 ORDER BY id'
        : 'SELECT * FROM artikel_gruppen ORDER BY id';
    final rows = await executor.runSelect(sql, const <Object?>[]);
    return rows
        .map(
          (r) => ArtikelGruppe(
            id: _asInt(r['id']) ?? 0,
            name: _asString(r['name']) ?? '',
            beschreibung: _asString(r['beschreibung']),
            typ: _asString(r['typ']),
            aktiv: _asBool(r['aktiv']),
          ),
        )
        .toList(growable: false);
  }

  Future<ArtikelGruppe> createGruppe({
    required String name,
    String? beschreibung,
    String? typ,
    bool aktiv = true,
  }) async {
    await ensureSchema();
    final id = await executor.runInsert(
      'INSERT INTO artikel_gruppen (name, beschreibung, typ, aktiv) VALUES (?, ?, ?, ?)',
      <Object?>[name, beschreibung, typ, aktiv ? 1 : 0],
    );
    await executor.runSelect('SELECT * FROM artikel_gruppen WHERE id = ?', <Object?>[id]);
    return ArtikelGruppe(id: id, name: name, beschreibung: beschreibung, typ: typ, aktiv: aktiv);
  }

  Future<num> _resolveUstSatz(int? id, num? direct) async {
    if (direct != null) return direct;
    if (id != null) {
      final rows = await executor.runSelect('SELECT satz FROM ust_saetze WHERE id = ?', <Object?>[id]);
      if (rows.isNotEmpty) {
        final v = _asNum(rows.single['satz']);
        if (v != null) return v;
      }
    }
    return 19;
  }

  Artikel _fromRow(Map<String, Object?> r) {
    return Artikel(
      id: _asInt(r['id']) ?? 0,
      bezeichnung: _asString(r['bezeichnung']) ?? '',
      typ: _asString(r['typ']) ?? 'Artikel',
      beschreibung: _asString(r['beschreibung']),
      einheit: _asString(r['einheit']),
      vkNetto: _asNum(r['vk_netto']) ?? 0,
      vkBrutto: _asNum(r['vk_brutto']) ?? 0,
      vkEingabe: _asString(r['vk_eingabe']) ?? 'brutto',
      ustSatzId: _asInt(r['ust_satz_id']),
      ustSatz: _asNum(r['ust_satz']),
      differenzbesteuerung: _asBool(r['differenzbesteuerung']),
      ekNetto: _asNum(r['ek_netto']),
      lagerAktiv: _asBool(r['lager_aktiv']),
      bestandAktuell: _asNum(r['bestand_aktuell']) ?? _asNum(r['bestand']) ?? 0,
      mindestbestand: _asNum(r['mindestbestand']) ?? 0,
      minusbestandErlaubt: _asBool(r['minusbestand_erlaubt']),
      lieferantId: _asInt(r['lieferant_id']),
      lieferantenArtikelnr: _asString(r['lieferanten_artikelnr']),
      gruppeId: _asInt(r['gruppe_id']),
      artikelnummer: _asString(r['artikelnummer']),
      aktiv: _asBool(r['aktiv']),
    );
  }

  static Future<void> _ensureSchema(QueryExecutor executor) async {
    await executor.ensureOpen(_NoopUser());
    final t = executor.beginTransaction();
    try {
      await t.ensureOpen(_NoopUser());
      await _addMissing(t, 'artikel', _artikelColumns);
      await _addMissing(t, 'artikel_gruppen', _gruppeColumns);
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
  static num? _asNum(Object? v) => v is num
      ? v
      : v is String
      ? num.tryParse(v)
      : null;
  static int? _asInt(Object? v) => _asNum(v)?.toInt();
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
