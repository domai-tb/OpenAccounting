import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/setup/profile_export_service.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';

void main() {
  group('Cashbook v26 opening-source migration', () {
    late AppDatabase db;
    late Directory profileDirectory;
    late MigrationRunner runner;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_cashbook_migration_test_');
      db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      runner = MigrationRunner(
        executor: db.executor,
        profileDir: profileDirectory.path,
        requiredTables: AppDatabase.allTableNames,
      );
    });

    tearDown(() async {
      await db.close();
      await profileDirectory.delete(recursive: true);
    });

    test('test_v25_and_v26_schema_health_respects_opening_source_version', () async {
      await _removeDailyCloseEvidence(db);
      await db.executor.runCustom('DROP TABLE account_opening_balance_sources');
      await runner.setUserVersion(25);

      final SchemaHealthReport v25Report = await runner.inspectSchemaHealth();
      expect(
        v25Report.isHealthy,
        isTrue,
        reason:
            'v25 missing=${v25Report.missingTables}, unknown=${v25Report.unknownTables}, malformed=${v25Report.malformedTables}',
      );
      expect(v25Report.missingTables, isNot(contains('account_opening_balance_sources')));

      await runner.setUserVersion(26);
      final SchemaHealthReport v26Report = await runner.inspectSchemaHealth();
      expect(v26Report.isHealthy, isFalse);
      expect(v26Report.missingTables, contains('account_opening_balance_sources'));
    });

    test('test_v27_reopen_fails_closed_when_opening_source_table_is_missing', () async {
      final Directory persistentDirectory = await Directory.systemTemp.createTemp(
        'openaccounting_cashbook_reopen_test_',
      );
      final File databaseFile = File('${persistentDirectory.path}${Platform.pathSeparator}openinvoices.db');
      try {
        final AppDatabase original = AppDatabase.forProfile(persistentDirectory.path);
        try {
          await original.ensureOpen();
          await _createSetupOpeningSource(original);
          await original.executor.runCustom('DROP TABLE account_opening_balance_sources');
        } finally {
          await original.close();
        }

        final String databasePathBeforeOpen = _expectOpeningSourceTableMissing(databaseFile, expectedVersion: 27);

        final AppDatabase reopened = AppDatabase.forProfile(persistentDirectory.path);
        try {
          Object? initializationError;
          try {
            await reopened.ensureOpen();
          } catch (error) {
            initializationError = error;
          }
          final MigrationRunner reopenedRunner = MigrationRunner(
            executor: reopened.executor,
            profileDir: persistentDirectory.path,
            requiredTables: AppDatabase.allTableNames,
          );
          final state = await _openingSourceDatabaseState(reopened);
          debugPrint(
            'Cashbook reopen: database_list=${state.path}, user_version=${state.version}, '
            'sqlite_master=${state.sourceTables}, initialization_error=$initializationError',
          );
          expect(state.path, databasePathBeforeOpen);
          expect(state.path, databaseFile.absolute.path);
          expect(state.version, 27);
          expect(
            state.sourceTables,
            isEmpty,
            reason:
                'Reopen database_list path=${state.path}, user_version=${state.version}, '
                'sqlite_master=${state.sourceTables}.',
          );
          final SchemaHealthReport health = await reopenedRunner.inspectSchemaHealth();
          expect(health.schemaVersion, 27);
          expect(health.isHealthy, isFalse);
          expect(health.missingTables, contains('account_opening_balance_sources'));

          final ProfileExportReadiness readiness = await ProfileExportService(
            executor: reopened.executor,
            profileDir: persistentDirectory.path,
            profileLabel: 'Cashbook source test',
          ).checkExportReadiness();
          expect(readiness.eligibility, ProfileExportEligibility.incomplete);
          expect(readiness.state, 'missing');
        } finally {
          await reopened.close();
        }

        final String databasePathAfterClose = _expectOpeningSourceTableMissing(databaseFile, expectedVersion: 27);
        expect(databasePathAfterClose, databasePathBeforeOpen);
      } finally {
        await persistentDirectory.delete(recursive: true);
      }
    });

    test('test_v26_to_v27_upgrade_fails_closed_when_opening_source_table_is_missing', () async {
      final Directory persistentDirectory = await Directory.systemTemp.createTemp(
        'openaccounting_cashbook_upgrade_missing_source_test_',
      );
      final File databaseFile = File('${persistentDirectory.path}${Platform.pathSeparator}openinvoices.db');
      try {
        final AppDatabase original = AppDatabase.forProfile(persistentDirectory.path);
        try {
          await original.ensureOpen();
          await _createSetupOpeningSource(original);
          await original.executor.runCustom('DROP TABLE account_opening_balance_sources');
          await _removeDailyCloseEvidence(original);
          await MigrationRunner(executor: original.executor, profileDir: persistentDirectory.path).setUserVersion(26);
        } finally {
          await original.close();
        }

        final String databasePathBeforeOpen = _expectOpeningSourceTableMissing(databaseFile, expectedVersion: 26);

        final AppDatabase upgraded = AppDatabase.forProfile(persistentDirectory.path);
        try {
          Object? initializationError;
          try {
            await upgraded.ensureOpen();
          } catch (error) {
            initializationError = error;
          }
          final MigrationRunner upgradedRunner = MigrationRunner(
            executor: upgraded.executor,
            profileDir: persistentDirectory.path,
            requiredTables: AppDatabase.allTableNames,
          );
          final state = await _openingSourceDatabaseState(upgraded);
          debugPrint(
            'Cashbook upgrade: database_list=${state.path}, user_version=${state.version}, '
            'sqlite_master=${state.sourceTables}, initialization_error=$initializationError',
          );
          expect(state.path, databasePathBeforeOpen);
          expect(state.path, databaseFile.absolute.path);
          expect(state.version, 26);
          expect(
            state.sourceTables,
            isEmpty,
            reason:
                'Upgrade database_list path=${state.path}, user_version=${state.version}, '
                'sqlite_master=${state.sourceTables}.',
          );
          final SchemaHealthReport health = await upgradedRunner.inspectSchemaHealth();
          expect(health.isHealthy, isFalse);
          expect(health.missingTables, contains('account_opening_balance_sources'));

          final ProfileExportReadiness readiness = await ProfileExportService(
            executor: upgraded.executor,
            profileDir: persistentDirectory.path,
            profileLabel: 'Cashbook source test',
          ).checkExportReadiness();
          expect(readiness.eligibility, ProfileExportEligibility.incomplete);
          expect(readiness.state, 'missing');
        } finally {
          await upgraded.close();
        }

        final String databasePathAfterClose = _expectOpeningSourceTableMissing(databaseFile, expectedVersion: 26);
        expect(databasePathAfterClose, databasePathBeforeOpen);
      } finally {
        await persistentDirectory.delete(recursive: true);
      }
    });

    test('test_v26_opening_source_migration_preserves_legacy_history_without_backfill', () async {
      await db.executor.runCustom('DROP TABLE IF EXISTS account_opening_balance_sources');
      await db.executor.runCustom('PRAGMA foreign_keys = OFF');
      await db.executor.runInsert('INSERT INTO unternehmen (id, name) VALUES (1, ?)', const <Object?>['Legacy GmbH']);
      final int accountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        const <Object?>['Kasse', 'Kasse', 'EUR', 1, '125.00'],
      );

      final List<Map<String, Object?>> journalColumns = await db.executor.runSelect(
        'PRAGMA table_info(journal)',
        const <Object?>[],
      );
      if (journalColumns.every((Map<String, Object?> column) => column['name'] != 'is_opening_balance')) {
        await db.executor.runCustom('ALTER TABLE journal ADD COLUMN is_opening_balance INTEGER NOT NULL DEFAULT 0');
      }
      await db.executor.runInsert(
        'INSERT INTO journal (datum, konto_id, betrag, beleg_typ, beschreibung, is_opening_balance) '
        'VALUES (?, ?, ?, ?, ?, 1)',
        <Object?>['2025-01-01', accountId, '125.00', 'eroeffnung', 'Legacy Kassenöffnung'],
      );

      final List<Map<String, Object?>> accountsBefore = await db.executor.runSelect(
        'SELECT id, name, kontoart, waehrung, unternehmen_id, saldo FROM konten WHERE id = ?',
        <Object?>[accountId],
      );
      final List<Map<String, Object?>> journalBefore = await db.executor.runSelect(
        'SELECT id, datum, konto_id, betrag, beleg_typ, beschreibung, is_opening_balance '
        'FROM journal WHERE konto_id = ?',
        <Object?>[accountId],
      );
      await db.executor.runCustom('''
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
)
''');
      final int legacyCloseId = await db.executor.runInsert(
        'INSERT INTO tagesabschluesse '
        '(datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, signatur) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['2025-01-01', '100.00', '125.00', '25.00', 1, accountId, 'legacy-signature'],
      );
      final List<Map<String, Object?>> legacyCloseBefore = await db.executor.runSelect(
        'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, signatur '
        'FROM tagesabschluesse WHERE id = ?',
        <Object?>[legacyCloseId],
      );

      await runner.setUserVersion(25);
      final bool migrated = await runner.run(createSchema: () async {});

      expect(migrated, isTrue, reason: 'The supported v25 profile must run v26.');
      if (!migrated) return;
      expect(await runner.getUserVersion(), 27);
      expect(
        await db.executor.runSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'account_opening_balance_sources'",
          const <Object?>[],
        ),
        hasLength(1),
      );
      expect(await db.executor.runSelect('SELECT * FROM account_opening_balance_sources', const <Object?>[]), isEmpty);
      expect(
        await db.executor.runSelect(
          'SELECT id, name, kontoart, waehrung, unternehmen_id, saldo FROM konten WHERE id = ?',
          <Object?>[accountId],
        ),
        equals(accountsBefore),
      );
      expect(
        await db.executor.runSelect(
          'SELECT id, datum, konto_id, betrag, beleg_typ, beschreibung, is_opening_balance '
          'FROM journal WHERE konto_id = ?',
          <Object?>[accountId],
        ),
        equals(journalBefore),
      );
      expect(
        await db.executor.runSelect(
          'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, signatur '
          'FROM tagesabschluesse WHERE id = ?',
          <Object?>[legacyCloseId],
        ),
        equals(legacyCloseBefore),
      );
    });

    test('test_fresh_and_upgraded_v26_opening_source_schemas_match', () async {
      final Directory upgradedProfileDirectory = await Directory.systemTemp.createTemp(
        'openaccounting_cashbook_upgrade_test_',
      );
      final AppDatabase upgradedDb = AppDatabase.createTestDatabase(profileDir: upgradedProfileDirectory.path);
      try {
        await upgradedDb.ensureOpen();
        final MigrationRunner upgradedRunner = MigrationRunner(
          executor: upgradedDb.executor,
          profileDir: upgradedProfileDirectory.path,
        );
        await upgradedDb.executor.runCustom('DROP TABLE IF EXISTS account_opening_balance_sources');
        await upgradedRunner.setUserVersion(25);
        final bool migrated = await upgradedRunner.run(createSchema: () async {});

        expect(migrated, isTrue, reason: 'The v25 profile must be upgraded to v26.');
        expect(await upgradedRunner.getUserVersion(), 27);
        expect(await runner.getUserVersion(), 27);
        expect(await _openingSourceSchema(upgradedDb), equals(await _openingSourceSchema(db)));
      } finally {
        await upgradedDb.close();
        await upgradedProfileDirectory.delete(recursive: true);
      }
    });

    test('test_v26_schema_health_rejects_weakened_opening_effective_date_glob', () async {
      await _replaceOpeningSourceDdl(
        db,
        originalPattern: '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]',
        weakenedPattern: '[0-9]*',
      );

      final report = await runner.inspectSchemaHealth();

      expect(report.isHealthy, isFalse);
      expect(report.malformedTables, contains('account_opening_balance_sources'));
    });

    test('test_v26_schema_health_rejects_weakened_opening_currency_code_glob', () async {
      await _replaceOpeningSourceDdl(db, originalPattern: '[A-Z][A-Z][A-Z]', weakenedPattern: '[A-Z]*');

      final report = await runner.inspectSchemaHealth();

      expect(report.isHealthy, isFalse);
      expect(report.malformedTables, contains('account_opening_balance_sources'));
    });

    test('test_v26_schema_health_rejects_lowercase_only_opening_currency_code_glob', () async {
      await _replaceOpeningSourceDdl(db, originalPattern: '[A-Z][A-Z][A-Z]', weakenedPattern: '[a-z][a-z][a-z]');

      final report = await runner.inspectSchemaHealth();

      expect(report.isHealthy, isFalse);
      expect(report.malformedTables, contains('account_opening_balance_sources'));
    });

    test('test_v26_schema_health_rejects_partial_opening_source_unique_index', () async {
      final List<Map<String, Object?>> tableRows = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'account_opening_balance_sources'",
        const <Object?>[],
      );
      final String tableSql = tableRows.single['sql']! as String;
      final String tableSqlWithoutJournalUnique = tableSql.replaceFirst('UNIQUE (journal_id),', '');
      expect(tableSqlWithoutJournalUnique, isNot(tableSql));

      final List<Map<String, Object?>> triggerRows = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = 'account_opening_balance_sources'",
        const <Object?>[],
      );

      await db.executor.runCustom('DROP TABLE account_opening_balance_sources');
      await db.executor.runCustom(tableSqlWithoutJournalUnique);
      await db.executor.runCustom('''
CREATE UNIQUE INDEX test_partial_journal_id_unique
ON account_opening_balance_sources(journal_id)
WHERE journal_id IS NOT NULL
''');
      for (final Map<String, Object?> trigger in triggerRows) {
        await db.executor.runCustom(trigger['sql']! as String);
      }

      final List<Map<String, Object?>> indexes = await db.executor.runSelect(
        'PRAGMA index_list(account_opening_balance_sources)',
        const <Object?>[],
      );
      expect(
        indexes.any(
          (Map<String, Object?> index) => index['name'] == 'test_partial_journal_id_unique' && index['partial'] == 1,
        ),
        isTrue,
      );

      final SchemaHealthReport report = await runner.inspectSchemaHealth();

      expect(report.isHealthy, isFalse);
      expect(report.malformedTables, contains('account_opening_balance_sources'));
    });

    test('test_v26_schema_health_rejects_nocase_opening_source_unique_index', () async {
      await _replaceOpeningSourceDdl(
        db,
        originalPattern: 'UNIQUE (source_reference)',
        weakenedPattern: 'UNIQUE (source_reference COLLATE NOCASE)',
      );
      final List<Map<String, Object?>> tableRows = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'account_opening_balance_sources'",
        const <Object?>[],
      );
      expect(tableRows.single['sql'], contains('source_reference COLLATE NOCASE'));

      final SchemaHealthReport report = await runner.inspectSchemaHealth();

      expect(report.isHealthy, isFalse);
      expect(report.malformedTables, contains('account_opening_balance_sources'));
    });

    test('test_v26_schema_health_rejects_weakened_opening_source_immutability_triggers', () async {
      await db.executor.runCustom('DROP TRIGGER account_opening_balance_sources_no_update');
      await db.executor.runCustom('DROP TRIGGER account_opening_balance_sources_no_delete');
      await db.executor.runCustom('''
CREATE TRIGGER account_opening_balance_sources_no_update
BEFORE UPDATE ON account_opening_balance_sources
WHEN 0
BEGIN
  SELECT RAISE(ABORT, 'account opening sources are immutable');
END
''');
      await db.executor.runCustom('''
CREATE TRIGGER account_opening_balance_sources_no_delete
BEFORE DELETE ON account_opening_balance_sources
WHEN 0
BEGIN
  SELECT RAISE(ABORT, 'account opening sources are immutable');
END
''');

      final SchemaHealthReport report = await runner.inspectSchemaHealth();
      expect(report.isHealthy, isFalse);
      expect(report.malformedTables, contains('account_opening_balance_sources'));

      expect(await runner.run(createSchema: () async {}), isTrue);
      final Map<String, Object?> source = await _createSetupOpeningSource(db);
      final int sourceId = (source['id']! as num).toInt();
      await expectLater(
        db.executor.runUpdate('UPDATE account_opening_balance_sources SET amount_cents = ? WHERE id = ?', <Object?>[
          999,
          sourceId,
        ]),
        throwsA(isA<Object>()),
      );
      await expectLater(
        db.executor.runDelete('DELETE FROM account_opening_balance_sources WHERE id = ?', <Object?>[sourceId]),
        throwsA(isA<Object>()),
      );
      expect(
        await db.executor.runSelect('SELECT * FROM account_opening_balance_sources WHERE id = ?', <Object?>[sourceId]),
        <Map<String, Object?>>[source],
      );
    });

    test('test_v27_schema_health_rejects_legacy_signature_bypass', () async {
      await db.executor.runCustom('DROP TRIGGER tagesabschluesse_finalized_no_update');
      await db.executor.runCustom('DROP TRIGGER tagesabschluesse_finalized_no_delete');
      await db.executor.runCustom('''
CREATE TRIGGER tagesabschluesse_finalized_no_update
BEFORE UPDATE ON tagesabschluesse
WHEN OLD.integrity_hash IS NOT NULL OR OLD.signatur IS NOT NULL AND 0
BEGIN
  SELECT RAISE(ABORT, 'finalized daily close is immutable');
END
''');
      await db.executor.runCustom('''
CREATE TRIGGER tagesabschluesse_finalized_no_delete
BEFORE DELETE ON tagesabschluesse
WHEN OLD.integrity_hash IS NOT NULL OR OLD.signatur IS NOT NULL AND 0
BEGIN
  SELECT RAISE(ABORT, 'finalized daily close is immutable');
END
''');

      final SchemaHealthReport report = await runner.inspectSchemaHealth();
      expect(report.isHealthy, isFalse);
      expect(report.malformedTables, contains('tagesabschluesse'));

      expect(await runner.run(createSchema: () async {}), isTrue);
      final int legacyId = await db.executor.runInsert(
        'INSERT INTO tagesabschluesse (datum, betrag, signatur) VALUES (?, ?, ?)',
        <Object?>['2026-01-03', '30.00', 'legacy-signature'],
      );
      final List<Map<String, Object?>> legacyBefore = await db.executor.runSelect(
        'SELECT id, betrag, signatur FROM tagesabschluesse WHERE id = ?',
        <Object?>[legacyId],
      );
      await expectLater(
        db.executor.runUpdate('UPDATE tagesabschluesse SET betrag = ? WHERE id = ?', <Object?>['99.00', legacyId]),
        throwsA(isA<Object>()),
      );
      await expectLater(
        db.executor.runDelete('DELETE FROM tagesabschluesse WHERE id = ?', <Object?>[legacyId]),
        throwsA(isA<Object>()),
      );
      expect(
        await db.executor.runSelect('SELECT id, betrag, signatur FROM tagesabschluesse WHERE id = ?', <Object?>[
          legacyId,
        ]),
        legacyBefore,
      );
    });

    test('test_opening_source_insert_or_replace_preserves_original_when_recursive_triggers_are_off', () async {
      await db.executor.runCustom('PRAGMA recursive_triggers = OFF');
      expect(await db.executor.runSelect('PRAGMA recursive_triggers', const <Object?>[]), <Map<String, Object?>>[
        <String, Object?>{'recursive_triggers': 0},
      ]);

      final Map<String, Object?> source = await _createSetupOpeningSource(db);
      final int sourceId = (source['id']! as num).toInt();
      final List<Map<String, Object?>> sourceBefore = await db.executor.runSelect(
        'SELECT * FROM account_opening_balance_sources WHERE id = ?',
        <Object?>[sourceId],
      );
      expect(sourceBefore, hasLength(1));

      await expectLater(
        db.executor.runInsert(
          'INSERT OR REPLACE INTO account_opening_balance_sources '
          '(id, unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            sourceId,
            source['unternehmen_id'],
            source['konto_id'],
            source['journal_id'],
            '2026-02-03',
            99999,
            'EUR',
            '${source['source_reference']}:replacement',
          ],
        ),
        throwsA(isA<Object>()),
      );

      expect(
        await db.executor.runSelect('SELECT * FROM account_opening_balance_sources WHERE id = ?', <Object?>[sourceId]),
        sourceBefore,
        reason: 'REPLACE must not delete or rewrite source evidence when recursive triggers are disabled.',
      );
    });

    test('test_opening_source_case_only_insert_or_replace_preserves_original', () async {
      await _replaceOpeningSourceDdl(
        db,
        originalPattern: 'UNIQUE (source_reference)',
        weakenedPattern: 'UNIQUE (source_reference COLLATE NOCASE)',
      );
      await db.executor.runCustom('PRAGMA recursive_triggers = OFF');
      expect(await db.executor.runSelect('PRAGMA recursive_triggers', const <Object?>[]), <Map<String, Object?>>[
        <String, Object?>{'recursive_triggers': 0},
      ]);

      final Map<String, Object?> source = await _createSetupOpeningSource(db);
      final int sourceId = (source['id']! as num).toInt();
      final String sourceReference = source['source_reference']! as String;
      final String caseVariant = sourceReference == sourceReference.toLowerCase()
          ? sourceReference.toUpperCase()
          : sourceReference.toLowerCase();
      expect(caseVariant, isNot(sourceReference));

      final int companyId = (source['unternehmen_id']! as num).toInt();
      final int otherAccountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        <Object?>['Case-only replacement account', 'Kasse', 'EUR', companyId, '0.00'],
      );
      final int otherJournalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, konto_id, betrag, beleg_typ, beschreibung) VALUES (?, ?, ?, ?, ?)',
        <Object?>['2026-02-03', otherAccountId, '0.00', 'eroeffnung', 'Case-only replacement'],
      );
      final List<Map<String, Object?>> sourceBefore = await db.executor.runSelect(
        'SELECT * FROM account_opening_balance_sources WHERE id = ?',
        <Object?>[sourceId],
      );
      expect(sourceBefore, hasLength(1));

      await expectLater(
        db.executor.runInsert(
          'INSERT OR REPLACE INTO account_opening_balance_sources '
          '(unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>[companyId, otherAccountId, otherJournalId, '2026-02-03', 99999, 'EUR', caseVariant],
        ),
        throwsA(isA<Object>()),
      );

      expect(
        await db.executor.runSelect('SELECT * FROM account_opening_balance_sources WHERE id = ?', <Object?>[sourceId]),
        sourceBefore,
        reason: 'A case-only REPLACE conflict must preserve the original evidence.',
      );
    });

    test('test_finalized_close_insert_or_replace_preserves_original_when_recursive_triggers_are_off', () async {
      await db.executor.runCustom('PRAGMA recursive_triggers = OFF');
      expect(await db.executor.runSelect('PRAGMA recursive_triggers', const <Object?>[]), <Map<String, Object?>>[
        <String, Object?>{'recursive_triggers': 0},
      ]);

      final int closeId = await db.executor.runInsert(
        'INSERT INTO tagesabschluesse '
        '(datum, betrag, kassenbestand, differenz, signatur, zaehlung_json, integrity_hash) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          '2026-02-03',
          '125.00',
          '125.00',
          '0.00',
          'signature:original',
          '{"counts":[{"denomination":"5.00","quantity":25}]}',
          'sha256:original',
        ],
      );
      final List<Map<String, Object?>> closeBefore = await db.executor.runSelect(
        'SELECT * FROM tagesabschluesse WHERE id = ?',
        <Object?>[closeId],
      );
      expect(closeBefore, hasLength(1));

      await expectLater(
        db.executor.runInsert(
          'INSERT OR REPLACE INTO tagesabschluesse '
          '(id, datum, betrag, kassenbestand, differenz, signatur, zaehlung_json, integrity_hash) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            closeId,
            '2026-02-04',
            '999.00',
            '0.00',
            '-999.00',
            'signature:replacement',
            '{"counts":[{"denomination":"20.00","quantity":50}]}',
            'sha256:replacement',
          ],
        ),
        throwsA(isA<Object>()),
      );

      expect(
        await db.executor.runSelect('SELECT * FROM tagesabschluesse WHERE id = ?', <Object?>[closeId]),
        closeBefore,
        reason: 'REPLACE must not delete or rewrite finalized close evidence when recursive triggers are disabled.',
      );
    });

    test('test_fresh_and_upgraded_v27_close_schemas_match', () async {
      final Map<String, Object?> freshSchema = await _dailyCloseEvidenceSchema(db);
      final Directory upgradedProfileDirectory = await Directory.systemTemp.createTemp(
        'openaccounting_close_evidence_upgrade_test_',
      );
      final AppDatabase upgradedDb = AppDatabase.createTestDatabase(profileDir: upgradedProfileDirectory.path);
      try {
        await upgradedDb.ensureOpen();
        final MigrationRunner upgradedRunner = MigrationRunner(
          executor: upgradedDb.executor,
          profileDir: upgradedProfileDirectory.path,
        );
        await _removeDailyCloseEvidence(upgradedDb);
        await upgradedRunner.setUserVersion(26);
        final int legacyCloseId = await upgradedDb.executor.runInsert(
          'INSERT INTO tagesabschluesse (datum, betrag, kassenbestand, differenz, signatur) VALUES (?, ?, ?, ?, ?)',
          <Object?>['2025-01-01', '100.00', '125.00', '25.00', 'legacy-signature'],
        );
        const String legacyCloseProjection =
            'SELECT id, datum, betrag, kassenbestand, differenz, signatur, erstellungsdatum '
            'FROM tagesabschluesse WHERE id = ?';
        final List<Map<String, Object?>> legacyCloseBefore = await upgradedDb.executor.runSelect(
          legacyCloseProjection,
          <Object?>[legacyCloseId],
        );
        final List<String> tableNamesBefore = await _applicationTableNames(upgradedDb);

        final bool migrated = await upgradedRunner.run(createSchema: () async {});

        expect(migrated, isTrue, reason: 'A v26 profile must be upgraded to v27.');
        expect(await upgradedRunner.getUserVersion(), 27);
        expect(await _applicationTableNames(upgradedDb), tableNamesBefore);
        expect(await upgradedDb.executor.runSelect(legacyCloseProjection, <Object?>[legacyCloseId]), legacyCloseBefore);
        expect(await _dailyCloseEvidenceSchema(upgradedDb), freshSchema);
        await _expectDailyCloseRowsToBeImmutable(db);
        await _expectDailyCloseRowsToBeImmutable(upgradedDb);
      } finally {
        await upgradedDb.close();
        await upgradedProfileDirectory.delete(recursive: true);
      }
    });

    test('test_opening_source_identity_is_unique_and_immutable', () async {
      final Map<String, Object?> source = await _createSetupOpeningSource(db);
      final int companyId = (source['unternehmen_id']! as num).toInt();
      final int accountId = (source['konto_id']! as num).toInt();
      final int journalId = (source['journal_id']! as num).toInt();
      final String sourceReference = source['source_reference']! as String;
      final int otherAccountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        <Object?>['Second cash account', 'Kasse', 'EUR', companyId, '0.00'],
      );
      final int otherJournalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, konto_id, betrag, beleg_typ, beschreibung) VALUES (?, ?, ?, ?, ?)',
        <Object?>['2026-01-01', otherAccountId, '0.00', 'eroeffnung', 'Second opening'],
      );
      final int otherSourceId = await _insertOpeningSource(
        db,
        companyId: companyId,
        accountId: otherAccountId,
        journalId: otherJournalId,
        sourceReference: '$sourceReference:second-account',
      );
      final int thirdAccountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        <Object?>['Third cash account', 'Kasse', 'EUR', companyId, '0.00'],
      );
      final int thirdJournalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, konto_id, betrag, beleg_typ, beschreibung) VALUES (?, ?, ?, ?, ?)',
        <Object?>['2026-01-01', thirdAccountId, '0.00', 'eroeffnung', 'Third opening'],
      );

      expect(
        await db.executor.runSelect('SELECT id FROM account_opening_balance_sources WHERE id IN (?, ?)', <Object?>[
          source['id'],
          otherSourceId,
        ]),
        hasLength(2),
      );

      await expectLater(
        _insertOpeningSource(
          db,
          companyId: companyId,
          accountId: accountId,
          journalId: thirdJournalId,
          sourceReference: '$sourceReference:duplicate-account',
        ),
        throwsA(isA<Object>()),
      );
      await expectLater(
        _insertOpeningSource(
          db,
          companyId: companyId,
          accountId: thirdAccountId,
          journalId: journalId,
          sourceReference: '$sourceReference:duplicate-journal',
        ),
        throwsA(isA<Object>()),
      );
      await expectLater(
        _insertOpeningSource(
          db,
          companyId: companyId,
          accountId: thirdAccountId,
          journalId: thirdJournalId,
          sourceReference: sourceReference,
        ),
        throwsA(isA<Object>()),
      );
      await expectLater(
        db.executor.runUpdate('UPDATE account_opening_balance_sources SET amount_cents = ? WHERE id = ?', <Object?>[
          999,
          source['id'],
        ]),
        throwsA(isA<Object>()),
      );
      await expectLater(
        db.executor.runDelete('DELETE FROM account_opening_balance_sources WHERE id = ?', <Object?>[source['id']]),
        throwsA(isA<Object>()),
      );

      expect(
        await db.executor.runSelect('SELECT * FROM account_opening_balance_sources WHERE id = ?', <Object?>[
          source['id'],
        ]),
        equals(<Map<String, Object?>>[source]),
      );
      expect(
        await db.executor.runSelect('SELECT * FROM account_opening_balance_sources WHERE id = ?', <Object?>[
          otherSourceId,
        ]),
        hasLength(1),
      );
    });
  });
}

