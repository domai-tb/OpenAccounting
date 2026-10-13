/// Profile-scoped write gate at the shared database write boundary.
///
/// Closed after a restore is confirmed; all repository mutations must call
/// [ProfileWriteGate.requireOpen] before issuing SQL. In-flight mutations are counted so the
/// restore coordinator can drain them before persisting pending state.
class ProfileWriteGateBlocked implements Exception {
  const ProfileWriteGateBlocked(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileWriteGate {
  bool _open = true;
  int _inflight = 0;

  bool get isOpen => _open;

  int get inflight => _inflight;

  void requireOpen() {
    if (!_open) {
      throw const ProfileWriteGateBlocked('Schreibzugriff ist für die Wiederherstellung gesperrt');
    }
  }

  /// Tracks one mutation; callers must call the returned release exactly once.
  void Function() beginMutation() {
    requireOpen();
    _inflight++;
    var released = false;
    return () {
      if (!released) {
        released = true;
        _inflight = _inflight > 0 ? _inflight - 1 : 0;
      }
    };
  }

  void close() => _open = false;

  void reopen() => _open = true;
}

/// Process-wide gate holder so every repository shares one gate per profile.
class ProfileGateRegistry {
  static final Map<String, ProfileWriteGate> _gates = <String, ProfileWriteGate>{};

  static ProfileWriteGate forProfile(String profileDir) {
    return _gates.putIfAbsent(profileDir, ProfileWriteGate.new);
  }

  static void resetForTests() => _gates.clear();
}
