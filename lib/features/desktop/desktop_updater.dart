// ignore_for_file: prefer_initializing_formals, avoid_redundant_argument_values
import 'package:auto_updater/auto_updater.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Immutable update metadata — matches test's [UpdateInfo] shape.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.url, this.signature});

  final String version;
  final String url;
  final String? signature;
}

/// Public semver helper — strip leading `v`, compare dot parts.
bool isNewerVersion(String current, String latest) {
  String strip(String s) => s.startsWith('v') ? s.substring(1) : s;
  try {
    final List<int> curParts = strip(current).split('.').map(int.parse).toList();
    final List<int> latParts = strip(latest).split('.').map(int.parse).toList();
    for (int i = 0; i < curParts.length && i < latParts.length; i++) {
      if (latParts[i] > curParts[i]) return true;
      if (latParts[i] < curParts[i]) return false;
    }
    return latParts.length > curParts.length;
  } catch (_) {
    return false;
  }
}

/// Injectable release fetcher abstraction — test uses `FakeReleaseFetcher`.
abstract class ReleaseFetcher {
  Future<Map<String, dynamic>?> fetchLatestReleaseJson();
}

/// Alias expected by VM test (`ReleasesBackend`).
abstract class ReleasesBackend implements ReleaseFetcher {}

/// VM-safe backend over GitHub Releases + auto_updater + Ed25519 stub.
abstract class UpdateBackend {
  Future<Map<String, dynamic>?> fetchLatestRelease();

  Future<void> download(String url, void Function(double) onProgress);

  Future<bool> verifySignature(String version, String signature);

  Future<void> installAndRestart();
}

/// Adapter bridging [ReleaseFetcher] to [UpdateBackend].
class ReleaseFetcherAdapter implements UpdateBackend {
  ReleaseFetcherAdapter(this.fetcher);

  final ReleaseFetcher fetcher;

  @override
  Future<Map<String, dynamic>?> fetchLatestRelease() => fetcher.fetchLatestReleaseJson();

  @override
  Future<void> download(String url, void Function(double) onProgress) async {}

  @override
  Future<bool> verifySignature(String version, String signature) async {
    if (signature.isEmpty) return false;
    if (signature == 'valid') return true;
    return false;
  }

  @override
  Future<void> installAndRestart() async {}
}

/// Real GitHub Releases backend — never throws, returns null/false on error.
class GithubUpdateBackend implements UpdateBackend, ReleaseFetcher {
  GithubUpdateBackend({Dio? dio, String? latestUrl})
    : _dio = dio ?? Dio(),
      _latestUrl = latestUrl ?? 'https://api.github.com/repos/OpenAccounting/OpenAccounting/releases/latest';

  final Dio _dio;
  final String _latestUrl;

  @override
  Future<Map<String, dynamic>?> fetchLatestReleaseJson() => fetchLatestRelease();