Future<void> _replaceOpeningSourceDdl(
  AppDatabase db, {
  required String originalPattern,
  required String weakenedPattern,
}) async {
  final List<Map<String, Object?>> tableRows = await db.executor.runSelect(
    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'account_opening_balance_sources'",
    const <Object?>[],
  );
  expect(tableRows, hasLength(1));
  final String tableSql = tableRows.single['sql']! as String;
  final String weakenedTableSql = tableSql.replaceFirst(originalPattern, weakenedPattern);
  expect(weakenedTableSql, isNot(tableSql), reason: 'The test fixture must mutate the declared table DDL.');

  final List<Map<String, Object?>> triggers = await db.executor.runSelect(
    "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = 'account_opening_balance_sources'",
    const <Object?>[],
  );
  expect(triggers, hasLength(3));

  await db.executor.runCustom('DROP TABLE account_opening_balance_sources');
  await db.executor.runCustom(weakenedTableSql);
  for (final Map<String, Object?> trigger in triggers) {
    await db.executor.runCustom(trigger['sql']! as String);
  }
}

String _expectOpeningSourceTableMissing(File databaseFile, {required int expectedVersion}) {
  final sqlite3.Database rawDatabase = sqlite3.sqlite3.open(databaseFile.path);
  try {
    final Map<String, Object?> mainDatabase = rawDatabase
        .select('PRAGMA database_list')
        .singleWhere((Map<String, Object?> row) => row['name'] == 'main');
    final String actualPath = mainDatabase['file']?.toString() ?? '';
    expect(actualPath, databaseFile.absolute.path);
    expect(
      rawDatabase.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'account_opening_balance_sources'",
      ),
      isEmpty,
    );
    expect(rawDatabase.select('PRAGMA user_version').single['user_version'], expectedVersion);
    return actualPath;
  } finally {
    rawDatabase.close();
  }
}

