// ignore_for_file: file_names, avoid_redundant_argument_values, prefer_const_constructors
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:openaccounting/core/db/backup_service.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/desktop/desktop_updater.dart';
import 'package:openaccounting/pages/stammdaten/unternehmen_repository.dart';

class _FakeBackend implements UpdateBackend {
  _FakeBackend({this.verifyResult = true});
  final bool verifyResult;
  final List<String> downloaded = <String>[];
  @override
  Future<Map<String, dynamic>?> fetchLatestRelease() async => <String, dynamic>{
    'tag_name': 'v2.0.0',
    'url': 'https://example.com/v2.zip',
    'signature': 'valid-sig',
  };
  @override
  Future<void> download(String url, void Function(double) onProgress) async {
    downloaded.add(url);
    onProgress(1);
  }

  @override
  Future<bool> verifySignature(String version, String signature) async => verifyResult;
  @override
  Future<void> installAndRestart() async {}
}

void main() {
  group('infra-hardening', () {
    test('infra_hardening_1_backup_gate_rejects_active_transaction_and_uses_atomic_replace', () async {
      final Directory profileDir = await Directory.systemTemp.createTemp('infra-backup-gate-');
      addTearDown(() async {
        try {
          await profileDir.delete(recursive: true);
        } catch (_) {}
      });
      final AppDatabase db = AppDatabase.forProfile(profileDir.path);
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, datum) VALUES ('RE-INFRA-1', 'rechnung', '2026-01-01')",
      );
      final BackupService service = BackupService(profileDir: profileDir.path, executor: db.executor);

      // Hold an active transaction — backup must require maintenance window.
      await db.executor.runCustom('BEGIN IMMEDIATE');
      await expectLater(
        service.createLocalBackup(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Wartungsfenster'))),
      );
      await db.executor.runCustom('ROLLBACK');

      // After rollback, backup succeeds and uses staged atomic replace.
      final String backupPath = await service.createLocalBackup();
      expect(File(backupPath).existsSync(), isTrue);
      expect(FileSystemEntity.typeSync(backupPath, followLinks: false), FileSystemEntityType.file);
      expect(backupPath.contains('.backup-'), isFalse, reason: 'Staged temp must be atomically replaced');
      final List<FileSystemEntity> backups = await Directory(service.backupDir).list().toList();
      expect(
        backups.where((e) => p.basename(e.path).contains('.backup-')).isEmpty,
        isTrue,
        reason: 'No staged temp left behind',
      );
      // Validate sqlite file
      final Database check = sqlite3.open(backupPath, mode: OpenMode.readOnly);
      try {
        final rows = check.select('SELECT rechnungsnummer FROM rechnungen WHERE rechnungsnummer = ?', <Object?>[
          'RE-INFRA-1',
        ]);
        expect(rows, hasLength(1));
      } finally {
        check.close();
      }

      // no-follow: backup dir symlink must be rejected
      final Directory backupDir = Directory(service.backupDir);
      // move real dir aside, create symlink in its place
      final Directory real = Directory('${profileDir.path}/backups-real');
      await backupDir.rename(real.path);
      final Link link = Link(service.backupDir);
      await link.create(real.path);
      addTearDown(() async {
        try {
          await link.delete();
        } catch (_) {}
        try {
          await real.rename(service.backupDir);
        } catch (_) {}
      });
      await expectLater(
        service.createLocalBackup(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('symbolischer Link'))),
      );
    });

    test('infra_hardening_2_smtp_plaintext_cleared_and_secret_in_file_store', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(db.close);

      // Seed legacy plaintext directly in DB, bypassing repo guard.
      await db.executor.runCustom('INSERT OR IGNORE INTO unternehmen (id, name) VALUES (1, ?)', const <Object?>[
        'Test Firma',
      ]);
      await db.executor.runCustom('UPDATE unternehmen SET smtp_passwort = ? WHERE id = 1', <Object?>[
        'legacy-plaintext-123',
      ]);
      final List<Map<String, Object?>> before = await db.executor.runSelect(
        'SELECT smtp_passwort FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      expect(before.single['smtp_passwort'], 'legacy-plaintext-123');

      // ensureSchema must clear it
      final UnternehmenRepository repo = UnternehmenRepository(db.executor);
      await repo.ensureSchema();
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT smtp_passwort FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      expect(after.single['smtp_passwort'], isNull, reason: 'Migration must clear legacy plaintext');

      // Repo update with smtp_passwort must still throw (no DB write)
      await expectLater(
        repo.update(<String, dynamic>{'smtp_passwort': 'should-fail'}),
        throwsA(isA<UnternehmenException>()),
      );

      // File-backed secret store (OS keychain ceiling via 600 file)
      final Directory tmp = await Directory.systemTemp.createTemp('infra-smtp-secret-');
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });
      final UnternehmenRepository repo2 = UnternehmenRepository(db.executor, profileDir: tmp.path);
      await repo2.ensureSchema();
      await repo2.setSmtpPassword('super-secret-98765');
      final String? stored = await repo2.getSmtpPassword();
      expect(stored, 'super-secret-98765');
      // DB still null
      final List<Map<String, Object?>> stillNull = await db.executor.runSelect(
        'SELECT smtp_passwort FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      expect(stillNull.single['smtp_passwort'], isNull);
      // File exists, not a symlink, not logged as plaintext elsewhere
      final File secretFile = File(p.join(tmp.path, '.smtp_secret'));
      expect(secretFile.existsSync(), isTrue);
      expect(FileSystemEntity.typeSync(secretFile.path, followLinks: false), FileSystemEntityType.file);
      // Ensure _selectSafeRows never returns smtp_passwort
      final Unternehmen u = await repo2.get();
      expect(u.data.containsKey('smtp_passwort'), isFalse);

      await repo2.clearSmtpPassword();
      expect(await repo2.getSmtpPassword(), isNull);
      expect(secretFile.existsSync(), isFalse);
    });

    test('infra_hardening_3_updater_sig_verification_enforced_or_adr_documents_removal', () async {
      // Backend deny-all
      final GithubUpdateBackend backend = GithubUpdateBackend();
      expect(await backend.verifySignature('1.0.0', 'any-sig'), isFalse);
      expect(await backend.verifySignature('1.0.0', ''), isFalse);

      // Service binding: download + verify fails when backend denies
      final _FakeBackend fakeDeny = _FakeBackend(verifyResult: false);
      final DesktopUpdaterService denyService = DesktopUpdaterServiceImpl(
        backend: fakeDeny,
        currentVersion: '1.0.0',
        enabled: true,
      );
      const UpdateInfo info = UpdateInfo(version: 'v2.0.0', url: 'https://example.com/v2.zip', signature: 'valid-sig');
      await expectLater(
        denyService.downloadUpdate(info, (_) {}),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Signatur'))),
      );
      expect(await denyService.verifySignature(info), isFalse);
      await expectLater(denyService.installAndRestart(), throwsA(isA<StateError>()));

      // Service success only when backend verifies and binding matches
      final _FakeBackend fakeOk = _FakeBackend(verifyResult: true);
      final DesktopUpdaterService okService = DesktopUpdaterServiceImpl(
        backend: fakeOk,
        currentVersion: '1.0.0',
        enabled: true,
      );
      // need checkForUpdate to get info that matches downloaded binding
      // Directly use same info
      await okService.downloadUpdate(info, (_) {});
      await okService.installAndRestart();
      expect(fakeOk.downloaded, const <String>['https://example.com/v2.zip']);

      // Empty signature must be rejected without calling backend
      final _FakeBackend fakeShouldNotBeCalled = _FakeBackend(verifyResult: true);
      final DesktopUpdaterService svc2 = DesktopUpdaterServiceImpl(
        backend: fakeShouldNotBeCalled,
        currentVersion: '1.0.0',
        enabled: true,
      );
      // Manually set downloaded to test empty sig path
      const UpdateInfo emptySig = UpdateInfo(version: 'v2.0.0', url: 'https://example.com/v2.zip', signature: '');
      // download will fail due to empty sig via verifySignature path
      await expectLater(svc2.downloadUpdate(emptySig, (_) {}), throwsA(isA<StateError>()));

      // ADR documents the deferral/removal
      final File adr = File('docs/adr/001-desktop-updater-trust.md');
      expect(adr.existsSync(), isTrue, reason: 'ADR must document sig verification or removal');
      final String adrText = await adr.readAsString();
      expect(adrText, contains('deny-all'));
      expect(adrText, contains('Ed25519'));
      expect(adrText, contains('ponytail'));

      // Real file also blocks install without verified artifact
      final GithubUpdateBackend realBackend = GithubUpdateBackend();
      expect(realBackend.installAndRestart, isA<Function>());
      await expectLater(realBackend.installAndRestart(), throwsA(isA<StateError>()));
    });
  });
}
