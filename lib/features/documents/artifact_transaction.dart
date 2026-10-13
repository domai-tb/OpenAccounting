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
  Future<File> writeArtifact({required Directory directory, required String baseName, required List<int> bytes}) async {
    directory.createSync(recursive: true);
    final File target = File('${directory.path}/$baseName');
    if (target.existsSync()) {
      throw FileSystemException('Artifact existiert bereits', target.path);
    }
    final File staging = File('${directory.path}/$baseName.tmp.${DateTime.now().microsecondsSinceEpoch}');
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
  }) async {
    if (!directory.existsSync()) return 0;
    final RegExp owned = ownedArtifactPattern ?? RegExp(r'^\d+\.pdf$');
    var removed = 0;
    await for (final FileSystemEntity entity in directory.list()) {
      final String name = entity.path.split(Platform.pathSeparator).last;
      final bool isStaging = name.contains('.tmp.');
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
}
