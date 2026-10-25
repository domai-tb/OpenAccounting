import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';

void main() {
  group('mileage lifecycle migration', () {
    late AppDatabase db;
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_mileage_migration_');
      db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
      await profileDirectory.delete(recursive: true);
    });

    test('fresh schema installs structured eligibility and lifecycle guards', () async {
      final List<Map<String, Object?>> columns = await db.executor.runSelect(
        'PRAGMA table_info(mileage_trips)',
        const <Object?>[],
      );
      final Set<String> names = <String>{for (final Map<String, Object?> row in columns) row['name'].toString()};
      expect(names, containsAll(<String>{'trip_kind', 'vehicle_source', 'vehicle_class'}));

      final List<Map<String, Object?>> triggers = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'trg_mileage_%'",
        const <Object?>[],
      );
      expect(triggers, hasLength(16));
      expect(
        await MigrationRunner(executor: db.executor, profileDir: profileDirectory.path).getUserVersion(),
        MigrationRunner.currentVersion,
      );
    });

    test('v30 adds nullable applied_business_date on fresh and upgraded schemas without backfill', () async {
      List<Map<String, Object?>> columns = await db.executor.runSelect(
        'PRAGMA table_info(mileage_trip_corrections)',
        const <Object?>[],
      );
      expect(MigrationRunner.currentVersion, 30);
      expect(columns.map((Map<String, Object?> row) => row['name']), contains('applied_business_date'));
      final Map<String, Object?> businessDateColumn = columns.singleWhere(
        (Map<String, Object?> row) => row['name'] == 'applied_business_date',
      );
      expect((businessDateColumn['notnull']! as num).toInt(), 0);

      await db.executor.runCustom('PRAGMA foreign_keys = OFF');
      await db.executor.runCustom('DROP TRIGGER IF EXISTS trg_mileage_correction_insert_draft');
      await db.executor.runCustom('DROP TRIGGER IF EXISTS trg_mileage_correction_update_guard');
      await db.executor.runInsert(
        'INSERT INTO mileage_trip_corrections '
        '(id, trip_id, kind, replacement_trip_id, reason, state, accounting_correction_id, created_at, applied_at, '
        'applied_business_date) VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, NULL)',
        const <Object?>[
          'legacy-applied-correction',
          'legacy-source-trip',
          'void',
          'Legacy applied correction',
          'applied',
          'legacy-applied-correction',
          '2025-01-01T00:00:00.000Z',
          '2026-01-01T00:30:00.000Z',
        ],
      );
      await db.executor.runCustom('ALTER TABLE mileage_trip_corrections DROP COLUMN applied_business_date');
      await db.executor.runCustom('PRAGMA user_version = 29');

      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      expect(await runner.run(createSchema: () async {}), isTrue);
      expect(await runner.getUserVersion(), 30);
      columns = await db.executor.runSelect('PRAGMA table_info(mileage_trip_corrections)', const <Object?>[]);
      expect(columns.map((Map<String, Object?> row) => row['name']), contains('applied_business_date'));
      final List<Map<String, Object?>> legacyRows = await db.executor.runSelect(
        'SELECT state, applied_at, applied_business_date FROM mileage_trip_corrections WHERE id = ?',
        const <Object?>['legacy-applied-correction'],
      );
      expect(legacyRows.single, <String, Object?>{
        'state': 'applied',
        'applied_at': '2026-01-01T00:30:00.000Z',
        'applied_business_date': null,
      });
    });

    test('v22 migration demotes unknown calculated facts and preserves posted facts', () async {
      final List<Map<String, Object?>> existingTriggers = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'trg_mileage_%'",
        const <Object?>[],
      );
      for (final Map<String, Object?> trigger in existingTriggers) {
        final String name = trigger['name'].toString();
        await db.executor.runCustom('DROP TRIGGER "$name"');
      }
      await db.executor.runCustom('ALTER TABLE mileage_trips DROP COLUMN vehicle_class');
      await db.executor.runCustom('ALTER TABLE mileage_trips DROP COLUMN vehicle_source');
      await db.executor.runCustom('ALTER TABLE mileage_trips DROP COLUMN trip_kind');
      await db.executor.runCustom('''
INSERT INTO mileage_trips (
  id, trip_date, purpose, business_context, distance_hundredths_km, state,
  policy_id, policy_source, policy_version, policy_effective_from, policy_effective_to,
  calculated_amount, calculated_at, posting_event_id, created_at, updated_at
) VALUES (
  'legacy-posted-trip', '2026-03-14', 'Kundenbesuch', 'Altbestand', 4525, 'posted',
  'old-policy', 'old-source', 'old-version', '2025-01-01', '2026-12-31',
  13.58, '2026-03-14T12:00:00Z', 'old-event', '2026-03-14T12:00:00Z', '2026-03-14T12:00:00Z'
)''');
      await db.executor.runCustom('''
INSERT INTO mileage_trips (
  id, trip_date, purpose, business_context, distance_hundredths_km, state,
  policy_id, policy_source, policy_version, policy_effective_from, policy_effective_to,
  calculated_amount, calculated_at, posting_event_id, created_at, updated_at
) VALUES (
  'legacy-calculated-trip', '2026-03-15', 'Kundenbesuch', 'Projekt Alt', 1250, 'calculated',
  'legacy-policy', 'legacy-source', 'legacy-version', '2025-01-01', '2026-12-31',
  3.75, '2026-03-15T12:00:00Z', NULL, '2026-03-15T12:00:00Z', '2026-03-15T12:00:00Z'
)''');
      await db.executor.runCustom('PRAGMA user_version = 22');

      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      expect(await runner.run(createSchema: () async {}), isTrue);

      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        const <Object?>['legacy-posted-trip'],
      );
      final Map<String, Object?> migrated = rows.single;
      expect(migrated['trip_kind'], 'unknown');
      expect(migrated['vehicle_source'], 'unknown');
      expect(migrated['vehicle_class'], 'unknown');
      expect(migrated['distance_hundredths_km'], 4525);
      expect(migrated['state'], 'posted');
      expect(migrated['policy_id'], 'old-policy');
      expect(migrated['calculated_amount'], 13.58);
      expect(migrated['posting_event_id'], 'old-event');

      final List<Map<String, Object?>> calculatedRows = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        const <Object?>['legacy-calculated-trip'],
      );
      final Map<String, Object?> migratedCalculated = calculatedRows.single;
      expect(migratedCalculated['trip_date'], '2026-03-15');
      expect(migratedCalculated['purpose'], 'Kundenbesuch');
      expect(migratedCalculated['business_context'], 'Projekt Alt');
      expect(migratedCalculated['distance_hundredths_km'], 1250);
      expect(migratedCalculated['trip_kind'], 'unknown');
      expect(migratedCalculated['vehicle_source'], 'unknown');
      expect(migratedCalculated['vehicle_class'], 'unknown');
      expect(migratedCalculated['state'], 'unresolved');
      expect(migratedCalculated['policy_id'], isNull);
      expect(migratedCalculated['policy_source'], isNull);
      expect(migratedCalculated['policy_version'], isNull);
      expect(migratedCalculated['policy_effective_from'], isNull);
      expect(migratedCalculated['policy_effective_to'], isNull);
      expect(migratedCalculated['calculated_amount'], isNull);
      expect(migratedCalculated['calculated_at'], isNull);
      expect(migratedCalculated['posting_event_id'], isNull);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
    });

    test('v23 correction demotes unknown calculations and refreshes snapshot guards', () async {
      final List<Map<String, Object?>> existingTriggers = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'trg_mileage_%'",
        const <Object?>[],
      );
      for (final Map<String, Object?> trigger in existingTriggers) {
        await db.executor.runCustom('DROP TRIGGER "${trigger['name']}"');
      }
      await db.executor.runCustom('''
INSERT INTO mileage_trips (
  id, trip_date, purpose, business_context, trip_kind, vehicle_source, vehicle_class,
  distance_hundredths_km, state, policy_id, policy_source, policy_version,
  policy_effective_from, policy_effective_to, calculated_amount, calculated_at,
  posting_event_id, created_at, updated_at
) VALUES (
  'v23-calculated-trip', '2026-03-14', 'Kundenbesuch', 'V23 Altbestand', 'unknown', 'unknown', 'unknown',
  1000, 'calculated', 'DE-private-business-travel/1',
  'EStG-9-1-3-4a;BRKG-5-1-2;BMF-LStH-2026-A25-III-37;EÜR-2025-71',
  '1', '2025-01-01', '2026-12-31', 3.00, '2026-03-14T12:00:00Z', NULL,
  '2026-03-14T12:00:00Z', '2026-03-14T12:00:00Z'
)''');
      await db.executor.runCustom('PRAGMA user_version = 23');

      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      expect(await runner.run(createSchema: () async {}), isTrue);

      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        const <Object?>['v23-calculated-trip'],
      );
      final Map<String, Object?> migrated = rows.single;
      expect(migrated['trip_date'], '2026-03-14');
      expect(migrated['purpose'], 'Kundenbesuch');
      expect(migrated['business_context'], 'V23 Altbestand');
      expect(migrated['distance_hundredths_km'], 1000);
      expect(migrated['trip_kind'], 'unknown');
      expect(migrated['vehicle_source'], 'unknown');
      expect(migrated['vehicle_class'], 'unknown');
      expect(migrated['state'], 'unresolved');
      expect(migrated['policy_id'], isNull);
      expect(migrated['policy_source'], isNull);
      expect(migrated['policy_version'], isNull);
      expect(migrated['policy_effective_from'], isNull);
      expect(migrated['policy_effective_to'], isNull);
      expect(migrated['calculated_amount'], isNull);
      expect(migrated['calculated_at'], isNull);
      expect(migrated['posting_event_id'], isNull);

      final List<Map<String, Object?>> triggers = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = 'trg_mileage_trip_calculation_guard'",
        const <Object?>[],
      );
      final String triggerSql = triggers.single['sql']! as String;
      for (final String field in <String>[
        'policy_id',
        'policy_source',
        'policy_version',
        'policy_effective_from',
        'policy_effective_to',
        'calculated_amount',
        'calculated_at',
      ]) {
        expect(triggerSql, contains('NEW.$field IS NULL'));
      }
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
    });

    test('v24 upgrade adds mileage mapping snapshots and preserves existing ledger rows', () async {
      final int accountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart) VALUES (?, ?)',
        const <Object?>['Existing Sachkonto', 'Sachkonto'],
      );
      final int categoryId = await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, euer_zeile) VALUES (?, ?)',
        const <Object?>['Existing legacy category', 12],
      );
      final int journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) '
        'VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2025-01-02', 'Existing legacy journal row', categoryId, '10.00', 'Einnahme'],
      );
      await db.executor.runCustom('''
INSERT INTO mileage_trips (
  id, trip_date, purpose, business_context, trip_kind, vehicle_source, vehicle_class,
  distance_hundredths_km, state, created_at, updated_at
) VALUES (
  'v24-existing-trip', '2025-01-03', 'Existing trip', 'Existing project',
  'business_trip', 'private', 'kraftwagen', 1000, 'unresolved',
  '2025-01-03T12:00:00Z', '2025-01-03T12:00:00Z'
)''');

      await db.executor.runCustom('DROP TRIGGER IF EXISTS trg_mileage_trip_posting_guard');
      await db.executor.runCustom('DROP TRIGGER IF EXISTS trg_mileage_correction_update_guard');
      await db.executor.runCustom('DROP TABLE mileage_posting_account_mapping');
      await db.executor.runCustom('DROP TABLE IF EXISTS mileage_posting_period_closures');
      const List<String> v25Columns = <String>[
        'mileage_role_snapshot',
        'mileage_kategorie_id_snapshot',
        'mileage_kategorie_name_snapshot',
        'mileage_kategorie_art_snapshot',
        'mileage_euer_zeile_snapshot',
        'mileage_kategorie_skr03_snapshot',
        'mileage_kategorie_skr04_snapshot',
        'mileage_mapping_status_snapshot',
        'mileage_mapping_source_reference_snapshot',
        'mileage_mapping_source_version_snapshot',
        'mileage_mapping_history_id_snapshot',
      ];
      const Set<String> previousPrototypeColumns = <String>{
        'mileage_event_id_snapshot',
        'mileage_payload_snapshot',
        'mileage_account_id_snapshot',
        'mileage_category_id_snapshot',
        'mileage_category_label_snapshot',
        'mileage_category_art_snapshot',
        'mileage_euer_line_snapshot',
        'mileage_konto_skr03_snapshot',
        'mileage_konto_skr04_snapshot',
        'mileage_mapping_reviewed_at_snapshot',
      };
      final List<Map<String, Object?>> existingJournalColumns = await db.executor.runSelect(
        'PRAGMA table_info(journal)',
        const <Object?>[],
      );
      final Set<String> existingJournalColumnNames = <String>{
        for (final Map<String, Object?> row in existingJournalColumns) row['name'].toString(),
      };
      for (final String column in <String>{...v25Columns, ...previousPrototypeColumns}) {
        if (existingJournalColumnNames.contains(column)) {
          await db.executor.runCustom('ALTER TABLE journal DROP COLUMN $column');
        }
      }
      await db.executor.runCustom('PRAGMA user_version = 24');

      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      expect(await runner.run(createSchema: () async {}), isTrue);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);

      final List<Map<String, Object?>> accountRows = await db.executor.runSelect(
        'SELECT id, name, kontoart FROM konten WHERE id = ?',
        <Object?>[accountId],
      );
      expect(accountRows.single, <String, Object?>{
        'id': accountId,
        'name': 'Existing Sachkonto',
        'kontoart': 'Sachkonto',
      });
      final List<Map<String, Object?>> journalRows = await db.executor.runSelect(
        'SELECT id, datum, beschreibung, kategorie_id, betrag, beleg_typ FROM journal WHERE id = ?',
        <Object?>[journalId],
      );
      expect(journalRows.single['datum'], '2025-01-02');
      expect(journalRows.single['beschreibung'], 'Existing legacy journal row');
      expect(journalRows.single['kategorie_id'], categoryId);
      expect(journalRows.single['betrag'], 10.0);
      expect(journalRows.single['beleg_typ'], 'Einnahme');
      final List<Map<String, Object?>> tripRows = await db.executor.runSelect(
        'SELECT id, state, purpose FROM mileage_trips WHERE id = ?',
        const <Object?>['v24-existing-trip'],
      );
      expect(tripRows.single, <String, Object?>{
        'id': 'v24-existing-trip',
        'state': 'unresolved',
        'purpose': 'Existing trip',
      });

      final List<Map<String, Object?>> mappingTable = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'mileage_posting_account_mapping'",
        const <Object?>[],
      );
      expect(mappingTable, hasLength(1));
      final List<Map<String, Object?>> mappingRows = await db.executor.runSelect(
        'SELECT role FROM mileage_posting_account_mapping',
        const <Object?>[],
      );
      expect(mappingRows, isEmpty);
      final List<Map<String, Object?>> journalColumns = await db.executor.runSelect(
        'PRAGMA table_info(journal)',
        const <Object?>[],
      );
      final Set<String> journalColumnNames = <String>{
        for (final Map<String, Object?> row in journalColumns) row['name'].toString(),
      };
      expect(journalColumnNames, containsAll(v25Columns));
      expect(
        journalColumnNames.intersection(<String>{
          'mileage_event_id_snapshot',
          'mileage_payload_snapshot',
          'mileage_account_id_snapshot',
          'mileage_category_id_snapshot',
          'mileage_category_label_snapshot',
          'mileage_category_art_snapshot',
          'mileage_euer_line_snapshot',
          'mileage_konto_skr03_snapshot',
          'mileage_konto_skr04_snapshot',
          'mileage_mapping_reviewed_at_snapshot',
        }),
        isEmpty,
      );
      final List<Map<String, Object?>> closureColumns = await db.executor.runSelect(
        'PRAGMA table_info(mileage_posting_period_closures)',
        const <Object?>[],
      );
      expect(<String>{
        for (final Map<String, Object?> row in closureColumns) row['name'].toString(),
      }, containsAll(<String>{'id', 'closed_from', 'closed_through', 'closed_at'}));
      final List<Map<String, Object?>> closureRows = await db.executor.runSelect(
        'SELECT COUNT(*) AS row_count FROM mileage_posting_period_closures',
        const <Object?>[],
      );
      expect((closureRows.single['row_count']! as num).toInt(), 0);
    });

    test('v27-to-v28 correction migration preserves existing trip and journal rows', () async {
      final int categoryId = await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, euer_zeile) VALUES (?, ?)',
        const <Object?>['Legacy v27 category', 12],
      );
      final int journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) '
        'VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-10-01', 'Legacy v27 journal row', categoryId, '17.00', 'Einnahme'],
      );
      await db.executor.runCustom('''
INSERT INTO mileage_trips (
  id, trip_date, purpose, business_context, trip_kind, vehicle_source, vehicle_class,
  distance_hundredths_km, state, created_at, updated_at
) VALUES (
  'v27-existing-trip', '2026-10-02', 'Legacy trip', 'Legacy project',
  'business_trip', 'private', 'kraftwagen', 1000, 'unresolved',
  '2026-10-02T12:00:00Z', '2026-10-02T12:00:00Z'
)''');
      await db.executor.runCustom('DROP TRIGGER IF EXISTS trg_mileage_correction_update_guard');
      await db.executor.runCustom('''
CREATE TRIGGER trg_mileage_correction_update_guard
BEFORE UPDATE ON mileage_trip_corrections
WHEN OLD.state <> 'draft' OR NEW.state = 'applied'
BEGIN
  SELECT RAISE(ABORT, 'v27 fail-closed correction guard');
END''');
      await db.executor.runCustom('PRAGMA user_version = 27');

      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      expect(await runner.run(createSchema: () async {}), isTrue);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);

      final List<Map<String, Object?>> tripRows = await db.executor.runSelect(
        'SELECT id, trip_date, purpose, business_context, distance_hundredths_km, state, posting_event_id '
        'FROM mileage_trips WHERE id = ?',
        const <Object?>['v27-existing-trip'],
      );
      expect(tripRows.single, <String, Object?>{
        'id': 'v27-existing-trip',
        'trip_date': '2026-10-02',
        'purpose': 'Legacy trip',
        'business_context': 'Legacy project',
        'distance_hundredths_km': 1000,
        'state': 'unresolved',
        'posting_event_id': null,
      });
      final List<Map<String, Object?>> journalRows = await db.executor.runSelect(
        'SELECT id, datum, beschreibung, kategorie_id, betrag, beleg_typ FROM journal WHERE id = ?',
        <Object?>[journalId],
      );
      expect(journalRows.single, <String, Object?>{
        'id': journalId,
        'datum': '2026-10-01',
        'beschreibung': 'Legacy v27 journal row',
        'kategorie_id': categoryId,
        'betrag': 17.0,
        'beleg_typ': 'Einnahme',
      });
      final List<Map<String, Object?>> correctionGuards = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = 'trg_mileage_correction_update_guard'",
        const <Object?>[],
      );
      expect(correctionGuards, hasLength(1));
      expect(correctionGuards.single['sql'].toString().toLowerCase(), contains('mileage_correction'));
      final List<Map<String, Object?>> tripPostingGuards = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = 'trg_mileage_trip_posting_guard'",
        const <Object?>[],
      );
      expect(tripPostingGuards, hasLength(1));
      expect(tripPostingGuards.single['sql'].toString().toLowerCase(), contains('mileage_correction'));
      expect(tripPostingGuards.single['sql'].toString().toLowerCase(), contains('reversal_of_group_id'));
    });

    test('current v29 repair replaces marker-retaining weakened correction guards', () async {
      await db.executor.runCustom('DROP TRIGGER trg_mileage_correction_update_guard');
      await db.executor.runCustom('DROP TRIGGER trg_mileage_trip_posting_guard');
      await db.executor.runCustom('''
CREATE TRIGGER trg_mileage_correction_update_guard
BEFORE UPDATE ON mileage_trip_corrections
WHEN 0 /* new.accounting_correction_id is not new.id reversal_of_group_id source_kind = 'mileage_correction' marker-only-weakened-trigger */
BEGIN
  SELECT RAISE(ABORT, 'weakened correction guard');
END''');
      await db.executor.runCustom('''
CREATE TRIGGER trg_mileage_trip_posting_guard
BEFORE UPDATE ON mileage_trips
WHEN 0 /* mileage_correction reversal_of_group_id new.posting_event_id mileage_posting_period_closures mileage_kategorie_id_snapshot mileage_euer_zeile_snapshot source_kind count(*) marker-only-weakened-trigger */
BEGIN
  SELECT RAISE(ABORT, 'weakened posting guard');
END''');

      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      final SchemaHealthReport weakenedHealth = await runner.inspectSchemaHealth();
      expect(weakenedHealth.isHealthy, isFalse);
      expect(weakenedHealth.malformedTables, containsAll(<String>['mileage_trips', 'mileage_trip_corrections']));
      expect(await runner.run(createSchema: () async {}), isTrue);
      final SchemaHealthReport repairedHealth = await runner.inspectSchemaHealth();
      expect(repairedHealth.malformedTables, isNot(contains('mileage_trips')));
      expect(repairedHealth.malformedTables, isNot(contains('mileage_trip_corrections')));

      final List<Map<String, Object?>> triggers = await db.executor.runSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND name IN (?, ?)",
        const <Object?>['trg_mileage_correction_update_guard', 'trg_mileage_trip_posting_guard'],
      );
      expect(triggers, hasLength(2));
      final Map<String, String> triggerSql = <String, String>{
        for (final Map<String, Object?> trigger in triggers)
          trigger['name'].toString(): trigger['sql'].toString().toLowerCase(),
      };
      final String correctionSql = triggerSql['trg_mileage_correction_update_guard']!.replaceAll(RegExp(r'\\s+'), ' ');
      final String postingSql = triggerSql['trg_mileage_trip_posting_guard']!.replaceAll(RegExp(r'\\s+'), ' ');
      expect(correctionSql, isNot(contains('marker-only-weakened-trigger')));
      expect(correctionSql, contains('reversal.reversal_of_group_id = original.gruppe_id'));
      expect(postingSql, isNot(contains('marker-only-weakened-trigger')));
      expect(postingSql, contains('reversal.reversal_of_group_id = original.gruppe_id'));
    });

    test('current v28 startup fails closed when required mileage configuration tables are missing', () async {
      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      final List<Object> startupErrors = <Object>[];
      final List<String> recreatedTables = <String>[];
      final int accountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart) VALUES (?, ?)',
        const <Object?>['Configured mileage account', 'Sachkonto'],
      );
      final int categoryId = await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung) VALUES (?)',
        const <Object?>['Configured mileage category'],
      );
      await db.executor.runInsert(
        'INSERT INTO mileage_posting_account_mapping (role, konto_id, kategorie_id, reviewed_at) VALUES (?, ?, ?, ?)',
        <Object?>['travel_expense', accountId, categoryId, '2026-10-18T12:00:00Z'],
      );

      for (final String table in const <String>['mileage_posting_period_closures', 'mileage_posting_account_mapping']) {
        await db.executor.runCustom('DROP TABLE IF EXISTS $table');
        try {
          await runner.run(createSchema: () async {});
        } catch (error) {
          startupErrors.add(error);
        }
        final List<Map<String, Object?>> rows = await db.executor.runSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
          <Object?>[table],
        );
        if (rows.isNotEmpty) recreatedTables.add(table);
      }

      expect(startupErrors, hasLength(2));
      expect(startupErrors.every((Object error) => error is StateError), isTrue);
      expect(recreatedTables, isEmpty, reason: 'A missing v25 config table must remain missing after failed startup');
    });

    test('schema health requires non-null mapping role fields and role uniqueness', () async {
      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      for (final String nullableColumn in const <String>['konto_id', 'kategorie_id', 'reviewed_at']) {
        await db.executor.runCustom('DROP TABLE mileage_posting_account_mapping');
        final String kontoNotNull = nullableColumn == 'konto_id' ? '' : 'NOT NULL';
        final String kategorieNotNull = nullableColumn == 'kategorie_id' ? '' : 'NOT NULL';
        final String reviewedNotNull = nullableColumn == 'reviewed_at' ? '' : 'NOT NULL';
        await db.executor.runCustom('''
CREATE TABLE mileage_posting_account_mapping (
  role TEXT PRIMARY KEY NOT NULL CHECK (role IN ('travel_expense', 'private_contribution')),
  konto_id INTEGER $kontoNotNull REFERENCES konten(id) ON DELETE RESTRICT,
  kategorie_id INTEGER $kategorieNotNull REFERENCES kategorien(id) ON DELETE RESTRICT,
  reviewed_at TEXT $reviewedNotNull CHECK (trim(reviewed_at) <> '')
)''');
        final SchemaHealthReport health = await runner.inspectSchemaHealth();
        expect(
          health.malformedTables,
          contains('mileage_posting_account_mapping'),
          reason: '$nullableColumn must be NOT NULL',
        );
      }

      await db.executor.runCustom('DROP TABLE mileage_posting_account_mapping');
      await db.executor.runCustom('''
CREATE TABLE mileage_posting_account_mapping (
  role TEXT NOT NULL CHECK (role IN ('travel_expense', 'private_contribution')),
  konto_id INTEGER NOT NULL REFERENCES konten(id) ON DELETE RESTRICT,
  kategorie_id INTEGER NOT NULL REFERENCES kategorien(id) ON DELETE RESTRICT,
  reviewed_at TEXT NOT NULL CHECK (trim(reviewed_at) <> '')
)''');
      final SchemaHealthReport nonUniqueRole = await runner.inspectSchemaHealth();
      expect(nonUniqueRole.malformedTables, contains('mileage_posting_account_mapping'));

      await db.executor.runCustom('DROP TABLE mileage_posting_account_mapping');
      await db.executor.runCustom('''
CREATE TABLE mileage_posting_account_mapping (
  role TEXT PRIMARY KEY NOT NULL CHECK (role IN ('travel_expense', 'private_contribution')),
  konto_id INTEGER NOT NULL REFERENCES konten(id) ON DELETE RESTRICT,
  kategorie_id INTEGER NOT NULL,
  reviewed_at TEXT NOT NULL CHECK (trim(reviewed_at) <> '')
)''');
      final SchemaHealthReport missingCategoryForeignKey = await runner.inspectSchemaHealth();
      expect(missingCategoryForeignKey.malformedTables, contains('mileage_posting_account_mapping'));
    });

    test('calculation trigger rejects each null snapshot field', () async {
      await db.executor.runCustom('''
INSERT INTO mileage_trips (
  id, trip_date, purpose, business_context, trip_kind, vehicle_source, vehicle_class,
  distance_hundredths_km, state, created_at, updated_at
) VALUES (
  'null-snapshot-field-trip', '2026-03-14', 'Fahrt', 'Projekt', 'business_trip', 'private', 'kraftwagen',
  1000, 'unresolved', '2026-03-14T12:00:00Z', '2026-03-14T12:00:00Z'
)''');

      const Map<String, String> snapshotFields = <String, String>{
        'policy_id': "'DE-private-business-travel/1'",
        'policy_source': "'EStG-9-1-3-4a;BRKG-5-1-2;BMF-LStH-2026-A25-III-37;EÜR-2025-71'",
        'policy_version': "'1'",
        'policy_effective_from': "'2025-01-01'",
        'policy_effective_to': "'2026-12-31'",
        'calculated_amount': '3.00',
        'calculated_at': "'2026-03-14T12:00:00Z'",
      };

      for (final String missingField in snapshotFields.keys) {
        final List<String> assignments = <String>["state = 'calculated'"];
        for (final MapEntry<String, String> field in snapshotFields.entries) {
          assignments.add('${field.key} = ${field.key == missingField ? 'NULL' : field.value}');
        }
        await expectLater(
          () => db.executor.runCustom(
            'UPDATE mileage_trips SET ${assignments.join(', ')} WHERE id = ?',
            const <Object?>['null-snapshot-field-trip'],
          ),
          throwsA(isA<Exception>()),
          reason: 'calculation must reject a null $missingField',
        );
        final List<Map<String, Object?>> rows = await db.executor.runSelect(
          'SELECT state FROM mileage_trips WHERE id = ?',
          const <Object?>['null-snapshot-field-trip'],
        );
        expect(rows.single['state'], 'unresolved', reason: '$missingField must not partially calculate the trip');
      }
    });

    test('database rejects ineligible calculation and fake posting event', () async {
      await db.executor.runCustom('''
INSERT INTO mileage_trips (
  id, trip_date, purpose, business_context, trip_kind, vehicle_source, vehicle_class,
  distance_hundredths_km, state, created_at, updated_at
) VALUES (
  'mileage-test-trip', '2026-03-14', 'Fahrt', 'Projekt', 'commuting', 'private', 'kraftwagen',
  1000, 'unresolved', '2026-03-14T12:00:00Z', '2026-03-14T12:00:00Z'
)''');

      await expectLater(
        () => db.executor.runCustom('''
UPDATE mileage_trips SET state = 'calculated', policy_id = 'DE-private-business-travel/1',
  policy_source = 'EStG-9-1-3-4a;BRKG-5-1-2;BMF-LStH-2026-A25-III-37;EÜR-2025-71',
  policy_version = '1', policy_effective_from = '2025-01-01', policy_effective_to = '2026-12-31',
  calculated_amount = 3.00, calculated_at = '2026-03-14T12:00:00Z'
WHERE id = 'mileage-test-trip' '''),
        throwsA(isA<Exception>()),
      );
      final List<Map<String, Object?>> unresolved = await db.executor.runSelect(
        'SELECT state, calculated_amount FROM mileage_trips WHERE id = ?',
        const <Object?>['mileage-test-trip'],
      );
      expect(unresolved.single['state'], 'unresolved');
      expect(unresolved.single['calculated_amount'], isNull);

      await db.executor.runCustom(
        "UPDATE mileage_trips SET trip_kind = 'business_trip' WHERE id = 'mileage-test-trip'",
      );
      await db.executor.runCustom('''
UPDATE mileage_trips SET state = 'calculated', policy_id = 'DE-private-business-travel/1',
  policy_source = 'EStG-9-1-3-4a;BRKG-5-1-2;BMF-LStH-2026-A25-III-37;EÜR-2025-71',
  policy_version = '1', policy_effective_from = '2025-01-01', policy_effective_to = '2026-12-31',
  calculated_amount = 3.00, calculated_at = '2026-03-14T12:00:00Z'
WHERE id = 'mileage-test-trip' ''');
      await expectLater(
        () => db.executor.runCustom(
          "UPDATE mileage_trips SET state = 'posted', posting_event_id = 'de305d54-75b4-431b-adb2-eb6b9e546014' WHERE id = 'mileage-test-trip'",
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        () => db.executor.runCustom("UPDATE mileage_trips SET state = 'voided' WHERE id = 'mileage-test-trip'"),
        throwsA(isA<Exception>()),
      );
      final List<Map<String, Object?>> calculated = await db.executor.runSelect(
        'SELECT state, purpose, posting_event_id FROM mileage_trips WHERE id = ?',
        const <Object?>['mileage-test-trip'],
      );
      expect(calculated.single['state'], 'calculated');
      expect(calculated.single['purpose'], 'Fahrt');
      expect(calculated.single['posting_event_id'], isNull);
    });
  });
}
