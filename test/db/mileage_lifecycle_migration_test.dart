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
      expect(await MigrationRunner(executor: db.executor, profileDir: profileDirectory.path).getUserVersion(), 24);
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
      expect(await runner.getUserVersion(), 24);
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
      expect(await runner.getUserVersion(), 24);
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

    test('database rejects ineligible calculation and ungated void transition', () async {
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
      await db.executor.runCustom(
        "UPDATE mileage_trips SET state = 'posted', posting_event_id = 'mileage-event' WHERE id = 'mileage-test-trip'",
      );
      await expectLater(
        () => db.executor.runCustom("UPDATE mileage_trips SET state = 'voided' WHERE id = 'mileage-test-trip'"),
        throwsA(isA<Exception>()),
      );
    });
  });
}
