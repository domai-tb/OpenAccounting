import 'dart:io';

import 'package:drift/drift.dart';

/// Atomic artifact writer for finalized documents.
///
/// Lifecycle transactions SHALL write bytes to a unique profile-local
/// temporary file, verify readability, atomically rename it to its final
/// path, and commit the row only after the rename succeeds. SQLite and
/// filesystem writes cannot be one atomic transaction; user-visible success
/// is defined by the committed path resolving to a readable artifact.
class ArtifactTransaction {
  const ArtifactTransaction();

  /// Writes [bytes] atomically below [directory] with base name [baseName].
  ///
  /// Returns the final file. Throws and leaves no temporary file behind when
  /// the write or readability verification fails.
  Future<File> writeArtifact({
    required Directory directory,
    required String baseName,
    required List<int> bytes,
    String? stagingName,
  }) async {
    directory.createSync(recursive: true);
    final File target = File('${directory.path}/$baseName');
    if (target.existsSync()) {
      throw FileSystemException('Artifact existiert bereits', target.path);
    }
    if (stagingName != null &&
        (stagingName.isEmpty ||
            stagingName == '.' ||
            stagingName == '..' ||
            stagingName == baseName ||
            stagingName.contains('/') ||
            stagingName.contains(Platform.pathSeparator))) {
      throw ArgumentError.value(stagingName, 'stagingName', 'Must be a distinct file name');
    }
    final String stagingFileName = stagingName ?? '$baseName.tmp.${DateTime.now().microsecondsSinceEpoch}';
    final File staging = File('${directory.path}/$stagingFileName');
    if (staging.existsSync()) {
      throw FileSystemException('Artifact-Temporärdatei existiert bereits', staging.path);
    }
    try {
      staging.writeAsBytesSync(bytes, flush: true);
      // Readability verification before the rename commits the artifact.
      final List<int> probe = staging.readAsBytesSync();
      if (probe.isEmpty) {
        throw FileSystemException('Artifact ist nicht lesbar', staging.path);
      }
      staging.renameSync(target.path);
      return target;
    } catch (_) {
      try {
        if (staging.existsSync()) staging.deleteSync();
      } catch (_) {}
      rethrow;
    }
  }

  /// Reconciles crash leftovers at startup.
  ///
  /// Removes owned staging files (`*.tmp.*`) and uniquely named generated
  /// artifacts (`*.pdf` matching the owned pattern) without a committed
  /// database reference. Unknown files are never deleted. Returns the number
  /// of removed files.
  Future<int> reconcile({
    required Directory directory,
    required Set<String> referencedNames,
    RegExp? ownedArtifactPattern,
    RegExp? ownedStagingPattern,
  }) async {
    if (!directory.existsSync()) return 0;
    final RegExp owned = ownedArtifactPattern ?? RegExp(r'^\d+\.pdf$');
    var removed = 0;
    await for (final FileSystemEntity entity in directory.list()) {
      final String name = entity.path.split(Platform.pathSeparator).last;
      final bool isStaging = name.contains('.tmp.') || (ownedStagingPattern?.hasMatch(name) ?? false);
      final bool isUnreferencedOwned = owned.hasMatch(name) && !referencedNames.contains(name);
      if (!isStaging && !isUnreferencedOwned) continue;
      try {
        await entity.delete();
        removed++;
      } catch (_) {}
    }
    return removed;
  }

  /// Checks a committed artifact path. Returns null when readable, otherwise
  /// a German repair hint (missing or unreadable).
  String? checkCommitted(String? path) {
    if (path == null || path.isEmpty) return 'Artifact fehlt — zur Reparatur vormerken';
    final File file = File(path);
    if (!file.existsSync()) return 'Artifact fehlt — zur Reparatur vormerken';
    try {
      if (file.readAsBytesSync().isEmpty) return 'Artifact nicht lesbar — zur Reparatur vormerken';
    } catch (_) {
      return 'Artifact nicht lesbar — zur Reparatur vormerken';
    }
    return null;
  }
}

