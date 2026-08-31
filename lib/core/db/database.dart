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
import 'package:openaccounting/core/db/seed.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';

/// Drift-backed app database with 38 tables per spec §Table Definitions.
/// Ponytail ultra: raw SQL via drift executor — no codegen, minimal boilerplate.
/// Handles WAL, FK, schema versioning, GoBD triggers, seed, profiles.
class AppDatabase {
  AppDatabase([QueryExecutor? executor, this.profileDir])
    : _executor = executor ?? driftDatabase(name: 'openaccounting'),
      _ownsExecutor = executor == null;

  AppDatabase.forTesting(QueryExecutor executor, {this.profileDir}) : _executor = executor, _ownsExecutor = true;

  AppDatabase.forProfile(String profileDirectory)
    : this(drift_native.NativeDatabase(File(p.join(profileDirectory, 'openinvoices.db'))), profileDirectory);

  final QueryExecutor _executor;
  final String? profileDir;
  final bool _ownsExecutor;
  bool _opened = false;
  late final KundenRepository _kundenRepository = KundenRepository(_executor);
  late final LieferantenRepository _lieferantenRepository = LieferantenRepository(_executor);

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
    final runner = MigrationRunner(executor: _executor, profileDir: profileDir ?? resolveDefaultBaseDir());
    await runner.run(createSchema: _createAllTables);
    // Ensure triggers and seed idempotent even when no migration
    await GobdTriggers.install(_executor);
    await SeedData.run(_executor);
    await _kundenRepository.ensureSchema();
    await _lieferantenRepository.ensureSchema();
    // Ensure user_version set for fresh memory DB where runner may have skipped (hasTables false path sets version)
    final v = await runner.getUserVersion();
    if (v == 0) {
      await runner.setUserVersion(currentVersion);
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

  Future<void> close() async {
    if (_ownsExecutor) {
      await _executor.close();
    }
    _opened = false;
  }

  /// Helper for VM tests creating in-memory instance with full schema.
  static AppDatabase createTestDatabase({String? profileDir}) {
    return AppDatabase.forTesting(drift_native.NativeDatabase.memory(), profileDir: profileDir);
  }

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

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    unawaited(db.close());
  });
  return db;
});

/// Raw DDL for 38 tables — uses NUMERIC(12,2) for money, NUMERIC(12,4) for vk_netto.
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
  datev_konto_bar TEXT
)''',
  // 2 kategorien
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
  eks_kategorie TEXT
)''',
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
  note TEXT
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
  storno_von INTEGER REFERENCES rechnungen(id)
)''',
  // 12 rechnungspositionen
  '''
CREATE TABLE IF NOT EXISTS rechnungspositionen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rechnung_id INTEGER NOT NULL REFERENCES rechnungen(id) ON DELETE CASCADE,
  artikel_id INTEGER REFERENCES artikel(id),
  bezeichnung TEXT NOT NULL,
  menge NUMERIC(12,2) DEFAULT 1,
  einzelpreis NUMERIC(12,2) NOT NULL,
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
  dateipfad TEXT
)''',
  // 14 journal
  // ponytail: gruppe_id deferred — storno_von chain covers Buchungsgruppe
  // (Original→Storno) without extra FK/table; add `gruppe_id INTEGER REFERENCES journal(id)`
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
  km_anzahl NUMERIC(12,2)
)''',
  // 15 bank_templates
  '''
CREATE TABLE IF NOT EXISTS bank_templates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  typ TEXT NOT NULL,
  konfiguration TEXT
)''',
  // 16 bank_imports
  '''
CREATE TABLE IF NOT EXISTS bank_imports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  konto_id INTEGER REFERENCES konten(id),
  dateiname TEXT,
  datum TEXT DEFAULT CURRENT_TIMESTAMP,
  anzahl_transaktionen INTEGER DEFAULT 0,
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
  vorlage_daten TEXT
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
  aktiv INTEGER DEFAULT 1
)''',
  // 22 anlageverzeichnis
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
  privatanteil NUMERIC(12,2) DEFAULT 0
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
  system_stufe INTEGER DEFAULT 0
)''',
  // 26 mahnwesen_einstellungen
  '''
CREATE TABLE IF NOT EXISTS mahnwesen_einstellungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  aktiv INTEGER DEFAULT 0,
  schwelle_warnung INTEGER DEFAULT 2,
  schwelle_sperrung INTEGER DEFAULT 3,
  unternehmen_id INTEGER REFERENCES unternehmen(id)
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
  snapshot TEXT
)''',
  // 28 forderungen
  '''
CREATE TABLE IF NOT EXISTS forderungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kunde_id INTEGER REFERENCES kunden(id),
  rechnung_id INTEGER REFERENCES rechnungen(id),
  betrag NUMERIC(12,2) NOT NULL,
  status TEXT DEFAULT 'offen',
  faelligkeit TEXT,
  beschreibung TEXT
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
  unternehmen_id INTEGER REFERENCES unternehmen(id)
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
  status TEXT
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
  // 36 schnellbuchungen
  '''
CREATE TABLE IF NOT EXISTS schnellbuchungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  konto_id INTEGER REFERENCES konten(id),
  betrag NUMERIC(12,2) NOT NULL,
  beschreibung TEXT
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
];
