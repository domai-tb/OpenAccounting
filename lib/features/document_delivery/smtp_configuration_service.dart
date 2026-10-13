import 'package:drift/drift.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:openaccounting/features/document_delivery/smtp_credential_vault.dart';
import 'package:openaccounting/features/document_delivery/smtp_transport.dart';

// Application boundary for SMTP setup: typed connection test (greeting, TLS,
// second EHLO after STARTTLS, AUTH — never MAIL/RCPT/DATA) and vault-first
// legacy migration that runs before AppDatabase schema cleanup can clear the
// legacy password column.

class SmtpConnectionTest {
  const SmtpConnectionTest({required this.ok, required this.steps, required this.detail});

  final bool ok;
  final List<String> steps;
  final String detail;
}

class SmtpMigrationReport {
  const SmtpMigrationReport({
    required this.mode,
    required this.profileId,
    required this.passwordMigrated,
    required this.secretFileRemoved,
    required this.vaultAvailable,
    required this.note,
  });

  final String mode;
  final String profileId;
  final bool passwordMigrated;
  final bool secretFileRemoved;
  final bool vaultAvailable;
  final String note;
}

class SmtpConfigurationService {
  SmtpConfigurationService({required this.executor, required this.transport, required this.migration});

  final QueryExecutor executor;
  final SmtpTransportAdapter transport;
  final SmtpCredentialMigration migration;

  /// Reads the stored SMTP setup and runs the protocol test without sending.
  Future<SmtpConnectionTest> testConnection() async {
    final Map<String, Object?> row = await _readSettingsRow();
    final String? host = row['smtp_host'] as String?;
    if (host == null || host.trim().isEmpty) {
      throw const DocumentDeliveryException('SMTP-Host fehlt', code: SmtpFailureKind.hostUnreachable);
    }
    final SmtpConfig config = _configFromRow(row);
    final String? password = await migration.readPassword();
    if (password == null || password.isEmpty) {
      throw const DocumentDeliveryException('SMTP-Passwort fehlt im Schlüsselspeicher', code: SmtpFailureKind.auth);
    }
    try {
      final SmtpTestReport report = await transport.testConnection(config, password);
      return SmtpConnectionTest(ok: true, steps: report.completedSteps, detail: 'authentifiziert ohne Nachricht');
    } on DocumentDeliveryException {
      rethrow;
    } on SmtpRejected catch (error) {
      throw DocumentDeliveryException('Anmeldung fehlgeschlagen: ${error.reply}', code: SmtpFailureKind.auth);
    }
  }

  /// Pre-database migration: profile ID first, then transport-mode mapping,
  /// then vault-first credential move. Never clears the only legacy source
  /// before vault read-back verification.
  Future<SmtpMigrationReport> migrateBeforeDatabaseOpen() async {
    final String profileId = await migration.identity.ensureProfileId();
    final bool vaultAvailable = await _vaultAvailable(profileId);
    final String mode = await _migrateTransportMode();
    if (!vaultAvailable) {
      await _disableSmtp();
      return SmtpMigrationReport(
        mode: mode,
        profileId: profileId,
        passwordMigrated: false,
        secretFileRemoved: false,
        vaultAvailable: false,
        note: 'Schlüsselspeicher nicht verfügbar; Legacy-Quelle erhalten, SMTP deaktiviert',
      );
    }
    final Map<String, Object?> row = await _readSettingsRow();
    final String? legacyPassword = row['smtp_passwort'] as String?;
    final bool hadSecretFile = await migration.legacyFile.exists();
    String? migrated;
    try {
      migrated = await migration.migrateSecret(legacyPassword, clearLegacy: _clearLegacyPasswordColumn);
    } on VaultUnavailable {
      await _disableSmtp();
      return SmtpMigrationReport(
        mode: mode,
        profileId: profileId,
        passwordMigrated: false,
        secretFileRemoved: false,
        vaultAvailable: false,
        note: 'Schlüsselspeicher-Prüfung fehlgeschlagen; Legacy-Quelle erhalten',
      );
    }
    final bool secretRemoved = hadSecretFile && !(await migration.legacyFile.exists());
    if (migrated == null) {
      final String? stored = await migration.readPassword();
      if (stored == null || stored.isEmpty) {
        await _disableSmtp();
        return SmtpMigrationReport(
          mode: mode,
          profileId: profileId,
          passwordMigrated: false,
          secretFileRemoved: secretRemoved,
          vaultAvailable: true,
          note: 'Kein Passwort vorhanden; SMTP bleibt deaktiviert bis zur Neueingabe',
        );
      }
    }
    return SmtpMigrationReport(
      mode: mode,
      profileId: profileId,
      passwordMigrated: migrated != null,
      secretFileRemoved: secretRemoved,
      vaultAvailable: true,
      note: migrated != null ? 'Legacy-Passwort verifiziert übernommen' : 'Schlüsselspeicher bereits befüllt',
    );
  }