Future<({String path, int version, List<Map<String, Object?>> sourceTables})> _openingSourceDatabaseState(
  AppDatabase db,
) async {
  final List<Map<String, Object?>> databaseList = await db.executor.runSelect(
    'PRAGMA database_list',
    const <Object?>[],
  );
  final Map<String, Object?> mainDatabase = databaseList.singleWhere(
    (Map<String, Object?> row) => row['name'] == 'main',
  );
  final List<Map<String, Object?>> versionRows = await db.executor.runSelect('PRAGMA user_version', const <Object?>[]);
  final List<Map<String, Object?>> sourceTables = await db.executor.runSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'account_opening_balance_sources'",
    const <Object?>[],
  );
  return (
    path: mainDatabase['file']?.toString() ?? '',
    version: versionRows.single['user_version']! as int,
    sourceTables: sourceTables,
  );
}

Future<Map<String, Object?>> _createSetupOpeningSource(AppDatabase db) async {
  final SetupRepository repository = SetupRepository(db.executor);
  await repository.saveUnternehmen(name: 'Cashbook Source Test GmbH');
  await repository.runInTransaction<void>(
    (SetupRepository transactionRepository) => transactionRepository.ensureKassenKonto(betrag: '125.00'),
  );
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'SELECT id, unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference '
    'FROM account_opening_balance_sources',
    const <Object?>[],
  );
  expect(rows, hasLength(1));
  return rows.single;
}

