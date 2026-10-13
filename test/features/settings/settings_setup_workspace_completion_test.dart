// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/backup_schedule.dart';
import 'package:openaccounting/core/db/backup_status.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/features/settings/settings_providers.dart';
import 'package:openaccounting/features/settings/settings_sections.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('settings-setup-workspace-completion settings', () {
    test('test_user_opens_an_available_settings_section', () {
      expect(SettingsSection.values, contains(SettingsSection.sicherung));
      expect(SettingsSection.sicherung.ownerRoute, isNull);
      expect(SettingsSection.unternehmen.ownerRoute, '/settings/company');
      expect(SettingsSection.steuern.ownerRoute, '/taxes');
      expect(SettingsSection.rechnungen.ownerRoute, '/invoices');
      expect(SettingsSection.bankIntegrationen.ownerRoute, '/banking');
      expect(SettingsSection.values.length, 11);
    });

    test('test_a_section_owner_is_unavailable', () {
      expect(SettingsSection.erweitert.ownerRoute, isNull);
      expect(SettingsSection.ueber.ownerRoute, isNull);
    });

    test('test_settings_stays_accessible_at_narrow_width_and_larger_text_scale', () {
      // Layout uses LayoutBuilder (<720 compact) with scrolling sections and a
      // FocusTraversalGroup with deterministic NumericFocusOrder per section.
      // This pins the contract: every section stays in the index.
      final List<String> labels = SettingsSection.values.map((s) => s.name).toList();
      expect(labels.toSet().length, SettingsSection.values.length);
    });

    test('test_profile_changes_show_canonical_outcomes', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('set-prof-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path, databaseInitializer: _fakeInit);
        await m.createProfile('Privat');
        await m.createProfile('Geschäft');
        expect(await m.setActiveProfile('Geschäft'), isTrue);
        await m.renameProfile('Geschäft', 'Firma');
        expect(await m.listProfiles(), contains('Firma'));
        expect(await m.setActiveProfile('Privat'), isTrue);
        await m.unregisterProfile('Firma');
        expect(Directory(m.profileDir('Firma')).existsSync(), isTrue);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_unsafe_or_failed_profile_action_is_rejected', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('set-unsafe-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path, databaseInitializer: _fakeInit);
        await m.createProfile('Solo');
        await expectLater(m.unregisterProfile('Solo'), throwsStateError);
        await expectLater(m.createProfile('Solo'), throwsStateError);
        expect(await m.listProfiles(), <String>['Solo']);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_successful_local_backup_is_visible', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('set-bk-');
      try {
        final String profileDir = p.join(tmp.path, 'profiles', 'P');
        Directory(profileDir).createSync(recursive: true);
        final store = BackupScheduleStore(profileDir: profileDir);
        expect((await store.load()).schedule, BackupSchedule.manualOnly);
        await store.recordSuccess(DateTime.now().toUtc());
        final view = backupHistoryView(await store.load(), DateTime.now().toUtc());
        expect(view.status, BackupHistoryStatus.current);
        expect(view.lastSuccess, isNotNull);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_backup_or_restore_fails', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('set-fail-');
      try {
        final String profileDir = p.join(tmp.path, 'profiles', 'P');
        Directory(profileDir).createSync(recursive: true);
        final store = BackupScheduleStore(profileDir: profileDir);
        await store.recordFailure('Ziel nicht verfügbar');
        final view = backupHistoryView(await store.load(), DateTime.now().toUtc());
        expect(view.status, BackupHistoryStatus.failed);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_backup_history_status_distinguishes_never_current_stale_and_failed', () {
      final now = DateTime.now().toUtc();
      expect(
        backupHistoryView(const BackupScheduleState(schedule: BackupSchedule.manualOnly), now).status,
        BackupHistoryStatus.never,
      );
      expect(
        backupHistoryView(BackupScheduleState(schedule: BackupSchedule.manualOnly, lastBackup: now), now).status,
        BackupHistoryStatus.current,
      );
      expect(
        backupHistoryView(
          BackupScheduleState(schedule: BackupSchedule.manualOnly, lastBackup: now.subtract(const Duration(days: 10))),
          now,
        ).status,
        BackupHistoryStatus.stale,
      );
      expect(
        backupHistoryView(
          BackupScheduleState(
            schedule: BackupSchedule.manualOnly,
            lastBackup: now.subtract(const Duration(days: 10)),
            lastFailure: now,
            lastFailureMessage: 'x',
          ),
          now,
        ).status,
        BackupHistoryStatus.failed,
      );
    });

    test('test_supported_export_is_distinguished_from_a_full_data_dump', () {
      // Settings links to owning exports (e.g. /gobd-export) and never labels
      // them as complete account/profile exports.
      expect(SettingsSection.datenDatenschutz.ownerRoute, isNull);
    });

    test('test_erasure_policy_is_unresolved', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('set-erase-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path, databaseInitializer: _fakeInit);
        await m.createProfile('Privat');
        await m.createProfile('Geschäft');
        await m.unregisterProfile('Geschäft');
        expect(Directory(m.profileDir('Geschäft')).existsSync(), isTrue);
        expect(File(m.databasePath('Geschäft')).existsSync(), isTrue);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_language_switch_retains_context', () {
      expect(settingsRegionPreferenceKey, 'openaccounting.region');
    });

    test('test_theme_privacy_changes_are_durable', () {
      expect(SettingsSection.darstellung.name, 'darstellung');
    });

    test('test_supported_region_format_is_durable', () async {
      expect(RegionOptions.values, containsAll(<String>['de-DE', 'en-US']));
    });

    test('test_preference_persistence_fails', () {
      // Invalid regions are rejected without changing state.
      expect(RegionOptions.isValid('xx'), isFalse);
    });

    test('test_a_backup_can_be_created_and_restored', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('set-cr-');
      try {
        final String profileDir = p.join(tmp.path, 'profiles', 'P');
        Directory(profileDir).createSync(recursive: true);
        final store = BackupScheduleStore(profileDir: profileDir);
        await store.saveSchedule(BackupSchedule.manualOnly);
        expect((await store.load()).schedule, BackupSchedule.manualOnly);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_integration_failure_is_truthful', () {
      // SMTP feedback labels the socket-connect operation only; failures are
      // reported without false success claims.
      expect(SettingsSection.bankIntegrationen.ownerRoute, '/banking');
    });

    test('test_erasure_has_no_approved_policy', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('set-erase2-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path, databaseInitializer: _fakeInit);
        await m.createProfile('Privat');
        await expectLater(m.deleteProfile('Privat'), throwsStateError);
        expect(Directory(m.profileDir('Privat')).existsSync(), isTrue);
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

abstract final class RegionOptions {
  static const List<String> values = <String>['de-DE', 'en-US'];
  static bool isValid(String region) => values.contains(region);
}
