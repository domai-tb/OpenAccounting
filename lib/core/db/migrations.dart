import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:openaccounting/core/db/backup_service.dart';
import 'package:openaccounting/core/db/lazy_feature_table.dart';
import 'package:openaccounting/features/feature_modules/feature_module_state.dart';

/// Migration runner per spec §Schema Versioning + §Migration System.
/// Handles PRAGMA user_version, backup-before-migrate, post-hooks.
class MigrationRunner {
  MigrationRunner({required this.executor, required this.profileDir, this.requiredTables = const <String>[]});

  final QueryExecutor executor;
  final String profileDir;
  final List<String> requiredTables;

  static const int currentVersion = 22;

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
      for (final String table in requiredTables)
        if (!_optionalSchemaTables.contains(table) &&
            (!_featureTableVersions.containsKey(table) || version >= _featureTableVersions[table]!))
          table,
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
    final List<String> malformedTables = <String>[];
    for (final String table in requiredForVersion) {
      if (actualTables.contains(table) && !await _hasDeclaredSchema(table)) {
        malformedTables.add(table);
      }
    }
    for (final String table in _optionalSchemaTables) {
      if (actualTables.contains(table) && !await _hasDeclaredSchema(table)) {
        malformedTables.add(table);
      }
    }
    malformedTables.sort();
    final ({bool healthy, bool complete}) lazyTables = await _inspectLazyOccurrenceTables(version, actualTables);
    final bool healthy =
        version <= currentVersion &&
        missingTables.isEmpty &&
        unknownTables.isEmpty &&
        malformedTables.isEmpty &&
        lazyTables.healthy;

