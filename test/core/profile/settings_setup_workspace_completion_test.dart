// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/profile_catalog.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/core/db/profile_read_only_probe.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('settings-setup-workspace-completion profiles', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('prof-');
    });

    tearDown(() async {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    ProfileManager manager() => ProfileManager(baseDir: tmp.path, databaseInitializer: _fakeInit);

    void makeDb(String name) {
      final String dir = p.join(tmp.path, 'profiles', name);
      Directory(dir).createSync(recursive: true);
      final Database db = sqlite3.open(p.join(dir, 'openinvoices.db'));
      try {
        db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY)');
      } finally {
        db.close();
      }
    }

    test('test_new_profile_creates_isolated_database', () async {
      final ProfileManager m = manager();
      await m.createProfile('Geschäft');
      expect(File(m.databasePath('Geschäft')).existsSync(), isTrue);
      final Map<String, dynamic> raw = jsonDecode(await File(m.profileJsonPath).readAsString());
      expect(raw['active'], 'Geschäft');
      expect((raw['registered'] as List), contains('Geschäft'));
    });

    test('test_additional_profile_is_registered_without_changing_the_active_profile', () async {
      final ProfileManager m = manager();
      await m.createProfile('Privat');
      await m.createProfile('Geschäft');
      expect(await m.getActiveProfile(), 'Privat');
      expect(await m.listProfiles(), containsAll(<String>['Privat', 'Geschäft']));
    });

    test('test_profile_isolation', () async {
      final ProfileManager m = manager();
      await m.createProfile('Privat');
      await m.createProfile('Geschäft');
      expect(m.databasePath('Privat'), isNot(m.databasePath('Geschäft')));
      expect(File(m.databasePath('Privat')).existsSync(), isTrue);
      expect(File(m.databasePath('Geschäft')).existsSync(), isTrue);
    });

    test('test_legacy_profile_catalog_is_migrated_without_data_loss', () async {
      makeDb('Alt1');
      makeDb('Alt2');
      await File(p.join(tmp.path, 'profile.json')).writeAsString(jsonEncode(<String, String>{'active': 'Alt1'}));
      final ProfileManager m = manager();
      final List<String> profiles = await m.listProfiles();
      expect(profiles, containsAll(<String>['Alt1', 'Alt2']));
      expect(Directory(p.join(tmp.path, 'profiles', 'Alt1')).existsSync(), isTrue);
      expect(Directory(p.join(tmp.path, 'profiles', 'Alt2')).existsSync(), isTrue);
    });

    test('test_profile_selection_uses_the_registered_catalog', () async {
      final ProfileManager m = manager();
      await m.createProfile('Privat');
      makeDb('Unregistriert');
      expect(await m.listProfiles(), <String>['Privat']);
      await expectLater(m.setActiveProfile('Unregistriert'), throwsStateError);
    });

    test('test_unregistered_active_pointer_is_not_loaded_after_restart', () async {
      final ProfileManager m = manager();
      await m.createProfile('Privat');
      await File(m.profileJsonPath).writeAsString(
        jsonEncode(<String, Object?>{
          'active': 'Fremd',
          'registered': <String>['Privat'],
        }),
      );
      await expectLater(m.getActiveProfile(), throwsA(isA<ProfileSelectionRequiredException>()));
    });

    test('test_corrupted_profile_json_falls_back_to_default', () async {
      makeDb('Einzig');
      await File(p.join(tmp.path, 'profile.json')).writeAsString('{ungültig');
      final ProfileManager m = manager();
      expect(await m.getActiveProfile(), 'Einzig');
    });

    test('test_corrupted_profile_catalog_with_multiple_validated_profiles', () async {
      makeDb('A');
      makeDb('B');
      await File(p.join(tmp.path, 'profile.json')).writeAsString('{ungültig');
      final ProfileManager m = manager();
      final CatalogRecoveryResult loaded = await ProfileCatalogStore(baseDir: tmp.path).load();
      expect(loaded.outcome, CatalogRecovery.needsChoice);
      expect(loaded.catalog.active, isNull);
      await expectLater(m.getActiveProfile(), throwsA(isA<ProfileSelectionRequiredException>()));
    });

    test('test_invalid_profile_candidates_are_preserved_but_unavailable', () async {
      final Directory bad = Directory(p.join(tmp.path, 'profiles', '..-böse'));
      bad.createSync(recursive: true);
      await File(p.join(tmp.path, 'profile.json')).writeAsString('{ungültig');
      final ProfileManager m = manager();
      expect(await m.listProfiles(), isEmpty);
      expect(bad.existsSync(), isTrue);
    });

    test('test_valid_but_outdated_candidate_remains_unchanged_until_selected', () async {
      makeDb('Alt');
      final String dbPath = p.join(tmp.path, 'profiles', 'Alt', 'openinvoices.db');
      final int before = await File(dbPath).length();
      final ProfileReadOnlyProbe probe = ProfileReadOnlyProbe(baseDir: tmp.path);
      expect(probe.probe('Alt').compatible, isTrue);
      expect(await File(dbPath).length(), before);
    });

    test('test_delete_inactive_profile', () async {
      final ProfileManager m = manager();
      await m.createProfile('Privat');
      await m.createProfile('Geschäft');
      await m.deleteProfile('Geschäft');
      expect(await m.listProfiles(), <String>['Privat']);
      expect(Directory(m.profileDir('Geschäft')).existsSync(), isTrue);
      expect(File(m.databasePath('Geschäft')).existsSync(), isTrue);
    });

    test('test_cannot_delete_active_profile', () async {
      final ProfileManager m = manager();
      await m.createProfile('Privat');
      await m.createProfile('Geschäft');
      await expectLater(m.deleteProfile('Privat'), throwsStateError);
      expect(await m.listProfiles(), containsAll(<String>['Privat', 'Geschäft']));
    });

    test('test_delete_last_remaining_profile', () async {
      final ProfileManager m = manager();
      await m.createProfile('Solo');
      await expectLater(m.deleteProfile('Solo'), throwsStateError);
      expect(Directory(m.profileDir('Solo')).existsSync(), isTrue);
    });

    test('test_unregistered_data_is_not_automatically_purged', () async {
      final ProfileManager m = manager();
      await m.createProfile('Privat');
      await m.createProfile('Geschäft');
      await m.unregisterProfile('Geschäft');
      expect(Directory(m.profileDir('Geschäft')).existsSync(), isTrue);
      await m.listProfiles();
      expect(Directory(m.profileDir('Geschäft')).existsSync(), isTrue);
    });

    test('test_corrupt_catalog_with_one_candidate_recovers_without_mutation', () async {
      makeDb('Solo');
      final String dbPath = p.join(tmp.path, 'profiles', 'Solo', 'openinvoices.db');
      final List<int> before = await File(dbPath).readAsBytes();
      await File(p.join(tmp.path, 'profile.json')).writeAsString('kaputt');
      final ProfileManager m = manager();
      expect(await m.getActiveProfile(), 'Solo');
      expect(await File(dbPath).readAsBytes(), before);
    });

    test('test_corrupt_catalog_with_multiple_candidates_requires_explicit_choice', () async {
      makeDb('A');
      makeDb('B');
      await File(p.join(tmp.path, 'profile.json')).writeAsString('kaputt');
      final ProfileManager m = manager();
      final List<String> candidates = await m.recoveryCandidates();
      expect(candidates, containsAll(<String>['A', 'B']));
      await expectLater(m.getActiveProfile(), throwsA(isA<ProfileSelectionRequiredException>()));
    });

    test('test_switch_profile_persists_selection_and_requires_restart', () async {
      final ProfileManager m = manager();
      await m.createProfile('Geschäft');
      await m.createProfile('Privat');
      expect(await m.getActiveProfile(), 'Geschäft');
      final bool restart = await m.setActiveProfile('Privat');
      expect(restart, isTrue);
      final Map<String, dynamic> raw = jsonDecode(await File(m.profileJsonPath).readAsString());
      expect(raw['active'], 'Privat');
    });

    test('test_switch_to_same_profile_is_a_no_op', () async {
      final ProfileManager m = manager();
      await m.createProfile('Privat');
      final File file = File(m.profileJsonPath);
      final DateTime modified = await file.lastModified();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await m.setActiveProfile('Privat'), isFalse);
      expect(await file.lastModified(), modified);
    });

    test('test_switch_to_non_existent_profile_does_not_fall_back_to_first_available', () async {
      final ProfileManager m = manager();
      await m.createProfile('B');
      await m.createProfile('A');
      await expectLater(m.setActiveProfile('Fehlt'), throwsStateError);
      expect(await m.getActiveProfile(), isNot('A'));
    });

    test('test_switch_profile_follows_normative_restart', () async {
      final ProfileManager m = manager();
      await m.createProfile('Geschäft');
      await m.createProfile('Privat');
      expect(await m.setActiveProfile('Privat'), isTrue);
      expect(jsonDecode(await File(m.profileJsonPath).readAsString())['active'], 'Privat');
    });

    test('test_switch_to_nonexistent_profile_no_fallback', () async {
      final ProfileManager m = manager();
      await m.createProfile('A');
      await expectLater(m.setActiveProfile('X'), throwsStateError);
    });

    test('profile name traversal rejected', () async {
      final ProfileManager m = manager();
      await expectLater(m.createProfile('../Geschäft'), throwsArgumentError);
      await expectLater(m.createProfile('Privat/Geschäft'), throwsArgumentError);
      await expectLater(m.createProfile(r'Privat\Geschäft'), throwsArgumentError);
    });
  });
}

Future<void> _fakeInit(String databasePath) async {
  final Database db = sqlite3.open(databasePath);
  try {
    db.execute('CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY)');
  } finally {
    db.close();
  }
}
