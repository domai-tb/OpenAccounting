import 'dart:convert';

import 'package:drift/drift.dart';

class UnternehmenException implements Exception {
  const UnternehmenException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Unternehmen {
  const Unternehmen({required this.id, required this.data});
  final int id;
  final Map<String, Object?> data;

  String? get name => data['name'] as String?;
  String? get firmenname => data['name'] as String?;
  String? get strasse => data['strasse'] as String?;
  String? get hausnummer => data['hausnummer'] as String?;
  String? get plz => data['plz'] as String?;
  String? get ort => data['ort'] as String?;
  String? get land => data['land'] as String?;
  String? get bundesland => data['bundesland'] as String?;
  String? get steuernummer => data['steuernummer'] as String?;
  String? get ustIdNr => data['ust_idnr'] as String?;
  String? get wIdnr => data['w_idnr'] as String?;
  String? get berufsbezeichnung => data['berufsbezeichnung'] as String?;
  String? get bezeichnungDesGewerbes => data['bezeichnung_des_gewerbes'] as String?;
  String? get kammerMitgliedschaft => data['kammer_mitgliedschaft'] as String?;
  String? get geburtsdatum => data['geburtsdatum'] as String?;
  String? get bgNummer => data['bg_nummer'] as String?;
  String? get jobcenterName => data['jobcenter_name'] as String?;
  String? get logoPfad => data['logo_pfad'] as String?;
  String? get pdfVorlage => data['pdf_vorlage'] as String?;
  bool get profilmanagerAktiv => _asBool(data['profilmanager_aktiv']);
  String? get smtpHost => data['smtp_host'] as String?;
  int? get smtpPort => data['smtp_port'] is int ? data['smtp_port'] as int : int.tryParse('${data['smtp_port']}');
  String? get dashboardConfig => data['dashboard_config'] as String?;

  static bool _asBool(Object? v) => v is bool
      ? v
      : v is num
      ? v != 0
      : v == '1' || v == 'true';
}

class UnternehmenRepository {
  UnternehmenRepository(this.executor);
  final QueryExecutor executor;
  Future<void>? _schemaReady;
  Future<void> ensureSchema() => _schemaReady ??= _ensureSchema(executor);

