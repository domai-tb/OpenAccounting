import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:openaccounting/core/db/backup_service.dart';
import 'package:openaccounting/core/db/database.dart';

void main() {
  group('BackupService', () {
    late Directory profileDirectory;
    late Directory externalDirectory;
    late AppDatabase database;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_backup_test_');
      externalDirectory = await Directory.systemTemp.createTemp('openaccounting_external_backup_test_');
      database = AppDatabase.forProfile(profileDirectory.path);
      await database.ensureOpen();
    });

    tearDown(() async {
      await database.close();
      await profileDirectory.delete(recursive: true);
      await externalDirectory.delete(recursive: true);
    });

    test('creates a restorable backup containing committed data', () async {
      await database.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-260001', 'rechnung', '2026-01-01')",
      );
      final service = BackupService(profileDir: profileDirectory.path);

      final backupPath = await service.createLocalBackup();
      final backup = sqlite3.open(backupPath, mode: OpenMode.readOnly);
      try {
        final rows = backup.select('SELECT rechnungsnummer FROM rechnungen');
        expect(rows, hasLength(1));
        expect(rows.single['rechnungsnummer'], 'RE-260001');
      } finally {
        backup.close();
      }
    });

    test('retains only the five newest local backups', () async {
      final service = BackupService(profileDir: profileDirectory.path);

      for (var index = 0; index < BackupService.maxBackups + 1; index++) {
        await service.createLocalBackup();
      }

      final backups = await Directory(service.backupDir)
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.db'))
          .toList();
      expect(backups, hasLength(BackupService.maxBackups));
    });

    test('encrypted backups store a versioned salt and IV header', () async {
      final service = BackupService(profileDir: profileDirectory.path, externalTargetApproved: true);

      final firstPath = await service.createEncryptedBackup('${externalDirectory.path}/external-a', 'secret');
      final secondPath = await service.createEncryptedBackup('${externalDirectory.path}/external-b', 'secret');
      final first = await File(firstPath).readAsBytes();
      final second = await File(secondPath).readAsBytes();

      expect(first.take(8).toList(), <int>[79, 65, 66, 75, 48, 48, 48, 49]);
      expect(first.length, greaterThan(40));
      expect(first.sublist(8, 24), isNot(equals(second.sublist(8, 24))));
    });

    test('restores a local backup atomically', () async {
      await database.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-ORIGINAL', 'rechnung', '2026-01-01')",
      );
      final service = BackupService(profileDir: profileDirectory.path);
      final backupPath = await service.createLocalBackup();
      final backup = sqlite3.open(backupPath, mode: OpenMode.readOnly);
      expect(backup.select('SELECT rechnungsnummer FROM rechnungen').single['rechnungsnummer'], 'RE-ORIGINAL');
      backup.close();
      await database.executor.runCustom("UPDATE rechnungen SET rechnungsnummer = 'RE-CHANGED' WHERE id = 1");
      final activeDbPath = p.join(profileDirectory.path, 'openinvoices.db');
      expect(File('$activeDbPath-wal').existsSync(), isTrue, reason: 'diagnostic: expected active WAL before close');
      await database.close();
      await service.restoreFromBackup(backupPath, activeDbPath);

      final restored = sqlite3.open(p.join(profileDirectory.path, 'openinvoices.db'), mode: OpenMode.readOnly);
      try {
        final rows = restored.select('SELECT rechnungsnummer FROM rechnungen');
        expect(rows.single['rechnungsnummer'], 'RE-ORIGINAL');
      } finally {
        restored.close();
      }
    });

    test('wrong encrypted passphrase leaves active database unchanged', () async {
      await database.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-ORIGINAL', 'rechnung', '2026-01-01')",
      );
      final service = BackupService(profileDir: profileDirectory.path, externalTargetApproved: true);
      final encryptedPath = await service.createEncryptedBackup('${externalDirectory.path}/external', 'secret');
      await database.executor.runCustom("UPDATE rechnungen SET rechnungsnummer = 'RE-CHANGED' WHERE id = 1");

      await expectLater(
        service.restoreEncrypted(encryptedPath, 'wrong', p.join(profileDirectory.path, 'openinvoices.db')),
        throwsA(isA<StateError>()),
      );

      final active = sqlite3.open(p.join(profileDirectory.path, 'openinvoices.db'), mode: OpenMode.readOnly);
      try {
        final rows = active.select('SELECT rechnungsnummer FROM rechnungen');
        expect(rows.single['rechnungsnummer'], 'RE-CHANGED');
      } finally {
        active.close();
      }
    });

    test('restores an encrypted backup with the correct passphrase', () async {
      await database.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-ORIGINAL', 'rechnung', '2026-01-01')",
      );
      final service = BackupService(profileDir: profileDirectory.path, externalTargetApproved: true);
      final encryptedPath = await service.createEncryptedBackup('${externalDirectory.path}/external', 'secret');
      await database.executor.runCustom("UPDATE rechnungen SET rechnungsnummer = 'RE-CHANGED' WHERE id = 1");
      final activeDbPath = p.join(profileDirectory.path, 'openinvoices.db');
      expect(File('$activeDbPath-wal').existsSync(), isTrue, reason: 'diagnostic: expected active WAL before close');
      await database.close();
      await service.restoreEncrypted(encryptedPath, 'secret', activeDbPath);

      final restored = sqlite3.open(p.join(profileDirectory.path, 'openinvoices.db'), mode: OpenMode.readOnly);
      try {
        final rows = restored.select('SELECT rechnungsnummer FROM rechnungen');
        expect(rows.single['rechnungsnummer'], 'RE-ORIGINAL');
      } finally {
        restored.close();
      }
    });

    test('persists last backup time for scheduled backup checks', () async {
      final service = BackupService(profileDir: profileDirectory.path);

      expect(await service.isScheduledDue(), isTrue);
      await service.createLocalBackup();

      expect(File(p.join(profileDirectory.path, 'backup_state.json')).existsSync(), isTrue);
      expect(await service.isScheduledDue(), isFalse);
    });

    test('uploads a verified backup through the SMB writer boundary', () async {
      String? uploadedUrl;
      String? uploadedRemotePath;
      int uploadedLength = 0;
      final service = BackupService(
        profileDir: profileDirectory.path,
        externalTargetApproved: true,
        smbWriter: (url, username, password, remotePath, bytes) async {
          uploadedUrl = url;
          uploadedRemotePath = remotePath;
          uploadedLength = bytes.length;
          expect(username, 'user');
          expect(password, 'password');
        },
      );

      final result = await service.createSmbBackup('smb://server/share/backups', 'user', 'password');

      expect(uploadedUrl, 'smb://server/share/backups');
      expect(uploadedRemotePath, startsWith('/share/backups/openinvoices_'));
      expect(uploadedRemotePath, endsWith('.db'));
      expect(uploadedLength, greaterThan(100));
      expect(result, startsWith('smb://server/share/backups/openinvoices_'));
    });

    test('rejects system-drive encrypted backup without explicit override', () async {
      final service = BackupService(profileDir: profileDirectory.path, externalTargetApproved: true);

      await expectLater(service.createEncryptedBackup('/', 'secret'), throwsA(isA<StateError>()));
    });

    test('requires explicit approval for external backup targets', () async {
      final service = BackupService(profileDir: profileDirectory.path);

      await expectLater(
        service.createEncryptedBackup('${profileDirectory.path}/external', 'secret'),
        throwsA(isA<StateError>()),
      );
      await expectLater(service.createSmbBackup('smb://server/share', 'user', 'password'), throwsA(isA<StateError>()));
    });

    test('rejects approved external path inside active APP_DATA_DIR', () async {
      final service = BackupService(profileDir: profileDirectory.path, externalTargetApproved: true);

      await expectLater(
        service.createEncryptedBackup(p.join(profileDirectory.path, 'inside'), 'secret'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects corrupted encrypted backup without replacing active database', () async {
      await database.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-ORIGINAL', 'rechnung', '2026-01-01')",
      );
      final service = BackupService(profileDir: profileDirectory.path, externalTargetApproved: true);
      final encryptedPath = await service.createEncryptedBackup('${externalDirectory.path}/external', 'secret');
      final corrupted = await File(encryptedPath).readAsBytes();
      corrupted[corrupted.length - 1] ^= 1;
      await File(encryptedPath).writeAsBytes(corrupted, flush: true);

      await expectLater(
        service.restoreEncrypted(encryptedPath, 'secret', p.join(profileDirectory.path, 'openinvoices.db')),
        throwsA(isA<StateError>()),
      );
      final active = sqlite3.open(p.join(profileDirectory.path, 'openinvoices.db'), mode: OpenMode.readOnly);
      try {
        expect(active.select('SELECT rechnungsnummer FROM rechnungen').single['rechnungsnummer'], 'RE-ORIGINAL');
      } finally {
        active.close();
      }
    });

    test('missing local backup leaves active database unchanged', () async {
      await database.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-ORIGINAL', 'rechnung', '2026-01-01')",
      );
      final service = BackupService(profileDir: profileDirectory.path);
      final activeDbPath = p.join(profileDirectory.path, 'openinvoices.db');

      await expectLater(
        service.restoreFromBackup(p.join(externalDirectory.path, 'missing.db'), activeDbPath),
        throwsA(isA<StateError>()),
      );
      final active = sqlite3.open(activeDbPath, mode: OpenMode.readOnly);
      try {
        expect(active.select('SELECT rechnungsnummer FROM rechnungen').single['rechnungsnummer'], 'RE-ORIGINAL');
      } finally {
        active.close();
      }
    });

    test('maps SMB writer failures without exposing credentials', () async {
      var writerCalled = false;
      final service = BackupService(
        profileDir: profileDirectory.path,
        externalTargetApproved: true,
        smbWriter: (url, username, password, remotePath, bytes) async {
          writerCalled = true;
          throw StateError('authentication failed for $username:$password');
        },
      );

      await expectLater(
        service.createSmbBackup('smb://server/share', 'user', 'password'),
        throwsA(predicate<Object>((error) => error.toString() == 'Bad state: SMB-Backup fehlgeschlagen')),
      );
      expect(writerCalled, isTrue);
    });
  });
}
