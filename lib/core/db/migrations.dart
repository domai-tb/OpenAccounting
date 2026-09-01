import 'package:drift/drift.dart';

import 'package:openaccounting/core/db/backup_service.dart';

/// Migration runner per spec §Schema Versioning + §Migration System.
/// Handles PRAGMA user_version, backup-before-migrate, post-hooks.
class MigrationRunner {
  MigrationRunner({required this.executor, required this.profileDir});

  final QueryExecutor executor;
  final String profileDir;

  static const int currentVersion = 5;

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
  Future<bool> run({required Future<void> Function() createSchema}) async {
    final version = await getUserVersion();
    final hasTables = await hasAnyTables();

    if (version == currentVersion && hasTables) {
      return false;
    }

    if (version > currentVersion) {
      return false;
    }

    if (version == 0 && !hasTables) {
      await _createFreshSchema(createSchema);
      return false;
    }

    if (version == currentVersion && !hasTables) {
      await _createFreshSchema(createSchema);
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
          }
          await _postHooks();
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

  Future<void> _createFreshSchema(Future<void> Function() createSchema) async {
    await executor.runCustom('BEGIN');
    try {
      await createSchema();
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
      await _migrateMahnwesen();
    }
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
        try {
          await executor.runCustom('ALTER TABLE journal ADD COLUMN $col');
        } catch (_) {
          try {
            await executor.runCustom('ALTER TABLE journal ADD COLUMN IF NOT EXISTS $col');
          } catch (_) {}
        }
      }
    }
    final List<Map<String, Object?>> vCols = await executor.runSelect(
      'PRAGMA table_info(vorsteuer_ansprueche)',
      const <Object?>[],
    );
    final Set<String> vNames = <String>{for (final Map<String, Object?> r in vCols) r['name'].toString()};
    if (!vNames.contains('ust_sonderfall')) {
      try {
        await executor.runCustom('ALTER TABLE vorsteuer_ansprueche ADD COLUMN ust_sonderfall TEXT');
      } catch (_) {
        try {
          await executor.runCustom('ALTER TABLE vorsteuer_ansprueche ADD COLUMN IF NOT EXISTS ust_sonderfall TEXT');
        } catch (_) {}
      }
    }
  }

  Future<void> _migrateFinalization() async {
    final columns = await executor.runSelect('PRAGMA table_info(rechnungen)', const <Object?>[]);
    final names = <String>{for (final column in columns) column['name'].toString()};
    if (!names.contains('absender_snapshot')) {
      await executor.runCustom('ALTER TABLE rechnungen ADD COLUMN absender_snapshot TEXT');
    }
    if (!names.contains('ausgegeben_am')) {
      await executor.runCustom('ALTER TABLE rechnungen ADD COLUMN ausgegeben_am TEXT');
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
        try {
          await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN ${e.key} ${e.value}');
        } catch (_) {
          try {
            await executor.runCustom('ALTER TABLE mahnungen ADD COLUMN IF NOT EXISTS ${e.key} ${e.value}');
          } catch (_) {}
        }
      }
    }
    final rCols = await executor.runSelect('PRAGMA table_info(rechnungen)', const <Object?>[]);
    final rNames = <String>{for (final r in rCols) r['name'].toString()};
    if (!rNames.contains('mahnstufe_aktuell')) {
      try {
        await executor.runCustom('ALTER TABLE rechnungen ADD COLUMN mahnstufe_aktuell INTEGER DEFAULT 0');
      } catch (_) {
        try {
          await executor.runCustom(
            'ALTER TABLE rechnungen ADD COLUMN IF NOT EXISTS mahnstufe_aktuell INTEGER DEFAULT 0',
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _rebuildRechnungen() async {
    await executor.runCustom('ALTER TABLE rechnungen RENAME TO rechnungen_v1');
    await executor.runCustom(_rechnungenTableSql);
    await executor.runCustom('''
INSERT INTO rechnungen (
  id, rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, lieferant_id, datum, faelligkeit,
  netto_betrag, brutto_betrag, ust_betrag, skonto_prozent, skonto_faelligkeit,
  notiz, unternehmen_id, nummernkreis_id, storno_von
)
SELECT
  id, rechnungsnummer, typ, status,
  CASE WHEN status = 'entwurf' THEN 1 ELSE 0 END,
  'netto',
  kunde_id, lieferant_id, datum, faelligkeit,
  netto_betrag, brutto_betrag, ust_betrag, skonto_prozent, skonto_faelligkeit,
  notiz, unternehmen_id, nummernkreis_id, storno_von
FROM rechnungen_v1
''');
    await executor.runCustom('DROP TABLE rechnungen_v1');
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