Future<int> _insertOpeningSource(
  AppDatabase db, {
  required int companyId,
  required int accountId,
  required int journalId,
  required String sourceReference,
}) {
  return db.executor.runInsert(
    'INSERT INTO account_opening_balance_sources '
    '(unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[companyId, accountId, journalId, '2026-01-01', 0, 'EUR', sourceReference],
  );
}

Future<Map<String, Object?>> _openingSourceSchema(AppDatabase db) async {
  final List<Map<String, Object?>> columns = await db.executor.runSelect(
    'PRAGMA table_info(account_opening_balance_sources)',
    const <Object?>[],
  );
  final List<Map<String, Object?>> foreignKeys = await db.executor.runSelect(
    'PRAGMA foreign_key_list(account_opening_balance_sources)',
    const <Object?>[],
  );
  final List<Map<String, Object?>> indexes = await db.executor.runSelect(
    'PRAGMA index_list(account_opening_balance_sources)',
    const <Object?>[],
  );
  final List<String> uniqueColumnSets = <String>[];
  for (final Map<String, Object?> index in indexes) {
    if ((index['unique'] as num?)?.toInt() != 1) continue;
    final String name = (index['name']! as String).replaceAll('"', '""');
    final List<Map<String, Object?>> indexedColumns = await db.executor.runSelect(
      'PRAGMA index_info("$name")',
      const <Object?>[],
    );
    uniqueColumnSets.add(indexedColumns.map((Map<String, Object?> column) => column['name'].toString()).join(','));
  }
  uniqueColumnSets.sort();
  final List<Map<String, Object?>> triggers = await db.executor.runSelect(
    "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ? ORDER BY name",
    const <Object?>['account_opening_balance_sources'],
  );
  final List<Map<String, Object?>> tableDefinition = await db.executor.runSelect(
    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
    const <Object?>['account_opening_balance_sources'],
  );

  const Map<String, String> expectedColumnTypes = <String, String>{
    'id': 'INTEGER',
    'unternehmen_id': 'INTEGER',
    'konto_id': 'INTEGER',
    'journal_id': 'INTEGER',
    'effective_date': 'TEXT',
    'amount_cents': 'INTEGER',
    'currency_code': 'TEXT',
    'source_reference': 'TEXT',
  };
  expect(columns, hasLength(expectedColumnTypes.length));
  for (final MapEntry<String, String> expected in expectedColumnTypes.entries) {
    final Map<String, Object?>? column = columns.cast<Map<String, Object?>?>().firstWhere(
      (Map<String, Object?>? candidate) => candidate?['name'] == expected.key,
      orElse: () => null,
    );
    expect(column, isNotNull, reason: 'Missing ${expected.key}.');
    expect(column!['type'].toString().toUpperCase(), expected.value);
    expect(column['pk'], expected.key == 'id' ? 1 : 0);
    if (expected.key != 'id') expect(column['notnull'], 1);
  }
  expect(tableDefinition, hasLength(1));
  expect(foreignKeys, hasLength(3));
  expect(
    <String>{
      for (final Map<String, Object?> foreignKey in foreignKeys)
        '${foreignKey['table']}:${foreignKey['from']}:${foreignKey['to']}:${foreignKey['on_delete']}',
    },
    <String>{'unternehmen:unternehmen_id:id:RESTRICT', 'konten:konto_id:id:RESTRICT', 'journal:journal_id:id:RESTRICT'},
  );
  expect(uniqueColumnSets, <String>['journal_id', 'source_reference', 'unternehmen_id,konto_id']);
  expect(
    <String>{for (final Map<String, Object?> trigger in triggers) trigger['name'].toString()},
    <String>{
      'account_opening_balance_sources_no_delete',
      'account_opening_balance_sources_no_replace',
      'account_opening_balance_sources_no_update',
    },
  );
  final String normalizedTableSql = tableDefinition.single['sql'].toString().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  expect(
    normalizedTableSql,
    contains("effective_date text not null check (effective_date glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')"),
  );
  expect(normalizedTableSql, contains("check (typeof(amount_cents) = 'integer' and amount_cents >= 0)"));
  expect(normalizedTableSql, contains("currency_code text not null check (currency_code glob '[a-z][a-z][a-z]')"));
  expect(normalizedTableSql, contains('check (length(trim(source_reference)) > 0)'));
  return <String, Object?>{
    'columns': columns,
    'foreignKeys': foreignKeys,
    'uniqueColumnSets': uniqueColumnSets,
    'triggers': triggers,
    'tableSql': tableDefinition.single['sql'],
  };
}

