import 'dart:io';

import 'package:path/path.dart' as p;

/// Exclusive OS-level profile lock, acquired before any writable database
/// handle opens and held for the process lifetime. A second process that
/// cannot acquire it must stop with a profile-in-use state.
class ProfileInUseException implements Exception {
  const ProfileInUseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileFileLock {
  ProfileFileLock._(this.lockPath, this._handle);

  final String lockPath;
  final RandomAccessFile _handle;

  static ProfileFileLock? _held;

  static String lockPathFor(String profileDir) => p.join(profileDir, '.profile.lock');

  /// Tries to acquire the lock without blocking. Throws [ProfileInUseException]
  /// when another process owns the profile.
  factory ProfileFileLock.acquire(String profileDir) {
    final String lockPath = lockPathFor(profileDir);
    Directory(profileDir).createSync(recursive: true);
    final File file = File(lockPath);
    final RandomAccessFile handle = file.openSync(mode: FileMode.write);
    try {
      handle.lockSync();
    } catch (_) {
      try {
        handle.closeSync();
      } catch (_) {}
      throw const ProfileInUseException('Profil wird bereits verwendet');
    }
    try {
      handle.writeStringSync('pid=$pid\n');
      handle.flushSync();
    } catch (_) {}
    final ProfileFileLock lock = ProfileFileLock._(lockPath, handle);
    _held = lock;
    return lock;
  }

  /// Non-throwing probe used by startup and tests.
  static bool tryAcquire(String profileDir) {
    try {
      ProfileFileLock.acquire(profileDir);
      return true;
    } on ProfileInUseException {
      return false;
    } catch (_) {
      return false;
    }
  }

  bool get isHeld => identical(_held, this);

  void release() {
    if (identical(_held, this)) _held = null;
    try {
      _handle.unlockSync();
    } catch (_) {}
    try {
      _handle.closeSync();
    } catch (_) {}
  }
}
