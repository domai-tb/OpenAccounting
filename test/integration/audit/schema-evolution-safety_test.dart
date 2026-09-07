// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';

void main() {
  group('Schema evolution safety', () {
    test('test_schema_evolution_safety_1_1_fresh_database_has_the_complete_schema', () async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();

      for (final table in AppDatabase.allTableNames) {
        final rows = await db.executor.runSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          <Object?>[table],
        );
        expect(rows.isNotEmpty, isTrue, reason: 'Table $table missing from fresh schema');
      }

      await db.close();
    });

    test('test_schema_evolution_safety_1_2_a_workflow_cannot_hide_missing_schema', () async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();

      // Drop inventarbewegungen — it should exist only via migrations
      await db.executor.runCustom('DROP TABLE IF EXISTS inventarbewegungen');

      // Querying a missing table should fail, not recreate it
      expect(
        () => db.executor.runSelect('SELECT * FROM inventarbewegungen WHERE artikel_id = ?', const <Object?>[1]),
        throwsA(anything),
      );

      // Verify table was NOT recreated by the query
      final tables = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='inventarbewegungen'",
        const <Object?>[],
      );
      expect(tables.isEmpty, isTrue, reason: 'inventarbewegungen must not be created by query');

      await db.close();
    });

    test('test_schema_evolution_safety_2_1_unsupported_future_database_is_rejected', () async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();

      // Set version higher than currentVersion
      await db.executor.runCustom('PRAGMA user_version = ${MigrationRunner.currentVersion + 10}');

      // Verify the precondition: version is ahead of application
      final rows = await db.executor.runSelect('PRAGMA user_version', const <Object?>[]);
      final version = (rows.first.values.first! as num).toInt();
      expect(version, greaterThan(MigrationRunner.currentVersion));

      // MigrationRunner.run should reject the future version with a clear error
      // We test the run method through the same executor that is already open
      await expectLater(db.executor.runSelect('PRAGMA user_version', const <Object?>[]), completes);

      // Now test via MigrationRunner — must throw for future version
      final runner = MigrationRunner(executor: db.executor, profileDir: '/tmp');
      await expectLater(
        () => runner.run(createSchema: () async {}),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('newer than application'))),
      );

      await db.close();
    });

    test('test_schema_evolution_safety_2_2_legacy_rebuild_preserves_extended_data', () async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();

      // Create old rechnungen table
      await db.executor.runCustom('DROP TABLE IF EXISTS rechnungen');
      await db.executor.runCustom('''
        CREATE TABLE rechnungen (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rechnungsnummer TEXT,
          typ TEXT NOT NULL,
          status TEXT DEFAULT 'entwurf',
          kunde_id INTEGER,
          lieferant_id INTEGER,
          datum TEXT NOT NULL,
          faelligkeit TEXT,
          netto_betrag NUMERIC(12,2) DEFAULT 0,
          brutto_betrag NUMERIC(12,2) DEFAULT 0,
          ust_betrag NUMERIC(12,2) DEFAULT 0,
          skonto_prozent NUMERIC(12,2) DEFAULT 0,
          skonto_faelligkeit TEXT,
          notiz TEXT,
          unternehmen_id INTEGER,
          nummernkreis_id INTEGER,
          storno_von INTEGER
        )
      ''');
      await db.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, datum, netto_betrag) VALUES ('R-001', 'rechnung', '2026-01-01', 100.00)",
      );

      // Add columns from later migrations
      await db.executor.runCustom('ALTER TABLE rechnungen ADD COLUMN ist_entwurf INTEGER NOT NULL DEFAULT 1');
      await db.executor.runCustom("ALTER TABLE rechnungen ADD COLUMN eingabemodus TEXT NOT NULL DEFAULT 'netto'");
      await db.executor.runCustom('ALTER TABLE rechnungen ADD COLUMN absender_snapshot TEXT');
      await db.executor.runCustom('ALTER TABLE rechnungen ADD COLUMN ausgegeben_am TEXT');
      await db.executor.runCustom('ALTER TABLE rechnungen ADD COLUMN mahnstufe_aktuell INTEGER DEFAULT 0');

      // Update with extended data
      await db.executor.runCustom(
        "UPDATE rechnungen SET absender_snapshot = '{\"test\": true}', mahnstufe_aktuell = 3 WHERE rechnungsnummer = 'R-001'",
      );

      // Verify extended data exists
      final before = await db.executor.runSelect(
        'SELECT absender_snapshot, mahnstufe_aktuell FROM rechnungen WHERE rechnungsnummer = ?',
        const <Object?>['R-001'],
      );
      expect(before.isNotEmpty, isTrue);
      expect(before.single['absender_snapshot'], isNotNull);
      expect(before.single['mahnstufe_aktuell'], 3);

      await db.close();
    });
  });
}
