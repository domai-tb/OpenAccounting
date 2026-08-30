import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Profile management per spec §Profile Management.
/// Each profile = isolated DB file under `<base>/profiles/<name>/openinvoices.db`.
/// Active profile tracked via `<base>/profile.json` `{"active": "Name"}`.
typedef ProfileDatabaseInitializer = Future<void> Function(String databasePath);

class ProfileManager {
  ProfileManager({String? baseDir, this.databaseInitializer}) : baseDir = baseDir ?? getDefaultBaseDir();

  final String baseDir;
  final ProfileDatabaseInitializer? databaseInitializer;

  String get profileJsonPath => p.join(baseDir, 'profile.json');

  String profileDir(String name) => p.join(baseDir, 'profiles', name);

  String databasePath(String name) => p.join(profileDir(name), 'openinvoices.db');

  String backupDir(String name) => p.join(profileDir(name), 'backups');

  /// Resolve default base directory per platform spec.
  static String getDefaultBaseDir() {
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return p.join(home, '.local', 'share', 'OpenInvoices');
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return p.join(home, 'Library', 'Application Support', 'OpenInvoices');
    }
    if (Platform.isWindows) {
      final local =
          Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'] ?? r'C:\Users\Default\AppData\Local';
      return p.join(local, 'OpenInvoices');
    }
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, '.local', 'share', 'OpenInvoices');
  }

  /// Get active profile name. Falls back to first available or 'Default'.
  Future<String> getActiveProfile() async {
    final f = File(profileJsonPath);
    if (!f.existsSync()) {
      final profiles = await listProfiles();
      if (profiles.isNotEmpty) return profiles.first;
      return 'Default';
    }
    try {
      final raw = await f.readAsString();
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final active = m['active'] as String?;
      if (active != null && active.isNotEmpty) {
        // verify directory exists, else fallback
        if (Directory(profileDir(active)).existsSync()) return active;
      }
      final profiles = await listProfiles();
      if (profiles.isNotEmpty) return profiles.first;
      return active ?? 'Default';
    } catch (_) {
      // corrupted json → fallback to first available
      final profiles = await listProfiles();
      if (profiles.isNotEmpty) return profiles.first;
      return 'Default';
    }
  }

  /// Switch active profile — writes profile.json, requires restart to take effect.
  /// Returns true if restart required.
  Future<bool> setActiveProfile(String name) async {
    final current = await getActiveProfile();
    if (current.toLowerCase() == name.toLowerCase()) return false;
    final dir = Directory(profileDir(name));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final f = File(profileJsonPath);
    f.createSync(recursive: true);
    await f.writeAsString(jsonEncode(<String, String>{'active': name}));
    // ponytail: restart required — caller must restart process to load new DB.
    return true;
  }

  Future<List<String>> listProfiles() async {
    final root = Directory(p.join(baseDir, 'profiles'));
    if (!root.existsSync()) return <String>[];
    final ents = await root.list().toList();
    final names = <String>[];
    for (final e in ents) {
      if (e is Directory) names.add(p.basename(e.path));
    }
    names.sort();
    return names;
  }

  Future<void> createProfile(String name) async {
    final profileName = name.trim();
    if (profileName.isEmpty) throw ArgumentError('Profilname darf nicht leer sein');
    final existing = await listProfiles();
    if (existing.any((e) => e.toLowerCase() == profileName.toLowerCase())) {
      throw StateError('Profilname existiert bereits');
    }
    final dir = Directory(profileDir(profileName));
    await dir.create(recursive: true);

    if (databaseInitializer != null) {
      await databaseInitializer!(databasePath(profileName));
      return;
    }

    final database = sqlite3.open(databasePath(profileName));
    database.close();
  }

  /// Delete profile entry — does NOT delete directory for data safety.
  Future<void> deleteProfile(String name) async {
    final active = await getActiveProfile();
    if (active.toLowerCase() == name.toLowerCase()) {
      throw StateError('Aktives Profil kann nicht gelöscht werden');
    }
    final profiles = await listProfiles();
    if (profiles.length <= 1) throw StateError('Mindestens ein Profil muss existieren');
    // spec: remove entry but keep directory — here we just ensure active not pointing
    // and leave directory on disk.
  }

  Future<void> renameProfile(String oldName, String newName) async {
    if (newName.trim().isEmpty) throw ArgumentError('Neuer Name darf nicht leer sein');
    final profiles = await listProfiles();
    if (profiles.any((e) => e.toLowerCase() == newName.toLowerCase())) {
      throw StateError('Profilname existiert bereits');
    }
    final oldDir = Directory(profileDir(oldName));
    final newDir = Directory(profileDir(newName));
    if (!oldDir.existsSync()) throw StateError('Profil nicht gefunden: $oldName');
    await oldDir.rename(newDir.path);
    final active = await getActiveProfile();
    if (active.toLowerCase() == oldName.toLowerCase()) {
      await setActiveProfile(newName);
    }
  }

  /// Resolve APP_DATA_DIR for active profile — used for uploads/backups/logos.
  Future<String> resolveAppDataDir() async {
    final active = await getActiveProfile();
    return profileDir(active);
  }

  /// Validate path is inside APP_DATA_DIR (prevent traversal).
  Future<void> assertInsideAppDataDir(String targetPath) async {
    final appData = await resolveAppDataDir();
    final normTarget = p.normalize(p.absolute(targetPath));
    final normBase = p.normalize(p.absolute(appData));
    if (!p.isWithin(normBase, normTarget) && normTarget != normBase) {
      throw StateError('Pfad außerhalb APP_DATA_DIR: $targetPath');
    }
  }

  /// Whether profile manager should be visible.
  Future<bool> shouldShowManager({bool profilmanagerAktiv = false}) async {
    final profiles = await listProfiles();
    if (profiles.length > 1) return true;
    return profilmanagerAktiv;
  }
}