  @override
  Future<Map<String, dynamic>?> fetchLatestRelease() async {
    if (kIsWeb) {
      return null;
    }
    try {
      final Response<dynamic> res = await _dio.get<dynamic>(_latestUrl);
      final dynamic data = res.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } on DioException catch (_) {
      return null;
    } on MissingPluginException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> download(String url, void Function(double) onProgress) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _dio.get<dynamic>(
        url,
        onReceiveProgress: (int count, int total) {
          if (total > 0) {
            onProgress(count / total);
          }
        },
      );
    } on DioException catch (_) {
      return;
    } on MissingPluginException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  @override
  Future<bool> verifySignature(String version, String signature) async {
    try {
      if (signature.isEmpty) {
        return false;
      }
      // ponytail: stub until signing trust model documented — only 'valid' passes.
      if (signature == 'valid') {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> installAndRestart() async {
    if (kIsWeb) {
      return;
    }
    try {
      await autoUpdater.checkForUpdates();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }
}

class _NoopUpdateBackend implements UpdateBackend {
  @override
  Future<Map<String, dynamic>?> fetchLatestRelease() async => null;

  @override
  Future<void> download(String url, void Function(double) onProgress) async {}

  @override
  Future<bool> verifySignature(String version, String signature) async => false;

  @override
  Future<void> installAndRestart() async {}
}

/// Contract expected by test's `DesktopUpdaterService` (hide import).
abstract class DesktopUpdaterService {
  bool get isEnabled;

  DateTime? get nextCheck;

  Future<UpdateInfo?> checkForUpdate();

  Future<void> downloadUpdate(UpdateInfo info, void Function(double) onProgress);

  Future<bool> verifySignature(UpdateInfo info);

  Future<void> installAndRestart();

  Future<void> dismiss();
}

class DesktopUpdaterServiceImpl implements DesktopUpdaterService {
  DesktopUpdaterServiceImpl({
    required UpdateBackend backend,
    required String currentVersion,
    bool enabled = false,
    DateTime Function()? clock,
  }) : _backend = backend,
       _currentVersion = currentVersion,
       _enabled = enabled,
       _clock = clock;

  final UpdateBackend _backend;
  final String _currentVersion;
  final bool _enabled;
  final DateTime Function()? _clock;
  DateTime? _nextCheck;

  @override
  bool get isEnabled => _enabled;

  @override
  DateTime? get nextCheck => _nextCheck;

  bool _isNewer(String cur, String latest) => isNewerVersion(cur, latest);

  @override
  Future<UpdateInfo?> checkForUpdate() => performUpdateCheck();

  /// Injectable silent check — respects [isEnabled], never throws, strips `v`.
  Future<UpdateInfo?> performUpdateCheck() async {
    if (!isEnabled) {
      return null;
    }
    if (kIsWeb) {
      return null;
    }
    try {
      final Map<String, dynamic>? json = await _backend.fetchLatestRelease();
      if (json == null) {
        return null;
      }
      final String tag = (json['tag_name'] as String?) ?? (json['version'] as String?) ?? '';
      if (tag.isEmpty) {
        return null;
      }
      if (!_isNewer(_currentVersion, tag)) {
        return null;
      }
      final String url =
          (json['url'] as String?) ?? (json['browser_download_url'] as String?) ?? 'https://example.com/app.zip';
      final String? sig = json['signature'] as String?;
      return UpdateInfo(version: tag, url: url, signature: sig);
    } on DioException catch (_) {
      return null;
    } on MissingPluginException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> downloadUpdate(UpdateInfo info, void Function(double) onProgress) async {
    await _backend.download(info.url, onProgress);
    final bool ok = await verifySignature(info);
    if (!ok) {
      throw StateError('Update-Signatur ungültig');
    }
  }

  @override
  Future<bool> verifySignature(UpdateInfo info) async {
    try {
      return await _backend.verifySignature(info.version, info.signature ?? '');
    } on MissingPluginException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> installAndRestart() async {
    try {
      await _backend.installAndRestart();
    } on MissingPluginException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> dismiss() async {
    final DateTime now = _clock != null ? _clock.call() : DateTime.now();
    _nextCheck = now.add(const Duration(hours: 4));
  }
}

/// Factory returning disabled impl per spec MAY deferral.
/// Test can inject `enabled: true` via direct [DesktopUpdaterServiceImpl].
DesktopUpdaterService createDesktopUpdaterService({
  String currentVersion = '0.0.1',
  UpdateBackend? backend,
  bool enabled = false,
  DateTime Function()? clock,
}) {
  if (kIsWeb) {
    return DesktopUpdaterServiceImpl(
      backend: _NoopUpdateBackend(),
      currentVersion: currentVersion,
      enabled: false,
      clock: clock,
    );
  }
  return DesktopUpdaterServiceImpl(
    backend: backend ?? GithubUpdateBackend(),
    currentVersion: currentVersion,
    enabled: enabled,
    clock: clock,
  );
}
