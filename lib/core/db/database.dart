// ignore_for_file: no_adjacent_strings_in_list
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' as drift_native;
import 'package:drift_flutter/drift_flutter.dart' show driftDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:openaccounting/core/db/data_paths.dart';
import 'package:openaccounting/core/db/gobd_triggers.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/documents/artifact_transaction.dart';
import 'package:openaccounting/core/db/rechnung_triggers.dart';
import 'package:openaccounting/core/db/seed.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';
import 'package:openaccounting/pages/stammdaten/unternehmen_repository.dart';

/// Drift-backed app database with 41 declared tables per spec §Table Definitions.
/// Ponytail ultra: raw SQL via drift executor — no codegen, minimal boilerplate.
/// Handles WAL, FK, schema versioning, GoBD triggers, seed, profiles.
class AppDatabase {
  AppDatabase([QueryExecutor? executor, this.profileDir])
    : _executor = executor ?? driftDatabase(name: 'openaccounting'),
      _ownsExecutor = executor == null,
      afterFeatureSchemaDdl = null;

  AppDatabase.forTesting(QueryExecutor executor, {this.profileDir, this.afterFeatureSchemaDdl})
    : _executor = _InvoiceErrorMappingExecutor(executor),
      _ownsExecutor = true;

  AppDatabase.forProfile(String profileDirectory)
    : this(drift_native.NativeDatabase(File(p.join(profileDirectory, 'openinvoices.db'))), profileDirectory);

  final QueryExecutor _executor;
  final String? profileDir;
  final Future<void> Function(QueryExecutor executor)? afterFeatureSchemaDdl;
  final bool _ownsExecutor;
  bool _opened = false;
  late final KundenRepository _kundenRepository = KundenRepository(_executor);
  late final LieferantenRepository _lieferantenRepository = LieferantenRepository(_executor);
  late final ArtikelRepository _artikelRepository = ArtikelRepository(_executor);
  late final UnternehmenRepository _unternehmenRepository = UnternehmenRepository(_executor, profileDir: profileDir);
  late final KategorienRepository _kategorienRepository = KategorienRepository(_executor);

  static const int currentVersion = MigrationRunner.currentVersion;

  static const List<String> allTableNames = <String>[
    'unternehmen',
    'kunden',
    'lieferanten',
    'artikel',
    'journal',
    'rechnungen',
    'rechnungspositionen',
    'kategorien',
    'konten',
    'nummernkreise',
    'ust_saetze',
    'tagesabschluesse',
    'belege',
    'mahnungen',
    'mahnstufen',
    'mahnwesen_einstellungen',
    'forderungen',
    'bank_transaktionen',
    'bank_templates',
    'bank_imports',
    'kunden_belege',
    'kunden_lieferadressen',
    'artikel_gruppen',
    'rechnungsvorlagen',
    'buchungsvorlagen',
    'anlageverzeichnis',
    'dokumentenpakete',
    'dokumentenpaket_belege',
    'ustva_exporte',
    'euer_exporte',
    'eks_exporte',
    'datev_export_log',
    'eu_laender',
    'eks_einstellungen',
    'vorsteuer_ansprueche',
    'schnellbuchungen',
    'auto_filter_regeln',
    'import_mapping_vorlagen',
    'inventarbewegungen',
    'inventuren',
    'inventur_positionen',
    'settlement_groups',
    'settlement_allocations',
    'statutory_timing_rules',
  ];

  QueryExecutor get executor => _executor;

  KundenRepository get kundenRepository {
    if (!_opened) {
      throw StateError('AppDatabase.ensureOpen() muss vor kundenRepository aufgerufen werden');
    }
    return _kundenRepository;
  }

  LieferantenRepository get lieferantenRepository {
    if (!_opened) {
      throw StateError('AppDatabase.ensureOpen() muss vor lieferantenRepository aufgerufen werden');
    }
    return _lieferantenRepository;
  }

  ArtikelRepository get artikelRepository {
    if (!_opened) {
      throw StateError('AppDatabase.ensureOpen() muss vor artikelRepository aufgerufen werden');
    }
    return _artikelRepository;
  }

  UnternehmenRepository get unternehmenRepository {
    if (!_opened) {
      throw StateError('AppDatabase.ensureOpen() muss vor unternehmenRepository aufgerufen werden');
    }
    return _unternehmenRepository;
  }

  KategorienRepository get kategorienRepository {
    if (!_opened) {
      throw StateError('AppDatabase.ensureOpen() muss vor kategorienRepository aufgerufen werden');
    }
    return _kategorienRepository;
  }

  bool get isOpen => _opened;

