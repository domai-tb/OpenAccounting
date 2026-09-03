import 'package:drift/drift.dart';

class Lieferant {
  const Lieferant({
    required this.id,
    required this.kreditorNr,
    required this.anrede,
    required this.name,
    this.firma,
    required this.strasse,
    this.hausnummer,
    required this.plz,
    required this.ort,
    required this.land,
    this.ustIdNr,
    this.foreignTaxNumber,
    this.telefon,
    this.email,
    this.iban,
    required this.zahlungsziel,
    required this.skontoProzent,
    required this.skontoTage,
    this.note,
  });

  final int id;
  final String kreditorNr;
  final String anrede;
  final String name;
  final String? firma;
  final String strasse;
  final String? hausnummer;
  final String plz;
  final String ort;
  final String land;
  final String? ustIdNr;
  final String? foreignTaxNumber;
  final String? telefon;
  final String? email;
  final String? iban;
  final int zahlungsziel;
  final num skontoProzent;
  final int skontoTage;
  final String? note;

  String get lieferantennummer => kreditorNr;

  String? get steuernummerAusland => foreignTaxNumber;
}

class LieferantenException implements Exception {
  const LieferantenException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LieferantenRepository {
  LieferantenRepository(this.executor);

  final QueryExecutor executor;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??= _ensureSchema(executor);

  static const List<_ColumnDefinition> _lieferantenColumns = <_ColumnDefinition>[
    _ColumnDefinition('anrede', "TEXT NOT NULL DEFAULT 'Herr'"),
    _ColumnDefinition('firma', 'TEXT'),
    _ColumnDefinition('hausnummer', 'TEXT'),
    _ColumnDefinition('steuernummer_ausland', 'VARCHAR(50)'),
    _ColumnDefinition('zahlungsziel', 'INTEGER DEFAULT 14'),
    _ColumnDefinition('skonto_prozent', 'NUMERIC(12,2) DEFAULT 0'),
    _ColumnDefinition('skonto_tage', 'INTEGER NOT NULL DEFAULT 0'),
    _ColumnDefinition('note', 'TEXT'),
    _ColumnDefinition('kreditor_nr', 'TEXT'),
    _ColumnDefinition('lieferantennummer', 'TEXT'),
  ];

  static const List<_ColumnDefinition> _nummernkreisColumns = <_ColumnDefinition>[
    _ColumnDefinition('naechste_nummer', 'INTEGER DEFAULT 1'),
    _ColumnDefinition('aktiv', 'INTEGER NOT NULL DEFAULT 1'),
    _ColumnDefinition('letzte_nummer', 'INTEGER'),
    _ColumnDefinition('letze_nummer', 'INTEGER'),
  ];

  static const Map<String, String> _updateColumns = <String, String>{
    'anrede': 'anrede',
    'name': 'name',
    'firma': 'firma',
    'strasse': 'strasse',
    'hausnummer': 'hausnummer',
    'plz': 'plz',
    'ort': 'ort',
    'land': 'land',
    'ustIdNr': 'ust_idnr',
    'ust_idnr': 'ust_idnr',
    'foreignTaxNumber': 'steuernummer_ausland',
    'steuernummerAusland': 'steuernummer_ausland',
    'steuernummer_ausland': 'steuernummer_ausland',
    'telefon': 'telefon',
    'email': 'email',
    'iban': 'iban',
    'zahlungsziel': 'zahlungsziel',
    'skontoProzent': 'skonto_prozent',
    'skonto_prozent': 'skonto_prozent',
    'skontoTage': 'skonto_tage',
    'skonto_tage': 'skonto_tage',
    'note': 'note',
  };

  static const Map<String, String> _fallbackVatPatterns = <String, String>{
    'DE': r'^DE[0-9]{9}$',
    'AT': r'^ATU[0-9]{8}$',
    'FR': r'^FR[0-9A-Z]{2}[0-9]{9}$',
    'IT': r'^IT[0-9]{11}$',
    'ES': r'^ES[A-Z0-9][0-9]{7}[A-Z0-9]$',
    'NL': r'^NL[0-9]{9}B[0-9]{2}$',
    'PL': r'^PL[0-9]{10}$',
    'BE': r'^BE[0-9]{10}$',
    'SE': r'^SE[0-9]{12}$',
    'DK': r'^DK[0-9]{8}$',
    'FI': r'^FI[0-9]{8}$',
    'IE': r'^IE[0-9][0-9A-Z*+][0-9]{5}[A-Z]{1,2}$',
    'PT': r'^PT[0-9]{9}$',
    'CZ': r'^CZ[0-9]{8,10}$',
    'HR': r'^HR[0-9]{11}$',
    'HU': r'^HU[0-9]{8}$',
    'RO': r'^RO[0-9]{2,10}$',
    'BG': r'^BG[0-9]{9,10}$',
    'SK': r'^SK[0-9]{10}$',
    'SI': r'^SI[0-9]{8}$',
    'LT': r'^LT[0-9]{9,12}$',
    'LV': r'^LV[0-9]{11}$',
    'EE': r'^EE[0-9]{9}$',
    'CY': r'^CY[0-9]{8}[A-Z]$',
    'MT': r'^MT[0-9]{8}$',
    'LU': r'^LU[0-9]{8}$',
    'GR': r'^EL[0-9]{9}$',
  };

  static const String _lieferantSelect = '''
SELECT id, lieferantennummer, kreditor_nr, anrede, name, firma, strasse, hausnummer,
       plz, ort, land, ust_idnr, steuernummer_ausland, telefon, email, iban,
       zahlungsziel, skonto_prozent, skonto_tage, note
FROM lieferanten
''';

  Future<Lieferant> create({
    required String name,
    String anrede = 'Herr',
    String? firma,
    required String strasse,
    String? hausnummer,
    required String plz,
    required String ort,
    String land = 'DE',
    String? ustIdNr,
    String? foreignTaxNumber,
    String? telefon,
    String? email,
    String? iban,
    int zahlungsziel = 14,
    num skontoProzent = 0,
    int skontoTage = 0,
    String? note,
  }) async {
    _validateRequired(anrede, 'Anrede');
    _validateRequired(name, 'Name');
    _validateRequired(strasse, 'Straße');
    _validateRequired(plz, 'PLZ');
    _validateRequired(ort, 'Ort');
    _validateRequired(land, 'Land');
    final country = _normalizeCountry(land);
    _validateForeignTaxNumber(foreignTaxNumber);
    await ensureSchema();
    await _validateVatId(country, ustIdNr);

    final transaction = executor.beginTransaction();
    late final int id;
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final kreditorNr = await _allocateKreditorNumber(transaction);
      id = await transaction.runInsert(
        '''
INSERT INTO lieferanten (
  lieferantennummer, kreditor_nr, anrede, name, firma, strasse, hausnummer, plz, ort, land,
  ust_idnr, steuernummer_ausland, telefon, email, iban, zahlungsziel, skonto_prozent, skonto_tage, note
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
        <Object?>[
          kreditorNr,
          kreditorNr,
          anrede,
          name,
          firma,
          strasse,
          hausnummer,
          plz,
          ort,
          country,
          ustIdNr,
          foreignTaxNumber,
          telefon,
          email,
          iban,
          zahlungsziel,
          skontoProzent,
          skontoTage,
          note,
        ],
      );
      await transaction.send();
    } catch (error, stackTrace) {
      await _rollback(transaction);
      if (error is LieferantenException) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      Error.throwWithStackTrace(const LieferantenException('Lieferant konnte nicht gespeichert werden'), stackTrace);
    }

    final stored = await findById(id);
    if (stored == null) {
      throw const LieferantenException('Lieferant konnte nicht gespeichert werden');
    }
    return stored;
  }

  Future<Lieferant?> findById(int id) async {
    await ensureSchema();
    final rows = await executor.runSelect('$_lieferantSelect WHERE id = ?', <Object?>[id]);
    return rows.isEmpty ? null : _lieferantFromRow(rows.single);
  }

  Future<List<Lieferant>> list() async {
    await ensureSchema();
    final rows = await executor.runSelect('$_lieferantSelect ORDER BY id', const <Object?>[]);
    return rows.map(_lieferantFromRow).toList(growable: false);
  }

  Future<Lieferant> update(int id, Map<String, dynamic> values) async {
    await ensureSchema();
    final currentRows = await executor.runSelect('$_lieferantSelect WHERE id = ?', <Object?>[id]);
    if (currentRows.isEmpty) {
      throw const LieferantenException('Lieferant nicht gefunden');
    }
    final current = currentRows.single;
    final merged = Map<String, Object?>.from(current);
    final assignments = <String, Object?>{};
    for (final entry in values.entries) {
      final column = _updateColumns[entry.key];
      if (column == null) {
        throw LieferantenException('Unbekanntes Lieferantenfeld: ${entry.key}');
      }
      final value = _toDatabaseValue(column, entry.value);
      assignments[column] = value;
      merged[column] = value;
    }
    if (assignments.isEmpty) return _lieferantFromRow(current);

    _validateRequired(_asString(merged['anrede']) ?? '', 'Anrede');
    _validateRequired(_asString(merged['name']) ?? '', 'Name');
    _validateRequired(_asString(merged['strasse']) ?? '', 'Straße');
    _validateRequired(_asString(merged['plz']) ?? '', 'PLZ');
    _validateRequired(_asString(merged['ort']) ?? '', 'Ort');
    _validateRequired(_asString(merged['land']) ?? '', 'Land');
    _validateForeignTaxNumber(_asString(merged['steuernummer_ausland']));
    await _validateVatId(_normalizeCountry(_asString(merged['land']) ?? 'DE'), _asString(merged['ust_idnr']));

    final assignmentSql = assignments.keys.map((column) => '$column = ?').join(', ');
    try {
      await executor.runUpdate('UPDATE lieferanten SET $assignmentSql WHERE id = ?', <Object?>[
        ...assignments.values,
        id,
      ]);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(const LieferantenException('Lieferant konnte nicht aktualisiert werden'), stackTrace);
    }

    final updated = await findById(id);
    if (updated == null) {
      throw const LieferantenException('Lieferant konnte nicht aktualisiert werden');
    }
    return updated;
  }

  Future<void> delete(int id) async {
    await ensureSchema();
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final reference = await _lieferantReference(transaction, id);
      if (reference != null) {
        throw LieferantenException('Lieferant kann nicht gelöscht werden: $reference');
      }
      final deleted = await transaction.runDelete('DELETE FROM lieferanten WHERE id = ?', <Object?>[id]);
      if (deleted == 0) {
        throw const LieferantenException('Lieferant nicht gefunden');
      }
      await transaction.send();
    } catch (error, stackTrace) {
      await _rollback(transaction);
      if (error is LieferantenException) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      Error.throwWithStackTrace(const LieferantenException('Lieferant konnte nicht gelöscht werden'), stackTrace);
    }
  }

  static Future<void> _ensureSchema(QueryExecutor executor) async {
    await executor.ensureOpen(_NoopTransactionUser());
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      await _addMissingColumns(transaction, 'lieferanten', _lieferantenColumns);
      await _addMissingColumns(transaction, 'nummernkreise', _nummernkreisColumns);
      // ponytail: journal/artikel lieferant linkage for delete protection
      await _ensureLieferantLinkColumns(transaction);
      await transaction.runCustom(
        'UPDATE lieferanten SET kreditor_nr = lieferantennummer '
        'WHERE kreditor_nr IS NULL AND lieferantennummer IS NOT NULL',
      );
      await transaction.runCustom(
        'UPDATE lieferanten SET lieferantennummer = kreditor_nr '
        'WHERE lieferantennummer IS NULL AND kreditor_nr IS NOT NULL',
      );
      await transaction.runCustom(
        'UPDATE nummernkreise SET letzte_nummer = naechste_nummer - 1 '
        'WHERE letzte_nummer IS NULL AND naechste_nummer IS NOT NULL',
      );
      await transaction.runCustom(
        'UPDATE nummernkreise SET letze_nummer = naechste_nummer - 1 '
        'WHERE letze_nummer IS NULL AND naechste_nummer IS NOT NULL',
      );
      await transaction.runCustom(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_lieferanten_kreditor_nr_unique '
        'ON lieferanten(kreditor_nr) WHERE kreditor_nr IS NOT NULL',
      );
      await transaction.send();
    } catch (error, stackTrace) {
      try {
        await transaction.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<void> _ensureLieferantLinkColumns(QueryExecutor executor) async {
    for (final table in <String>['journal', 'artikel']) {
      try {
        final rows = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
        final hasCol = rows.any((r) => r['name'] == 'lieferant_id');
        if (!hasCol) {
          await executor.runCustom('ALTER TABLE $table ADD COLUMN lieferant_id INTEGER REFERENCES lieferanten(id)');
        }
      } catch (_) {}
    }
  }

  static Future<void> _addMissingColumns(
    QueryExecutor executor,
    String table,
    List<_ColumnDefinition> definitions,
  ) async {
    final rows = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    final existing = <String>{
      for (final row in rows)
        if (row['name'] is String) row['name']! as String,
    };
    for (final definition in definitions) {
      if (!existing.contains(definition.name)) {
        await executor.runCustom('ALTER TABLE $table ADD COLUMN ${definition.name} ${definition.definition}');
      }
    }
  }

  Future<String> _allocateKreditorNumber(TransactionExecutor transaction) async {
    final rows = await transaction.runSelect(
      '''
SELECT id, format, naechste_nummer, letzte_nummer, letze_nummer
FROM nummernkreise
WHERE typ = ? AND aktiv = 1
ORDER BY id
LIMIT 1
''',
      const <Object?>['kreditor'],
    );
    if (rows.isEmpty) {
      throw const LieferantenException('Kreditor-Nummernkreis fehlt');
    }
    final row = rows.single;
    final number = _nextNumber(row);
    final updated = await transaction.runUpdate(
      '''
UPDATE nummernkreise
SET naechste_nummer = ?, letzte_nummer = ?, letze_nummer = ?
WHERE id = ?
''',
      <Object?>[number + 1, number, number, row['id']],
    );
    if (updated != 1) {
      throw const LieferantenException('Kreditor-Nummernkreis konnte nicht aktualisiert werden');
    }
    return _formatNumber(_asString(row['format']) ?? '7####', number);
  }

  Future<void> _validateVatId(String country, String? value) async {
    if (value == null) return;
    final rows = await executor.runSelect('SELECT ust_idnr_format FROM eu_laender WHERE laendercode = ?', <Object?>[
      country,
    ]);
    final seededPattern = rows.isEmpty ? null : _asString(rows.single['ust_idnr_format']);
    final pattern = seededPattern?.trim().isNotEmpty == true ? seededPattern : _fallbackVatPatterns[country];
    if (pattern == null) return;
    var valid = false;
    try {
      valid = RegExp(pattern).hasMatch(value);
    } on FormatException {
      valid = false;
    }
    if (!valid) {
      throw LieferantenException(_vatError(country));
    }
  }

  Lieferant _lieferantFromRow(Map<String, Object?> row) {
    return Lieferant(
      id: _requiredIntValue(row['id'], 'ID'),
      kreditorNr: _requiredText(_asString(row['kreditor_nr']) ?? _asString(row['lieferantennummer']), 'Kreditor-Nr'),
      anrede: _requiredText(row['anrede'], 'Anrede'),
      name: _requiredText(row['name'], 'Name'),
      firma: _asString(row['firma']),
      strasse: _requiredText(row['strasse'], 'Straße'),
      hausnummer: _asString(row['hausnummer']),
      plz: _requiredText(row['plz'], 'PLZ'),
      ort: _requiredText(row['ort'], 'Ort'),
      land: _requiredText(row['land'], 'Land'),
      ustIdNr: _asString(row['ust_idnr']),
      foreignTaxNumber: _asString(row['steuernummer_ausland']),
      telefon: _asString(row['telefon']),
      email: _asString(row['email']),
      iban: _asString(row['iban']),
      zahlungsziel: _asInt(row['zahlungsziel']) ?? 14,
      skontoProzent: _asNum(row['skonto_prozent']) ?? 0,
      skontoTage: _asInt(row['skonto_tage']) ?? 0,
      note: _asString(row['note']),
    );
  }

  static int _nextNumber(Map<String, Object?> row) {
    final configured = _asInt(row['naechste_nummer']);
    final lastValues = <int>[
      if (_asInt(row['letzte_nummer']) != null) _asInt(row['letzte_nummer'])!,
      if (_asInt(row['letze_nummer']) != null) _asInt(row['letze_nummer'])!,
    ];
    final last = lastValues.isEmpty ? null : lastValues.reduce((a, b) => a > b ? a : b);
    final minimum = last == null ? 1 : last + 1;
    return (configured ?? 1) > minimum ? (configured ?? 1) : minimum;
  }

  static String _formatNumber(String format, int number) {
    final numericPattern = RegExp(r'^([0-9]*)(#+)$').firstMatch(format);
    if (numericPattern != null) {
      final prefix = numericPattern.group(1)!;
      final width = numericPattern.group(2)!.length;
      final value = number.toString();
      if (prefix.isEmpty) return value.padLeft(width, '0');
      if (value.startsWith(prefix) && value.length > width) return value;
      return '$prefix${value.padLeft(width, '0')}';
    }
    final now = DateTime.now();
    var result = format
        .replaceAll('{YYYY}', now.year.toString())
        .replaceAll('{YY}', _twoDigits(now.year % 100))
        .replaceAll('{MM}', _twoDigits(now.month))
        .replaceAll('YYYY', now.year.toString())
        .replaceAll('YY', _twoDigits(now.year % 100))
        .replaceAll('MM', _twoDigits(now.month));
    result = result.replaceAllMapped(RegExp(r'\{N+\}'), (match) {
      final width = match.group(0)!.length - 2;
      return number.toString().padLeft(width, '0');
    });
    return result.replaceAllMapped(RegExp('#+'), (match) {
      return number.toString().padLeft(match.group(0)!.length, '0');
    });
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static Object? _toDatabaseValue(String column, Object? value) {
    if (column == 'land') return _normalizeCountry(_asString(value) ?? 'DE');
    return value;
  }

  static String _normalizeCountry(String value) => value.trim().toUpperCase();

  static void _validateRequired(String value, String field) {
    if (value.trim().isEmpty) {
      throw LieferantenException('$field ist Pflicht');
    }
  }

  static String _vatError(String country) {
    switch (country) {
      case 'DE':
        return 'USt-IdNr ungültig: Erwartet DE gefolgt von 9 Ziffern';
      case 'AT':
        return 'USt-IdNr ungültig: Erwartet ATU gefolgt von 8 Ziffern';
      case 'FR':
        return 'USt-IdNr ungültig: Erwartet FR gefolgt von 13 Zeichen';
      default:
        return 'USt-IdNr ungültig für $country';
    }
  }

  static String? _asString(Object? value) => value is String ? value : value?.toString();

  static num? _asNum(Object? value) {
    if (value is num) return value;
    return value is String ? num.tryParse(value) : null;
  }

  static int? _asInt(Object? value) {
    final number = _asNum(value);
    return number?.toInt();
  }

  static String _requiredText(Object? value, String field) {
    final text = _asString(value);
    if (text == null || text.trim().isEmpty) {
      throw LieferantenException('$field ist Pflicht');
    }
    return text;
  }

  static int _requiredIntValue(Object? value, String field) {
    final number = _asInt(value);
    if (number == null) throw LieferantenException('$field ist ungültig');
    return number;
  }

  static void _validateForeignTaxNumber(String? value) {
    if (value != null && value.length > 50) {
      throw const LieferantenException('Steuernummer Ausland darf höchstens 50 Zeichen enthalten');
    }
  }

  Future<String?> _lieferantReference(TransactionExecutor transaction, int id) async {
    final queries = <({String sql, String label})>[
      (sql: 'SELECT id, rechnungsnummer FROM rechnungen WHERE lieferant_id = ? ORDER BY id LIMIT 1', label: 'Rechnung'),
      (sql: 'SELECT id FROM journal WHERE lieferant_id = ? ORDER BY id LIMIT 1', label: 'Journal'),
      (sql: 'SELECT id FROM artikel WHERE lieferant_id = ? ORDER BY id LIMIT 1', label: 'Artikel'),
      (sql: 'SELECT id FROM belege WHERE lieferant_id = ? ORDER BY id LIMIT 1', label: 'Beleg'),
    ];
    for (final query in queries) {
      try {
        final rows = await transaction.runSelect(query.sql, <Object?>[id]);
        if (rows.isEmpty) continue;
        final row = rows.single;
        final number = query.label == 'Rechnung'
            ? (_asString(row['rechnungsnummer']) ?? _asString(row['id']))
            : _asString(row['id']);
        return '${query.label} #$number';
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<void> _rollback(TransactionExecutor transaction) async {
    await transaction.rollback();
  }
}

class _ColumnDefinition {
  const _ColumnDefinition(this.name, this.definition);

  final String name;
  final String definition;
}

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
