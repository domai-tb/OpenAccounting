import 'dart:io';

import 'package:path/path.dart' as p;

/// Read-only candidate validation for profile catalog migration/recovery.
///
/// Never opens a writable database handle, never migrates, installs triggers,
/// repairs schema, or seeds rows. Candidate bytes stay untouched; an outdated
/// but readable database is reported compatible and left byte-for-byte
/// unchanged until the user selects it for normal startup.
class ProfileProbeResult {
  const ProfileProbeResult({required this.name, required this.compatible, this.reason});

  final String name;
  final bool compatible;
  final String? reason;
}

class ProfileReadOnlyProbe {
  const ProfileReadOnlyProbe({required this.baseDir});

  final String baseDir;

  /// Validates one candidate directory without writing anything.
  ProfileProbeResult probe(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const ProfileProbeResult(name: '', compatible: false, reason: 'empty');
    }
    if (!_isSafeName(trimmed)) {
      return ProfileProbeResult(name: trimmed, compatible: false, reason: 'unsafe-name');
    }
    final String root = p.absolute(p.join(baseDir, 'profiles'));
    final String target = p.absolute(p.join(root, trimmed));
    if (target == root || !p.isWithin(root, target)) {
      return ProfileProbeResult(name: trimmed, compatible: false, reason: 'outside-base');
    }
    final FileSystemEntityType type = FileSystemEntity.typeSync(target, followLinks: false);
    if (type == FileSystemEntityType.link) {
      return ProfileProbeResult(name: trimmed, compatible: false, reason: 'symlink');
    }
    if (type != FileSystemEntityType.directory) {
      return ProfileProbeResult(name: trimmed, compatible: false, reason: 'missing');
    }
    final File db = File(p.join(target, 'openinvoices.db'));
    final FileSystemEntityType dbType = FileSystemEntity.typeSync(
      db.path,
      followLinks: false,
    ); // ignore: avoid_redundant_argument_values
    if (dbType != FileSystemEntityType.file) {
      return ProfileProbeResult(name: trimmed, compatible: false, reason: 'no-database');
    }
    try {
      final RandomAccessFile handle = db.openSync();
      try {
        final int length = handle.lengthSync();
        if (length < 100) {
          return ProfileProbeResult(name: trimmed, compatible: false, reason: 'too-small');
        }
        handle.setPositionSync(0);
        final List<int> header = handle.readSync(16);
        const String magic = 'SQLite format 3';
        final String actual = String.fromCharCodes(header);
        if (!actual.startsWith(magic)) {
          return ProfileProbeResult(name: trimmed, compatible: false, reason: 'not-sqlite');
        }
      } finally {
        handle.closeSync();
      }
    } catch (_) {
      return ProfileProbeResult(name: trimmed, compatible: false, reason: 'unreadable');
    }
    return ProfileProbeResult(name: trimmed, compatible: true);
  }

  /// Lists direct-child directory names without opening any database.
  List<String> listCandidateNames() {
    final Directory root = Directory(p.join(baseDir, 'profiles'));
    if (!root.existsSync()) return <String>[];
    if (FileSystemEntity.typeSync(root.path, followLinks: false) == FileSystemEntityType.link) {
      return <String>[];
    }
    final List<String> names = <String>[];
    for (final FileSystemEntity entity in root.listSync()) {
      if (entity is Directory &&
          FileSystemEntity.typeSync(entity.path, followLinks: false) == FileSystemEntityType.directory) {
        names.add(p.basename(entity.path));
      }
    }
    names.sort();
    return names;
  }

  static bool _isSafeName(String name) {
    if (name.isEmpty || name == '.' || name == '..') return false;
    if (name.contains('/') || name.contains(r'\') || name.contains('\x00')) return false;
    for (final int unit in name.codeUnits) {
      if (unit < 32 || unit == 127) return false;
    }
    if (name.trim() != name) return false;
    return true;
  }
}