/// Startup recovery for owned artifact and source directories.
///
/// Scans only application-owned directories (`pdfs/documents` for generated
/// artifacts, `uploads/belege` for imported sources): removes owned staging
/// files and uniquely named files without a committed database reference,
/// and reports committed references whose artifact is missing/unreadable.
/// Unknown files are never deleted. Best-effort: never throws.
class ArtifactRecovery {
  const ArtifactRecovery();

  /// Runs recovery for [profileDir]. Returns removed orphan count.
  static Future<({int removed, List<String> broken})> reconcileAtStartup(
    QueryExecutor executor,
    String profileDir,
  ) async {
    var removed = 0;
    final List<String> broken = <String>[];
    try {
      final Set<String> referencedDocs = <String>{};
      try {
        final List<Map<String, Object?>> rows = await executor.runSelect(
          'SELECT original_pdf_pfad FROM rechnungen WHERE original_pdf_pfad IS NOT NULL',
          const <Object?>[],
        );
        for (final Map<String, Object?> row in rows) {
          final Object? path = row['original_pdf_pfad'];
          if (path == null) continue;
          referencedDocs.add(path.toString().split(Platform.pathSeparator).last);
          if (const ArtifactTransaction().checkCommitted(path.toString()) != null) {
            broken.add(path.toString());
          }
        }
      } catch (_) {}
      final Directory docsDir = Directory('$profileDir/pdfs/documents');
      if (docsDir.existsSync()) {
        removed += await const ArtifactTransaction().reconcile(directory: docsDir, referencedNames: referencedDocs);
        removed += await _reconcileZugferdSidecars(executor, docsDir);
      }
      try {
        final List<Map<String, Object?>> rows = await executor.runSelect(
          'SELECT dateipfad FROM belege WHERE dateipfad IS NOT NULL',
          const <Object?>[],
        );
        final Set<String> referencedSources = <String>{
          for (final Map<String, Object?> row in rows) row['dateipfad'].toString(),
        };
        final Directory sourceDir = Directory('$profileDir/uploads/belege');
        if (sourceDir.existsSync()) {
          await for (final FileSystemEntity entity in sourceDir.list()) {
            if (entity is! File) continue;
            final String name = entity.path.split(Platform.pathSeparator).last;
            final bool owned = RegExp(r'^\d+_').hasMatch(name) || name.endsWith('.tmp');
            if (!owned || referencedSources.contains(entity.path)) continue;
            try {
              await entity.delete();
              removed++;
            } catch (_) {}
          }
        }
      } catch (_) {}
    } catch (_) {}
    return (removed: removed, broken: broken);
  }

  /// Removes only numeric ZUGFeRD sidecars whose invoice is still a draft or
  /// whose invoice row is absent. Finalized rows are always preserved.
  static Future<int> _reconcileZugferdSidecars(QueryExecutor executor, Directory docsDir) async {
    if (!docsDir.existsSync()) return 0;

    final List<Map<String, Object?>> invoiceRows;
    try {
      invoiceRows = await executor.runSelect('SELECT id, ist_entwurf FROM rechnungen', const <Object?>[]);
    } catch (_) {
      // Without authoritative row state, fail closed and preserve sidecars.
      return 0;
    }

    final Map<int, int?> draftStateById = <int, int?>{};
    for (final Map<String, Object?> row in invoiceRows) {
      final int? id = int.tryParse(row['id']?.toString() ?? '');
      if (id == null || id <= 0) continue;
      draftStateById[id] = int.tryParse(row['ist_entwurf']?.toString() ?? '');
    }

    final RegExp sidecarName = RegExp(r'^([1-9]\d*)\.zugferd\.xml(?:\.tmp)?$');
    var removed = 0;
    try {
      await for (final FileSystemEntity entity in docsDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final String name = entity.path.split(Platform.pathSeparator).last;
        final RegExpMatch? match = sidecarName.firstMatch(name);
        if (match == null) continue;

        final String idText = match.group(1)!;
        final int? id = int.tryParse(idText);
        if (id == null || id.toString() != idText) continue;
        if (draftStateById.containsKey(id) && draftStateById[id] != 1) continue;

        try {
          await entity.delete();
          removed++;
        } catch (_) {}
      }
    } catch (_) {}
    return removed;
  }
}
