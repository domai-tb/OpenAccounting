// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('settings-setup-workspace-completion profile workspace lifecycle', () {
    test('test_user_switches_profiles', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('lc-switch-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path, databaseInitializer: _fakeInit);
        await m.createProfile('Erstes');
        await m.createProfile('Zweites');
        expect(await m.getActiveProfile(), 'Erstes');
        expect(await m.setActiveProfile('Zweites'), isTrue);
        expect(await m.getActiveProfile(), 'Zweites');
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_active_profile_selection_is_a_no_op', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('lc-noop-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path, databaseInitializer: _fakeInit);
        await m.createProfile('Aktiv');
        expect(await m.setActiveProfile('Aktiv'), isFalse);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_corrupt_or_unavailable_profile_is_recoverable', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('lc-recover-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path, databaseInitializer: _fakeInit);
        await m.createProfile('Gut');
        await expectLater(m.setActiveProfile('Fehlt'), throwsStateError);
        expect(await m.getActiveProfile(), 'Gut');
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });
}

Future<void> _fakeInit(String databasePath) async {
  final db = sqlite3.open(databasePath);
  try {
    db.execute('CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY)');
  } finally {
    db.close();
  }
}