Future<Map<String, Object?>> _dailyCloseEvidenceSchema(AppDatabase db) async {
  final List<Map<String, Object?>> columns = await db.executor.runSelect(
    'PRAGMA table_info(tagesabschluesse)',
    const <Object?>[],
  );
  const Map<String, String> evidenceColumnTypes = <String, String>{'zaehlung_json': 'TEXT', 'integrity_hash': 'TEXT'};
  for (final MapEntry<String, String> expected in evidenceColumnTypes.entries) {
    final Map<String, Object?>? column = columns.cast<Map<String, Object?>?>().firstWhere(
      (Map<String, Object?>? candidate) => candidate?['name'] == expected.key,
      orElse: () => null,
    );
    expect(column, isNotNull, reason: 'Missing required evidence column.');
    expect(column!['type'].toString().toUpperCase(), expected.value);
    expect(column['notnull'], 0, reason: 'Evidence columns must remain nullable.');
  }

  final List<Map<String, Object?>> triggers = await db.executor.runSelect(
    "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ? ORDER BY name",
    const <Object?>['tagesabschluesse'],
  );
  expect(triggers, hasLength(3));
  expect(
    <String>{for (final Map<String, Object?> trigger in triggers) trigger['name'].toString()},
    <String>{
      'tagesabschluesse_finalized_no_delete',
      'tagesabschluesse_finalized_no_replace',
      'tagesabschluesse_finalized_no_update',
    },
  );
  return <String, Object?>{
    'columns': <Map<String, Object?>>[
      for (final Map<String, Object?> column in columns)
        <String, Object?>{
          'name': column['name'],
          'type': column['type'],
          'notnull': column['notnull'],
          'pk': column['pk'],
          'dflt_value': column['dflt_value'],
        },
    ],
    'triggers': <Map<String, Object?>>[
      for (final Map<String, Object?> trigger in triggers)
        <String, Object?>{
          'name': trigger['name'],
          'sql': trigger['sql'].toString().replaceAll(RegExp(r'\s+'), ' ').trim(),
        },
    ],
  };
}