    return SchemaHealthReport(
      schemaVersion: version,
      isHealthy: healthy,
      isCompleteForVersion13Export: healthy && version >= currentVersion && lazyTables.complete,
      missingTables: missingTables,
      unknownTables: unknownTables,
      malformedTables: malformedTables,
    );
  }

  Future<({bool healthy, bool complete})> _inspectLazyOccurrenceTables(int version, Set<String> actualTables) async {
    if (version < currentVersion) return (healthy: true, complete: false);
    if (!actualTables.contains('feature_table_state')) return (healthy: false, complete: false);
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT table_name, state FROM feature_table_state ORDER BY table_name',
      const <Object?>[],
    );
    final Map<String, String> states = <String, String>{
      for (final row in rows) row['table_name'].toString(): row['state'].toString(),
    };
    if (rows.length != LazyFeatureTableInitializer.tableNames.length ||
        states.length != LazyFeatureTableInitializer.tableNames.length) {
      return (healthy: false, complete: false);
    }

    bool complete = true;
    for (final table in LazyFeatureTableInitializer.tableNames) {
      final bool exists = actualTables.contains(table);
      final String? state = states[table];
      final bool neverInitialized = state == 'never_initialized' && !exists;
      final bool initialized = state == 'initialized' && exists;
      final bool unknown = state == 'unknown' && !exists;
      if (!(neverInitialized || initialized || unknown)) return (healthy: false, complete: false);
      if (unknown) complete = false;
    }
    return (healthy: true, complete: complete);
  }

  /// Verifies the declared schema of a version-required feature table. Base
  /// tables keep presence-only checks; a feature table with missing columns
  /// or constraints fails health so no exporter can claim completeness.
  Future<bool> _hasDeclaredSchema(String table) async {
    final Set<String>? requiredColumns = _declaredSchemaColumns[table];
    if (requiredColumns != null) {
      final List<Map<String, Object?>> columns = await executor.runSelect(
        'PRAGMA table_info($table)',
        const <Object?>[],
      );
      final Set<String> names = <String>{for (final row in columns) row['name'].toString()};
      if (_optionalSchemaTables.contains(table)) {
        final bool uniqueAttemptKey =
            table == 'dokument_email_versuche' && await _hasUniqueColumnIndex(table, 'idempotenz_schluessel');
        if (!hasDeclaredOptionalSchema(table, columns, hasUniqueAttemptKey: uniqueAttemptKey)) return false;
      } else if (!hasDeclaredSchemaColumns(table, names) || !hasDeclaredRelationshipIdTypes(table, columns)) {
        return false;
      }
    }
    if (table == 'forderung_zahlungen') {
      return _receivableFeatureHasRequiredConstraints();
    }
    return true;
  }

  static bool hasDeclaredSchemaColumns(String table, Iterable<String> columns) {
    final Set<String>? requiredColumns = _declaredSchemaColumns[table];
    if (requiredColumns == null) return true;
    final Set<String> availableColumns = columns.toSet();
    if (_optionalSchemaTables.contains(table)) {
      return availableColumns.length == requiredColumns.length && requiredColumns.containsAll(availableColumns);
    }
    return requiredColumns.every(availableColumns.contains);
  }

  static bool hasDeclaredRelationshipIdTypes(String table, List<Map<String, Object?>> columns) {
    final Set<String> relationshipColumns = _declaredRelationshipIdColumns[table] ?? const <String>{};
    for (final Map<String, Object?> column in columns) {
      if (!relationshipColumns.contains(column['name'])) continue;
      if (!(column['type']?.toString().toUpperCase().contains('INT') ?? false)) return false;
    }
    return true;
  }

  static bool hasDeclaredOptionalSchema(
    String table,
    Iterable<Map<String, Object?>> columns, {
    bool hasUniqueAttemptKey = false,
  }) {
    final Map<String, String>? expectedTypes = _optionalSchemaColumnTypes[table];
    if (expectedTypes == null) return false;
    final List<Map<String, Object?>> actual = columns.toList(growable: false);
    if (actual.length != expectedTypes.length) return false;
    for (final Map<String, Object?> column in actual) {
      final String name = column['name']?.toString() ?? '';
      if (expectedTypes[name] != column['type']?.toString().toUpperCase()) return false;
      if (_asInt(column['notnull']) != (_optionalSchemaNotNull[table]!.contains(name) ? 1 : 0)) return false;
      if (_asInt(column['pk']) != (_optionalSchemaPrimaryKey[table] == name ? 1 : 0)) return false;
    }
    return table != 'dokument_email_versuche' || hasUniqueAttemptKey;
  }

  Future<bool> _hasUniqueColumnIndex(String table, String column) async {
    final List<Map<String, Object?>> indexes = await executor.runSelect('PRAGMA index_list($table)', const <Object?>[]);
    for (final Map<String, Object?> index in indexes) {
      if (_asInt(index['unique']) != 1) continue;
      final String name = index['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final String quotedName = name.replaceAll('"', '""');
      final List<Map<String, Object?>> fields = await executor.runSelect(
        'PRAGMA index_info("$quotedName")',
        const <Object?>[],
      );
      if (fields.length == 1 && fields.single['name'] == column) return true;
    }
    return false;
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
      if (await _receivableFeatureNeedsRepair() || await _postingSchemaNeedsRepair()) {
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
      await _migrateFeatureModules();
      await _migrateProfilePortabilityTables(freshProfile: true);
      await _migrateContactArchive();
      await _migrateMasterDataImportTemplates();
      await _migrateAssetRegister();
      await _migrateStocktake();
      await _migratePostingGroups();
      await _migrateAccountHolder();
      await _migrateOccurrenceReviewState();
      await _migrateEInvoiceOutputFormat();
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
    if (version == 14) {
      await _migrateTo(13, createSchema);
      await _migrateFeatureModules();
    }
    if (version == 15) {
      await _migrateTo(14, createSchema);
      await _migrateContactArchive();
    }
    if (version == 16) {
      await _migrateTo(15, createSchema);
      await _migrateMasterDataImportTemplates();
    }
    if (version == 17) {
      await _migrateTo(16, createSchema);
      await _migrateAssetRegister();
    }
    if (version == 18) {
      await _migrateTo(17, createSchema);
      await _migrateStocktake();
    }
    if (version == 19) {
      await _migrateTo(18, createSchema);
      await _migratePostingGroups();
    }
    if (version == 20) {
      await _migrateTo(19, createSchema);
      await _migrateAccountHolder();
    }
    if (version == 21) {
      await _migrateTo(20, createSchema);
      await _migrateOccurrenceReviewState();
    }
    if (version == 22) {
      await _migrateTo(21, createSchema);
      await _migrateEInvoiceOutputFormat();
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
      await _migratePostingGroups();
      await _migrateAccountHolder();
      await _migrateOccurrenceReviewState();
      await _migrateEInvoiceOutputFormat();
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
  leistungsdatum,
  netto_betrag, brutto_betrag, ust_betrag, skonto_prozent, skonto_faelligkeit,
  notiz, unternehmen_id, nummernkreis_id, storno_von,
  absender_snapshot, ausgegeben_am, mahnstufe_aktuell
)
SELECT
  ${expression('id')}, ${expression('rechnungsnummer')}, ${expression('typ')}, ${expression('status', "'entwurf'")},
  CASE WHEN ${expression('status', "'entwurf'")} = 'entwurf' THEN 1 ELSE 0 END,
  'netto',
  ${expression('kunde_id')}, ${expression('lieferant_id')}, ${expression('datum')}, ${expression('faelligkeit')},
  ${expression('leistungsdatum')},
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

  /// Optional feature module state (v14, next sequential after the v13
  /// baseline). Adds nullable `unternehmen.feature_modules_json` and
  /// backfills NULL-only rows from legacy integer flags: only `0`/`1`
  /// values are valid, absent or invalid values become `false`. Preserves
  /// every non-NULL canonical value, all legacy columns and values,
  /// unrelated company data, and the table count; touches no module-owned
  /// business records. Runs inside the shared migration transaction, so
  /// column creation, backfill, and the version bump commit atomically
  /// and roll back together on failure.
  Future<void> _migrateFeatureModules() async {
    final tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'unternehmen'",
      const <Object?>[],
    );
    if (tables.isEmpty) {
      throw StateError('Funktionsmodule brauchen die Tabelle unternehmen');
    }
    final columns = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    final names = <String>{for (final row in columns) row['name'].toString()};
    if (!names.contains('feature_modules_json')) {
      await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN feature_modules_json TEXT');
    }
    const legacy = <String>['profilmanager_aktiv', 'lagerfuehrung_aktiv', 'guv_aktiv'];
    final present = <String>[
      for (final col in legacy)
        if (names.contains(col)) col,
    ];
    final projection = <String>['id', ...present].join(', ');
    final pending = await executor.runSelect(
      'SELECT $projection FROM unternehmen WHERE feature_modules_json IS NULL',
      const <Object?>[],
    );
    for (final row in pending) {
      await executor.runUpdate('UPDATE unternehmen SET feature_modules_json = ? WHERE id = ?', <Object?>[
        FeatureModuleState.backfillJson(
          profilmanagerAktiv: present.contains('profilmanager_aktiv') ? row['profilmanager_aktiv'] : null,
          lagerfuehrungAktiv: present.contains('lagerfuehrung_aktiv') ? row['lagerfuehrung_aktiv'] : null,
          guvAktiv: present.contains('guv_aktiv') ? row['guv_aktiv'] : null,
        ),
        row['id'],
      ]);
    }
    final verify = await executor.runSelect('PRAGMA table_info(unternehmen)', const <Object?>[]);
    if (!verify.any((row) => row['name'] == 'feature_modules_json')) {
      throw StateError('Funktionsmodul-Spalte konnte nicht verifiziert werden');
    }
  }

  /// Customer/supplier archive state (v15, next sequential after the v14
  /// baseline). Adds nullable `archived_at TEXT` to `kunden` and
  /// `lieferanten`; NULL means active, a UTC timestamp means archived.
  /// Existing rows keep NULL so every identifier, value, and reference is
  /// preserved. Runs inside the shared migration transaction, so DDL,
  /// verification, and the version bump commit atomically.
  Future<void> _migrateContactArchive() async {
    for (final String table in const <String>['kunden', 'lieferanten']) {
      final tables = await executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        <Object?>[table],
      );
      if (tables.isEmpty) {
        throw StateError('Archivstatus braucht die Tabelle $table');
      }
    }
    await _addColumnIfMissing('kunden', 'archived_at', 'TEXT');
    await _addColumnIfMissing('lieferanten', 'archived_at', 'TEXT');
    final archived = await executor.runSelect(
      'SELECT COUNT(*) AS c FROM kunden WHERE archived_at IS NOT NULL '
      'UNION ALL SELECT COUNT(*) AS c FROM lieferanten WHERE archived_at IS NOT NULL',
      const <Object?>[],
    );
    if (archived.length != 2) {
      throw StateError('Archivstatus konnte nicht verifiziert werden');
    }
  }

  /// Master-data CSV import templates (v16, next sequential after the v15
  /// baseline). Dedicated profile-local `master_data_import_templates` table;
  /// never reuses bank-owned `import_mapping_vorlagen`. Stores template name,
  /// entity, column mapping JSON, header/delimiter/numeric/duplicate options,
  /// optional match field, and timestamps. No file bytes or row values.
  /// Idempotent: safe on fresh schemas and reruns.
  Future<void> _migrateMasterDataImportTemplates() async {
    await executor.runCustom(_masterDataImportTemplatesTableSql);
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_master_data_import_templates_entity '
      'ON master_data_import_templates(entity)',
    );
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'master_data_import_templates'",
      const <Object?>[],
    );
    if (tables.isEmpty) {
      throw StateError('Importvorlagen-Tabelle konnte nicht erstellt werden');
    }
    final List<Map<String, Object?>> columns = await executor.runSelect(
      'PRAGMA table_info(master_data_import_templates)',
      const <Object?>[],
    );
    const Set<String> required = <String>{
      'id',
      'name',
      'entity',
      'mapping_json',
      'has_header',
      'delimiter',
      'decimal_convention',
      'duplicate_policy',
      'match_field',
      'created_at',
      'updated_at',
    };
    final Set<String> names = <String>{for (final Map<String, Object?> row in columns) row['name'].toString()};
    if (!required.every(names.contains)) {
      throw StateError('Importvorlagen-Schema konnte nicht verifiziert werden');
    }
  }

  /// Fixed-asset register (v17, next sequential after the v16 baseline).
  /// Adds nullable canonical columns to `anlageverzeichnis` (`asset_typ`,
  /// `kaufpreis_netto`, `nutzungsdauer_jahre`, `afa_methode`,
  /// `privat_anteil_prozent`, `verkauft_am`) and the append-only
  /// `anlage_afa_jahreswerte` schedule-snapshot table owned by
  /// `fixed-asset-register-workspace`. Legacy columns and values are never
  /// copied or reinterpreted; existing rows keep NULL canonical fields.
  /// Schedule rows are immutable via triggers and keyed by
  /// `(anlage_id, jahr, quell_hash, regel_version)`. Any DDL or verification
  /// failure rolls back with the version bump.
  Future<void> _migrateAssetRegister() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'anlageverzeichnis'",
      const <Object?>[],
    );
    if (tables.isEmpty) {
      throw StateError('Anlagenverzeichnis-Tabelle fehlt');
    }
    await _addColumnIfMissing('anlageverzeichnis', 'asset_typ', "TEXT CHECK (asset_typ IN ('KFZ','EDV','sonstig'))");
    await _addColumnIfMissing('anlageverzeichnis', 'kaufpreis_netto', 'NUMERIC(12,2) CHECK (kaufpreis_netto >= 0)');
    await _addColumnIfMissing('anlageverzeichnis', 'nutzungsdauer_jahre', 'INTEGER CHECK (nutzungsdauer_jahre > 0)');
    await _addColumnIfMissing('anlageverzeichnis', 'afa_methode', "TEXT CHECK (afa_methode IN ('linear'))");
    await _addColumnIfMissing(
      'anlageverzeichnis',
      'privat_anteil_prozent',
      'NUMERIC(5,2) CHECK (privat_anteil_prozent BETWEEN 0 AND 100)',
    );
    await _addColumnIfMissing('anlageverzeichnis', 'verkauft_am', 'TEXT');
    await executor.runCustom(_assetScheduleTableSql);
    await executor.runCustom(
      'CREATE TRIGGER IF NOT EXISTS trg_anlage_afa_no_update '
      'BEFORE UPDATE ON anlage_afa_jahreswerte '
      "BEGIN SELECT RAISE(ABORT, 'anlage_afa_jahreswerte is append-only'); END",
    );
    await executor.runCustom(
      'CREATE TRIGGER IF NOT EXISTS trg_anlage_afa_no_delete '
      'BEFORE DELETE ON anlage_afa_jahreswerte '
      "BEGIN SELECT RAISE(ABORT, 'anlage_afa_jahreswerte is append-only'); END",
    );
    final List<Map<String, Object?>> created = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'anlage_afa_jahreswerte'",
      const <Object?>[],
    );
    if (created.isEmpty) {
      throw StateError('AfA-Jahreswerte konnten nicht erstellt werden');
    }
    final List<Map<String, Object?>> columns = await executor.runSelect(
      'PRAGMA table_info(anlage_afa_jahreswerte)',
      const <Object?>[],
    );
    const Set<String> required = <String>{
      'id',
      'anlage_id',
      'jahr',
      'quell_snapshot',
      'quell_hash',
      'regel_version',
      'status',
      'formel',
      'betrag',
      'blockierungsgrund',
      'berechnet_am',
    };
    final Set<String> names = <String>{for (final Map<String, Object?> row in columns) row['name'].toString()};
    if (!required.every(names.contains)) {
      throw StateError('AfA-Jahreswerte-Schema konnte nicht verifiziert werden');
    }
    final List<Map<String, Object?>> assetColumns = await executor.runSelect(
      'PRAGMA table_info(anlageverzeichnis)',
      const <Object?>[],
    );
    final Set<String> assetNames = <String>{
      for (final Map<String, Object?> row in assetColumns) row['name'].toString(),
    };
    const Set<String> assetRequired = <String>{
      'id',
      'bezeichnung',
      'anschaffungsdatum',
      'anschaffungskosten',
      'nutzungsdauer',
      'privatanteil',
      'asset_typ',
      'kaufpreis_netto',
      'nutzungsdauer_jahre',
      'afa_methode',
      'privat_anteil_prozent',
      'verkauft_am',
    };
    if (!assetRequired.every(assetNames.contains)) {
      throw StateError('Anlagen-Schema konnte nicht verifiziert werden');
    }
  }

  /// Physical stocktake count evidence (v18, next sequential after the v17
  /// baseline). Creates exactly `inventuren` and `inventur_positionen` plus
  /// their immutability/completeness guards. Headers are inserted only as
  /// `entwurf`; the draft-to-recorded transition requires at least one
  /// position with an explicit count. Recorded headers and their positions
  /// are immutable at the persistence boundary, including direct SQL.
  /// Count snapshots never touch `artikel` stock, `inventarbewegungen`, or
  /// accounting records. Idempotent: existing verified tables are kept as-is
  /// so reruns and full-schema fixtures emit no DDL; any DDL or verification
  /// failure rolls back with the version bump.
  Future<void> _migrateStocktake() async {
    final List<Map<String, Object?>> existing = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('inventuren', 'inventur_positionen')",
      const <Object?>[],
    );
    final Set<String> names = <String>{for (final Map<String, Object?> row in existing) row['name'].toString()};
    if (names.length == 2) {
      await _verifyStocktakeSchema();
      return;
    }
    if (names.isNotEmpty) {
      throw StateError('Inventur-Schema unvollständig');
    }
    await executor.runCustom(_inventurenTableSql);
    await executor.runCustom(_inventurPositionenTableSql);
    for (final String trigger in _stocktakeTriggerSql) {
      await executor.runCustom(trigger);
    }
    await _verifyStocktakeSchema();
  }

  /// Balanced posting groups + settlement allocations (v19, next sequential
  /// after the v18 baseline). Adds source/group/reversal columns to `journal`
  /// (`source_kind`, `source_id`, `reversal_of_group_id`, durable
  /// `legacy_unverified` defaulting to 1 so every pre-existing row stays
  /// readable history) plus `settlement_groups`, `settlement_allocations`,
  /// and `statutory_timing_rules`. The migration runner is forward-only;
  /// rollback means restoring the pre-migration backup, not removing schema
  /// in place. Idempotent: reruns and full-schema fixtures emit no
  /// duplicate DDL; any DDL or verification failure rolls back with the
  /// version bump.
  Future<void> _migratePostingGroups() async {
    final List<Map<String, Object?>> journalTables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'journal'",
      const <Object?>[],
    );
    if (journalTables.isEmpty) {
      throw StateError('Ausgleichsbuchungen brauchen die Tabelle journal');
    }
    await _addColumnIfMissing('journal', 'source_kind', 'TEXT');
    await _addColumnIfMissing('journal', 'source_id', 'TEXT');
    await _addColumnIfMissing('journal', 'reversal_of_group_id', 'INTEGER REFERENCES journal(id)');
    await _addColumnIfMissing('journal', 'legacy_unverified', 'INTEGER NOT NULL DEFAULT 1');
    // Pre-existing rows without balanced legs stay durable legacy history.
    await executor.runCustom(
      'UPDATE journal SET legacy_unverified = 1 WHERE source_kind IS NULL AND (legacy_unverified IS NULL OR legacy_unverified = 0)',
    );
    await executor.runCustom(_postingGroupsTableSql);
    await executor.runCustom(_settlementAllocationsTableSql);
    await executor.runCustom(_statutoryTimingRulesTableSql);
    await executor.runCustom('DROP INDEX IF EXISTS idx_journal_source_unique');
    await executor.runCustom(
      'CREATE UNIQUE INDEX idx_journal_source_unique '
      'ON journal(source_kind, source_id) '
      'WHERE source_kind IS NOT NULL AND source_id IS NOT NULL AND gruppe_id = id',
    );
    await executor.runCustom(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_settlement_groups_source_unique '
      'ON settlement_groups(source_kind, source_id)',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_settlement_groups_bank ON settlement_groups(bank_transaction_id) '
      'WHERE bank_transaction_id IS NOT NULL',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_settlement_allocations_group ON settlement_allocations(group_id)',
    );
    await _verifyPostingGroupsSchema();
  }

  /// Bank-account holder (v20, next sequential after the v19 baseline). Adds
  /// nullable `konten.inhaber` without rewriting existing account values or
  /// changing IDs. Create and duplicate-IBAN update paths persist the
  /// normalized holder; setup summaries read it back from the same row.
  Future<void> _migrateAccountHolder() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'konten'",
      const <Object?>[],
    );
    if (tables.isEmpty) {
      throw StateError('Kontoinhaber braucht die Tabelle konten');
    }
    await _addColumnIfMissing('konten', 'inhaber', 'TEXT');
    final List<Map<String, Object?>> columns = await executor.runSelect('PRAGMA table_info(konten)', const <Object?>[]);
    if (!columns.any((Map<String, Object?> row) => row['name'] == 'inhaber')) {
      throw StateError('Kontoinhaber-Spalte konnte nicht verifiziert werden');
    }
  }

  /// Occurrence review-state persistence (v21, next sequential after the v20
  /// baseline). Adds durable `review_status` (pending/blocked/ready/
  /// handed_off/posted/failed, default pending), `block_reason`, and
  /// `handoff_error` to the lazy `buchungsvorlagen_occurrences` table without
  /// touching the unique `(vorlage_id, faelligkeit)` key or the linked
  /// journal/invoice references. Existing rows backfill to `pending` with
  /// NULL reasons via the column default. Displays read these persisted
  /// values; the migration itself creates no financial record. Idempotent:
  /// reruns and fresh profiles (where the lazy table does not exist yet)
  /// emit no duplicate DDL.
  Future<void> _migrateOccurrenceReviewState() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'buchungsvorlagen_occurrences'",
      const <Object?>[],
    );
    if (tables.isEmpty) return;
    await _addColumnIfMissing(
      'buchungsvorlagen_occurrences',
      'review_status',
      "TEXT NOT NULL DEFAULT 'pending' CHECK (review_status IN "
          "('pending','blocked','ready','handed_off','posted','failed'))",
    );
    await _addColumnIfMissing('buchungsvorlagen_occurrences', 'block_reason', 'TEXT');
    await _addColumnIfMissing('buchungsvorlagen_occurrences', 'handoff_error', 'TEXT');
    await _verifyOccurrenceReviewState();
  }

  /// E-invoice output-format persistence (v22, next sequential after the v21
  /// baseline). Adds nullable `rechnungen.ausgabeformat` (`pdf`, `zugferd`,
  /// or `xrechnung`) plus `rechnungen.kunde_snapshot` (finalized customer
  /// JSON for standalone exports). Existing finalized rows backfill to
  /// `pdf` because the pre-change application never produced structured
  /// output; drafts keep NULL until finalization writes the explicit choice.
  /// Readers resolve any remaining NULL to `pdf` without consulting current
  /// customer settings. Idempotent: reruns emit no duplicate DDL.
  Future<void> _migrateEInvoiceOutputFormat() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rechnungen'",
      const <Object?>[],
    );
    if (tables.isEmpty) {
      throw StateError('Ausgabeformat braucht die Tabelle rechnungen');
    }
    await _addColumnIfMissing(
      'rechnungen',
      'ausgabeformat',
      "TEXT CHECK (ausgabeformat IS NULL OR ausgabeformat IN ('pdf', 'zugferd', 'xrechnung'))",
    );
    await _addColumnIfMissing('rechnungen', 'kunde_snapshot', 'TEXT');
    await executor.runCustom(
      "UPDATE rechnungen SET ausgabeformat = 'pdf' WHERE ist_entwurf = 0 AND ausgabeformat IS NULL",
    );
    await _verifyEInvoiceOutputFormat();
  }

  Future<void> _verifyEInvoiceOutputFormat() async {
    final List<Map<String, Object?>> columns = await executor.runSelect(
      'PRAGMA table_info(rechnungen)',
      const <Object?>[],
    );
    final Set<String> names = <String>{for (final Map<String, Object?> row in columns) row['name'].toString()};
    if (!names.contains('ausgabeformat') || !names.contains('kunde_snapshot')) {
      throw StateError('E-Rechnungs-Ausgabeformat-Schema konnte nicht verifiziert werden');
    }
    final List<Map<String, Object?>> legacy = await executor.runSelect(
      'SELECT id FROM rechnungen WHERE ist_entwurf = 0 AND ausgabeformat IS NULL LIMIT 1',
      const <Object?>[],
    );
    if (legacy.isNotEmpty) {
      throw StateError('Finalisierte Rechnungen ohne Ausgabeformat konnten nicht migriert werden');
    }
  }

  Future<void> _verifyOccurrenceReviewState() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'buchungsvorlagen_occurrences'",
      const <Object?>[],
    );
    if (tables.isEmpty) return;
    final List<Map<String, Object?>> columns = await executor.runSelect(
      'PRAGMA table_info(buchungsvorlagen_occurrences)',
      const <Object?>[],
    );
    const Set<String> required = <String>{
      'id',
      'vorlage_id',
      'faelligkeit',
      'journal_id',
      'rechnung_id',
      'review_status',
      'block_reason',
      'handoff_error',
    };
    final Set<String> names = <String>{for (final Map<String, Object?> row in columns) row['name'].toString()};
    if (!required.every(names.contains)) {
      throw StateError('Buchungsvorlagen-Occurrence-Review-Schema konnte nicht verifiziert werden');
    }
  }

  Future<bool> _postingSchemaNeedsRepair() async {
    try {
      await _verifyPostingGroupsSchema();
      await _verifyOccurrenceReviewState();
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _verifyPostingGroupsSchema() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
      "('settlement_groups', 'settlement_allocations', 'statutory_timing_rules')",
      const <Object?>[],
    );
    if (tables.length != 3) {
      throw StateError('Ausgleichs-Tabellen konnten nicht verifiziert werden');
    }
    final List<Map<String, Object?>> journalColumns = await executor.runSelect(
      'PRAGMA table_info(journal)',
      const <Object?>[],
    );
    final Set<String> journalNames = <String>{
      for (final Map<String, Object?> row in journalColumns) row['name'].toString(),
    };
    const Set<String> journalRequired = <String>{
      'source_kind',
      'source_id',
      'reversal_of_group_id',
      'legacy_unverified',
    };
    if (!journalRequired.every(journalNames.contains)) {
      throw StateError('Journal-Quellspalten konnten nicht verifiziert werden');
    }
    final List<Map<String, Object?>> sourceIndexes = await executor.runSelect(
      "PRAGMA index_list('journal')",
      const <Object?>[],
    );
    if (!sourceIndexes.any(
      (Map<String, Object?> row) =>
          row['name'] == 'idx_journal_source_unique' && row['unique'] == 1 && row['partial'] == 1,
    )) {
      throw StateError('Journal-Quellindex konnte nicht verifiziert werden');
    }
    final List<Map<String, Object?>> sourceIndexSql = await executor.runSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = 'idx_journal_source_unique'",
      const <Object?>[],
    );
    if (sourceIndexSql.isEmpty || !sourceIndexSql.single['sql'].toString().contains('gruppe_id = id')) {
      throw StateError('Journal-Quellindex muss nur die Gruppenwurzel eindeutigen');
    }
    final List<Map<String, Object?>> groupColumns = await executor.runSelect(
      'PRAGMA table_info(settlement_groups)',
      const <Object?>[],
    );
    final Set<String> groupNames = <String>{
      for (final Map<String, Object?> row in groupColumns) row['name'].toString(),
    };
    const Set<String> groupRequired = <String>{
      'id',
      'source_kind',
      'source_id',
      'signed_amount_cents',
      'settlement_date',
      'unapplied_cents',
      'group_root_journal_id',
    };
    if (!groupRequired.every(groupNames.contains)) {
      throw StateError('Ausgleichsgruppen-Schema konnte nicht verifiziert werden');
    }
  }

  Future<void> _verifyStocktakeSchema() async {
    final List<Map<String, Object?>> tables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('inventuren', 'inventur_positionen')",
      const <Object?>[],
    );
    if (tables.length != 2) {
      throw StateError('Inventur-Tabellen konnten nicht verifiziert werden');
    }
    final List<Map<String, Object?>> headerColumns = await executor.runSelect(
      'PRAGMA table_info(inventuren)',
      const <Object?>[],
    );
    final Set<String> headerNames = <String>{
      for (final Map<String, Object?> row in headerColumns) row['name'].toString(),
    };
    const Set<String> headerRequired = <String>{'id', 'stichtag', 'status', 'erstellt_am'};
    if (!headerRequired.every(headerNames.contains)) {
      throw StateError('Inventur-Kopf konnte nicht verifiziert werden');
    }
    final List<Map<String, Object?>> positionColumns = await executor.runSelect(
      'PRAGMA table_info(inventur_positionen)',
      const <Object?>[],
    );
    final Set<String> positionNames = <String>{
      for (final Map<String, Object?> row in positionColumns) row['name'].toString(),
    };
    const Set<String> positionRequired = <String>{
      'id',
      'inventur_id',
      'artikel_id',
      'bezeichnung_snapshot',
      'einheit_snapshot',
      'menge_gezaehlt',
    };
    if (!positionRequired.every(positionNames.contains)) {
      throw StateError('Inventur-Positionen konnten nicht verifiziert werden');
    }
    final List<Map<String, Object?>> guards = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name IN "
      "('trg_inventuren_insert_only_entwurf', 'trg_inventuren_no_update_recorded', "
      "'trg_inventuren_record_needs_counts', 'trg_inventuren_no_delete_recorded', "
      "'trg_inventur_positionen_no_insert_recorded', 'trg_inventur_positionen_no_update_recorded', "
      "'trg_inventur_positionen_no_delete_recorded')",
      const <Object?>[],
    );
    if (guards.length != 7) {
      throw StateError('Inventur-Schutz konnte nicht verifiziert werden');
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
    required this.malformedTables,
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

  /// Version-required tables that are present with an invalid declared schema.
  final List<String> malformedTables;
}

