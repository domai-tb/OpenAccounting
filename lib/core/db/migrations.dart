import 'package:drift/drift.dart';

import 'package:openaccounting/core/db/backup_service.dart';

/// Migration runner per spec §Schema Versioning + §Migration System.
/// Handles PRAGMA user_version, backup-before-migrate, post-hooks.
class MigrationRunner {
  MigrationRunner({required this.executor, required this.profileDir, this.requiredTables = const <String>[]});

  final QueryExecutor executor;
  final String profileDir;
  final List<String> requiredTables;

  static const int currentVersion = 8;

  Future<int> getUserVersion() async {
    final rows = await executor.runSelect('PRAGMA user_version', const []);
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<void> setUserVersion(int v) async {
    await executor.runCustom('PRAGMA user_version = $v');
  }

  Future<bool> hasAnyTables() async {
    final rows = await executor.runSelect(
      "SELECT count(*) as c FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      const [],
    );
    final c = rows.first['c'];
    if (c is int) return c > 0;
    if (c is num) return c > 0;
    return false;
  }

  /// Run migrations if needed. Returns true if migration executed.
  Future<bool> run({
    required Future<void> Function() createSchema,
    Future<void> Function(QueryExecutor executor)? afterFeatureSchemaDdl,
  }) async {
    final version = await getUserVersion();
    final hasTables = await hasAnyTables();

    if (version == currentVersion && hasTables) {
      await _verifyRequiredTables();
      if (await _receivableFeatureNeedsRepair()) {
        await _repairCurrentFeature(afterFeatureSchemaDdl);
        return true;
      }
      return false;
    }

    if (version > currentVersion) {
      throw StateError(
        'Database schema version $version is newer than application version $currentVersion. '
        'Downgrade not supported.',
      );
    }

    if (version == 0 && !hasTables) {
      await _createFreshSchema(createSchema, afterFeatureSchemaDdl);
      return false;
    }

    if (version == currentVersion && !hasTables) {
      await _createFreshSchema(createSchema, afterFeatureSchemaDdl);
      return true;
    }

    if (version < currentVersion) {
      try {
        await executor.runCustom('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {}
      final backup = BackupService(profileDir: profileDir, executor: executor);
      try {
        await backup.createLocalBackup();
      } catch (e) {
        throw StateError('Backup vor Migration fehlgeschlagen: $e');
      }

      final foreignKeysEnabled = await _pragmaEnabled('foreign_keys');
      final legacyAlterTableEnabled = await _pragmaEnabled('legacy_alter_table');
      if (foreignKeysEnabled) {
        await executor.runCustom('PRAGMA foreign_keys = OFF');
      }
      try {
        await executor.runCustom('PRAGMA legacy_alter_table = ON');
        await executor.runCustom('BEGIN');
        try {
          for (var v = version + 1; v <= currentVersion; v++) {
            await _migrateTo(v, createSchema);
            if (v == currentVersion) {
              await _runFeatureDdlCallback(afterFeatureSchemaDdl);
            }
          }
          await _postHooks();
          await _verifyRequiredTables();
          await setUserVersion(currentVersion);
          await executor.runCustom('COMMIT');
          return true;
        } catch (error, stackTrace) {
          try {
            await executor.runCustom('ROLLBACK');
          } catch (rollbackError, rollbackStackTrace) {
            Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      } finally {
        try {
          await executor.runCustom('PRAGMA legacy_alter_table = ${legacyAlterTableEnabled ? 1 : 0}');
        } catch (_) {}
        if (foreignKeysEnabled) {
          try {
            await executor.runCustom('PRAGMA foreign_keys = ON');
          } catch (_) {}
        }
      }
    }

    return false;
  }

  Future<void> _createFreshSchema(
    Future<void> Function() createSchema,
    Future<void> Function(QueryExecutor executor)? afterFeatureSchemaDdl,
  ) async {
    await executor.runCustom('BEGIN');
    try {
      await createSchema();
      await _migrateReceivableFeature();
      await _runFeatureDdlCallback(afterFeatureSchemaDdl);
      await _verifyRequiredTables();
      await setUserVersion(currentVersion);
      await executor.runCustom('COMMIT');
    } catch (error, stackTrace) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _migrateTo(int version, Future<void> Function() createSchema) async {
    if (version == 1) {
      await createSchema();
    }
    if (version == 2) {
      await createSchema();
      await _migrateRechnungen();
    }
    if (version == 3) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateAccounting();
    }
    if (version == 4) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateFinalization();
    }
    if (version == 5) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateMahnwesen();
    }
    if (version == 6) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateMahnwesen();
      await _migrateInventarbewegungen();
    }
    if (version == 7) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateMahnwesen();
      await _migrateInventarbewegungen();
      await _migrateJournalGruppeId();
    }
    if (version == 8) {
      // Keep the historical upgrade contract: an outdated profile still runs
      // the idempotent base-schema hook before the new feature DDL. This also
      // repairs partially rebuilt legacy tables encountered in old fixtures.
      await createSchema();
      await _migrateRechnungen();
      await _migrateMahnwesen();
      await _migrateInventarbewegungen();
      await _migrateJournalGruppeId();
      await _migrateReceivableFeature();
    }
  }

  Future<void> _runFeatureDdlCallback(Future<void> Function(QueryExecutor executor)? callback) async {
    if (callback != null) await callback(executor);
  }

  Future<void> _repairCurrentFeature(Future<void> Function(QueryExecutor executor)? callback) async {
    await executor.runCustom('BEGIN');
    try {
      await _migrateReceivableFeature();
      await _runFeatureDdlCallback(callback);
      await _verifyRequiredTables();
      await setUserVersion(currentVersion);
      await executor.runCustom('COMMIT');
    } catch (error, stackTrace) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<bool> _receivableFeatureNeedsRepair() async {
    final tableRows = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
      const <Object?>[],
    );
    if (tableRows.isEmpty) return true;
    final columns = await executor.runSelect('PRAGMA table_info(forderung_zahlungen)', const <Object?>[]);
    const required = <String>{
      'id',
      'forderung_id',
      'journal_id',
      'betrag',
      'typ',
      'datum',
      'idempotency_key',
      'requested_betrag_cents',
      'fingerprint_direction',
      'fingerprint_date_policy',
    };
    if (!required.every((name) => columns.any((row) => row['name'] == name))) return true;
    return !(await _receivableFeatureHasRequiredConstraints());
  }

  Future<bool> _receivableFeatureHasRequiredConstraints() async {
    final foreignKeys = await executor.runSelect('PRAGMA foreign_key_list(forderung_zahlungen)', const <Object?>[]);
    final bool hasForderungForeignKey = foreignKeys.any((row) => row['table']?.toString() == 'forderungen');
    final bool hasJournalForeignKey = foreignKeys.any((row) => row['table']?.toString() == 'journal');
    if (!hasForderungForeignKey || !hasJournalForeignKey) return false;

    final indexes = await executor.runSelect('PRAGMA index_list(forderung_zahlungen)', const <Object?>[]);
    bool hasUniqueIndex(String name) {
      return indexes.any((row) {
        final Object? unique = row['unique'];
        return row['name'] == name && (unique == 1 || unique == true);
      });
    }

    return hasUniqueIndex('forderung_zahlungen_key_unique') && hasUniqueIndex('forderung_zahlungen_journal_unique');
  }

  Future<void> _migrateReceivableFeature() async {
    final tableRows = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
      const <Object?>[],
    );
    if (tableRows.isEmpty) {
      // Create the table, then fall through to the shared constraint creation and
      // verification so a freshly created feature table is verified before the
      // migration transaction commits and `user_version` is raised.
      await executor.runCustom(_receivablePaymentTableSql);
    }
    final columnsRows = await executor.runSelect('PRAGMA table_info(forderung_zahlungen)', const <Object?>[]);
    final columns = <String>{for (final row in columnsRows) row['name'].toString()};
    const additions = <String, String>{
      'requested_betrag_cents': 'INTEGER',
      'fingerprint_direction': 'TEXT',
      'fingerprint_date_policy': 'TEXT',
    };
    for (final entry in additions.entries) {
      if (!columns.contains(entry.key)) {
        await executor.runCustom('ALTER TABLE forderung_zahlungen ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
    final foreignKeys = await executor.runSelect('PRAGMA foreign_key_list(forderung_zahlungen)', const <Object?>[]);
    final hasForderungForeignKey = foreignKeys.any((row) => row['table']?.toString() == 'forderungen');
    final hasJournalForeignKey = foreignKeys.any((row) => row['table']?.toString() == 'journal');
    if (!hasForderungForeignKey || !hasJournalForeignKey) {
      await _rebuildReceivablePaymentTable(columns);
    }
    await executor.runCustom(
      'CREATE UNIQUE INDEX IF NOT EXISTS forderung_zahlungen_key_unique '
      'ON forderung_zahlungen(idempotency_key) WHERE idempotency_key IS NOT NULL',
    );
    await executor.runCustom(
      'CREATE UNIQUE INDEX IF NOT EXISTS forderung_zahlungen_journal_unique ON forderung_zahlungen(journal_id)',
    );
    final verified = await executor.runSelect('PRAGMA table_info(forderung_zahlungen)', const <Object?>[]);
    const required = <String>{
      'id',
      'forderung_id',
      'journal_id',
      'betrag',
      'typ',
      'datum',
      'idempotency_key',
      'requested_betrag_cents',
      'fingerprint_direction',
      'fingerprint_date_policy',
    };
    if (!required.every((name) => verified.any((row) => row['name'] == name))) {
      throw StateError('Forderungen-Zahlungsschema konnte nicht verifiziert werden');
    }
    if (!(await _receivableFeatureHasRequiredConstraints())) {
      throw StateError('Forderungen-Zahlungsschema konnte seine Constraints nicht verifizieren');
    }
  }

  Future<void> _rebuildReceivablePaymentTable(Set<String> oldColumns) async {
    await executor.runCustom('ALTER TABLE forderung_zahlungen RENAME TO forderung_zahlungen_legacy');
    await executor.runCustom(_receivablePaymentTableSql);
    String expression(String name) => oldColumns.contains(name) ? '"$name"' : 'NULL';
    await executor.runCustom('''
INSERT INTO forderung_zahlungen (
  id, forderung_id, journal_id, betrag, typ, datum, idempotency_key,
  requested_betrag_cents, fingerprint_direction, fingerprint_date_policy
)
SELECT ${expression('id')}, ${expression('forderung_id')}, ${expression('journal_id')}, ${expression('betrag')},
       ${expression('typ')}, ${expression('datum')}, ${expression('idempotency_key')},
       ${expression('requested_betrag_cents')}, ${expression('fingerprint_direction')}, ${expression('fingerprint_date_policy')}
FROM forderung_zahlungen_legacy''');
    await executor.runCustom('DROP TABLE forderung_zahlungen_legacy');
  }

  Future<bool> _pragmaEnabled(String pragma) async {
    final rows = await executor.runSelect('PRAGMA $pragma', const <Object?>[]);
    if (rows.isEmpty) return false;
    final value = rows.first.values.first;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value == '1';
  }

  Future<void> _migrateRechnungen() async {
    final columns = await executor.runSelect('PRAGMA table_info(rechnungen)', const <Object?>[]);
    var hasDraftFlag = false;
    var hasInputMode = false;
    var numberIsRequired = false;
    for (final column in columns) {
      final name = column['name'];
      if (name == 'ist_entwurf') hasDraftFlag = true;
      if (name == 'eingabemodus') hasInputMode = true;
      if (name == 'rechnungsnummer') {
        final notNull = column['notnull'];
        numberIsRequired = notNull is num && notNull != 0;
      }
    }

    if (numberIsRequired || !hasDraftFlag || !hasInputMode) {
      await _rebuildRechnungen();
    }
  }

  Future<void> _migrateAccounting() async {
    final List<Map<String, Object?>> jCols = await executor.runSelect('PRAGMA table_info(journal)', const <Object?>[]);
    final Set<String> jNames = <String>{for (final Map<String, Object?> r in jCols) r['name'].toString()};
    const List<String> jAdds = <String>[
      'ust_satz NUMERIC(12,2)',
      'ust_sonderfall TEXT',
      'marge_25a_brutto NUMERIC(12,2)',
      'ust_satz_25a NUMERIC(12,2)',
      'ist_eu_lieferung INTEGER DEFAULT 0',
      'vorsteuer_betrag NUMERIC(12,2)',
    ];
    for (final String col in jAdds) {
      final String name = col.split(' ').first;
      if (!jNames.contains(name)) {
        await _addColumnIfMissing('journal', name, col.substring(name.length).trim());
      }
    }
    final List<Map<String, Object?>> vCols = await executor.runSelect(
      'PRAGMA table_info(vorsteuer_ansprueche)',
      const <Object?>[],
    );
    final Set<String> vNames = <String>{for (final Map<String, Object?> r in vCols) r['name'].toString()};
    if (!vNames.contains('ust_sonderfall')) {
      await _addColumnIfMissing('vorsteuer_ansprueche', 'ust_sonderfall', 'TEXT');
    }
  }

  Future<void> _migrateFinalization() async {
    final columns = await executor.runSelect('PRAGMA table_info(rechnungen)', const <Object?>[]);
    final names = <String>{for (final column in columns) column['name'].toString()};
    if (!names.contains('absender_snapshot')) {
      await _addColumnIfMissing('rechnungen', 'absender_snapshot', 'TEXT');
    }
    if (!names.contains('ausgegeben_am')) {
      await _addColumnIfMissing('rechnungen', 'ausgegeben_am', 'TEXT');
    }
  }

  Future<void> _migrateMahnwesen() async {
    final mCols = await executor.runSelect('PRAGMA table_info(mahnungen)', const <Object?>[]);
    final mNames = <String>{for (final r in mCols) r['name'].toString()};
    const mAdds = <String, String>{
      'gebuehr_bezahlt': 'NUMERIC(12,2) DEFAULT 0',
      'zinsen_bezahlt': 'NUMERIC(12,2) DEFAULT 0',
      'uebernommene_gebuehr': 'NUMERIC(12,2) DEFAULT 0',
      'uebernommene_zinsen': 'NUMERIC(12,2) DEFAULT 0',
      'versendet_am': 'TEXT',
    };
    for (final e in mAdds.entries) {
      if (!mNames.contains(e.key)) {
        await _addColumnIfMissing('mahnungen', e.key, e.value);
      }
    }
    final rCols = await executor.runSelect('PRAGMA table_info(rechnungen)', const <Object?>[]);
    final rNames = <String>{for (final r in rCols) r['name'].toString()};
    if (!rNames.contains('mahnstufe_aktuell')) {
      await _addColumnIfMissing('rechnungen', 'mahnstufe_aktuell', 'INTEGER DEFAULT 0');
    }
  }

  Future<void> _migrateInventarbewegungen() async {
    final rows = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='inventarbewegungen'",
      const <Object?>[],
    );
    if (rows.isEmpty) {
      await executor.runCustom('''
CREATE TABLE IF NOT EXISTS inventarbewegungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artikel_id INTEGER NOT NULL REFERENCES artikel(id),
  datum TEXT NOT NULL,
  diff NUMERIC(10,3) NOT NULL,
  grund TEXT NOT NULL,
  referenz_typ TEXT,
  referenz_id INTEGER
)''');
    }
  }

  Future<void> _rebuildRechnungen() async {
    await executor.runCustom('ALTER TABLE rechnungen RENAME TO rechnungen_v1');
    await executor.runCustom(_rechnungenTableSql);
    final oldColumns = await executor.runSelect('PRAGMA table_info(rechnungen_v1)', const <Object?>[]);
    final oldNames = <String>{for (final column in oldColumns) column['name'].toString()};
    String expression(String name, [String fallback = 'NULL']) => oldNames.contains(name) ? '"$name"' : fallback;
    if (!oldNames.contains('id') || !oldNames.contains('typ') || !oldNames.contains('datum')) {
      throw StateError('Rechnungen-Migration benötigt mindestens id, typ und datum');
    }
    await executor.runCustom('''
INSERT INTO rechnungen (
  id, rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, lieferant_id, datum, faelligkeit,
  netto_betrag, brutto_betrag, ust_betrag, skonto_prozent, skonto_faelligkeit,
  notiz, unternehmen_id, nummernkreis_id, storno_von,
  absender_snapshot, ausgegeben_am, mahnstufe_aktuell
)
SELECT
  ${expression('id')}, ${expression('rechnungsnummer')}, ${expression('typ')}, ${expression('status', "'entwurf'")},
  CASE WHEN ${expression('status', "'entwurf'")} = 'entwurf' THEN 1 ELSE 0 END,
  'netto',
  ${expression('kunde_id')}, ${expression('lieferant_id')}, ${expression('datum')}, ${expression('faelligkeit')},
  ${expression('netto_betrag', '0')}, ${expression('brutto_betrag', '0')}, ${expression('ust_betrag', '0')},
  ${expression('skonto_prozent', '0')}, ${expression('skonto_faelligkeit')}, ${expression('notiz')},
  ${expression('unternehmen_id')}, ${expression('nummernkreis_id')}, ${expression('storno_von')},
  ${expression('absender_snapshot')}, ${expression('ausgegeben_am')}, ${expression('mahnstufe_aktuell', '0')}
FROM rechnungen_v1
''');
    await executor.runCustom('DROP TABLE rechnungen_v1');
  }

  Future<void> _migrateJournalGruppeId() async {
    final columns = await executor.runSelect('PRAGMA table_info(journal)', const <Object?>[]);
    bool hasGruppeId = false;
    for (final column in columns) {
      if (column['name'] == 'gruppe_id') {
        hasGruppeId = true;
        break;
      }
    }
    if (!hasGruppeId) {
      await _addColumnIfMissing('journal', 'gruppe_id', 'INTEGER REFERENCES journal(id)');
    }
    await executor.runCustom('UPDATE journal SET gruppe_id = id WHERE gruppe_id IS NULL');
  }

  Future<void> _addColumnIfMissing(String table, String name, String definition) async {
    final columns = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (columns.any((column) => column['name'] == name)) return;
    await executor.runCustom('ALTER TABLE $table ADD COLUMN $name $definition');
    final verified = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (!verified.any((column) => column['name'] == name)) {
      throw StateError('Migration konnte Spalte $table.$name nicht verifizieren');
    }
  }

  Future<void> _verifyRequiredTables() async {
    if (requiredTables.isEmpty) return;
    final rows = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      const <Object?>[],
    );
    final actual = <String>{for (final row in rows) row['name'].toString()};
    final missing = requiredTables.where((table) => !actual.contains(table)).toList(growable: false);
    if (missing.isNotEmpty) {
      throw StateError('Datenbankschema unvollständig; fehlende Tabellen: ${missing.join(', ')}');
    }
  }

  Future<void> _postHooks() async {
    // Intentionally left empty.
    // Triggers and seeds are installed in AppDatabase.ensureOpen after migration.
  }
}

const String _rechnungenTableSql = '''
CREATE TABLE rechnungen (
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
  mahnstufe_aktuell INTEGER DEFAULT 0
)''';

const String _receivablePaymentTableSql = '''
CREATE TABLE IF NOT EXISTS forderung_zahlungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  forderung_id INTEGER NOT NULL REFERENCES forderungen(id),
  journal_id INTEGER NOT NULL UNIQUE REFERENCES journal(id),
  betrag NUMERIC(12,2) NOT NULL,
  typ TEXT NOT NULL CHECK (typ IN ('zahlung','ueberzahlung','ausbuchen')),
  datum TEXT NOT NULL,
  idempotency_key TEXT UNIQUE,
  requested_betrag_cents INTEGER,
  fingerprint_direction TEXT,
  fingerprint_date_policy TEXT
)''';