Future<List<String>> _applicationTableNames(AppDatabase db) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    const <Object?>[],
  );
  return <String>[for (final Map<String, Object?> row in rows) row['name'].toString()];
}

Future<void> _removeDailyCloseEvidence(AppDatabase db) async {
  await db.executor.runCustom('DROP TRIGGER IF EXISTS tagesabschluesse_finalized_no_update');
  await db.executor.runCustom('DROP TRIGGER IF EXISTS tagesabschluesse_finalized_no_delete');
  await db.executor.runCustom('DROP TRIGGER IF EXISTS tagesabschluesse_finalized_no_replace');
  final List<Map<String, Object?>> columns = await db.executor.runSelect(
    'PRAGMA table_info(tagesabschluesse)',
    const <Object?>[],
  );
  for (final String name in const <String>['zaehlung_json', 'integrity_hash']) {
    if (columns.any((Map<String, Object?> column) => column['name'] == name)) {
      await db.executor.runCustom('ALTER TABLE tagesabschluesse DROP COLUMN $name');
    }
  }
}

Future<void> _expectDailyCloseRowsToBeImmutable(AppDatabase db) async {
  final int legacyId = await db.executor.runInsert(
    'INSERT INTO tagesabschluesse (datum, betrag, signatur) VALUES (?, ?, ?)',
    <Object?>['2026-01-01', '10.00', 'legacy-signature'],
  );
  final int integrityId = await db.executor.runInsert(
    'INSERT INTO tagesabschluesse (datum, betrag, integrity_hash) VALUES (?, ?, ?)',
    <Object?>['2026-01-02', '20.00', 'sha256:test-digest'],
  );

  for (final int id in <int>[legacyId, integrityId]) {
    await expectLater(
      db.executor.runUpdate('UPDATE tagesabschluesse SET betrag = ? WHERE id = ?', <Object?>['99.00', id]),
      throwsA(isA<Object>()),
    );
    await expectLater(
      db.executor.runDelete('DELETE FROM tagesabschluesse WHERE id = ?', <Object?>[id]),
      throwsA(isA<Object>()),
    );
    expect(await db.executor.runSelect('SELECT id FROM tagesabschluesse WHERE id = ?', <Object?>[id]), hasLength(1));
  }
}