  Future<void> ensureOpen() async {
    if (_opened) return;
    await _executor.ensureOpen(_NoopUser());
    await _executor.runCustom('PRAGMA journal_mode = WAL');
    await _executor.runCustom('PRAGMA foreign_keys = ON');
    // Verify WAL
    try {
      await _executor.runCustom('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
    final runner = MigrationRunner(
      executor: _executor,
      profileDir: profileDir ?? resolveDefaultBaseDir(),
      requiredTables: allTableNames,
    );
    try {
      await runner.run(createSchema: _createAllTables, afterFeatureSchemaDdl: afterFeatureSchemaDdl);
    } catch (error, stackTrace) {
      if (error is ForderungenException) rethrow;
      Error.throwWithStackTrace(
        ForderungenException(
          'Datenbankschema konnte nicht migriert werden',
          code: ForderungenErrorCode.schemaMigrationFailed,
          cause: error,
        ),
        stackTrace,
      );
    }
    await _addColumnIfMissing('rechnungen', 'dokumentenpaket_id', 'INTEGER REFERENCES dokumentenpakete(id)');
    for (final entry in <String, String>{
      'dateiname': 'TEXT',
      'original_name': 'TEXT',
      'mime_type': 'TEXT',
      'dateigroesse': 'INTEGER DEFAULT 0',
      'sha256': 'TEXT',
      'hochgeladen_am': 'TEXT',
      'beleg_pdfa_pfad': 'TEXT',
      'loeschdatum': 'TEXT',
    }.entries) {
      await _addColumnIfMissing('belege', entry.key, entry.value);
    }
    // Ensure triggers and seed idempotent even when no migration
    await GobdTriggers.install(_executor);
    await RechnungTriggers.install(_executor);
    await SeedData.run(_executor);
    await _kundenRepository.ensureSchema();
    await _lieferantenRepository.ensureSchema();
    await _artikelRepository.ensureSchema();
    await _unternehmenRepository.ensureSchema();
    await _kategorienRepository.ensureSchema();
    // Bank import history is additive so existing profiles keep their current columns and rows.
    // `fehler_details` stores a JSON array of per-row diagnostics when a partial import is allowed.
    final List<Map<String, Object?>> bankImportColumns = await _executor.runSelect(
      'PRAGMA table_info(bank_imports)',
      const <Object?>[],
    );
    final bool hadPersistedCount = bankImportColumns.any((row) => row['name'] == 'anzahl_importiert');
    for (final entry in <String, String>{
      'duplikate': 'INTEGER DEFAULT 0',
      'template_typ': 'TEXT',
      'anzahl_importiert': 'INTEGER NOT NULL DEFAULT 0',
      'anzahl_auto_kategorisiert': 'INTEGER NOT NULL DEFAULT 0',
      'anzahl_manuelle_pruefung': 'INTEGER NOT NULL DEFAULT 0',
      'anzahl_fehlgeschlagen': 'INTEGER NOT NULL DEFAULT 0',
      'fehler_details': 'TEXT',
    }.entries) {
      await _addColumnIfMissing('bank_imports', entry.key, entry.value);
    }
    // Before these fields existed, anzahl_transaktionen was the persisted-row count written by the service.
    // Preserve that historical meaning for upgraded databases without changing the legacy column.
    if (!hadPersistedCount) {
      await _executor.runCustom(
        'UPDATE bank_imports SET anzahl_importiert = anzahl_transaktionen '
        'WHERE anzahl_importiert = 0 AND anzahl_transaktionen > 0',
      );
    }
    await _addColumnIfMissing('unternehmen', 'dashboard_config', 'TEXT');
    for (final entry in <String, String>{
      'einleitungstext_rechnung': 'TEXT',
      'schlusstext_rechnung': 'TEXT',
      'einleitungstext_angebot': 'TEXT',
      'schlusstext_angebot': 'TEXT',
      'einleitungstext_auftrag': 'TEXT',
      'schlusstext_auftrag': 'TEXT',
      'einleitungstext_proforma': 'TEXT',
      'schlusstext_proforma': 'TEXT',
      'einleitungstext_lieferschein': 'TEXT',
      'schlusstext_lieferschein': 'TEXT',
      'einleitungstext_gutschrift': 'TEXT',
      'schlusstext_gutschrift': 'TEXT',
      'einleitungstext_storno': 'TEXT',
      'schlusstext_storno': 'TEXT',
      'setup_kategorie_ids': 'TEXT',
    }.entries) {
      await _addColumnIfMissing('unternehmen', entry.key, entry.value);
    }
    await _addColumnIfMissing('unternehmen', 'lagerfuehrung_aktiv', 'INTEGER DEFAULT 0');
    // recurring: rechnungsvorlagen status/auftrag_id, buchungsvorlagen intervall etc., vorlage_id links
    for (final entry in <String, ({String table, String definition})>{
      'rechnungsvorlagen.status': (table: 'rechnungsvorlagen', definition: "TEXT DEFAULT 'aktiv'"),
      'rechnungsvorlagen.auftrag_id': (table: 'rechnungsvorlagen', definition: 'INTEGER REFERENCES rechnungen(id)'),
      'buchungsvorlagen.intervall': (table: 'buchungsvorlagen', definition: 'TEXT'),
      'buchungsvorlagen.naechste_faelligkeit': (table: 'buchungsvorlagen', definition: 'TEXT'),
      'buchungsvorlagen.art': (table: 'buchungsvorlagen', definition: 'TEXT'),
      'buchungsvorlagen.lieferant_id': (table: 'buchungsvorlagen', definition: 'INTEGER REFERENCES lieferanten(id)'),
      'buchungsvorlagen.status': (table: 'buchungsvorlagen', definition: "TEXT DEFAULT 'aktiv'"),
      'rechnungen.vorlage_id': (table: 'rechnungen', definition: 'INTEGER REFERENCES rechnungsvorlagen(id)'),
      'journal.vorlage_id': (table: 'journal', definition: 'INTEGER REFERENCES buchungsvorlagen(id)'),
    }.entries) {
      await _addColumnIfMissing(entry.value.table, entry.key.split('.').last, entry.value.definition);
    }
    // Ensure user_version set for fresh memory DB where runner may have skipped (hasTables false path sets version)
    final v = await runner.getUserVersion();
    if (v == 0) {
      await runner.setUserVersion(currentVersion);
    }
    // Crash recovery for owned artifact/source directories (best-effort,
    // profile-scoped only; never touches unknown files or test memory DBs).
    final String? recoveryDir = profileDir;
    if (recoveryDir != null && recoveryDir.isNotEmpty) {
      try {
        await ArtifactRecovery.reconcileAtStartup(_executor, recoveryDir);
      } catch (_) {}
    }
    _opened = true;
  }

  Future<void> _createAllTables() async {
    // Create in dependency order to satisfy FKs (SQLite allows deferred but we order).
    for (final sql in _schemaSql) {
      await _executor.runCustom(sql);
    }
    for (final sql in _indexSql) {
      await _executor.runCustom(sql);
    }
  }

  Future<void> _addColumnIfMissing(String table, String name, String definition) async {
    final columns = await _executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (columns.any((column) => column['name'] == name)) return;
    await _executor.runCustom('ALTER TABLE $table ADD COLUMN $name $definition');
    final verified = await _executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (!verified.any((column) => column['name'] == name)) {
      throw StateError('Datenbank konnte Spalte $table.$name nicht verifizieren');
    }
  }

  Future<void> close() async {
    if (_ownsExecutor) {
      await _executor.close();
    }
    _opened = false;
  }

  /// Helper for VM tests creating in-memory instance with full schema.
  AppDatabase.createTestDatabase({String? profileDir})
    : this.forTesting(drift_native.NativeDatabase.memory(), profileDir: profileDir);

  // ponytail: WAL lock ceiling — global checkpoint before backup, per-DB if concurrency matters.
}

/// Top-level helper for VM tests — matches legacy import path.
AppDatabase createTestDatabase({String? profileDir}) => AppDatabase.createTestDatabase(profileDir: profileDir);

class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

class _InvoiceErrorMappingExecutor extends QueryExecutor {
  _InvoiceErrorMappingExecutor(this._delegate);

  final QueryExecutor _delegate;

  @override
  SqlDialect get dialect => _delegate.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _delegate.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) {
    return _delegate.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    return _mapErrors(() => _delegate.runInsert(statement, args));
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    return _mapErrors(() => _delegate.runUpdate(statement, args));
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    return _mapErrors(() => _delegate.runDelete(statement, args));
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _mapErrors(() => _delegate.runCustom(statement, args));
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    return _mapErrors(() => _delegate.runBatched(statements));
  }

  @override
  TransactionExecutor beginTransaction() => _delegate.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _delegate.beginExclusive();

  @override
  Future<void> close() => _delegate.close();

  Future<T> _mapErrors<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      final message = error.toString();
      if (message.contains('Absender-Snapshot ist nach Finalisierung unveränderlich')) {
        Error.throwWithStackTrace(StateError('Absender-Snapshot ist nach Finalisierung unveränderlich'), stackTrace);
      }
      if (message.contains('Dokument ist bereits finalisiert')) {
        Error.throwWithStackTrace(StateError('Dokument ist bereits finalisiert'), stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  // ponytail: throw-by-default enforces spec §One opened application graph.
  // main.dart overrides with the profile DB after ensureOpen.
  // Tests override via overrideWithValue or overrideWith.
  throw StateError(
    'appDatabaseProvider has no database. '
    'Override it in ProviderScope before reading.',
  );
});

/// Raw DDL for the declared tables — uses NUMERIC(12,2) for money, NUMERIC(12,4) for vk_netto.
const List<String> _schemaSql = <String>[
  // 1 unternehmen
  '''
CREATE TABLE IF NOT EXISTS unternehmen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  strasse TEXT,
  plz TEXT,
  ort TEXT,
  land TEXT DEFAULT 'DE',
  steuernummer TEXT,
  ust_idnr TEXT,
  iban TEXT,
  bic TEXT,
  finanzamt TEXT,
  kleinunternehmer INTEGER DEFAULT 0,
  profilmanager_aktiv INTEGER DEFAULT 0,
  backup_extern_pfad TEXT,
  backup_extern_pfad_lokal_ok INTEGER DEFAULT 0,
  logo_pfad TEXT,
  erstellungsdatum TEXT DEFAULT CURRENT_TIMESTAMP,
  berufsbezeichnung TEXT,
  kammer_mitgliedschaft TEXT,
  geburtsdatum TEXT,
  bg_nummer TEXT,
  jobcenter_name TEXT,
  jobcenter TEXT,
  datev_beraternummer TEXT,
  datev_mandantennummer TEXT,
  datev_konto_bank TEXT,
  datev_konto_bar TEXT,
  dashboard_config TEXT,
  einleitungstext_rechnung TEXT,
  schlusstext_rechnung TEXT,
  einleitungstext_angebot TEXT,
  schlusstext_angebot TEXT,
  einleitungstext_auftrag TEXT,
  schlusstext_auftrag TEXT,
  einleitungstext_proforma TEXT,
  schlusstext_proforma TEXT,
  einleitungstext_lieferschein TEXT,
  schlusstext_lieferschein TEXT,
  einleitungstext_gutschrift TEXT,
  schlusstext_gutschrift TEXT,
  einleitungstext_storno TEXT,
  schlusstext_storno TEXT,
  bank_import_manuell INTEGER NOT NULL DEFAULT 1 CHECK (bank_import_manuell IN (0, 1)),
  geschaeftsjahr_startmonat INTEGER NOT NULL DEFAULT 1 CHECK (geschaeftsjahr_startmonat BETWEEN 1 AND 12),
  feature_modules_json TEXT
)''',
  // 2 kategorien — mapping provenance per accounting-catalog-provenance (v9).
  // mapping_status defaults to legacy_unverified so legacy insert paths and
  // migrated rows are never silently treated as verified. Only an approved
  // manifest import or an explicit user-review transaction may set a trusted
  // status. Fresh profiles ship with no approved manifest, hence no
  // preconfigured mappings (explicit unconfigured state).
  '''
CREATE TABLE IF NOT EXISTS kategorien (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bezeichnung TEXT NOT NULL,
  beschreibung TEXT,
  konto_skr03 TEXT,
  konto_skr04 TEXT,
  euer_zeile INTEGER,
  aktiv INTEGER DEFAULT 1,
  typ TEXT,
  eks_kategorie TEXT,
  mapping_status TEXT NOT NULL DEFAULT 'legacy_unverified' CHECK (mapping_status IN ('catalog_verified','user_confirmed','legacy_unverified','review_required','unmapped')),
  catalog_entry_key TEXT,
  catalog_source_reference TEXT,
  catalog_source_version TEXT,
  mapping_reviewed_at TEXT
)''',
  // 2b category_mapping_history — append-only provenance log (v9, feature-owned).
  '''
CREATE TABLE IF NOT EXISTS category_mapping_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kategorie_id INTEGER NOT NULL REFERENCES kategorien(id) ON DELETE RESTRICT,
  geaendert_am TEXT NOT NULL,
  aktion TEXT NOT NULL CHECK (aktion IN ('migration','catalog_import','mapping_edit','user_review')),
  vorher_mapping_json TEXT,
  nachher_mapping_json TEXT NOT NULL,
  katalog_quelle TEXT,
  katalog_version TEXT
)''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_category_mapping_history_no_update
BEFORE UPDATE ON category_mapping_history
BEGIN SELECT RAISE(ABORT, 'category_mapping_history is append-only'); END''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_category_mapping_history_no_delete
BEFORE DELETE ON category_mapping_history
BEGIN SELECT RAISE(ABORT, 'category_mapping_history is append-only'); END''',
  // 3 konten
  '''
CREATE TABLE IF NOT EXISTS konten (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  iban TEXT,
  bic TEXT,
  waehrung TEXT DEFAULT 'EUR',
  kontoart TEXT,
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  saldo NUMERIC(12,2) DEFAULT 0,
  datev_kontonummer TEXT
)''',
  // 4 ust_saetze
  '''
CREATE TABLE IF NOT EXISTS ust_saetze (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  satz NUMERIC(12,2) NOT NULL,
  bezeichnung TEXT NOT NULL,
  gueltig_ab TEXT
)''',
  // 5 nummernkreise
  '''
CREATE TABLE IF NOT EXISTS nummernkreise (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  typ TEXT NOT NULL UNIQUE,
  prefix TEXT,
  format TEXT NOT NULL,
  naechste_nummer INTEGER DEFAULT 1,
  aktiv INTEGER DEFAULT 1
)''',
  // 6 eu_laender
  '''
CREATE TABLE IF NOT EXISTS eu_laender (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  laendercode TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  ust_idnr_format TEXT
)''',
  // 7 artikel_gruppen
  '''
CREATE TABLE IF NOT EXISTS artikel_gruppen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  beschreibung TEXT
)''',
  // 8 kunden
  '''
CREATE TABLE IF NOT EXISTS kunden (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kundennummer TEXT,
  debitor_nr TEXT,
  anrede TEXT NOT NULL DEFAULT 'Herr',
  name TEXT NOT NULL,
  firma TEXT,
  strasse TEXT NOT NULL,
  hausnummer TEXT,
  plz TEXT NOT NULL,
  ort TEXT NOT NULL,
  land TEXT NOT NULL DEFAULT 'DE',
  email TEXT,
  telefon TEXT,
  ust_idnr TEXT,
  steuernummer_ausland VARCHAR(50),
  zahlungsziel INTEGER DEFAULT 14,
  skonto_prozent NUMERIC(12,2) DEFAULT 0,
  skonto_tage INTEGER NOT NULL DEFAULT 0,
  kreditlimit NUMERIC(12,2),
  mahngesperrt INTEGER NOT NULL DEFAULT 0 CHECK (mahngesperrt IN (0, 1)),
  mahngesperrt_bis TEXT,
  mahngesperrt_grund TEXT,
  zugferd_aktiv INTEGER NOT NULL DEFAULT 0 CHECK (zugferd_aktiv IN (0, 1)),
  note TEXT,
  notiz TEXT,
  archived_at TEXT,
  erstellungsdatum TEXT DEFAULT CURRENT_TIMESTAMP
)''',
  // 9 lieferanten
  '''
CREATE TABLE IF NOT EXISTS lieferanten (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  lieferantennummer TEXT,
  anrede TEXT NOT NULL DEFAULT 'Herr',
  name TEXT NOT NULL,
  firma TEXT,
  strasse TEXT,
  hausnummer TEXT,
  plz TEXT,
  ort TEXT,
  land TEXT DEFAULT 'DE',
  email TEXT,
  telefon TEXT,
  ust_idnr TEXT,
  steuernummer_ausland VARCHAR(50),
  iban TEXT,
  zahlungsziel INTEGER DEFAULT 14,
  skonto_prozent NUMERIC(12,2) DEFAULT 0,
  skonto_tage INTEGER NOT NULL DEFAULT 0,
  note TEXT,
  archived_at TEXT
)''',
  // 10 artikel
  '''
CREATE TABLE IF NOT EXISTS artikel (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artikelnummer TEXT,
  bezeichnung TEXT NOT NULL,
  beschreibung TEXT,
  einheit TEXT DEFAULT 'Stk',
  vk_netto NUMERIC(12,4) NOT NULL DEFAULT 0,
  ek_preis NUMERIC(12,2) DEFAULT 0,
  ust_satz_id INTEGER REFERENCES ust_saetze(id),
  gruppe_id INTEGER REFERENCES artikel_gruppen(id),
  typ TEXT DEFAULT 'ware',
  bestand INTEGER DEFAULT 0,
  mindestbestand INTEGER DEFAULT 0,
  aktiv INTEGER DEFAULT 1
)''',
  // 11 rechnungen
  '''
CREATE TABLE IF NOT EXISTS rechnungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rechnungsnummer TEXT,
  typ TEXT NOT NULL,
  status TEXT DEFAULT 'entwurf',
  ist_entwurf INTEGER NOT NULL DEFAULT 1 CHECK (ist_entwurf IN (0, 1)),
  eingabemodus TEXT NOT NULL DEFAULT 'netto' CHECK (eingabemodus IN ('netto', 'brutto')),
  kunde_id INTEGER REFERENCES kunden(id),
  lieferant_id INTEGER REFERENCES lieferanten(id),
  datum TEXT NOT NULL,
  faelligkeit TEXT,
  netto_betrag NUMERIC(12,2) DEFAULT 0,
  brutto_betrag NUMERIC(12,2) DEFAULT 0,
  ust_betrag NUMERIC(12,2) DEFAULT 0,
  skonto_prozent NUMERIC(12,2) DEFAULT 0,
  skonto_faelligkeit TEXT,
  notiz TEXT,
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  nummernkreis_id INTEGER REFERENCES nummernkreise(id),
  storno_von INTEGER REFERENCES rechnungen(id),
  absender_snapshot TEXT,
  ausgegeben_am TEXT,
  original_pdf_pfad TEXT,
  dokumentenpaket_id INTEGER REFERENCES dokumentenpakete(id),
  mahnstufe_aktuell INTEGER DEFAULT 0,
  vorlage_id INTEGER
)''',
  // 12 rechnungspositionen
  '''
CREATE TABLE IF NOT EXISTS rechnungspositionen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rechnung_id INTEGER NOT NULL REFERENCES rechnungen(id) ON DELETE CASCADE,
  artikel_id INTEGER REFERENCES artikel(id),
  bezeichnung TEXT NOT NULL,
  menge NUMERIC(12,3) DEFAULT 1,
  einzelpreis NUMERIC(12,4) NOT NULL,
  gesamt NUMERIC(12,2) NOT NULL,
  ust_satz NUMERIC(12,2) DEFAULT 19,
  position INTEGER DEFAULT 0
)''',
  // 13 belege (before journal for FK)
  '''
CREATE TABLE IF NOT EXISTS belege (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  belegnummer TEXT,
  typ TEXT,
  datum TEXT NOT NULL,
  betrag NUMERIC(12,2) NOT NULL,
  konto_id INTEGER REFERENCES konten(id),
  kategorie_id INTEGER REFERENCES kategorien(id),
  lieferant_id INTEGER REFERENCES lieferanten(id),
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  status TEXT DEFAULT 'neu',
  beschreibung TEXT,
  dateipfad TEXT,
  dateiname TEXT,
  original_name TEXT,
  mime_type TEXT,
  dateigroesse INTEGER DEFAULT 0,
  sha256 TEXT,
  hochgeladen_am TEXT,
  beleg_pdfa_pfad TEXT,
  loeschdatum TEXT
)''',
  // 14 journal
  // if multi-entry groups required, migrate via ALTER TABLE + PRAGMA table_info check (see migrations.dart).
  '''
CREATE TABLE IF NOT EXISTS journal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  datum TEXT NOT NULL,
  beleg_nr TEXT,
  kategorie_id INTEGER REFERENCES kategorien(id),
  konto_id INTEGER REFERENCES konten(id),
  betrag NUMERIC(12,2) NOT NULL,
  soll NUMERIC(12,2) DEFAULT 0,
  haben NUMERIC(12,2) DEFAULT 0,
  beschreibung TEXT,
  immutable INTEGER DEFAULT 0,
  beleg_typ TEXT,
  soll_konto_id INTEGER REFERENCES konten(id),
  haben_konto_id INTEGER REFERENCES konten(id),
  rechnung_id INTEGER REFERENCES rechnungen(id),
  beleg_id INTEGER REFERENCES belege(id),
  erstellungsdatum TEXT DEFAULT CURRENT_TIMESTAMP,
  storno_von INTEGER REFERENCES journal(id),
  ust_satz_id INTEGER REFERENCES ust_saetze(id),
  konto_skr03_snapshot TEXT,
  konto_skr04_snapshot TEXT,
  ust_satz NUMERIC(12,2),
  ust_sonderfall TEXT,
  marge_25a_brutto NUMERIC(12,2),
  ust_satz_25a NUMERIC(12,2),
  ist_eu_lieferung INTEGER DEFAULT 0,
  vorsteuer_betrag NUMERIC(12,2),
  km_anzahl NUMERIC(12,2),
  vorlage_id INTEGER REFERENCES buchungsvorlagen(id),
  gruppe_id INTEGER REFERENCES journal(id),
  source_kind TEXT,
  source_id TEXT,
  reversal_of_group_id INTEGER REFERENCES journal(id),
  legacy_unverified INTEGER NOT NULL DEFAULT 1
)''',
  // 15 bank_templates
  '''
CREATE TABLE IF NOT EXISTS bank_templates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  typ TEXT NOT NULL,
  konfiguration TEXT
)''',
  // 16 bank_imports — ponytail: duplikate+template_typ added for history completeness (review L312)
  '''
CREATE TABLE IF NOT EXISTS bank_imports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  konto_id INTEGER REFERENCES konten(id),
  dateiname TEXT,
  datum TEXT DEFAULT CURRENT_TIMESTAMP,
  anzahl_transaktionen INTEGER DEFAULT 0,
  duplikate INTEGER DEFAULT 0,
  template_typ TEXT,
  anzahl_importiert INTEGER NOT NULL DEFAULT 0,
  anzahl_auto_kategorisiert INTEGER NOT NULL DEFAULT 0,
  anzahl_manuelle_pruefung INTEGER NOT NULL DEFAULT 0,
  anzahl_fehlgeschlagen INTEGER NOT NULL DEFAULT 0,
  fehler_details TEXT,
  status TEXT DEFAULT 'importiert'
)''',
  // 17 bank_transaktionen
  '''
CREATE TABLE IF NOT EXISTS bank_transaktionen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  konto_id INTEGER NOT NULL REFERENCES konten(id),
  import_id INTEGER REFERENCES bank_imports(id),
  datum TEXT NOT NULL,
  betrag NUMERIC(12,2) NOT NULL,
  verwendungszweck TEXT,
  gegenkonto TEXT,
  gegenkonto_name TEXT,
  kategorie_id INTEGER REFERENCES kategorien(id),
  journal_id INTEGER REFERENCES journal(id),
  dedupe_hash TEXT,
  status TEXT DEFAULT 'neu'
)''',
  // 18 kunden_belege
  '''
CREATE TABLE IF NOT EXISTS kunden_belege (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kunde_id INTEGER NOT NULL REFERENCES kunden(id) ON DELETE CASCADE,
  beleg_id INTEGER NOT NULL REFERENCES belege(id) ON DELETE CASCADE,
  rolle TEXT
)''',
  // 19 kunden_lieferadressen
  '''
CREATE TABLE IF NOT EXISTS kunden_lieferadressen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kunde_id INTEGER NOT NULL REFERENCES kunden(id) ON DELETE CASCADE,
  bezeichnung TEXT,
  strasse TEXT,
  plz TEXT,
  ort TEXT,
  land TEXT
)''',
  // 20 rechnungsvorlagen
  '''
CREATE TABLE IF NOT EXISTS rechnungsvorlagen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kunde_id INTEGER REFERENCES kunden(id),
  intervall TEXT,
  naechste_faelligkeit TEXT,
  aktiv INTEGER DEFAULT 1,
  vorlage_daten TEXT,
  status TEXT DEFAULT 'aktiv',
  auftrag_id INTEGER REFERENCES rechnungen(id)
)''',
  // 21 buchungsvorlagen
  '''
CREATE TABLE IF NOT EXISTS buchungsvorlagen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  konto_id INTEGER REFERENCES konten(id),
  betrag NUMERIC(12,2) DEFAULT 0,
  beschreibung TEXT,
  modus TEXT DEFAULT 'direkt',
  aktiv INTEGER DEFAULT 1,
  intervall TEXT,
  naechste_faelligkeit TEXT,
  art TEXT,
  lieferant_id INTEGER REFERENCES lieferanten(id),
  status TEXT DEFAULT 'aktiv'
)''',
  // 22 anlageverzeichnis — canonical asset fields (v17) live in the base DDL
  // so fresh profiles carry them; legacy columns stay for review.
  '''
CREATE TABLE IF NOT EXISTS anlageverzeichnis (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bezeichnung TEXT NOT NULL,
  anschaffungsdatum TEXT,
  anschaffungskosten NUMERIC(12,2) NOT NULL,
  nutzungsdauer INTEGER,
  kategorie_id INTEGER REFERENCES kategorien(id),
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  status TEXT DEFAULT 'aktiv',
  privatanteil NUMERIC(12,2) DEFAULT 0,
  asset_typ TEXT CHECK (asset_typ IN ('KFZ', 'EDV', 'sonstig')),
  kaufpreis_netto NUMERIC(12,2) CHECK (kaufpreis_netto >= 0),
  nutzungsdauer_jahre INTEGER CHECK (nutzungsdauer_jahre > 0),
  afa_methode TEXT CHECK (afa_methode IN ('linear')),
  privat_anteil_prozent NUMERIC(5,2) CHECK (privat_anteil_prozent BETWEEN 0 AND 100),
  verkauft_am TEXT
)''',
  // 23 dokumentenpakete
  '''
CREATE TABLE IF NOT EXISTS dokumentenpakete (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  erstellungsdatum TEXT DEFAULT CURRENT_TIMESTAMP,
  status TEXT DEFAULT 'offen'
)''',
  // 24 dokumentenpaket_belege
  '''
CREATE TABLE IF NOT EXISTS dokumentenpaket_belege (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  paket_id INTEGER NOT NULL REFERENCES dokumentenpakete(id) ON DELETE CASCADE,
  beleg_id INTEGER NOT NULL REFERENCES belege(id) ON DELETE CASCADE
)''',
  // 25 mahnstufen
  '''
CREATE TABLE IF NOT EXISTS mahnstufen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stufe INTEGER NOT NULL,
  bezeichnung TEXT NOT NULL,
  tage_nach_faelligkeit INTEGER DEFAULT 0,
  gebuehr NUMERIC(12,2) DEFAULT 0,
  zinssatz NUMERIC(12,2) DEFAULT 0,
  system_stufe INTEGER DEFAULT 0,
  multiplier INTEGER DEFAULT 0
)''',
  // 26 mahnwesen_einstellungen
  '''
CREATE TABLE IF NOT EXISTS mahnwesen_einstellungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  aktiv INTEGER DEFAULT 0,
  schwelle_warnung INTEGER DEFAULT 2,
  schwelle_sperrung INTEGER DEFAULT 3,
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  grace_tage INTEGER DEFAULT 0,
  zinssatz_default NUMERIC(12,2) DEFAULT 0,
  email_template TEXT
)''',
  // 27 mahnungen
  '''
CREATE TABLE IF NOT EXISTS mahnungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rechnung_id INTEGER NOT NULL REFERENCES rechnungen(id),
  kunde_id INTEGER REFERENCES kunden(id),
  stufe_id INTEGER REFERENCES mahnstufen(id),
  datum TEXT NOT NULL,
  betrag NUMERIC(12,2) NOT NULL,
  gebuehr NUMERIC(12,2) DEFAULT 0,
  zinsen NUMERIC(12,2) DEFAULT 0,
  status TEXT DEFAULT 'offen',
  snapshot TEXT,
  gebuehr_bezahlt NUMERIC(12,2) DEFAULT 0,
  zinsen_bezahlt NUMERIC(12,2) DEFAULT 0,
  uebernommene_gebuehr NUMERIC(12,2) DEFAULT 0,
  uebernommene_zinsen NUMERIC(12,2) DEFAULT 0,
  versendet_am TEXT
)''',
  // 28 forderungen
  '''
CREATE TABLE IF NOT EXISTS forderungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kunde_id INTEGER REFERENCES kunden(id),
  rechnung_id INTEGER REFERENCES rechnungen(id),
  betrag NUMERIC(12,2) NOT NULL,
  anfangsbetrag NUMERIC(12,2),
  status TEXT DEFAULT 'offen',
  faelligkeit TEXT,
  beschreibung TEXT,
  typ TEXT NOT NULL DEFAULT 'rechnung' CHECK (typ IN ('rechnung','rechnung_eingang','journal')),
  partner_typ TEXT NOT NULL DEFAULT 'kunde' CHECK (partner_typ IN ('kunde','lieferant')),
  partner_id INTEGER NOT NULL DEFAULT 0,
  journal_id INTEGER REFERENCES journal(id),
  ausgleich_journal_id INTEGER REFERENCES journal(id),
  erstellt_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  aktualisiert_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)''',
  // 29 tagesabschluesse
  '''
CREATE TABLE IF NOT EXISTS tagesabschluesse (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  datum TEXT NOT NULL,
  betrag NUMERIC(12,2) NOT NULL,
  kassenbestand NUMERIC(12,2) DEFAULT 0,
  differenz NUMERIC(12,2) DEFAULT 0,
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  konto_id INTEGER REFERENCES konten(id),
  signatur TEXT,
  erstellungsdatum TEXT DEFAULT CURRENT_TIMESTAMP
)''',
  // 30 ustva_exporte
  '''
CREATE TABLE IF NOT EXISTS ustva_exporte (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  zeitraum TEXT NOT NULL,
  jahr INTEGER NOT NULL,
  monat INTEGER,
  quartal INTEGER,
  kz_summen TEXT,
  status TEXT DEFAULT 'entwurf',
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  erstellungsdatum TEXT DEFAULT CURRENT_TIMESTAMP
)''',
  // 31 euer_exporte
  '''
CREATE TABLE IF NOT EXISTS euer_exporte (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  jahr INTEGER NOT NULL,
  summen TEXT,
  status TEXT DEFAULT 'entwurf',
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  mapping_provenance_json TEXT
)''',
  // 32 eks_exporte
  '''
CREATE TABLE IF NOT EXISTS eks_exporte (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  jahr INTEGER NOT NULL,
  daten TEXT,
  status TEXT DEFAULT 'entwurf',
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  seite INTEGER DEFAULT 1
)''',
  // 33 datev_export_log
  '''
CREATE TABLE IF NOT EXISTS datev_export_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  datum TEXT DEFAULT CURRENT_TIMESTAMP,
  zeitraum_von TEXT,
  zeitraum_bis TEXT,
  anzahl_buchungen INTEGER DEFAULT 0,
  datei_pfad TEXT,
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  status TEXT,
  mapping_provenance_json TEXT
)''',
  // 34 eks_einstellungen
  '''
CREATE TABLE IF NOT EXISTS eks_einstellungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  bedarfsgemeinschaft INTEGER DEFAULT 0,
  kosten_unterkunft NUMERIC(12,2) DEFAULT 0
)''',
  // 35 vorsteuer_ansprueche
  '''
CREATE TABLE IF NOT EXISTS vorsteuer_ansprueche (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  beleg_id INTEGER REFERENCES belege(id),
  rechnung_id INTEGER REFERENCES rechnungen(id),
  betrag NUMERIC(12,2) NOT NULL,
  status TEXT DEFAULT 'offen',
  faelligkeit TEXT,
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  ust_sonderfall TEXT
)''',
  // 36 schnellbuchungen — explicit execution semantics (v12).
  '''
CREATE TABLE IF NOT EXISTS schnellbuchungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  konto_id INTEGER REFERENCES konten(id),
  betrag NUMERIC(12,2),
  beschreibung TEXT,
  art TEXT CHECK (art IN ('einnahme','ausgabe')),
  ust_satz_id INTEGER REFERENCES ust_saetze(id),
  eingabemodus TEXT CHECK (eingabemodus IN ('netto','brutto'))
)''',
  // 37 auto_filter_regeln
  '''
CREATE TABLE IF NOT EXISTS auto_filter_regeln (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  muster TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  konto_id INTEGER REFERENCES konten(id),
  prioritaet INTEGER DEFAULT 0,
  aktiv INTEGER DEFAULT 1
)''',
  // 38 import_mapping_vorlagen
  '''
CREATE TABLE IF NOT EXISTS import_mapping_vorlagen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  template_id INTEGER REFERENCES bank_templates(id),
  mapping TEXT,
  aktiv INTEGER DEFAULT 1
)''',
  // 39 inventarbewegungen
  '''
CREATE TABLE IF NOT EXISTS inventarbewegungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artikel_id INTEGER NOT NULL REFERENCES artikel(id),
  datum TEXT NOT NULL,
  diff NUMERIC(10,3) NOT NULL,
  grund TEXT NOT NULL,
  referenz_typ TEXT,
  referenz_id INTEGER
)''',
  // 40 master_data_import_templates (v16, profile-local CSV mapping templates).
  '''
CREATE TABLE IF NOT EXISTS master_data_import_templates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  entity TEXT NOT NULL CHECK (entity IN ('customer', 'supplier', 'article')),
  mapping_json TEXT NOT NULL,
  has_header INTEGER NOT NULL DEFAULT 1 CHECK (has_header IN (0, 1)),
  delimiter TEXT NOT NULL,
  decimal_convention TEXT NOT NULL,
  duplicate_policy TEXT NOT NULL,
  match_field TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
  // 41 anlage_afa_jahreswerte (v17, owned by fixed-asset-register-workspace).
  // Append-only annual schedule snapshots; immutable via triggers below.
  '''
CREATE TABLE IF NOT EXISTS anlage_afa_jahreswerte (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  anlage_id INTEGER NOT NULL REFERENCES anlageverzeichnis(id) ON DELETE RESTRICT,
  jahr INTEGER NOT NULL,
  quell_snapshot TEXT NOT NULL,
  quell_hash TEXT NOT NULL,
  regel_version TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('verfuegbar', 'nicht_verfuegbar')),
  formel TEXT,
  betrag NUMERIC(12,2),
  blockierungsgrund TEXT,
  berechnet_am TEXT NOT NULL,
  CHECK ((status = 'verfuegbar' AND betrag IS NOT NULL AND blockierungsgrund IS NULL) OR (status = 'nicht_verfuegbar' AND betrag IS NULL AND blockierungsgrund IS NOT NULL AND trim(blockierungsgrund) <> '')),
  UNIQUE (anlage_id, jahr, quell_hash, regel_version)
)''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_anlage_afa_no_update
BEFORE UPDATE ON anlage_afa_jahreswerte
BEGIN SELECT RAISE(ABORT, 'anlage_afa_jahreswerte is append-only'); END''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_anlage_afa_no_delete
BEFORE DELETE ON anlage_afa_jahreswerte
BEGIN SELECT RAISE(ABORT, 'anlage_afa_jahreswerte is append-only'); END''',
  // 42 inventuren + 43 inventur_positionen (v18, count evidence only).
  // Recorded rows are immutable via the triggers below; snapshots never
  // touch artikel stock, inventarbewegungen, or accounting records.
  '''
CREATE TABLE IF NOT EXISTS inventuren (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stichtag TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'entwurf' CHECK (status IN ('entwurf', 'erfasst')),
  erstellt_am TEXT NOT NULL
)''',
  '''
CREATE TABLE IF NOT EXISTS inventur_positionen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  inventur_id INTEGER NOT NULL REFERENCES inventuren(id) ON DELETE RESTRICT,
  artikel_id INTEGER NOT NULL,
  bezeichnung_snapshot TEXT NOT NULL CHECK (trim(bezeichnung_snapshot) <> ''),
  einheit_snapshot TEXT NOT NULL CHECK (trim(einheit_snapshot) <> ''),
  menge_gezaehlt NUMERIC(10,3) CHECK (menge_gezaehlt IS NULL OR menge_gezaehlt >= 0),
  UNIQUE (inventur_id, artikel_id)
)''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_inventuren_insert_only_entwurf
BEFORE INSERT ON inventuren
WHEN NEW.status <> 'entwurf'
BEGIN SELECT RAISE(ABORT, 'Inventur wird nur als Entwurf angelegt'); END''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_inventuren_no_update_recorded
BEFORE UPDATE ON inventuren
WHEN OLD.status = 'erfasst'
BEGIN SELECT RAISE(ABORT, 'Erfasste Inventur ist unveraenderlich'); END''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_inventuren_record_needs_counts
BEFORE UPDATE ON inventuren
WHEN NEW.status = 'erfasst' AND OLD.status = 'entwurf'
BEGIN
  SELECT RAISE(ABORT, 'Inventur ohne Positionen kann nicht erfasst werden')
    WHERE (SELECT COUNT(*) FROM inventur_positionen WHERE inventur_id = NEW.id) = 0;
  SELECT RAISE(ABORT, 'Inventur mit fehlenden Zaehlmengen kann nicht erfasst werden')
    WHERE (SELECT COUNT(*) FROM inventur_positionen WHERE inventur_id = NEW.id AND menge_gezaehlt IS NULL) > 0;
END''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_inventuren_no_delete_recorded
BEFORE DELETE ON inventuren
WHEN OLD.status = 'erfasst'
BEGIN SELECT RAISE(ABORT, 'Erfasste Inventur kann nicht geloescht werden'); END''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_inventur_positionen_no_insert_recorded
BEFORE INSERT ON inventur_positionen
WHEN (SELECT status FROM inventuren WHERE id = NEW.inventur_id) = 'erfasst'
BEGIN SELECT RAISE(ABORT, 'Position einer erfassten Inventur ist unveraenderlich'); END''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_inventur_positionen_no_update_recorded
BEFORE UPDATE ON inventur_positionen
WHEN (SELECT status FROM inventuren WHERE id = NEW.inventur_id) = 'erfasst'
  OR (SELECT status FROM inventuren WHERE id = OLD.inventur_id) = 'erfasst'
BEGIN SELECT RAISE(ABORT, 'Position einer erfassten Inventur ist unveraenderlich'); END''',
  '''
CREATE TRIGGER IF NOT EXISTS trg_inventur_positionen_no_delete_recorded
BEFORE DELETE ON inventur_positionen
WHEN (SELECT status FROM inventuren WHERE id = OLD.inventur_id) = 'erfasst'
BEGIN SELECT RAISE(ABORT, 'Position einer erfassten Inventur ist unveraenderlich'); END''',
  // 44 settlement_groups + 45 settlement_allocations + 46 statutory_timing_rules (v19).
  // Balanced posting groups, payment allocations, and versioned statutory
  // timing exceptions. Fresh profiles carry them; upgrades add them via
  // _migratePostingGroups with legacy marking for pre-existing journal rows.
  '''
CREATE TABLE IF NOT EXISTS settlement_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_kind TEXT NOT NULL,
  source_id TEXT NOT NULL,
  bank_transaction_id INTEGER REFERENCES bank_transaktionen(id),
  signed_amount_cents INTEGER NOT NULL CHECK (signed_amount_cents != 0),
  settlement_date TEXT NOT NULL,
  unapplied_cents INTEGER NOT NULL DEFAULT 0,
  group_root_journal_id INTEGER NOT NULL REFERENCES journal(id),
  reversal_of_group_id INTEGER REFERENCES settlement_groups(id),
  reversed_by_group_id INTEGER REFERENCES settlement_groups(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (source_kind, source_id)
)''',
  '''
CREATE TABLE IF NOT EXISTS settlement_allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL REFERENCES settlement_groups(id) ON DELETE CASCADE,
  forderung_id INTEGER REFERENCES forderungen(id),
  applied_cents INTEGER NOT NULL CHECK (applied_cents != 0),
  settlement_date TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  euer_zeile INTEGER,
  direction TEXT NOT NULL DEFAULT 'einnahme' CHECK (direction IN ('einnahme', 'ausgabe')),
  ust_satz NUMERIC(5,2),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)''',
  '''
