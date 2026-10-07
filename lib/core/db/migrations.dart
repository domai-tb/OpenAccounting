import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:openaccounting/core/db/backup_service.dart';
import 'package:openaccounting/core/db/lazy_feature_table.dart';

/// Migration runner per spec §Schema Versioning + §Migration System.
/// Handles PRAGMA user_version, backup-before-migrate, post-hooks.
class MigrationRunner {
  MigrationRunner({required this.executor, required this.profileDir, this.requiredTables = const <String>[]});

  final QueryExecutor executor;
  final String profileDir;
  final List<String> requiredTables;

  static const int currentVersion = 13;

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

  Future<SchemaHealthReport> inspectSchemaHealth() async {
    final int version = await getUserVersion();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      const <Object?>[],
    );
    final Set<String> actualTables = <String>{for (final row in rows) row['name'].toString()};
    final Set<String> knownTables = <String>{...requiredTables, ..._featureOwnedTables};
    final Set<String> requiredForVersion = <String>{
      ...requiredTables,
      for (final entry in _featureTableVersions.entries)
        if (version >= entry.value) entry.key,
    };

    final List<String> missingTables = <String>[
      for (final table in requiredForVersion)
        if (!actualTables.contains(table)) table,
    ]..sort();
    final List<String> unknownTables = <String>[
      for (final table in actualTables)
        if (!knownTables.contains(table)) table,
    ]..sort();
    final bool healthy = version <= currentVersion && missingTables.isEmpty && unknownTables.isEmpty;

    final bool lazyTablesComplete = await _lazyOccurrenceTablesComplete(version, actualTables);