  Future<void> savePassword(String password) async {
    final String profileId = await migration.identity.ensureProfileId();
    await migration.vault.write(profileId: profileId, password: password);
    final String? verified = await migration.vault.read(profileId: profileId);
    if (verified != password) {
      throw const VaultUnavailable('Schlüsselspeicher-Prüfung fehlgeschlagen');
    }
    await _clearLegacyPasswordColumn();
  }

  SmtpConfig _configFromRow(Map<String, Object?> row) {
    final String host = (row['smtp_host'] as String? ?? '').trim();
    final Object? portRaw = row['smtp_port'];
    final int port = portRaw is int ? portRaw : int.tryParse('${portRaw ?? ''}') ?? 587;
    final String? storedMode = row['smtp_transport_modus'] as String?;
    final String mode = storedMode != null && SmtpTransportMode.allowed.contains(storedMode)
        ? storedMode
        : SmtpTransportMode.fromLegacySsl(row['smtp_ssl']);
    return SmtpConfig(
      host: host,
      port: port,
      mode: mode,
      username: (row['smtp_user'] as String? ?? '').trim(),
      sender: (row['smtp_von_adresse'] as String? ?? '').trim(),
      fingerprintSha256: row['smtp_zertifikat_fingerprint'] as String?,
    );
  }

  Future<Map<String, Object?>> _readSettingsRow() async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT smtp_host, smtp_port, smtp_ssl, smtp_user, smtp_passwort, '
        'smtp_von_adresse, smtp_zertifikat_fingerprint, smtp_transport_modus, smtp_aktiv '
        'FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      if (rows.isNotEmpty) return rows.single;
    } catch (_) {
      // Table or new column missing (fresh/legacy profile): fall back below.
    }
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT smtp_host, smtp_port, smtp_ssl, smtp_user, smtp_passwort, '
        'smtp_von_adresse, smtp_zertifikat_fingerprint '
        'FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      if (rows.isNotEmpty) return rows.single;
    } catch (_) {}
    return const <String, Object?>{};
  }

  Future<String> _migrateTransportMode() async {
    try {
      final List<Map<String, Object?>> columns = await executor.runSelect(
        'PRAGMA table_info(unternehmen)',
        const <Object?>[],
      );
      final Set<String> names = <String>{for (final Map<String, Object?> column in columns) '${column['name']}'};
      if (!names.contains('smtp_transport_modus')) {
        await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN smtp_transport_modus TEXT');
      }
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT smtp_ssl, smtp_transport_modus FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      if (rows.isEmpty) return SmtpTransportMode.starttlsRequired;
      final Map<String, Object?> row = rows.single;
      final String? stored = row['smtp_transport_modus'] as String?;
      if (stored != null && SmtpTransportMode.allowed.contains(stored)) return stored;
      final String mapped = SmtpTransportMode.fromLegacySsl(row['smtp_ssl']);
      await executor.runUpdate('UPDATE unternehmen SET smtp_transport_modus = ? WHERE id = 1', <Object?>[mapped]);
      return mapped;
    } catch (_) {
      return SmtpTransportMode.starttlsRequired;
    }
  }

  Future<void> _clearLegacyPasswordColumn() async {
    try {
      await executor.runCustom('UPDATE unternehmen SET smtp_passwort = NULL WHERE smtp_passwort IS NOT NULL');
    } catch (_) {}
  }

  Future<void> _disableSmtp() async {
    try {
      await executor.runUpdate('UPDATE unternehmen SET smtp_aktiv = 0 WHERE id = 1', const <Object?>[]);
    } catch (_) {}
  }

  Future<bool> _vaultAvailable(String profileId) async {
    try {
      await migration.vault.read(profileId: profileId);
      return true;
    } on VaultUnavailable {
      return false;
    } catch (_) {
      return false;
    }
  }
}