const Set<String> _featureOwnedTables = <String>{
  'forderung_zahlungen',
  'buchungsvorlagen_occurrences',
  'rechnungsvorlagen_occurrences',
  'mileage_trips',
  'mileage_trip_corrections',
  'category_mapping_history',
  'feature_table_state',
  'master_data_import_templates',
  'anlage_afa_jahreswerte',
  'inventuren',
  'inventur_positionen',
  'settlement_groups',
  'settlement_allocations',
  'statutory_timing_rules',
  'dokument_email_templates',
  'dokument_email_versuche',
};

const Map<String, int> _featureTableVersions = <String, int>{
  'forderung_zahlungen': 8,
  'category_mapping_history': 9,
  'feature_table_state': 13,
  'mileage_trips': 13,
  'mileage_trip_corrections': 13,
  'master_data_import_templates': 16,
  'anlage_afa_jahreswerte': 17,
  'inventuren': 18,
  'inventur_positionen': 18,
  'settlement_groups': 19,
  'settlement_allocations': 19,
  'statutory_timing_rules': 19,
};

// shortcut: subset check covers load-bearing columns only; extend when the exporter reads additional columns.
const Set<String> _optionalSchemaTables = <String>{'dokument_email_templates', 'dokument_email_versuche'};

const Map<String, Map<String, String>> _optionalSchemaColumnTypes = <String, Map<String, String>>{
  'dokument_email_templates': <String, String>{
    'typ': 'TEXT',
    'betreff': 'TEXT',
    'text': 'TEXT',
    'aktualisiert_am': 'TEXT',
  },
  'dokument_email_versuche': <String, String>{
    'id': 'INTEGER',
    'dokument_id': 'INTEGER',
    'dokument_typ': 'TEXT',
    'empfaenger': 'TEXT',
    'ergebnis': 'TEXT',
    'mahnung_id': 'INTEGER',
    'idempotenz_schluessel': 'TEXT',
    'artefakt_ids': 'TEXT',
    'erstellt_am': 'TEXT',
    'abgeschlossen_am': 'TEXT',
    'fehler_kategorie': 'TEXT',
  },
};

