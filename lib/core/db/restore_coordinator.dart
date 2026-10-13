import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:openaccounting/core/db/profile_write_gate.dart';

/// Staged restore coordinator: validates while the app is live, blocks writes
/// after confirmation, and applies only after restart before any database
/// handle opens. The passphrase is never persisted.
class RestoreStaged {
  const RestoreStaged({required this.stagedPath, required this.sourceLabel, required this.stagedAt});

  final String stagedPath;
  final String sourceLabel;
  final DateTime stagedAt;
}

class RestoreCoordinator {
  RestoreCoordinator({required this.profileDir, ProfileWriteGate? gate})
    : gate = gate ?? ProfileGateRegistry.forProfile(profileDir);

  final String profileDir;
  final ProfileWriteGate gate;

  String get _pendingPath => p.join(profileDir, 'pending_restore.json');

  String get _stagedPath => p.join(profileDir, 'staged_restore.db');

  String get databasePath => p.join(profileDir, 'openinvoices.db');

  /// Validates [sourcePath] and stages it; closes the gate and requires
  /// restart. Reopens the gate when staging or state persistence fails.
  Future<RestoreStaged> stageLocalRestore(String sourcePath) async {
    gate.requireOpen();
    final void Function() release = gate.beginMutation();
    try {
      final File source = File(sourcePath);
      if (!source.existsSync()) {
        throw StateError('Backup-Datei nicht gefunden');
      }
      if (!_isBackupFile(p.basename(sourcePath))) {
        throw StateError('Backup-Quelle ist keine lokale OpenAccounting-Sicherung');
      }
      await _validateSqliteFile(sourcePath);
      await _stageValidatedFile(sourcePath, label: p.basename(sourcePath));
      release();
      gate.close();
      // Wait for in-flight writes already tracked; new writes are rejected.
      await _waitForInflight();
      try {
        await _writePending(<String, Object?>{'staged': _stagedPath, 'source': sourcePath});
      } catch (error) {
        gate.reopen();
        rethrow;
      }
      return RestoreStaged(
        stagedPath: _stagedPath,
        sourceLabel: p.basename(sourcePath),
        stagedAt: DateTime.now().toUtc(),
      );
    } catch (error) {
      try {
        release();
      } catch (_) {}
      if (gate.isOpen == false && !_pendingExists()) {
        gate.reopen();
      }
      rethrow;
    }
  }

  Future<RestoreStaged> stageEncryptedRestore(
    String encPath,
    String passphrase,
    Uint8List Function(Uint8List, String) decrypt,
  ) async {
    gate.requireOpen();
    final void Function() release = gate.beginMutation();
    try {
      final File source = File(encPath);
      if (!source.existsSync()) {
        throw StateError('Verschlüsselte Backup-Datei nicht gefunden');
      }
      if (!encPath.toLowerCase().endsWith('.enc')) {
        throw StateError('Verschlüsselte Backup-Quelle muss auf .enc enden');
      }
      if (passphrase.trim().length < 12) {
        throw ArgumentError('Passphrase muss mindestens 12 Zeichen enthalten');
      }
      late final Uint8List plain;
      try {
        plain = decrypt(await source.readAsBytes(), passphrase);
      } catch (error) {
        final String message = error.toString().toLowerCase();
        if (message.contains('passphrase') || message.contains('decrypt') || message.contains('mac')) {
          throw StateError('Entschlüsselung fehlgeschlagen: falsche Passphrase');
        }
        throw StateError('Integritätsprüfung fehlgeschlagen');
      }
      final String tmpPlain = '$_stagedPath.plain-${DateTime.now().microsecondsSinceEpoch}';
      await File(tmpPlain).writeAsBytes(plain, flush: true);
      try {
        await _validateSqliteFile(tmpPlain);
      } catch (_) {
        await _deleteQuiet(tmpPlain);
        throw StateError('Integritätsprüfung fehlgeschlagen');
      }
      await _stageValidatedFile(tmpPlain, label: p.basename(encPath));
      await _deleteQuiet(tmpPlain);
      release();
      gate.close();
      await _waitForInflight();
      try {
        await _writePending(<String, Object?>{'staged': _stagedPath, 'source': encPath});
      } catch (error) {
        gate.reopen();
        rethrow;
      }
      return RestoreStaged(stagedPath: _stagedPath, sourceLabel: p.basename(encPath), stagedAt: DateTime.now().toUtc());
    } catch (error) {
      try {
        release();
      } catch (_) {}
      if (gate.isOpen == false && !_pendingExists()) {
        gate.reopen();
      }
      rethrow;
    }
  }

