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
      expect(await MigrationRunner(executor: db.executor, profileDir: profileDirectory.path).getUserVersion(), 23);
    });

    test('v22 migration preserves posted facts and marks legacy classifications unknown', () async {
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
      expect(await runner.getUserVersion(), 23);
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
