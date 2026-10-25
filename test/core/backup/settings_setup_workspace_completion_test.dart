// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/backup_schedule.dart';
import 'package:openaccounting/core/db/backup_service.dart';
import 'package:openaccounting/core/db/backup_startup.dart';
import 'package:openaccounting/core/db/backup_status.dart';
import 'package:openaccounting/core/db/data_paths.dart';
import 'package:openaccounting/core/db/profile_lock.dart';
import 'package:openaccounting/core/db/profile_write_gate.dart';
import 'package:openaccounting/core/db/restore_coordinator.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('settings-setup-workspace-completion backup', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('bk-');
      ProfileGateRegistry.resetForTests();
      BackupStartupCheck.resetForTests();
    });

    tearDown(() async {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    String makeProfile(String name) {
      final String dir = p.join(tmp.path, 'profiles', name);
      Directory(dir).createSync(recursive: true);
      final Database db = sqlite3.open(p.join(dir, 'openinvoices.db'));
      try {
        db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
        db.execute("INSERT INTO t (v) VALUES ('x')");
      } finally {
        db.close();
      }
      return dir;
    }

    test('test_linux_backup_path', () {
      final String profileDir = p.join('/home/u/.local/share/OpenAccounting', 'profiles', 'Geschäft');
      expect(BackupService.canonicalBackupDir(profileDir), '$profileDir/backups');
      expect(resolveDefaultBaseDir(), contains('OpenAccounting'));
    });

    test('test_macos_backup_path', () {
      final String profileDir = p.join('/Users/u/Library/Application Support/OpenAccounting', 'profiles', 'Geschäft');
      expect(BackupService.canonicalBackupDir(profileDir), '$profileDir/backups');
    });

    test('test_windows_backup_path', () {
      final String profileDir = p.join(r'C:\Users\u\AppData\Local\OpenAccounting', 'profiles', 'Geschäft');
      expect(BackupService.canonicalBackupDir(profileDir), endsWith('backups'));
      expect(p.basename(BackupService.canonicalBackupDir(profileDir)), 'backups');
    });

    test('test_manual_only_skips_startup_backup', () async {
      final String profileDir = makeProfile('Geschaeft');
      final BackupService backup = BackupService(profileDir: profileDir);
      final bool ran = await BackupStartupCheck.runOnceAfterReady(profileDir: profileDir, backup: backup);
      expect(ran, isFalse);
      expect(await backup.listLocalBackups(), isEmpty);
    });

    test('test_due_scheduled_backup_runs_once_after_database_readiness', () async {
      final String profileDir = makeProfile('Faellig');
      await BackupScheduleStore(profileDir: profileDir).saveSchedule(BackupSchedule.daily);
      final BackupService backup = BackupService(profileDir: profileDir);
      final bool ran = await BackupStartupCheck.runOnceAfterReady(profileDir: profileDir, backup: backup);
      expect(ran, isTrue);
      expect(await backup.listLocalBackups(), isNotEmpty);
      final BackupScheduleState state = await BackupScheduleStore(profileDir: profileDir).load();
      expect(state.lastBackup, isNotNull);
    });

    test('test_recent_backup_suppresses_duplicate_startup_work', () async {
      final String profileDir = makeProfile('Aktuell');
      final BackupService backup = BackupService(profileDir: profileDir);
      await backup.createLocalBackup();
      await BackupScheduleStore(profileDir: profileDir).saveSchedule(BackupSchedule.daily);
      await BackupScheduleStore(profileDir: profileDir).recordSuccess(DateTime.now().toUtc());
      BackupStartupCheck.resetForTests();
      final bool ran = await BackupStartupCheck.runOnceAfterReady(profileDir: profileDir, backup: backup);
      expect(ran, isFalse);
    });

    test('test_failed_scheduled_backup_remains_due', () async {
      final String profileDir = p.join(tmp.path, 'profiles', 'Fehler');
      Directory(profileDir).createSync(recursive: true);
      await BackupScheduleStore(profileDir: profileDir).saveSchedule(BackupSchedule.daily);
      final BackupService backup = BackupService(profileDir: profileDir);
      final bool ran = await BackupStartupCheck.runOnceAfterReady(profileDir: profileDir, backup: backup);
      expect(ran, isFalse);
      final BackupScheduleState state = await BackupScheduleStore(profileDir: profileDir).load();
      expect(state.lastBackup, isNull);
      expect(state.lastFailureMessage, isNotNull);
    });

    test('test_live_settings_restore_waits_for_restart', () async {
      final String profileDir = makeProfile('Live');
      final BackupService backup = BackupService(profileDir: profileDir);
      final String snapshot = await backup.createLocalBackup();
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      final String liveBefore = await File(p.join(profileDir, 'openinvoices.db'))
          .readAsBytes()
          .then((b) => b.length.toString());
      await coordinator.stageLocalRestore(snapshot);
      expect(coordinator.hasPendingRestore(), isTrue);
      expect(coordinator.gate.isOpen, isFalse);
      final String liveAfter = await File(p.join(profileDir, 'openinvoices.db'))
          .readAsBytes()
          .then((b) => b.length.toString());
      expect(liveAfter, liveBefore);
    });

    test('test_startup_restore_applies_before_opening_the_database', () async {
      final String profileDir = makeProfile('Neustart');
      final BackupService backup = BackupService(profileDir: profileDir);
      final String snapshot = await backup.createLocalBackup();
      final Database live = sqlite3.open(p.join(profileDir, 'openinvoices.db'));
      try {
        live.execute("INSERT INTO t (v) VALUES ('live-change')");
      } finally {
        live.close();
      }
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      await coordinator.stageLocalRestore(snapshot);
      await coordinator.applyPendingBeforeOpen();
      expect(coordinator.hasPendingRestore(), isFalse);
      final Database check = sqlite3.open(p.join(profileDir, 'openinvoices.db'));
      try {
        final ResultSet rows = check.select('SELECT COUNT(*) AS c FROM t');
        expect(rows.single['c'], 1);
      } finally {
        check.close();
      }
    });

    test('test_invalid_restore_does_not_replace_the_database', () async {
      final String profileDir = makeProfile('Ungueltig');
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      final Database before = sqlite3.open(p.join(profileDir, 'openinvoices.db'));
      int countBefore = 0;
      try {
        countBefore = (before.select('SELECT COUNT(*) AS c FROM t').single['c'] as num).toInt();
      } finally {
        before.close();
      }
      await expectLater(coordinator.stageLocalRestore(p.join(profileDir, 'fehlt.db')), throwsStateError);
      final Database after = sqlite3.open(p.join(profileDir, 'openinvoices.db'));
      try {
        expect((after.select('SELECT COUNT(*) AS c FROM t').single['c'] as num).toInt(), countBefore);
      } finally {
        after.close();
      }
      expect(coordinator.hasPendingRestore(), isFalse);
    });

    test('test_startup_replacement_failure_restores_the_prior_database', () async {
      final String profileDir = makeProfile('Rollback');
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      final BackupService backup = BackupService(profileDir: profileDir);
      final String snapshot = await backup.createLocalBackup();
      await coordinator.stageLocalRestore(snapshot);
      await File(p.join(profileDir, 'staged_restore.db')).writeAsBytes(<int>[0, 1, 2, 3]);
      await expectLater(coordinator.applyPendingBeforeOpen(), throwsStateError);
      expect(File(p.join(profileDir, 'openinvoices.db')).existsSync(), isTrue);
    });

    test('test_a_second_process_cannot_open_the_same_profile', () {
      final String profileDir = makeProfile('Sperre');
      final ProfileFileLock lock = ProfileFileLock.acquire(profileDir);
      try {
        expect(File(ProfileFileLock.lockPathFor(profileDir)).existsSync(), isTrue);
        expect(lock.isHeld, isTrue);
      } finally {
        lock.release();
      }
      final ProfileFileLock again = ProfileFileLock.acquire(profileDir);
      again.release();
    });

    test('test_restore_blocks_every_profile_mutation', () async {
      final String profileDir = makeProfile('Gate');
      final BackupService backup = BackupService(profileDir: profileDir);
      final String snapshot = await backup.createLocalBackup();
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      await coordinator.stageLocalRestore(snapshot);
      expect(coordinator.gate.requireOpen, throwsA(isA<ProfileWriteGateBlocked>()));
    });

    test('test_restore_staging_failure_reopens_writes', () async {
      final String profileDir = makeProfile('Offen');
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      expect(coordinator.gate.isOpen, isTrue);
      await expectLater(coordinator.stageLocalRestore(p.join(profileDir, 'fehlt.db')), throwsStateError);
      expect(coordinator.gate.isOpen, isTrue);
    });

    test('test_restore_from_encrypted_backup', () async {
      final String profileDir = makeProfile('Verschluesselt');
      final BackupService backup = BackupService(profileDir: profileDir, externalTargetApproved: true);
      final String external = p.join(tmp.path, 'extern.db');
      final String enc = await backup.createEncryptedBackup(external, 'korrekte-passphrase-123');
      expect(enc.endsWith('.enc'), isTrue);
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      await coordinator.stageEncryptedRestore(enc, 'korrekte-passphrase-123', backup.decryptForRestore);
      expect(coordinator.hasPendingRestore(), isTrue);
    });

    test('test_restore_with_corrupted_encrypted_backup', () async {
      final String profileDir = makeProfile('Korrupt');
      final BackupService backup = BackupService(profileDir: profileDir);
      final String bad = p.join(tmp.path, 'kaputt.enc');
      await File(bad).writeAsBytes(<int>[1, 2, 3, 4, 5]);
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      await expectLater(
        coordinator.stageEncryptedRestore(bad, 'korrekte-passphrase-123', backup.decryptForRestore),
        throwsStateError,
      );
      expect(coordinator.hasPendingRestore(), isFalse);
    });

    test('test_encrypted_backup_with_wrong_passphrase_on_restore', () async {
      final String profileDir = makeProfile('Falsch');
      final BackupService backup = BackupService(profileDir: profileDir, externalTargetApproved: true);
      final String enc = await backup.createEncryptedBackup(p.join(tmp.path, 'falsch.db'), 'korrekte-passphrase-123');
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      await expectLater(
        coordinator.stageEncryptedRestore(enc, 'falsche-passphrase-456', backup.decryptForRestore),
        throwsStateError,
      );
      expect(coordinator.hasPendingRestore(), isFalse);
    });

    test('test_restore_from_local_backup', () async {
      final String profileDir = makeProfile('Lokal');
      final BackupService backup = BackupService(profileDir: profileDir);
      final String snapshot = await backup.createLocalBackup();
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      final RestoreStaged staged = await coordinator.stageLocalRestore(snapshot);
      expect(staged.stagedPath, endsWith('staged_restore.db'));
    });

    test('test_restore_with_missing_backup_file', () async {
      final String profileDir = makeProfile('Fehlt');
      final RestoreCoordinator coordinator = RestoreCoordinator(profileDir: profileDir);
      await expectLater(
        coordinator.stageLocalRestore(p.join(profileDir, 'openinvoices_20990101_000000.db')),
        throwsStateError,
      );
      expect(coordinator.hasPendingRestore(), isFalse);
    });

    test('backup history status distinguishes never current stale and failed', () async {
      final String profileDir = makeProfile('Verlauf');
      final BackupHistoryView never = backupHistoryView(
        const BackupScheduleState(schedule: BackupSchedule.manualOnly),
        DateTime.now().toUtc(),
      );
      expect(never.status, BackupHistoryStatus.never);
      final BackupScheduleStore store = BackupScheduleStore(profileDir: profileDir);
      await store.recordSuccess(DateTime.now().toUtc());
      final BackupHistoryView current = backupHistoryView(await store.load(), DateTime.now().toUtc());
      expect(current.status, BackupHistoryStatus.current);
      await store.recordSuccess(DateTime.now().toUtc().subtract(const Duration(days: 30)));
      final BackupHistoryView stale = backupHistoryView(await store.load(), DateTime.now().toUtc());
      expect(stale.status, BackupHistoryStatus.stale);
      await store.recordFailure('boom');
      final BackupHistoryView failed = backupHistoryView(await store.load(), DateTime.now().toUtc());
      expect(failed.status, BackupHistoryStatus.failed);
    });
  });
}