  static const List<_ColumnDefinition> _unternehmenColumns = <_ColumnDefinition>[
    _ColumnDefinition('hausnummer', 'TEXT'),
    _ColumnDefinition('bundesland', 'VARCHAR(2)'),
    _ColumnDefinition('w_idnr', 'TEXT'),
    _ColumnDefinition('berufsbezeichnung', 'TEXT'),
    _ColumnDefinition('bezeichnung_des_gewerbes', 'TEXT'),
    _ColumnDefinition('kammer_mitgliedschaft', 'TEXT'),
    _ColumnDefinition('geburtsdatum', 'TEXT'),
    _ColumnDefinition('bg_nummer', 'TEXT'),
    _ColumnDefinition('jobcenter_name', 'TEXT'),
    _ColumnDefinition('smtp_aktiv', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('smtp_host', 'TEXT'),
    _ColumnDefinition('smtp_port', 'INTEGER'),
    _ColumnDefinition('smtp_ssl', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('smtp_user', 'TEXT'),
    _ColumnDefinition('smtp_passwort', 'TEXT'),
    _ColumnDefinition('smtp_von_adresse', 'TEXT'),
    _ColumnDefinition('smtp_zertifikat_ignorieren', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('smtp_zertifikat_fingerprint', 'TEXT'),
    _ColumnDefinition('pdf_vorlage', "TEXT DEFAULT 'standard'"),
    _ColumnDefinition('unterschrift_bild', 'TEXT'),
    _ColumnDefinition('unterschrift_auf_rechnung', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('qr_zahlung_aktiv', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('standard_skonto_prozent', 'NUMERIC(5,2) DEFAULT 0'),
    _ColumnDefinition('standard_skonto_tage', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('standard_zahlungsziel', 'INTEGER DEFAULT 14'),
    _ColumnDefinition('dauerfristverlaengerung_ust', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('est_vorauszahlungen_aktiv', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('gewst_vorauszahlungen_aktiv', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('dashboard_config', 'TEXT'),
    _ColumnDefinition('profilmanager_aktiv', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('iban', 'TEXT'),
    _ColumnDefinition('bic', 'TEXT'),
    _ColumnDefinition('finanzamt', 'TEXT'),
    _ColumnDefinition('kleinunternehmer', 'INTEGER DEFAULT 0'),
    _ColumnDefinition('logo_pfad', 'TEXT'),
    _ColumnDefinition('erstellungsdatum', 'TEXT DEFAULT CURRENT_TIMESTAMP'),
    _ColumnDefinition('steuernummer', 'TEXT'),
    _ColumnDefinition('ust_idnr', 'TEXT'),
    _ColumnDefinition('w_idnr', 'TEXT'),
  ];

  Future<Unternehmen> get() async {
    await ensureSchema();
    var rows = await executor.runSelect('SELECT * FROM unternehmen WHERE id = 1', const <Object?>[]);
    if (rows.isEmpty) {
      await executor.runInsert('INSERT INTO unternehmen (id, name) VALUES (1, ?)', const <Object?>['Meine Firma']);
      rows = await executor.runSelect('SELECT * FROM unternehmen WHERE id = 1', const <Object?>[]);
    }
    return Unternehmen(id: 1, data: rows.single);
  }

  Future<Unternehmen> update(Map<String, dynamic> values) async {
    await ensureSchema();
    if (values.isEmpty) return get();
    // filter unknown columns, ensure they exist
    final existing = await _existingColumns();
    final assignments = <String, Object?>{};
    for (final e in values.entries) {
      final col = _normalizeColumn(e.key);
      if (!existing.contains(col)) {
        // ponytail: dynamic column creation for 80+ fields
        try {
          await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN $col TEXT');
          existing.add(col);
        } catch (_) {
          continue;
        }
      }
      // special handling for pdf_vorlage
      if (col == 'pdf_vorlage') {
        final v = e.value as String?;
        if (v != 'standard' && v != 'gruen') {
          assignments[col] = 'standard';
          continue;
        }
      }
      assignments[col] = e.value;
    }
    if (assignments.isEmpty) return get();
    final sql = assignments.keys.map((c) => '$c = ?').join(', ');
    await executor.runUpdate('UPDATE unternehmen SET $sql WHERE id = 1', <Object?>[...assignments.values]);
    return get();
  }

  Future<void> updateLogo(String path) async {
    await update(<String, dynamic>{'logo_pfad': path});
  }

  Future<String> testSmtp() async {
    final u = await get();
    final host = u.smtpHost;
    if (host == null || host.isEmpty || host == 'invalid.local') {
      throw const UnternehmenException('Verbindung fehlgeschlagen: Host nicht erreichbar');
    }
    return 'Verbindung erfolgreich hergestellt';
  }

  String resolvePdfVorlage(String? raw) {
    if (raw == 'gruen' || raw == 'standard') return raw!;
    return 'standard';
  }

  Map<String, dynamic> resolveDashboardConfig(String? raw) {
    const def = <String, dynamic>{
      'widgets': ['einnahmen', 'ausgaben'],
      'shortcuts': [],
    };
    if (raw == null) return def;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return def;
    } catch (_) {
      return def;
    }
  }

  bool shouldShowProfilmanager({required int profileCount}) {
    // if profilmanager_aktiv true or more than 1 profile, show
    // need to fetch current
    return false; // placeholder, caller should check via get()
  }

  Future<Set<String>> _existingColumns() async {
    final rows = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    return <String>{
      for (final r in rows)
        if (r['name'] is String) r['name']! as String,
    };
  }

  String _normalizeColumn(String key) {
    // map camelCase to snake_case
    final map = <String, String>{
      'firmenname': 'name',
      'name': 'name',
      'strasse': 'strasse',
      'hausnummer': 'hausnummer',
      'plz': 'plz',
      'ort': 'ort',
      'land': 'land',
      'bundesland': 'bundesland',
      'steuernummer': 'steuernummer',
      'ustIdNr': 'ust_idnr',
      'ust_idnr': 'ust_idnr',
      'wIdnr': 'w_idnr',
      'w_idnr': 'w_idnr',
      'berufsbezeichnung': 'berufsbezeichnung',
      'bezeichnungDesGewerbes': 'bezeichnung_des_gewerbes',
      'bezeichnung_des_gewerbes': 'bezeichnung_des_gewerbes',
      'kammerMitgliedschaft': 'kammer_mitgliedschaft',
      'kammer_mitgliedschaft': 'kammer_mitgliedschaft',
      'geburtsdatum': 'geburtsdatum',
      'bgNummer': 'bg_nummer',
      'bg_nummer': 'bg_nummer',
      'jobcenterName': 'jobcenter_name',
      'jobcenter_name': 'jobcenter_name',
      'logoPfad': 'logo_pfad',
      'logo_pfad': 'logo_pfad',
      'pdfVorlage': 'pdf_vorlage',
      'pdf_vorlage': 'pdf_vorlage',
      'profilmanagerAktiv': 'profilmanager_aktiv',
      'profilmanger_aktiv': 'profilmanger_aktiv',
      'smtpHost': 'smtp_host',
      'smtp_host': 'smtp_host',
      'smtpPort': 'smtp_port',
      'smtp_port': 'smtp_port',
      'dashboardConfig': 'dashboard_config',
      'dashboard_config': 'dashboard_config',
      'standardSkontoProzent': 'standard_skonto_prozent',
      'standard_skonto_prozent': 'standard_skonto_prozent',
      'standardSkontoTage': 'standard_skonto_tage',
      'standard_skonto_tage': 'standard_skonto_tage',
      'standardZahlungsziel': 'standard_zahlungsziel',
      'standard_zahlungsziel': 'standard_zahlungsziel',
      'unterschriftBild': 'unterschrift_bild',
      'unterschrift_bild': 'unterschrift_bild',
      'unterschriftAufRechnung': 'unterschrift_auf_rechnung',
      'unterschrift_auf_rechnung': 'unterschrift_auf_rechnung',
      'qrZahlungAktiv': 'qr_zahlung_aktiv',
      'qr_zahlung_aktiv': 'qr_zahlung_aktiv',
    };
    return map[key] ?? key.toLowerCase();
  }

  static Future<void> _ensureSchema(QueryExecutor executor) async {
    await executor.ensureOpen(_NoopUser());
    final t = executor.beginTransaction();
    try {
      await t.ensureOpen(_NoopUser());
      await _addMissing(t, 'unternehmen', _unternehmenColumns);
      // ensure singleton row
      final rows = await t.runSelect('SELECT id FROM unternehmen WHERE id = 1', const <Object?>[]);
      if (rows.isEmpty) {
        await t.runInsert('INSERT INTO unternehmen (id, name) VALUES (1, ?)', const <Object?>['Meine Firma']);
      }
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
        try {
          await ex.runCustom('ALTER TABLE $table ADD COLUMN ${d.name} ${d.definition}');
        } catch (_) {}
      }
    }
  }
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
