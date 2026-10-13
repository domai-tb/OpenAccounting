import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:openaccounting/features/document_delivery/smtp_configuration_service.dart';
import 'package:openaccounting/features/document_delivery/smtp_credential_vault.dart';
import 'package:openaccounting/features/document_delivery/smtp_transport.dart';

void main() {
  group('Unternehmen — SMTP-Konfiguration', () {
    late AppDatabase db;
    late Directory profileDir;
    late FakeSmtpTransport transport;
    late InMemoryVault vault;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runInsert('INSERT INTO unternehmen (id, name) VALUES (?, ?)', <Object?>[1, 'Muster GmbH']);
      profileDir = await Directory.systemTemp.createTemp('smtp-config-test-');
      transport = FakeSmtpTransport();
      vault = InMemoryVault();
      await db.executor.runUpdate(
        'UPDATE unternehmen SET smtp_host = ?, smtp_port = ?, smtp_ssl = ?, smtp_user = ?, '
        'smtp_von_adresse = ? WHERE id = 1',
        <Object?>['mail.example.de', 587, 0, 'rechnungen@example.de', 'rechnungen@example.de'],
      );
    });

    tearDown(() async {
      await db.close();
      try {
        await profileDir.delete(recursive: true);
      } catch (_) {}
    });

    SmtpConfigurationService serviceWith({SmtpCredentialVault? overrideVault, FakeSmtpTransport? overrideTransport}) {
      return SmtpConfigurationService(
        executor: db.executor,
        transport: overrideTransport ?? transport,
        migration: SmtpCredentialMigration(
          vault: overrideVault ?? vault,
          legacyFile: LegacySecretFile(profileDir.path),
          identity: ProfileIdentityStore(profileDir.path),
        ),
      );
    }

    Future<void> storeVaultPassword([String password = 'geheim-passwort-1']) async {
      final SmtpCredentialMigration migration = SmtpCredentialMigration(
        vault: vault,
        legacyFile: LegacySecretFile(profileDir.path),
        identity: ProfileIdentityStore(profileDir.path),
      );
      await migration.vault.write(profileId: await migration.identity.ensureProfileId(), password: password);
    }

    test('test_smtp_test_connection_with_invalid_host', () async {
      await db.executor.runUpdate('UPDATE unternehmen SET smtp_host = ? WHERE id = 1', const <Object?>[
        'invalid.local',
      ]);
      await storeVaultPassword();
      final SmtpConfigurationService service = serviceWith();
      final Stopwatch clock = Stopwatch()..start();
      try {
        await service.testConnection();
        fail('invalid host must fail');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, SmtpFailureKind.hostUnreachable);
      }
      clock.stop();
      expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
      expect(transport.dataCommands, 0);
      expect(transport.commands.any((String c) => c == 'DATA'), isFalse);
    });

    test('test_smtp_test_connection_succeeds', () async {
      await storeVaultPassword();
      final SmtpConnectionTest result = await serviceWith().testConnection();
      expect(result.ok, isTrue);
      expect(result.steps, containsAll(<String>['begruessung', 'ehlo', 'auth']));
      expect(result.steps, contains('ehlo_nach_tls'));
      expect(transport.dataCommands, 0);
      expect(transport.commands.where((String c) => c.startsWith('MAIL')).isEmpty, isTrue);
    });

    test('test_tls_or_credential_failure_is_reported_without_downgrade', () async {
      await storeVaultPassword();
      final FakeSmtpTransport failing = FakeSmtpTransport(
        failTestWith: const DocumentDeliveryException('Zertifikat ungültig', code: SmtpFailureKind.tls),
      );
      try {
        await serviceWith(overrideTransport: failing).testConnection();
        fail('TLS failure must surface');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, SmtpFailureKind.tls);
      }
      expect(failing.dataCommands, 0);

      final FakeSmtpTransport noStarttls = FakeSmtpTransport()..offerStarttls = false;
      try {
        await serviceWith(overrideTransport: noStarttls).testConnection();
        fail('missing STARTTLS must fail without plaintext retry');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, SmtpFailureKind.tls);
      }
      expect(noStarttls.dataCommands, 0);
      expect(noStarttls.commands.any((String c) => c.startsWith('MAIL')), isFalse);
    });

    test('test_legacy_smtp_settings_migrate_securely', () async {
      await db.executor.runUpdate(
        'UPDATE unternehmen SET smtp_ssl = ?, smtp_passwort = ? WHERE id = 1',
        const <Object?>[1, 'legacy-geheim-99'],
      );
      final SmtpMigrationReport report = await serviceWith().migrateBeforeDatabaseOpen();
      expect(report.vaultAvailable, isTrue);
      expect(report.mode, SmtpTransportMode.implicitTls);
      expect(report.passwordMigrated, isTrue);
      final String profileId = await ProfileIdentityStore(profileDir.path).ensureProfileId();
      expect(await vault.read(profileId: profileId), 'legacy-geheim-99');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT smtp_passwort FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      expect(rows.single['smtp_passwort'], isNull);

      final AppDatabase db2 = AppDatabase.createTestDatabase();
      await db2.ensureOpen();
      try {
        await db2.executor.runUpdate('UPDATE unternehmen SET smtp_ssl = ? WHERE id = 1', const <Object?>[0]);
        final Directory profile2 = await Directory.systemTemp.createTemp('smtp-config-test2-');
        try {
          final SmtpConfigurationService second = SmtpConfigurationService(
            executor: db2.executor,
            transport: FakeSmtpTransport(),
            migration: SmtpCredentialMigration(
              vault: InMemoryVault(),
              legacyFile: LegacySecretFile(profile2.path),
              identity: ProfileIdentityStore(profile2.path),
            ),
          );
          final SmtpMigrationReport report2 = await second.migrateBeforeDatabaseOpen();
          expect(report2.mode, SmtpTransportMode.starttlsRequired);
        } finally {
          await profile2.delete(recursive: true);
        }
      } finally {
        await db2.close();
      }
    });

    test('test_legacy_secret_file_migrates_only_after_vault_verification', () async {
      final File secret = File('${profileDir.path}/.smtp_secret');
      await secret.writeAsString('datei-geheim-42', flush: true);
      final SmtpMigrationReport report = await serviceWith().migrateBeforeDatabaseOpen();
      expect(report.passwordMigrated, isTrue);
      expect(report.secretFileRemoved, isTrue);
      expect(secret.existsSync(), isFalse);
      final String profileId = await ProfileIdentityStore(profileDir.path).ensureProfileId();
      expect(await vault.read(profileId: profileId), 'datei-geheim-42');
    });

    test('test_vault_unavailable_during_migration', () async {
      await db.executor.runUpdate('UPDATE unternehmen SET smtp_passwort = ? WHERE id = 1', const <Object?>[
        'einziges-legacy-passwort',
      ]);
      final SmtpMigrationReport report = await serviceWith(overrideVault: const UnavailableVault())
          .migrateBeforeDatabaseOpen();
      expect(report.vaultAvailable, isFalse);
      expect(report.passwordMigrated, isFalse);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT smtp_passwort, smtp_aktiv FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      expect(rows.single['smtp_passwort'], 'einziges-legacy-passwort');
      expect(File('${profileDir.path}/.smtp_secret').existsSync(), isFalse);
    });

    test('test_legacy_password_was_already_cleared', () async {
      final SmtpMigrationReport report = await serviceWith().migrateBeforeDatabaseOpen();
      expect(report.passwordMigrated, isFalse);
      expect(report.note, contains('Neueingabe'));
      try {
        await serviceWith().testConnection();
        fail('cleared password must not authenticate');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, SmtpFailureKind.auth);
      }
    });

    test('test_profile_rename_preserves_the_vault_credential', () async {
      await db.executor.runUpdate('UPDATE unternehmen SET smtp_passwort = ? WHERE id = 1', const <Object?>[
        'umbenannt-geheim',
      ]);
      final SmtpMigrationReport report = await serviceWith().migrateBeforeDatabaseOpen();
      expect(report.passwordMigrated, isTrue);
      final String profileId = report.profileId;

      final Directory renamed = Directory('${profileDir.path}-umbenannt');
      await renamed.create(recursive: true);
      try {
        await File('${profileDir.path}/.profil_id').copy('${renamed.path}/.profil_id');
        final SmtpCredentialMigration afterRename = SmtpCredentialMigration(
          vault: vault,
          legacyFile: LegacySecretFile(renamed.path),
          identity: ProfileIdentityStore(renamed.path),
        );
        expect(await afterRename.identity.ensureProfileId(), profileId);
        expect(await afterRename.readPassword(), 'umbenannt-geheim');
      } finally {
        await renamed.delete(recursive: true);
      }
    });
  });
}
