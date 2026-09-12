import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:openaccounting/core/db/data_paths.dart';
import 'package:openaccounting/core/db/profile_database.dart';

/// Profile management per spec §Profile Management.
/// Each profile = isolated DB file under `<base>/profiles/<name>/openinvoices.db`.
/// Active profile tracked via `<base>/profile.json` `{"active": "Name"}`.
typedef ProfileDatabaseInitializer = Future<void> Function(String databasePath);

class ProfileManager {
  ProfileManager({String? baseDir, ProfileDatabaseInitializer? databaseInitializer})
    : baseDir = baseDir ?? getDefaultBaseDir(),
      databaseInitializer = databaseInitializer ?? initializeProfileDatabase;

  final String baseDir;
  final ProfileDatabaseInitializer databaseInitializer;

  String get profileJsonPath => p.join(baseDir, 'profile.json');

  String profileDir(String name) => p.join(baseDir, 'profiles', _validateProfileName(name));

  String _validateProfileName(String name) {
    _assertSafeRoots();
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '..' || trimmed.contains(RegExp(r'[/\\]'))) {
      throw ArgumentError('Ungültiger Profilname');
    }
    final root = p.absolute(p.join(baseDir, 'profiles'));
    final target = p.absolute(p.join(root, trimmed));
    if (target == root || !p.isWithin(root, target)) {
      throw ArgumentError('Ungültiger Profilname');
    }
    return trimmed;
  }

  String databasePath(String name) => p.join(profileDir(name), 'openinvoices.db');

  String backupDir(String name) => p.join(profileDir(name), 'backups');

  /// Resolve default base directory per platform spec.
  static String getDefaultBaseDir() {
    return resolveDefaultBaseDir();
  }

  /// Get active profile name. Requires explicit recovery when several profiles
  /// exist but the durable pointer is absent or invalid.
  Future<String> getActiveProfile() async {
    _assertSafeRoots();
    final f = File(profileJsonPath);
    final profiles = await listProfiles();
    if (!f.existsSync()) {
      return _recoverableProfile(profiles);
    }
    try {
      final raw = await f.readAsString();
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final active = m['active'] as String?;
      if (active != null && active.isNotEmpty) {
        // Verify the pointer before opening a database. An invalid pointer is
        // recovered through explicit selection below.
        final String activePath = profileDir(active);
        if (FileSystemEntity.typeSync(activePath, followLinks: false) == FileSystemEntityType.directory) {
          return active;
        }
      }
      return _recoverableProfile(profiles);
    } on ProfileSelectionRequiredException {
      rethrow;
    } catch (error, stackTrace) {
      if (profiles.length <= 1) return _recoverableProfile(profiles);
      Error.throwWithStackTrace(
        ProfileSelectionRequiredException('Aktives Profil ist beschädigt; bitte ein Profil auswählen', cause: error),
        stackTrace,
      );
    }
  }

  /// Switch active profile — writes profile.json, requires restart to take effect.
  /// Returns true if restart required.
  Future<bool> setActiveProfile(String name) async {
    final String profileName = _validateProfileName(name);
    String? current;
    try {
      current = await getActiveProfile();
    } on ProfileSelectionRequiredException {
      // An explicit user selection is also the recovery action for a torn
      // pointer, so continue with the requested profile.
    }
    if (current?.toLowerCase() == profileName.toLowerCase()) return false;
    final dir = Directory(profileDir(profileName));
    final FileSystemEntityType type = FileSystemEntity.typeSync(dir.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw StateError('Profilpfad darf kein symbolischer Link sein');
    }
    if (type != FileSystemEntityType.directory) {
      await dir.create(recursive: true);
    }
    final File f = File(profileJsonPath);
    await f.parent.create(recursive: true);
    final String staged = '${f.path}.tmp-${DateTime.now().microsecondsSinceEpoch}';
    await File(staged).writeAsString(jsonEncode(<String, String>{'active': profileName}), flush: true);
    await File(staged).rename(f.path);
    // ponytail: restart required — caller must restart process to load new DB.
    return true;
  }

  Future<List<String>> listProfiles() async {
    _assertSafeRoots();
    final root = Directory(p.join(baseDir, 'profiles'));
    if (!root.existsSync()) return <String>[];
    final ents = await root.list().toList();
    final names = <String>[];
    for (final e in ents) {
      if (e is Directory && FileSystemEntity.typeSync(e.path, followLinks: false) == FileSystemEntityType.directory) {
        names.add(p.basename(e.path));
      }
    }
    names.sort();
    return names;
  }

  Future<void> createProfile(String name) async {
    final profileName = name.trim();
    if (profileName.isEmpty) {
      throw ArgumentError('Profilname darf nicht leer sein');
    }
    final existing = await listProfiles();
    if (existing.any((e) => e.toLowerCase() == profileName.toLowerCase())) {
      throw StateError('Profilname existiert bereits');
    }
    final dir = Directory(profileDir(profileName));
    if (FileSystemEntity.typeSync(dir.path, followLinks: false) == FileSystemEntityType.link) {
      throw StateError('Profilpfad darf kein symbolischer Link sein');
    }
    await dir.create(recursive: true);

    await databaseInitializer(databasePath(profileName));
  }

  /// Delete profile — removes directory and all data.
  /// Cannot delete the active profile or the last remaining profile.
  Future<void> deleteProfile(String name) async {
    final active = await getActiveProfile();
    if (active.toLowerCase() == name.toLowerCase()) {
      throw StateError('Aktives Profil kann nicht gelöscht werden');
    }
    final profiles = await listProfiles();
    if (profiles.length <= 1) {
      throw StateError('Mindestens ein Profil muss existieren');
    }
    final dir = Directory(profileDir(name));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> renameProfile(String oldName, String newName) async {
    if (newName.trim().isEmpty) {
      throw ArgumentError('Neuer Name darf nicht leer sein');
    }
    final profiles = await listProfiles();
    if (profiles.any((e) => e.toLowerCase() == newName.toLowerCase())) {
      throw StateError('Profilname existiert bereits');
    }
    final oldDir = Directory(profileDir(oldName));
    final newDir = Directory(profileDir(newName));
    if (FileSystemEntity.typeSync(oldDir.path, followLinks: false) != FileSystemEntityType.directory) {
      throw StateError('Profil nicht gefunden: $oldName');
    }
    if (FileSystemEntity.typeSync(newDir.path, followLinks: false) == FileSystemEntityType.link) {
      throw StateError('Profilpfad darf kein symbolischer Link sein');
    }
    String? activeBefore;
    try {
      activeBefore = await getActiveProfile();
    } on ProfileSelectionRequiredException {
      // Keep an invalid multi-profile pointer invalid until the user repairs it.
    }
    await oldDir.rename(newDir.path);
    if (activeBefore?.toLowerCase() == oldName.toLowerCase()) {
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
    _assertSafeRoots();
    final String appData = await resolveAppDataDir();
    final String normTarget = p.normalize(p.absolute(targetPath));
    final String normBase = p.normalize(p.absolute(appData));
    if (!p.isWithin(normBase, normTarget) && normTarget != normBase) {
      throw StateError('Pfad außerhalb APP_DATA_DIR: $targetPath');
    }
    final String resolvedBase = await Directory(normBase).resolveSymbolicLinks();
    final String resolvedTarget = await _resolvePathOrParent(normTarget);
    if (!p.isWithin(resolvedBase, resolvedTarget) && resolvedTarget != resolvedBase) {
      throw StateError('Pfad außerhalb APP_DATA_DIR: $targetPath');
    }
  }

  Future<String> _resolvePathOrParent(String path) async {
    final FileSystemEntity target = File(path);
    if (target.existsSync()) return target.resolveSymbolicLinks();
    Directory parent = Directory(p.dirname(path));
    while (!parent.existsSync() && parent.path != parent.parent.path) {
      parent = parent.parent;
    }
    final String resolvedParent = await parent.resolveSymbolicLinks();
    return p.normalize(p.join(resolvedParent, p.relative(path, from: parent.path)));
  }

  String _recoverableProfile(List<String> profiles) {
    if (profiles.isEmpty) return 'Default';
    if (profiles.length == 1) return profiles.single;
    throw const ProfileSelectionRequiredException('Aktives Profil fehlt oder ist ungültig; bitte ein Profil auswählen');
  }

  void _assertSafeRoots() {
    for (final path in <String>[baseDir, p.join(baseDir, 'profiles')]) {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw StateError('Profilbasis darf kein symbolischer Link sein');
      }
      if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.directory) {
        throw StateError('Profilbasis ist kein Verzeichnis: $path');
      }
    }
  }

  /// Whether profile manager should be visible.
  Future<bool> shouldShowManager({bool profilmanagerAktiv = false}) async {
    final profiles = await listProfiles();
    if (profiles.length > 1) return true;
    return profilmanagerAktiv;
  }
}

class ProfileSelectionRequiredException implements Exception {
  const ProfileSelectionRequiredException(this.message, {this.cause});

  final String message;

  final Object? cause;

  @override
  String toString() => message;
}