const Map<String, Set<String>> _optionalSchemaNotNull = <String, Set<String>>{
  'dokument_email_templates': <String>{'betreff', 'text', 'aktualisiert_am'},
  'dokument_email_versuche': <String>{
    'dokument_id',
    'dokument_typ',
    'empfaenger',
    'ergebnis',
    'idempotenz_schluessel',
    'artefakt_ids',
    'erstellt_am',
  },
};

const Map<String, String> _optionalSchemaPrimaryKey = <String, String>{
  'dokument_email_templates': 'typ',
  'dokument_email_versuche': 'id',
};

const Map<String, Set<String>> _declaredRelationshipIdColumns = <String, Set<String>>{
  'kunden_lieferadressen': <String>{'kunde_id'},
  'rechnungen': <String>{
    'kunde_id',
    'lieferadresse_id',
    'storno_von',
    'gutschrift_von',
    'ersatz_fuer',
    'ersatzrechnung_id',
    'konvertiert_von',
    'konvertiert_zu',
    'vorlage_id',
  },
  'rechnungspositionen': <String>{'rechnung_id'},
  'mahnungen': <String>{'kunde_id', 'rechnung_id'},
  'forderungen': <String>{'kunde_id', 'partner_id', 'rechnung_id', 'journal_id', 'ausgleich_journal_id'},
  'forderung_zahlungen': <String>{'forderung_id', 'journal_id'},
  'journal': <String>{'rechnung_id', 'beleg_id'},
  'vorsteuer_ansprueche': <String>{'rechnung_id'},
  'rechnungsvorlagen': <String>{'kunde_id', 'auftrag_id'},
  'rechnungsvorlagen_occurrences': <String>{'vorlage_id', 'rechnung_id'},
  'kunden_belege': <String>{'kunde_id', 'beleg_id'},
  'buchungsvorlagen_occurrences': <String>{'rechnung_id', 'journal_id'},
  'settlement_allocations': <String>{'forderung_id'},
  'dokument_email_versuche': <String>{'dokument_id', 'mahnung_id'},
};