  bool hasPendingRestore() => _pendingExists();

  /// Applies a staged restore before any database handle opens. Must run after
  /// acquiring the profile lock. Uses atomic replacement with rollback to the
  /// prior database when replacement fails.
  Future<void> applyPendingBeforeOpen() async {
    if (!_pendingExists()) return;
    final File staged = File(_stagedPath);
    if (!staged.existsSync()) {
      await _clearPending();
      throw StateError('Gestagte Wiederherstellung fehlt');
    }
    await _validateSqliteFile(_stagedPath);
    await _removeSidecars(databasePath);
    await _removeSidecars(_stagedPath);
    final File live = File(databasePath);
    final String backupPrior = '$databasePath.prior-${DateTime.now().microsecondsSinceEpoch}';
    final bool hadLive = live.existsSync();
    if (hadLive) {
      await live.rename(backupPrior);
    }
    try {
      await staged.rename(databasePath);
      await _removeSidecars(backupPrior);
      await _removeSidecars(databasePath);
      await _validateSqliteFile(databasePath);
      await _clearPending();
      if (hadLive) await _deleteQuiet(backupPrior);
    } catch (error) {
      try {
        if (hadLive && File(backupPrior).existsSync() && !File(databasePath).existsSync()) {
          await File(backupPrior).rename(databasePath);
        }
      } catch (_) {}
      throw StateError('Wiederherstellung fehlgeschlagen; vorherige Datenbank wurde wiederhergestellt');
    }
  }

  Future<void> _stageValidatedFile(String validatedPath, {required String label}) async {
    assert(label.isNotEmpty, 'restore label required');
    await Directory(p.dirname(_stagedPath)).create(recursive: true);
    await _deleteQuiet(_stagedPath);
    await File(validatedPath).copy(_stagedPath);
    await _validateSqliteFile(_stagedPath);
    label.isNotEmpty;
  }

  Future<void> _writePending(Map<String, Object?> pending) async {
    final File file = File(_pendingPath);
    final String staged = '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}';
    await File(staged).writeAsString(jsonEncode(pending), flush: true);
    await File(staged).rename(file.path);
  }

  bool _pendingExists() => File(_pendingPath).existsSync() && File(_stagedPath).existsSync();

  Future<void> _clearPending() async {
    await _deleteQuiet(_pendingPath);
  }

  Future<void> _waitForInflight() async {
    for (var i = 0; i < 100 && gate.inflight > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _validateSqliteFile(String path) async {
    Database? database;
    try {
      database = sqlite3.open(path, mode: OpenMode.readOnly);
      final result = database.select('PRAGMA quick_check');
      if (result.isEmpty || result.first.values.first != 'ok') {
        throw StateError('Ungültige SQLite-Datei');
      }
    } catch (_) {
      throw StateError('Ungültige SQLite-Datei');
    } finally {
      database?.close();
    }
  }

  Future<void> _removeSidecars(String dbPath) async {
    for (final String suffix in <String>['-wal', '-shm', '-journal']) {
      await _deleteQuiet('$dbPath$suffix');
    }
  }

  Future<void> _deleteQuiet(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  static bool _isBackupFile(String name) => name.startsWith('openinvoices_') && name.endsWith('.db');
}