CREATE TABLE IF NOT EXISTS statutory_timing_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rule_id TEXT NOT NULL,
  rule_version TEXT NOT NULL,
  legal_basis TEXT NOT NULL,
  affected_year INTEGER NOT NULL,
  approver TEXT NOT NULL,
  source_trace TEXT NOT NULL,
  settlement_group_id INTEGER NOT NULL REFERENCES settlement_groups(id) ON DELETE CASCADE,
  attributed_year INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (rule_id, rule_version, settlement_group_id)
)''',
];

const List<String> _indexSql = <String>[
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_kunden_kundennummer_unique '
      'ON kunden(kundennummer) WHERE kundennummer IS NOT NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_kunden_debitor_nr_unique '
      'ON kunden(debitor_nr) WHERE debitor_nr IS NOT NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_lieferanten_lieferantennummer_unique '
      'ON lieferanten(lieferantennummer) WHERE lieferantennummer IS NOT NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_bank_transaktionen_dedupe '
      'ON bank_transaktionen(konto_id, dedupe_hash) WHERE dedupe_hash IS NOT NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_source_unique '
      'ON journal(source_kind, source_id) WHERE source_kind IS NOT NULL AND source_id IS NOT NULL AND gruppe_id = id',
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_settlement_groups_source_unique '
      'ON settlement_groups(source_kind, source_id)',
];
