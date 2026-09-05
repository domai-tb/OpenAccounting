// ignore_for_file: dangling_library_doc_comments
/// SingleInstanceService — lock file + deep-link forwarding, VM-safe.
class SingleInstanceService {
  bool _locked = false;
  final List<String> forwarded = <String>[];

  bool get isLocked => _locked;

  bool tryLock() {
    if (_locked) return false;
    _locked = true;
    return true;
  }

  void unlock() => _locked = false;

  void onSecondInstance(String deepLink) => forwarded.add(deepLink);

  bool shouldExitSecondInstance() => _locked;
}