    return SchemaHealthReport(
      schemaVersion: version,
      isHealthy: healthy,
      isCompleteForVersion13Export: healthy && version >= currentVersion && lazyTablesComplete,
      missingTables: missingTables,
      unknownTables: unknownTables,
    );
  }

  Future<bool> _lazyOccurrenceTablesComplete(int version, Set<String> actualTables) async {
    if (version < currentVersion || !actualTables.contains('feature_table_state')) return false;
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT table_name, state FROM feature_table_state ORDER BY table_name',
      const <Object?>[],
    );
    final Map<String, String> states = <String, String>{
      for (final row in rows) row['table_name'].toString(): row['state'].toString(),
    };
    if (states.length != LazyFeatureTableInitializer.tableNames.length) return false;

    for (final table in LazyFeatureTableInitializer.tableNames) {
      final bool exists = actualTables.contains(table);
      final String? state = states[table];
      if (!((state == 'never_initialized' && !exists) || (state == 'initialized' && exists))) return false;
    }
    return true;
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

    if (version > currentVersion) {
      throw StateError(
        'Database schema version $version is newer than application version $currentVersion. '
        'Downgrade not supported.',
      );
    }

    await _verifyPaymentTableRequiredAtVersion(version);

    if (version == currentVersion && hasTables) {
      await _verifyRequiredTables();
      if (await _receivableFeatureNeedsRepair()) {
        await _repairCurrentFeature(afterFeatureSchemaDdl);
        return true;
      }
      return false;
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
      await _migrateCategoryProvenance();
      await _migrateBankImportMode();
      await _migrateFiscalYearStart();
      await _migrateQuickBookingPresets();
      await _migrateProfilePortabilityTables(freshProfile: true);
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
    if (version == 9) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateMahnwesen();
      await _migrateInventarbewegungen();
      await _migrateJournalGruppeId();
      await _migrateReceivableFeature();
      await _migrateCategoryProvenance();
    }
    if (version == 10) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateMahnwesen();
      await _migrateInventarbewegungen();
      await _migrateJournalGruppeId();
      await _migrateReceivableFeature();
      await _migrateCategoryProvenance();
      await _migrateBankImportMode();
    }
    if (version == 11) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateMahnwesen();
      await _migrateInventarbewegungen();
      await _migrateJournalGruppeId();
      await _migrateReceivableFeature();
      await _migrateCategoryProvenance();
      await _migrateBankImportMode();
      await _migrateFiscalYearStart();
    }
    if (version == 12) {
      await createSchema();
      await _migrateRechnungen();
      await _migrateMahnwesen();
      await _migrateInventarbewegungen();
      await _migrateJournalGruppeId();
      await _migrateReceivableFeature();
      await _migrateCategoryProvenance();
      await _migrateBankImportMode();
      await _migrateFiscalYearStart();
      await _migrateQuickBookingPresets();
    }
    if (version == 13) {
      await _migrateTo(12, createSchema);
      await _migrateProfilePortabilityTables(freshProfile: false);
    }
  }

  Future<void> _migrateProfilePortabilityTables({required bool freshProfile}) async {
    await executor.runCustom(_featureTableStateTableSql);
    await executor.runCustom(_mileageTripsTableSql);
    await executor.runCustom(_mileageTripCorrectionsTableSql);
    await executor.runCustom(
      'CREATE UNIQUE INDEX IF NOT EXISTS mileage_trip_corrections_active_trip_unique '
      "ON mileage_trip_corrections(trip_id) WHERE state IN ('draft', 'applied')",
    );

    for (final tableName in const <String>['buchungsvorlagen_occurrences', 'rechnungsvorlagen_occurrences']) {
      final existingTable = await executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        <Object?>[tableName],
      );
      final state = freshProfile
          ? 'never_initialized'
          : existingTable.isEmpty
          ? 'unknown'
          : 'initialized';
      await executor.runInsert('INSERT OR IGNORE INTO feature_table_state (table_name, state) VALUES (?, ?)', <Object?>[
        tableName,
        state,
      ]);
    }

    final required = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
      "('feature_table_state', 'mileage_trips', 'mileage_trip_corrections')",
      const <Object?>[],
    );
    if (required.length != 3) {
      throw StateError('Profilinventar konnte nicht vollständig erstellt werden');
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

  Future<void> _verifyPaymentTableRequiredAtVersion(int version) async {
    if (version < _featureTableVersions['forderung_zahlungen']!) return;
    final List<Map<String, Object?>> rows = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
      const <Object?>[],
    );
    if (rows.isEmpty) {
      throw StateError(
        'Datenbank unvollständig: forderung_zahlungen fehlt bei Schema-Version $version; automatische Reparatur gestoppt.',
      );
    }
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

  /// Accounting-catalog-provenance migration (v9, reassigned from v10: no accepted
  /// v9 migration had landed and no approved DDL exists for mileage/marker tables).
  /// Adds mapping-provenance columns to `kategorien` with a safe literal default
  /// so every preexisting row is classified `legacy_unverified` without rewriting
  /// values, creates the append-only `category_mapping_history`, records one
  /// migration history row per preexisting category, and adds nullable
  /// `mapping_provenance_json` snapshot columns to the export logs.
  /// Idempotent: safe to run on fresh schemas (columns/table already present)
  /// and to rerun (history rows are inserted only when missing).
  Future<void> _migrateCategoryProvenance() async {
    final katColumns = await executor.runSelect('PRAGMA table_info(kategorien)', const <Object?>[]);
    final katNames = <String>{for (final row in katColumns) row['name'].toString()};
    const additions = <String, String>{
      'mapping_status':
          "TEXT NOT NULL DEFAULT 'legacy_unverified' CHECK (mapping_status IN "
          "('catalog_verified','user_confirmed','legacy_unverified','review_required','unmapped'))",
      'catalog_entry_key': 'TEXT',
      'catalog_source_reference': 'TEXT',
      'catalog_source_version': 'TEXT',
      'mapping_reviewed_at': 'TEXT',
    };
    for (final entry in additions.entries) {
      if (!katNames.contains(entry.key)) {
        await executor.runCustom('ALTER TABLE kategorien ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
    final unverified = await executor.runSelect(
      'SELECT COUNT(*) AS c FROM kategorien WHERE mapping_status NOT IN '
      "('catalog_verified','user_confirmed','legacy_unverified','review_required','unmapped')",
      const <Object?>[],
    );
    if (_asInt(unverified.single['c']) != 0) {
      throw StateError('Kategorie-Provenienz konnte nicht verifiziert werden');
    }

    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS category_mapping_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kategorie_id INTEGER NOT NULL REFERENCES kategorien(id) ON DELETE RESTRICT,
  geaendert_am TEXT NOT NULL,
  aktion TEXT NOT NULL CHECK (aktion IN ('migration','catalog_import','mapping_edit','user_review')),
  vorher_mapping_json TEXT,
  nachher_mapping_json TEXT NOT NULL,
  katalog_quelle TEXT,
  katalog_version TEXT
)''');
    await executor.runCustom('''
CREATE TRIGGER IF NOT EXISTS trg_category_mapping_history_no_update
BEFORE UPDATE ON category_mapping_history
BEGIN SELECT RAISE(ABORT, 'category_mapping_history is append-only'); END''');
    await executor.runCustom('''
CREATE TRIGGER IF NOT EXISTS trg_category_mapping_history_no_delete
BEFORE DELETE ON category_mapping_history
BEGIN SELECT RAISE(ABORT, 'category_mapping_history is append-only'); END''');

    // One migration history row per preexisting category that lacks one.
    // Column-agnostic (SELECT k.*): optional mapping columns such as
    // konto_ust_skr03 are added lazily by the repository and may be absent.
    final pending = await executor.runSelect(
      'SELECT k.* '
      'FROM kategorien k LEFT JOIN category_mapping_history h '
      "ON h.kategorie_id = k.id AND h.aktion = 'migration' "
      'WHERE h.id IS NULL',
      const <Object?>[],
    );
    final now = DateTime.now().toUtc().toIso8601String();
    for (final row in pending) {
      final mapping = <String, Object?>{
        'konto_skr03': row['konto_skr03'],
        'konto_skr04': row['konto_skr04'],
        'konto_ust_skr03': row['konto_ust_skr03'],
        'konto_ust_skr04': row['konto_ust_skr04'],
        'euer_zeile': row['euer_zeile'],
        'eks_kategorie': row['eks_kategorie'],
      };
      final nachher = <String, Object?>{...mapping, 'mapping_status': row['mapping_status']};
      await executor.runInsert(
        'INSERT INTO category_mapping_history '
        '(kategorie_id, geaendert_am, aktion, vorher_mapping_json, nachher_mapping_json, katalog_quelle, katalog_version) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[row['id'], now, 'migration', jsonEncode(mapping), jsonEncode(nachher), null, null],
      );
    }

    await _addColumnIfMissing('euer_exporte', 'mapping_provenance_json', 'TEXT');
    await _addColumnIfMissing('datev_export_log', 'mapping_provenance_json', 'TEXT');

    final history = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='category_mapping_history'",
      const <Object?>[],
    );
    if (history.isEmpty) {
      throw StateError('Kategorie-Historie konnte nicht verifiziert werden');
    }
  }

  /// Bank-import profile mode (v10, reassigned from 9). Adds the strict
  /// `unternehmen.bank_import_manuell` flag (1 = manual default, 0 =
  /// automatic) without touching company data. No runtime fallback may
  /// create this column; any DDL/version failure rolls everything back.
  Future<void> _migrateBankImportMode() async {
    final columns = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    if (columns.isEmpty) {
      throw StateError('Bankimport-Modus braucht die Tabelle unternehmen');
    }
    if (!columns.any((c) => c['name'] == 'bank_import_manuell')) {
      await executor.runCustom(
        'ALTER TABLE unternehmen ADD COLUMN bank_import_manuell INTEGER NOT NULL DEFAULT 1 '
        'CHECK (bank_import_manuell IN (0, 1))',
      );
    }
    final verify = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    final col = verify.where((c) => c['name'] == 'bank_import_manuell').toList(growable: false);
    if (col.isEmpty) {
      throw StateError('Bankimport-Modus konnte nicht verifiziert werden');
    }
    final notNull = col.single['notnull'];
    if (notNull is! num || notNull == 0) {
      throw StateError('Bankimport-Modus muss NOT NULL sein');
    }
  }

  /// Company fiscal-year start month (v11). Adds strict
  /// `unternehmen.geschaeftsjahr_startmonat` (1–12, default January) and
  /// backfills existing company rows to January without touching other
  /// fields. Any DDL/verification failure rolls back with the version.
  Future<void> _migrateFiscalYearStart() async {
    final columns = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    if (columns.isEmpty) {
      throw StateError('Geschäftsjahr braucht die Tabelle unternehmen');
    }
    if (!columns.any((c) => c['name'] == 'geschaeftsjahr_startmonat')) {
      await executor.runCustom(
        'ALTER TABLE unternehmen ADD COLUMN geschaeftsjahr_startmonat INTEGER NOT NULL DEFAULT 1 '
        'CHECK (geschaeftsjahr_startmonat BETWEEN 1 AND 12)',
      );
    }
    final verify = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    final col = verify.where((c) => c['name'] == 'geschaeftsjahr_startmonat').toList(growable: false);
    if (col.isEmpty) {
      throw StateError('Geschäftsjahr-Startmonat konnte nicht verifiziert werden');
    }
    final notNull = col.single['notnull'];
    if (notNull is! num || notNull == 0) {
      throw StateError('Geschäftsjahr-Startmonat muss NOT NULL sein');
    }
    final bad = await executor.runSelect(
      'SELECT COUNT(*) AS c FROM unternehmen WHERE geschaeftsjahr_startmonat NOT BETWEEN 1 AND 12',
      const <Object?>[],
    );
    if (_asInt(bad.single['c']) != 0) {
      throw StateError('Ungültiger Geschäftsjahr-Startmonat gefunden');
    }
  }

  /// Quick-booking explicit execution semantics (v12). Adds nullable `art`,
  /// `ust_satz_id`, and `eingabemodus`, and rebuilds the table to make the
  /// default `betrag` nullable while preserving stable IDs and every stored
  /// value. No direction, tax, or basis is inferred; legacy presets stay
  /// reviewable but non-executable. Any failure rolls everything back.
  Future<void> _migrateQuickBookingPresets() async {
    final tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'schnellbuchungen'",
      const <Object?>[],
    );
    if (tables.isEmpty) {
      throw StateError('Schnellbuchungen-Tabelle fehlt');
    }
    final columns = await executor.runSelect('PRAGMA table_info(schnellbuchungen)', const <Object?>[]);
    final names = <String>{for (final row in columns) row['name'].toString()};
    final bool needsRebuild =
        !names.contains('art') || !names.contains('ust_satz_id') || !names.contains('eingabemodus');
    final Object? betragNotNull = columns.where((c) => c['name'] == 'betrag').map((c) => c['notnull']).firstOrNull;
    final bool betragRequired = betragNotNull is num && betragNotNull != 0;
    if (!needsRebuild && !betragRequired) {
      await _verifyQuickBookingColumns();
      return;
    }
    await executor.runCustom('ALTER TABLE schnellbuchungen RENAME TO schnellbuchungen_legacy');
    try {
      await executor.runCustom(_quickBookingTableSql);
      final copyCols = <String>[
        'id',
        'name',
        'kategorie_id',
        'konto_id',
        'betrag',
        'beschreibung',
        'art',
        'ust_satz_id',
        'eingabemodus',
      ];
      final selectCols = <String>[
        for (final c in copyCols)
          if (names.contains(c)) '"$c"' else 'NULL',
      ];
      await executor.runCustom(
        'INSERT INTO schnellbuchungen (${copyCols.join(', ')}) SELECT ${selectCols.join(', ')} FROM schnellbuchungen_legacy',
      );
      await executor.runCustom('DROP TABLE schnellbuchungen_legacy');
    } catch (error) {
      // Best-effort restore is handled by the caller's transaction rollback;
      // rethrow to trigger it.
      rethrow;
    }
    await _verifyQuickBookingColumns();
    final counts = await executor.runSelect(
      'SELECT COUNT(*) AS c, COUNT(id) AS ids, COUNT(DISTINCT id) AS distinct_ids FROM schnellbuchungen',
      const <Object?>[],
    );
    if (counts.single['c'] != counts.single['distinct_ids']) {
      throw StateError('Schnellbuchungen-IDs wurden nicht erhalten');
    }
  }

  Future<void> _verifyQuickBookingColumns() async {
    final columns = await executor.runSelect('PRAGMA table_info(schnellbuchungen)', const <Object?>[]);
    final names = <String>{for (final row in columns) row['name'].toString()};
    const required = <String>[
      'id',
      'name',
      'kategorie_id',
      'konto_id',
      'betrag',
      'beschreibung',
      'art',
      'ust_satz_id',
      'eingabemodus',
    ];
    if (!required.every(names.contains)) {
      throw StateError('Schnellbuchungen-Schema konnte nicht verifiziert werden');
    }
  }

  static int _asInt(Object? v) => v is int
      ? v
      : v is num
      ? v.toInt()
      : v is String
      ? int.tryParse(v) ?? -1
      : -1;

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

/// Result of checking the application tables against the profile's stored schema version.
class SchemaHealthReport {
  /// Creates a schema health result.
  const SchemaHealthReport({
    required this.schemaVersion,
    required this.isHealthy,
    required this.isCompleteForVersion13Export,
    required this.missingTables,
    required this.unknownTables,
  });

  /// The profile's stored SQLite schema version.
  final int schemaVersion;

  /// Whether the tables required at [schemaVersion] are present and known.
  final bool isHealthy;

  /// Whether the inventory is complete enough for a version-13 profile export.
  final bool isCompleteForVersion13Export;

  /// Required application tables that are absent at [schemaVersion].
  final List<String> missingTables;

  /// Application tables that are not in the known inventory.
  final List<String> unknownTables;
}

const Set<String> _featureOwnedTables = <String>{
  'forderung_zahlungen',
  'buchungsvorlagen_occurrences',
  'rechnungsvorlagen_occurrences',
  'mileage_trips',
  'mileage_trip_corrections',
  'category_mapping_history',
  'feature_table_state',
};

const Map<String, int> _featureTableVersions = <String, int>{
  'forderung_zahlungen': 8,
  'category_mapping_history': 9,
  'feature_table_state': 13,
  'mileage_trips': 13,
  'mileage_trip_corrections': 13,
};

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

const String _quickBookingTableSql = '''
CREATE TABLE schnellbuchungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  konto_id INTEGER REFERENCES konten(id),
  betrag NUMERIC(12,2),
  beschreibung TEXT,
  art TEXT CHECK (art IN ('einnahme','ausgabe')),
  ust_satz_id INTEGER REFERENCES ust_saetze(id),
  eingabemodus TEXT CHECK (eingabemodus IN ('netto','brutto'))
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

const String _featureTableStateTableSql = '''
CREATE TABLE IF NOT EXISTS feature_table_state (
  table_name TEXT PRIMARY KEY NOT NULL CHECK (table_name IN (
    'buchungsvorlagen_occurrences',
    'rechnungsvorlagen_occurrences'
  )),
  state TEXT NOT NULL CHECK (state IN ('never_initialized', 'initialized', 'unknown'))
)''';

const String _mileageTripsTableSql = '''
CREATE TABLE IF NOT EXISTS mileage_trips (
  id TEXT PRIMARY KEY NOT NULL,
  trip_date TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK (trim(purpose) <> ''),
  business_context TEXT NOT NULL CHECK (trim(business_context) <> ''),
  distance_hundredths_km INTEGER NOT NULL CHECK (distance_hundredths_km BETWEEN 1 AND 999999999999),
  state TEXT NOT NULL CHECK (state IN ('unresolved', 'calculated', 'posted', 'corrected', 'voided')),
  policy_id TEXT,
  policy_source TEXT,
  policy_version TEXT,
  policy_effective_from TEXT,
  policy_effective_to TEXT,
  calculated_amount NUMERIC(12,2),
  calculated_at TEXT,
  posting_event_id TEXT UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK (
    (policy_id IS NULL AND policy_source IS NULL AND policy_version IS NULL
      AND policy_effective_from IS NULL AND policy_effective_to IS NULL
      AND calculated_amount IS NULL AND calculated_at IS NULL)
    OR
    (trim(policy_id) <> '' AND trim(policy_source) <> '' AND trim(policy_version) <> ''
      AND policy_effective_from IS NOT NULL AND policy_effective_to IS NOT NULL
      AND calculated_amount IS NOT NULL AND calculated_amount >= 0 AND calculated_at IS NOT NULL)
  ),
  CHECK (
    (state = 'unresolved' AND calculated_amount IS NULL AND posting_event_id IS NULL)
    OR
    (state = 'calculated' AND calculated_amount IS NOT NULL AND posting_event_id IS NULL)
    OR
    (state IN ('posted', 'corrected', 'voided') AND calculated_amount IS NOT NULL
      AND posting_event_id IS NOT NULL AND trim(posting_event_id) <> '')
  )
)''';

const String _mileageTripCorrectionsTableSql = '''
CREATE TABLE IF NOT EXISTS mileage_trip_corrections (
  id TEXT PRIMARY KEY NOT NULL,
  trip_id TEXT NOT NULL REFERENCES mileage_trips(id) ON DELETE RESTRICT,
  kind TEXT NOT NULL CHECK (kind IN ('replace', 'void')),
  replacement_trip_id TEXT UNIQUE REFERENCES mileage_trips(id) ON DELETE RESTRICT,
  reason TEXT NOT NULL CHECK (trim(reason) <> ''),
  state TEXT NOT NULL CHECK (state IN ('draft', 'applied', 'cancelled')),
  accounting_correction_id TEXT UNIQUE,
  created_at TEXT NOT NULL,
  applied_at TEXT,
  CHECK ((kind = 'replace' AND replacement_trip_id IS NOT NULL AND replacement_trip_id <> trip_id)
      OR (kind = 'void' AND replacement_trip_id IS NULL)),
  CHECK ((state = 'draft' AND accounting_correction_id IS NULL AND applied_at IS NULL)
      OR (state = 'applied' AND accounting_correction_id IS NOT NULL
        AND trim(accounting_correction_id) <> '' AND applied_at IS NOT NULL)
      OR (state = 'cancelled' AND accounting_correction_id IS NULL AND applied_at IS NULL))
)''';
