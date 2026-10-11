import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/assets/asset_repository.dart';
import 'package:openaccounting/features/assets/asset_usecases.dart';

/// Asset schedule schema: legacy preservation and snapshot history (delta spec, group 2).
void main() {
  group('Fixed asset register workspace — migration', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_asset_migration_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    Future<void> downgradeToLegacyShape(AppDatabase db) async {
      await db.executor.runCustom('DROP TABLE IF EXISTS anlage_afa_jahreswerte');
      await db.executor.runCustom('ALTER TABLE anlageverzeichnis RENAME TO anlageverzeichnis_new');
      await db.executor.runCustom('''
CREATE TABLE anlageverzeichnis (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bezeichnung TEXT NOT NULL,
  anschaffungsdatum TEXT,
  anschaffungskosten NUMERIC(12,2) NOT NULL,
  nutzungsdauer INTEGER,
  kategorie_id INTEGER REFERENCES kategorien(id),
  unternehmen_id INTEGER REFERENCES unternehmen(id),
  status TEXT DEFAULT 'aktiv',
  privatanteil NUMERIC(12,2) DEFAULT 0
)''');
      await db.executor.runCustom('''
INSERT INTO anlageverzeichnis (id, bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer,
  kategorie_id, unternehmen_id, status, privatanteil)
SELECT id, bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer,
  kategorie_id, unternehmen_id, status, privatanteil FROM anlageverzeichnis_new''');
      await db.executor.runCustom('DROP TABLE anlageverzeichnis_new');
    }

    test('test_existing_asset_data_survives_migration', () async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);

      final int companyId = await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>[
        'Bestand GmbH',
      ]);
      final int categoryId = await db.executor.runInsert('INSERT INTO kategorien (bezeichnung) VALUES (?)', <Object?>[
        'Büro',
      ]);
      final int first = await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'kategorie_id, unternehmen_id, status, privatanteil) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Altlaptop', '2021-04-02', '899.99', 3, categoryId, companyId, 'aktiv', '12.50'],
      );
      final int second = await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'kategorie_id, unternehmen_id, status, privatanteil) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Altdrucker', null, '250.00', null, null, null, 'inaktiv', null],
      );
      final List<Map<String, Object?>> before = await db.executor.runSelect(
        'SELECT * FROM anlageverzeichnis ORDER BY id',
        const <Object?>[],
      );

      await downgradeToLegacyShape(db);
      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(MigrationRunner.currentVersion - 1);
      final bool migrated = await runner.run(createSchema: () async {});

      expect(migrated, isTrue);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT * FROM anlageverzeichnis ORDER BY id',
        const <Object?>[],
      );
      expect(after.length, before.length);
      for (int index = 0; index < before.length; index++) {
        for (final String key in before[index].keys) {
          expect(after[index][key], before[index][key], reason: 'anlageverzeichnis.$key changed');
        }
        expect(after[index]['id'], index == 0 ? first : second);
      }
      // Canonical fields exist without inferred values.
      final List<Map<String, Object?>> columns = await db.executor.runSelect(
        'PRAGMA table_info(anlageverzeichnis)',
        const <Object?>[],
      );
      final Set<String> names = <String>{for (final Map<String, Object?> row in columns) row['name'].toString()};
      for (final String column in <String>[
        'asset_typ',
        'kaufpreis_netto',
        'nutzungsdauer_jahre',
        'afa_methode',
        'privat_anteil_prozent',
        'verkauft_am',
      ]) {
        expect(names, contains(column));
      }
      final List<Map<String, Object?>> canonicals = await db.executor.runSelect(
        'SELECT asset_typ, kaufpreis_netto, nutzungsdauer_jahre, afa_methode, privat_anteil_prozent, verkauft_am '
        'FROM anlageverzeichnis ORDER BY id',
        const <Object?>[],
      );
      for (final Map<String, Object?> row in canonicals) {
        expect(row.values.every((Object? value) => value == null), isTrue);
      }
    });

    test('test_schedule_history_remains_immutable', () async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      final AssetRegisterUseCases assets = AssetRegisterUseCases(AssetRepository(db.executor));

      final asset = await assets.createAsset(
        bezeichnung: 'Büro-PC',
        assetTyp: 'EDV',
        anschaffungsdatum: '2022-06-15',
        kaufpreisNetto: '1000.00',
        nutzungsdauerJahre: 3,
      );
      final firstRow = await assets.generateSchedule(anlageId: asset.id, jahr: 2024);
      expect(firstRow.betrag, '333.33');
      final List<Map<String, Object?>> storedBefore = await db.executor.runSelect(
        'SELECT * FROM anlage_afa_jahreswerte WHERE anlage_id = ? ORDER BY id',
        <Object?>[asset.id],
      );

      // A source edit creates a new snapshot; the earlier one stays unchanged.
      await assets.updateAsset(asset.id, bezeichnung: 'Büro-PC aktualisiert');
      final List<Map<String, Object?>> storedAfter = await db.executor.runSelect(
        'SELECT * FROM anlage_afa_jahreswerte WHERE anlage_id = ? ORDER BY id',
        <Object?>[asset.id],
      );
      expect(storedAfter.length, storedBefore.length);
      for (int index = 0; index < storedBefore.length; index++) {
        for (final String key in storedBefore[index].keys) {
          expect(storedAfter[index][key], storedBefore[index][key], reason: 'anlage_afa_jahreswerte.$key changed');
        }
      }
      // Same source and rule: no duplicate snapshot row is written.
      await assets.generateSchedule(anlageId: asset.id, jahr: 2024);
      final List<Map<String, Object?>> storedStable = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM anlage_afa_jahreswerte WHERE anlage_id = ?',
        <Object?>[asset.id],
      );
      expect(storedStable.single['c'], storedBefore.length + 1);

      // Append-only enforcement: updates and deletes abort.
      final int rowId = (storedBefore.single['id']! as num).toInt();
      await expectLater(
        db.executor.runCustom('UPDATE anlage_afa_jahreswerte SET betrag = ? WHERE id = ?', <Object?>['1.00', rowId]),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runCustom('DELETE FROM anlage_afa_jahreswerte WHERE id = ?', <Object?>[rowId]),
        throwsA(anything),
      );
      // Hard deletion is refused while a schedule references the asset.
      await expectLater(
        db.executor.runDelete('DELETE FROM anlageverzeichnis WHERE id = ?', <Object?>[asset.id]),
        throwsA(anything),
      );
    });
  });
}
