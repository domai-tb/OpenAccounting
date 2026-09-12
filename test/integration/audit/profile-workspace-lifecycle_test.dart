// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/profile_manager.dart';

void main() {
  group('Profile workspace lifecycle', () {
    late Directory tmpDir;
    late ProfileManager pm;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('profile-lifecycle-');
      pm = ProfileManager(baseDir: tmpDir.path, databaseInitializer: (_) async {});
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    // ── Task 1: Profile CRUD changes real profile state ──

    test('test_profile_workspace_lifecycle_1_1_inactive_profile_can_be_deleted', () async {
      // An inactive profile must be fully removable (directory + files).
      await pm.createProfile('ProfileA');
      await pm.createProfile('ProfileB');

      // Set ProfileA as active.
      await pm.setActiveProfile('ProfileA');

      // Delete ProfileB (inactive).
      await pm.deleteProfile('ProfileB');

      // ProfileB directory must no longer exist.
      final profileBDir = Directory(pm.profileDir('ProfileB'));
      expect(profileBDir.existsSync(), isFalse, reason: 'Deleted profile directory must be removed');

      // ProfileA must still exist.
      final profileADir = Directory(pm.profileDir('ProfileA'));
      expect(profileADir.existsSync(), isTrue, reason: 'Active profile must remain');
    });

    // ── Task 2: Active/last profile deletion is protected ──

    test('test_profile_workspace_lifecycle_1_2_active_last_profile_deletion_is_protected', () async {
      // Cannot delete the active profile.
      await pm.createProfile('ProfileA');
      await pm.createProfile('ProfileB');
      await pm.setActiveProfile('ProfileA');

      expect(
        () => pm.deleteProfile('ProfileA'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Aktives Profil'))),
        reason: 'Deleting active profile must throw StateError',
      );

      // After deleting ProfileB, ProfileA is last → still protected as active.
      await pm.deleteProfile('ProfileB');
      expect(
        () => pm.deleteProfile('ProfileA'),
        throwsA(isA<StateError>()),
        reason: 'Deleting the last (active) profile must throw',
      );
    });

    // ── Task 3: Selection switches the running application coherently ──

    test('test_profile_workspace_lifecycle_2_1_user_switches_profiles', () async {
      // Switching profiles must update the active pointer.
      await pm.createProfile('ProfileA');
      await pm.createProfile('ProfileB');

      // Multiple profiles without a durable pointer require an explicit choice.
      await expectLater(pm.getActiveProfile(), throwsA(isA<ProfileSelectionRequiredException>()));

      // Switch to ProfileB.
      final restartRequired = await pm.setActiveProfile('ProfileB');
      expect(restartRequired, isTrue, reason: 'Switch must signal restart required');

      // Verify active profile changed.
      final afterSwitch = await pm.getActiveProfile();
      expect(afterSwitch, 'ProfileB', reason: 'Active profile must be ProfileB after switch');

      // Switching to same profile returns false (no restart needed).
      final noOp = await pm.setActiveProfile('ProfileB');
      expect(noOp, isFalse, reason: 'Same-profile switch must not require restart');
    });

    // ── Task 4: Corrupt or unavailable profile is recoverable ──

    test('test_profile_workspace_lifecycle_2_2_corrupt_or_unavailable_profile_is_recoverable', () async {
      // Corrupted profile.json must not silently select another company.
      await pm.createProfile('ProfileA');
      await pm.createProfile('ProfileB');
      await pm.setActiveProfile('ProfileA');

      // Corrupt profile.json.
      final jsonFile = File(pm.profileJsonPath);
      await jsonFile.writeAsString('{broken json!!!');

      await expectLater(pm.getActiveProfile(), throwsA(isA<ProfileSelectionRequiredException>()));

      // Missing profile.json — explicit selection is still required.
      await jsonFile.delete();
      await expectLater(pm.getActiveProfile(), throwsA(isA<ProfileSelectionRequiredException>()));

      // Non-existent active profile directory — explicit selection is required.
      await jsonFile.writeAsString('{"active": "NonExistent"}');
      await expectLater(pm.getActiveProfile(), throwsA(isA<ProfileSelectionRequiredException>()));
    });
  });
}
