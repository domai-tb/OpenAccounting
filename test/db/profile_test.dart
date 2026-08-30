import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  });
}