const Map<String, Set<String>> _declaredSchemaColumns = <String, Set<String>>{
  // These keys are stable across profile versions; the exporter validates every projected field separately.
  'kunden': <String>{'id'},
  'kunden_lieferadressen': <String>{'id', 'kunde_id'},
  'rechnungen': <String>{'id', 'kunde_id'},
  'rechnungspositionen': <String>{'id', 'rechnung_id'},
  'mahnungen': <String>{'id', 'rechnung_id', 'kunde_id'},
  'forderungen': <String>{'id', 'kunde_id', 'rechnung_id', 'journal_id', 'ausgleich_journal_id'},
  'journal': <String>{'id', 'rechnung_id'},
  'vorsteuer_ansprueche': <String>{'id', 'rechnung_id'},
  'rechnungsvorlagen': <String>{'id', 'kunde_id'},
  'kunden_belege': <String>{'id', 'kunde_id', 'beleg_id'},
  'belege': <String>{'id', 'dateipfad'},
  'forderung_zahlungen': <String>{
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
  },
  'category_mapping_history': <String>{'id', 'kategorie_id', 'geaendert_am', 'aktion', 'nachher_mapping_json'},
  'mileage_trips': <String>{
    'id',
    'trip_date',
    'purpose',
    'business_context',
    'distance_hundredths_km',
    'state',
    'created_at',
    'updated_at',
  },
  'mileage_trip_corrections': <String>{'id', 'trip_id', 'kind', 'reason', 'state', 'created_at'},
  'feature_table_state': <String>{'table_name', 'state'},
  'master_data_import_templates': <String>{
    'id',
    'name',
    'entity',
    'mapping_json',
    'has_header',
    'delimiter',
    'decimal_convention',
    'duplicate_policy',
    'match_field',
    'created_at',
    'updated_at',
  },
  'anlage_afa_jahreswerte': <String>{
    'id',
    'anlage_id',
    'jahr',
    'quell_snapshot',
    'quell_hash',
    'regel_version',
    'status',
    'betrag',
    'blockierungsgrund',
    'berechnet_am',
  },
  'inventuren': <String>{'id', 'stichtag', 'status', 'erstellt_am'},
  'inventur_positionen': <String>{
    'id',
    'inventur_id',
    'artikel_id',
    'bezeichnung_snapshot',
    'einheit_snapshot',
    'menge_gezaehlt',
  },
  'settlement_groups': <String>{
    'id',
    'source_kind',
    'source_id',
    'signed_amount_cents',
    'settlement_date',
    'unapplied_cents',
    'group_root_journal_id',
  },
  'settlement_allocations': <String>{
    'id',
    'group_id',
    'forderung_id',
    'applied_cents',
    'settlement_date',
    'euer_zeile',
    'direction',
  },
  'statutory_timing_rules': <String>{
    'id',
    'rule_id',
    'rule_version',
    'legal_basis',
    'affected_year',
    'approver',
    'source_trace',
    'settlement_group_id',
    'attributed_year',
  },
  'dokument_email_templates': <String>{'typ', 'betreff', 'text', 'aktualisiert_am'},
  'dokument_email_versuche': <String>{
    'id',
    'dokument_id',
    'dokument_typ',
    'empfaenger',
    'ergebnis',
    'mahnung_id',
    'idempotenz_schluessel',
    'artefakt_ids',
    'erstellt_am',
    'abgeschlossen_am',
    'fehler_kategorie',
  },
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
  leistungsdatum TEXT,
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
  mahnstufe_aktuell INTEGER DEFAULT 0,
  ausgabeformat TEXT CHECK (ausgabeformat IS NULL OR ausgabeformat IN ('pdf', 'zugferd', 'xrechnung')),
  kunde_snapshot TEXT
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

const String _masterDataImportTemplatesTableSql = '''
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
)''';

const String _assetScheduleTableSql = '''
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
)''';

const String _postingGroupsTableSql = '''
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
)''';

const String _settlementAllocationsTableSql = '''
CREATE TABLE IF NOT EXISTS settlement_allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL REFERENCES settlement_groups(id) ON DELETE CASCADE,
  forderung_id INTEGER REFERENCES forderungen(id),
  applied_cents INTEGER NOT NULL CHECK (applied_cents != 0),
  settlement_date TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  euer_zeile INTEGER,
  direction TEXT NOT NULL DEFAULT 'einnahme' CHECK (direction IN ('einnahme', 'ausgabe')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)''';

const String _statutoryTimingRulesTableSql = '''
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
)''';

const String _inventurenTableSql = '''
CREATE TABLE IF NOT EXISTS inventuren (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stichtag TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'entwurf' CHECK (status IN ('entwurf', 'erfasst')),
  erstellt_am TEXT NOT NULL
)''';

const String _inventurPositionenTableSql = '''
CREATE TABLE IF NOT EXISTS inventur_positionen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  inventur_id INTEGER NOT NULL REFERENCES inventuren(id) ON DELETE RESTRICT,
  artikel_id INTEGER NOT NULL,
  bezeichnung_snapshot TEXT NOT NULL CHECK (trim(bezeichnung_snapshot) <> ''),
  einheit_snapshot TEXT NOT NULL CHECK (trim(einheit_snapshot) <> ''),
  menge_gezaehlt NUMERIC(10,3) CHECK (menge_gezaehlt IS NULL OR menge_gezaehlt >= 0),
  UNIQUE (inventur_id, artikel_id)
)''';

/// Persistence-boundary guards for recorded count evidence. Draft rows stay
/// editable; anything touching a recorded (`erfasst`) header or its positions
/// is rejected, including direct SQL. The draft-to-recorded transition is the
/// only path to `erfasst` and requires at least one counted position.
const List<String> _stocktakeTriggerSql = <String>[
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
];
