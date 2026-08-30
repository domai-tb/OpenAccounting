import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';

void main() {
  group('ProfileManager', () {
    late Directory baseDirectory;
    late ProfileManager manager;

    setUp(() async {
      baseDirectory = await Directory.systemTemp.createTemp('openaccounting_profile_test_');
      manager = ProfileManager(baseDir: baseDirectory.path);
    });

    tearDown(() async {
      await baseDirectory.delete(recursive: true);
    });

    test('creates isolated profile directory and database', () async {
      await manager.createProfile('Geschäft');

      expect(Directory(manager.profileDir('Geschäft')).existsSync(), isTrue);
      expect(File(manager.databasePath('Geschäft')).existsSync(), isTrue);
      expect(Directory(manager.profileDir('Privat')).existsSync(), isFalse);
    });

    test('rejects profile names that escape the profiles directory', () async {
      await expectLater(manager.createProfile('../Outside'), throwsA(isA<ArgumentError>()));
      expect(await manager.listProfiles(), isEmpty);
    });

    test('creates profile database with schema and seed data', () async {
      await manager.createProfile('Geschäft');

      final database = sqlite3.open(manager.databasePath('Geschäft'));
      try {
        final tables = database.select(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        );
        expect(tables, hasLength(AppDatabase.allTableNames.length));

        final rates = database.select('SELECT satz FROM ust_saetze ORDER BY id');
        expect(rates.map((row) => row['satz']), containsAll(<num>[0, 7, 19]));
      } finally {
        database.close();
      }
    });

    test('keeps identical invoice numbers isolated between profile databases', () async {
      await manager.createProfile('Privat');
      await manager.createProfile('Geschäft');

      final databases = <AppDatabase>[
        AppDatabase.forProfile(manager.profileDir('Privat')),
        AppDatabase.forProfile(manager.profileDir('Geschäft')),
      ];
      try {
        for (final database in databases) {
          await database.ensureOpen();
        }
        await databases[0].executor.runCustom(
          "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-260001', 'rechnung', '2026-01-01')",
        );
        await databases[1].executor.runCustom(
          "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-260001', 'rechnung', '2026-01-01')",
        );

        final privateRows = await databases[0].executor.runSelect('SELECT rechnungsnummer FROM rechnungen', const []);
        final businessRows = await databases[1].executor.runSelect('SELECT rechnungsnummer FROM rechnungen', const []);
        expect(privateRows, hasLength(1));
        expect(businessRows, hasLength(1));
        expect(privateRows.single['rechnungsnummer'], 'RE-260001');
        expect(businessRows.single['rechnungsnummer'], 'RE-260001');
      } finally {
        for (final database in databases) {
          await database.close();
        }
      }
    });

    test('switches profiles through profile.json and skips same-profile restart', () async {
      await manager.createProfile('Geschäft');
      await manager.createProfile('Privat');

      expect(await manager.setActiveProfile('Geschäft'), isFalse);
      expect(await manager.setActiveProfile('Privat'), isTrue);
      expect(await manager.getActiveProfile(), 'Privat');
      expect(await File(manager.profileJsonPath).readAsString(), jsonEncode(<String, String>{'active': 'Privat'}));
      expect(await manager.setActiveProfile('Privat'), isFalse);
    });

    test('falls back to first profile when profile pointer is corrupted', () async {
      await manager.createProfile('Büro');
      await manager.createProfile('Privat');
      await File(manager.profileJsonPath).writeAsString('{invalid');

      expect(await manager.getActiveProfile(), 'Büro');
    });

    test('rejects paths outside active profile data directory', () async {
      await manager.createProfile('Privat');
      await manager.setActiveProfile('Privat');

      await expectLater(
        manager.assertInsideAppDataDir(File('${baseDirectory.path}/outside.txt').path),
        throwsA(isA<StateError>()),
      );
      await manager.assertInsideAppDataDir(File('${manager.profileDir('Privat')}/uploads/logo.png').path);
    });

    test('resolves APP_DATA_DIR to the active profile directory', () async {
      await manager.createProfile('Geschäft');
      await manager.createProfile('Privat');
      await manager.setActiveProfile('Privat');

      expect(await manager.resolveAppDataDir(), manager.profileDir('Privat'));
    });
  });
}
