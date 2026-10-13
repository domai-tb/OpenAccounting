import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:openaccounting/core/db/data_paths.dart';
import 'package:openaccounting/core/db/profile_catalog.dart';
import 'package:openaccounting/core/db/profile_database.dart';
import 'package:openaccounting/core/db/profile_read_only_probe.dart';

/// Profile management per specs `profiles` and `profile-workspace-lifecycle`.
/// Each profile = isolated DB file under `<base>/profiles/<name>/openinvoices.db`.
/// Active profile and registered names tracked via `<base>/profile.json`
/// `{"active": "Name", "registered": ["Name", ...]}`. Registered names are the
/// only source for startup, recovery, Settings, and explicit selection.
/// Removal is non-destructive registry unregister; files stay on disk.
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
    final String trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        trimmed.contains('/') ||
        trimmed.contains(r'\') ||
        trimmed.contains('\x00')) {
      throw ArgumentError('Ungültiger Profilname');
    }
    for (final int unit in trimmed.codeUnits) {
      if (unit < 32 || unit == 127) {
        throw ArgumentError('Ungültiger Profilname');
      }
    }
    final String root = p.absolute(p.join(baseDir, 'profiles'));
    final String target = p.absolute(p.join(root, trimmed));
    if (target == root || !p.isWithin(root, target)) {
      throw ArgumentError('Ungültiger Profilname');
    }
    if (p.basename(target) != trimmed) {
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

  ProfileCatalogStore get _catalog => ProfileCatalogStore(baseDir: baseDir);

  ProfileReadOnlyProbe get _probe => ProfileReadOnlyProbe(baseDir: baseDir);

  /// Get active profile name via the registered catalog. Never falls back to
  /// the first available profile by filesystem order. Missing/corrupt catalogs
  /// recover a sole validated candidate with a warning; multiple candidates
  /// require explicit selection.
  Future<String> getActiveProfile() async {
    _assertSafeRoots();
    final CatalogRecoveryResult loaded = await _catalog.load();
    final ProfileCatalog catalog = loaded.catalog;
    if (loaded.outcome == CatalogRecovery.needsChoice) {
      throw const ProfileSelectionRequiredException('Mehrere Profile gefunden; bitte ein Profil auswählen');
    }
    if (loaded.outcome == CatalogRecovery.noCandidates) {
      return 'Default';
    }
    final String? active = catalog.active;
    if (active == null || active.isEmpty) {
      if (catalog.registered.length == 1) return catalog.registered.single;
      throw const ProfileSelectionRequiredException('Aktives Profil fehlt; bitte ein Profil auswählen');
    }
    if (!catalog.registered.any((e) => e.toLowerCase() == active.toLowerCase())) {
      throw const ProfileSelectionRequiredException('Aktives Profil ist nicht registriert; bitte ein Profil auswählen');
    }
    final String canonical = catalog.registered.firstWhere((e) => e.toLowerCase() == active.toLowerCase());
    final String dir = p.join(baseDir, 'profiles', canonical);
    if (FileSystemEntity.typeSync(dir, followLinks: false) != FileSystemEntityType.directory) {
      throw const ProfileSelectionRequiredException('Aktives Profil ist nicht verfügbar; bitte ein Profil auswählen');
    }
    if (!_probe.probe(canonical).compatible) {
      throw const ProfileSelectionRequiredException(
        'Aktives Profil kann nicht validiert werden; bitte ein Profil auswählen',
      );
    }
    return canonical;
  }

  /// Switch active profile — persists pointer, requires restart to take effect.
  /// Same-profile selection is a no-op without pointer rewrite. Never switches
  /// the database, providers, or session identity before restart. Unknown or
  /// unregistered targets fail without fallback. Returns true if restart required.
  Future<bool> setActiveProfile(String name) async {
    final String profileName = _validateProfileName(name);
    String? current;
    try {
      current = await getActiveProfile();
    } on ProfileSelectionRequiredException {
      current = null;
    }
    if (current != null && current.toLowerCase() == profileName.toLowerCase()) return false;
    final CatalogRecoveryResult loaded = await _catalog.load();
    final List<String> registered = loaded.catalog.registered;
    final List<String> match = registered.where((e) => e.toLowerCase() == profileName.toLowerCase()).toList();
    if (match.isEmpty) {
      throw StateError('Profil ist nicht registriert: $profileName');
    }
    final String canonical = match.single;
    final String dir = p.join(baseDir, 'profiles', canonical);
    final FileSystemEntityType type = FileSystemEntity.typeSync(dir, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw StateError('Profilpfad darf kein symbolischer Link sein');
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError('Profil nicht gefunden: $canonical');
    }
    if (!_probe.probe(canonical).compatible) {
      throw StateError('Profil kann nicht validiert werden: $canonical');
    }
    await _catalog.save(ProfileCatalog(active: canonical, registered: registered));
    // ponytail: restart required — caller must restart process to load new DB.
    return true;
  }

  /// Registered profiles only. Unregistered directories are never listed.
  Future<List<String>> listProfiles() async {
    _assertSafeRoots();
    final CatalogRecoveryResult loaded = await _catalog.load();
    if (loaded.outcome == CatalogRecovery.noCandidates) return <String>[];
    if (loaded.outcome == CatalogRecovery.needsChoice) return List<String>.from(loaded.catalog.registered)..sort();
    final List<String> registered = List<String>.from(loaded.catalog.registered)..sort();
    return registered;
  }

  /// Explicit recovery candidates for the picker. No preselected choice.
  Future<List<String>> recoveryCandidates() async {
    final CatalogRecoveryResult loaded = await _catalog.load();
    return List<String>.from(loaded.candidates)..sort();
  }

  Future<void> createProfile(String name) async {
    final String profileName = name.trim();
    if (profileName.isEmpty) {
      throw ArgumentError('Profilname darf nicht leer sein');
    }
    final String validated = _validateProfileName(profileName);
    final List<String> existing = await listProfiles();
    if (existing.any((e) => e.toLowerCase() == validated.toLowerCase())) {
      throw StateError('Profilname existiert bereits');
    }
    final Directory dir = Directory(p.join(baseDir, 'profiles', validated));
    if (FileSystemEntity.typeSync(dir.path, followLinks: false) == FileSystemEntityType.link) {
      throw StateError('Profilpfad darf kein symbolischer Link sein');
    }
    await dir.create(recursive: true);
    await databaseInitializer(databasePath(validated));
    final CatalogRecoveryResult loaded = await _catalog.load();
    final List<String> registered = List<String>.from(loaded.catalog.registered);
    if (!registered.any((e) => e.toLowerCase() == validated.toLowerCase())) {
      registered.add(validated);
    }
    final String? active = loaded.catalog.active ?? (registered.length == 1 ? validated : null);
    if (loaded.outcome == CatalogRecovery.noCandidates) {
      await _catalog.save(ProfileCatalog(active: validated, registered: <String>[validated]));
    } else {
      await _catalog.save(ProfileCatalog(active: active, registered: registered));
    }
  }

  /// Non-destructive removal from the registered-name list. Retains the
  /// profile directory, database, uploads, and backups. Cannot remove the
  /// active profile or the last registered profile. No automatic purge.
  Future<void> deleteProfile(String name) => unregisterProfile(name);

  Future<void> unregisterProfile(String name) async {
    final String validated = _validateProfileName(name);
    final String active = await getActiveProfile();
    if (active.toLowerCase() == validated.toLowerCase()) {
      throw StateError('Aktives Profil kann nicht entfernt werden');
    }
    final List<String> registered = await listProfiles();
    if (registered.length <= 1) {
      throw StateError('Mindestens ein Profil muss registriert bleiben');
    }
    if (!registered.any((e) => e.toLowerCase() == validated.toLowerCase())) {
      throw StateError('Profil ist nicht registriert: $validated');
    }
    final String canonical = registered.firstWhere((e) => e.toLowerCase() == validated.toLowerCase());
    final List<String> next = registered.where((e) => e.toLowerCase() != validated.toLowerCase()).toList();
    await _catalog.save(ProfileCatalog(active: active, registered: next));
    // Files intentionally retained: directory, database, uploads, backups.
    canonical.isNotEmpty;
  }

  Future<void> renameProfile(String oldName, String newName) async {
    final String validatedNew = _validateProfileName(newName.trim());
    if (validatedNew.isEmpty) {
      throw ArgumentError('Neuer Name darf nicht leer sein');
    }
    final List<String> profiles = await listProfiles();
    if (profiles.any((e) => e.toLowerCase() == validatedNew.toLowerCase())) {
      throw StateError('Profilname existiert bereits');
    }
    final String validatedOld = _validateProfileName(oldName.trim());
    String? canonicalOld;
    for (final String entry in profiles) {
      if (entry.toLowerCase() == validatedOld.toLowerCase()) {
        canonicalOld = entry;
        break;
      }
    }
    if (canonicalOld == null) {
      throw StateError('Profil nicht gefunden: $oldName');
    }
    final String oldCanonical = canonicalOld;
    final Directory oldDir = Directory(p.join(baseDir, 'profiles', oldCanonical));
    final Directory newDir = Directory(p.join(baseDir, 'profiles', validatedNew));
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
    final List<String> next = <String>[
      for (final String entry in profiles)
        if (entry.toLowerCase() != oldCanonical.toLowerCase()) entry else validatedNew,
    ];
    final String? nextActive = activeBefore?.toLowerCase() == oldCanonical.toLowerCase() ? validatedNew : activeBefore;
    await _catalog.save(ProfileCatalog(active: nextActive, registered: next));
  }

  /// Resolve APP_DATA_DIR for active profile — used for uploads/backups/logos.
  Future<String> resolveAppDataDir() async {
    final String active = await getActiveProfile();
    return p.join(baseDir, 'profiles', active);
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

  void _assertSafeRoots() {
    for (final String path in <String>[baseDir, p.join(baseDir, 'profiles')]) {
      final FileSystemEntityType type = FileSystemEntity.typeSync(path, followLinks: false);
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
    final List<String> profiles = await listProfiles();
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
