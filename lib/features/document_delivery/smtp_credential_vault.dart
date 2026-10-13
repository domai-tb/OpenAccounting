import 'dart:io';

import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:path/path.dart' as p;

// OS-vault boundary: credentials are keyed by immutable profile ID (never by
// mutable name/path) so profile rename preserves access. No new plaintext
// copies are ever written; legacy sources are removed only after vault
// read-back verification. Production default is [UnavailableVault] until a
// maintained OS-vault plugin is added (no new dependencies in this change).

/// Maintained-adapter seam for macOS Keychain / Windows Credential Manager /
/// Linux Secret Service. Tests and embedders inject their implementation.
abstract class SmtpCredentialVault {
  Future<void> write({required String profileId, required String password});
  Future<String?> read({required String profileId});
  Future<void> remove({required String profileId});
}

/// Vault is locked or has no platform backend: SMTP stays disabled and the
/// only legacy source is preserved for a later migration retry.
class VaultUnavailable implements Exception {
  const VaultUnavailable([this.message = 'Schlüsselspeicher nicht verfügbar']);

  final String message;

  @override
  String toString() => message;
}

/// Production default until an OS-vault plugin lands: every operation reports
/// unavailable so SMTP is clearly disabled instead of falling back to files.
class UnavailableVault implements SmtpCredentialVault {
  const UnavailableVault();

  @override
  Future<void> write({required String profileId, required String password}) async {
    throw const VaultUnavailable();
  }

  @override
  Future<String?> read({required String profileId}) async {
    throw const VaultUnavailable();
  }

  @override
  Future<void> remove({required String profileId}) async {
    throw const VaultUnavailable();
  }
}

/// Test/fake vault: process-local map keyed by profile ID.
class InMemoryVault implements SmtpCredentialVault {
  InMemoryVault();

  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> write({required String profileId, required String password}) async {
    if (password.isEmpty) {
      throw const DocumentDeliveryException('SMTP-Passwort darf nicht leer sein', code: 'passwort_leer');
    }
    _store[profileId] = password;
  }

  @override
  Future<String?> read({required String profileId}) async => _store[profileId];

  @override
  Future<void> remove({required String profileId}) async {
    _store.remove(profileId);
  }
}

/// Read-only view of the legacy `.smtp_secret` file for migration recovery.
/// Never writes; deletion happens only via [SmtpCredentialMigration] after
/// vault read-back verification.
class LegacySecretFile {
  const LegacySecretFile(this.profileDir);

  final String? profileDir;

  String? get path {
    if (profileDir == null || profileDir!.trim().isEmpty) return null;
    return p.join(profileDir!, '.smtp_secret');
  }

  Future<String?> read() async {
    final String? filePath = path;
    if (filePath == null) return null;
    final File file = File(filePath);
    if (!file.existsSync()) return null;
    if (FileSystemEntity.typeSync(filePath, followLinks: false) != FileSystemEntityType.file) return null;
    try {
      final String resolved = await file.resolveSymbolicLinks();
      if (p.normalize(p.absolute(resolved)) != p.normalize(p.absolute(filePath))) return null;
    } catch (_) {
      return null;
    }
    final String value = await file.readAsString();
    return value.isEmpty ? null : value;
  }

  Future<bool> exists() async {
    final String? filePath = path;
    if (filePath == null) return false;
    return File(filePath).existsSync() &&
        FileSystemEntity.typeSync(filePath, followLinks: false) == FileSystemEntityType.file;
  }
}

/// Immutable per-profile identity persisted once under the profile directory.
/// The file moves with a profile rename, so the vault key is stable.
class ProfileIdentityStore {
  const ProfileIdentityStore(this.profileDir);

  final String? profileDir;

  String? get path {
    if (profileDir == null || profileDir!.trim().isEmpty) return null;
    return p.join(profileDir!, '.profil_id');
  }

  /// Returns the stored ID, creating and persisting one on first call.
  Future<String> ensureProfileId() async {
    final String? filePath = path;
    if (filePath == null) return 'profil-ohne-verzeichnis';
    final File file = File(filePath);
    if (file.existsSync() && FileSystemEntity.typeSync(filePath, followLinks: false) == FileSystemEntityType.file) {
      final String stored = (await file.readAsString()).trim();
      if (stored.isNotEmpty) return stored;
    }
    final String created = '${DateTime.now().toUtc().microsecondsSinceEpoch}-${(storedFallback++).toRadixString(16)}';
    await Directory(p.dirname(filePath)).create(recursive: true);
    await file.writeAsString(created, flush: true);
    return created;
  }

  static int storedFallback = 0;
}

/// Vault-first migration: write legacy value, read it back, verify equality,
/// then remove the old copy. On vault failure the legacy source is preserved
/// and SMTP stays disabled; nothing new is written to plaintext.
class SmtpCredentialMigration {
  SmtpCredentialMigration({required this.vault, required this.legacyFile, required this.identity});

  final SmtpCredentialVault vault;
  final LegacySecretFile legacyFile;
  final ProfileIdentityStore identity;

  /// Migrates one legacy secret. Returns the migrated value, or null when
  /// there was nothing to migrate. Throws [VaultUnavailable] without touching
  /// the legacy source when the vault cannot be used or verified.
  Future<String?> migrateSecret(String? legacyValue, {required Future<void> Function() clearLegacy}) async {
    final String? fileValue = await legacyFile.read();
    final String? source = _firstNonEmpty(legacyValue, fileValue);
    if (source == null) return null;
    final String profileId = await identity.ensureProfileId();
    try {
      await vault.write(profileId: profileId, password: source);
      final String? verified = await vault.read(profileId: profileId);
      if (verified != source) {
        throw const VaultUnavailable('Schlüsselspeicher-Prüfung fehlgeschlagen');
      }
    } on VaultUnavailable {
      rethrow;
    } catch (error) {
      throw VaultUnavailable('Schlüsselspeicher-Fehler: $error');
    }
    await clearLegacy();
    final String? filePath = legacyFile.path;
    if (filePath != null) {
      try {
        final File file = File(filePath);
        if (file.existsSync() && FileSystemEntity.typeSync(filePath, followLinks: false) == FileSystemEntityType.file) {
          await file.delete();
        }
      } catch (_) {}
    }
    return source;
  }

  Future<String?> readPassword() async {
    try {
      return await vault.read(profileId: await identity.ensureProfileId());
    } on VaultUnavailable {
      return null;
    }
  }

  static String? _firstNonEmpty(String? a, String? b) {
    if (a != null && a.isNotEmpty) return a;
    if (b != null && b.isNotEmpty) return b;
    return null;
  }
}
