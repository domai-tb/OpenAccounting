import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:openaccounting/core/db/profile_read_only_probe.dart';

/// Registered profile catalog persisted in `<base>/profile.json` as
/// `{"active": "<name>", "registered": ["<name>", ...]}`.
///
/// The registered names are the only source for startup, recovery, Settings,
/// and explicit selection. Unregistered directories stay untouched and are
/// never listed or loaded. Legacy pointer-only files are migrated by seeding
/// registered names only from candidates accepted by [ProfileReadOnlyProbe].
class ProfileCatalog {
  const ProfileCatalog({required this.active, required this.registered});

  final String? active;
  final List<String> registered;

  Map<String, Object?> toFileJson() => <String, Object?>{'active': active, 'registered': registered};
}

enum CatalogRecovery { ok, singleRecovered, needsChoice, noCandidates }

class CatalogRecoveryResult {
  const CatalogRecoveryResult({required this.outcome, required this.catalog, required this.candidates, this.warning});

  final CatalogRecovery outcome;
  final ProfileCatalog catalog;
  final List<String> candidates;
  final String? warning;
}

class ProfileCatalogStore {
  ProfileCatalogStore({required this.baseDir});

  final String baseDir;

  String get profileJsonPath => p.join(baseDir, 'profile.json');

  ProfileReadOnlyProbe get _probe => ProfileReadOnlyProbe(baseDir: baseDir);

  /// Loads the catalog; migrates legacy pointer-only files compatibly.
  Future<CatalogRecoveryResult> load() async {
    final File file = File(profileJsonPath);
    if (!file.existsSync()) {
      return _recoverFromCandidates(reason: 'missing');
    }
    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _recoverFromCandidates(reason: 'corrupt');
    }
    final Object? registeredRaw = decoded['registered'] ?? decoded['profiles'];
    final String? active = decoded['active'] is String ? decoded['active'] as String : null;
    if (registeredRaw is List) {
      final List<String> registered = <String>[
        for (final Object? entry in registeredRaw)
          if (entry is String && entry.trim().isNotEmpty) entry.trim(),
      ];
      if (registered.isEmpty) {
        return _recoverFromCandidates(reason: 'empty', legacyActive: active);
      }
      if (active != null && active.isNotEmpty && !registered.any((e) => e.toLowerCase() == active.toLowerCase())) {
        return CatalogRecoveryResult(
          outcome: CatalogRecovery.needsChoice,
          catalog: ProfileCatalog(active: null, registered: registered),
          candidates: registered,
          warning: 'Aktiver Zeiger ist nicht registriert',
        );
      }
      return CatalogRecoveryResult(
        outcome: CatalogRecovery.ok,
        catalog: ProfileCatalog(active: active, registered: registered),
        candidates: registered,
      );
    }
    return _migrateLegacyPointer(active);
  }

  Future<CatalogRecoveryResult> _migrateLegacyPointer(String? legacyActive) async {
    final List<String> candidates = _probe.listCandidateNames();
    final List<String> accepted = <String>[
      for (final String name in candidates)
        if (_probe.probe(name).compatible) name,
    ];
    if (accepted.isEmpty) {
      return const CatalogRecoveryResult(
        outcome: CatalogRecovery.noCandidates,
        catalog: ProfileCatalog(active: null, registered: <String>[]),
        candidates: <String>[],
        warning: 'Kein Profil gefunden',
      );
    }
    if (accepted.length == 1) {
      final ProfileCatalog catalog = ProfileCatalog(active: accepted.single, registered: accepted);
      await save(catalog);
      return CatalogRecoveryResult(
        outcome: CatalogRecovery.singleRecovered,
        catalog: catalog,
        candidates: accepted,
        warning: 'Profilkatalog wurde wiederhergestellt',
      );
    }
    if (legacyActive != null && accepted.any((e) => e.toLowerCase() == legacyActive.toLowerCase())) {
      final String canonical = accepted.firstWhere((e) => e.toLowerCase() == legacyActive.toLowerCase());
      final ProfileCatalog catalog = ProfileCatalog(active: null, registered: accepted);
      await saveRegisteredOnly(accepted);
      return CatalogRecoveryResult(
        outcome: CatalogRecovery.needsChoice,
        catalog: catalog,
        candidates: accepted,
        warning: 'Mehrere Profile gefunden; Auswahl erforderlich ($canonical zuletzt verwendet)',
      );
    }
    final ProfileCatalog catalog = ProfileCatalog(active: null, registered: accepted);
    await saveRegisteredOnly(accepted);
    return CatalogRecoveryResult(
      outcome: CatalogRecovery.needsChoice,
      catalog: catalog,
      candidates: accepted,
      warning: 'Mehrere Profile gefunden; Auswahl erforderlich',
    );
  }

  Future<CatalogRecoveryResult> _recoverFromCandidates({required String reason, String? legacyActive}) async {
    final List<String> candidates = _probe.listCandidateNames();
    final List<String> accepted = <String>[
      for (final String name in candidates)
        if (_probe.probe(name).compatible) name,
    ];
    if (accepted.isEmpty) {
      return CatalogRecoveryResult(
        outcome: CatalogRecovery.noCandidates,
        catalog: const ProfileCatalog(active: null, registered: <String>[]),
        candidates: const <String>[],
        warning: reason == 'missing' ? 'Kein Profil gefunden' : 'Profilkatalog ist beschädigt',
      );
    }
    if (accepted.length == 1) {
      final ProfileCatalog catalog = ProfileCatalog(active: accepted.single, registered: accepted);
      await save(catalog);
      return CatalogRecoveryResult(
        outcome: CatalogRecovery.singleRecovered,
        catalog: catalog,
        candidates: accepted,
        warning: 'Profilkatalog wurde wiederhergestellt',
      );
    }
    await saveRegisteredOnly(accepted);
    return CatalogRecoveryResult(
      outcome: CatalogRecovery.needsChoice,
      catalog: ProfileCatalog(active: null, registered: accepted),
      candidates: accepted,
      warning: 'Profilkatalog ist beschädigt; bitte ein Profil wählen',
    );
  }

  Future<void> save(ProfileCatalog catalog) async {
    final File file = File(profileJsonPath);
    await file.parent.create(recursive: true);
    final String staged = '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}';
    await File(staged)
        .writeAsString(jsonEncode(<String, Object?>{'active': catalog.active, 'registered': catalog.registered}));
    await File(staged).rename(file.path);
  }

  /// Persists registered names without choosing an active profile. Used for
  /// ambiguous recovery where no filesystem-order fallback is allowed.
  Future<void> saveRegisteredOnly(List<String> registered) async {
    final File file = File(profileJsonPath);
    await file.parent.create(recursive: true);
    final String staged = '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}';
    await File(staged).writeAsString(jsonEncode(<String, Object?>{'active': null, 'registered': registered}));
    await File(staged).rename(file.path);
  }
}
