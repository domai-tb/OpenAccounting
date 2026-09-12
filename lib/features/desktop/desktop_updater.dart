// ignore_for_file: prefer_initializing_formals, avoid_redundant_argument_values
import 'dart:io';

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

/// VM-safe backend over GitHub Releases + auto_updater.
///
/// Installation is deliberately unavailable until a reviewed signature
/// verifier and updater hand-off are configured. Downloaded bytes are still
/// written to a private temporary artifact so a future verifier can bind the
/// exact bytes it checks to the install operation.
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
  Future<void> download(String url, void Function(double) onProgress) async {
    throw UnsupportedError('Update download is unavailable until artifact storage is configured');
  }

  @override
  Future<bool> verifySignature(String version, String signature) async {
    return false;
  }

  @override
  Future<void> installAndRestart() async {
    throw UnsupportedError('Update installation is unavailable until signature verification is configured');
  }
}

/// Real GitHub Releases backend.
class GithubUpdateBackend implements UpdateBackend, ReleaseFetcher {
  GithubUpdateBackend({Dio? dio, String? latestUrl})
    : _dio = dio ?? Dio(),
      _latestUrl = latestUrl ?? 'https://api.github.com/repos/OpenAccounting/OpenAccounting/releases/latest';

  final Dio _dio;
  final String _latestUrl;
  File? _downloadedArtifact;
  String? _downloadedUrl;
  String? _verifiedVersion;

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
      throw UnsupportedError('Desktop updates are unavailable on web');
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('Update artifact URL must use HTTPS', url);
    }
    final Response<List<int>> response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (int count, int total) {
        if (total > 0) {
          onProgress(count / total);
        }
      },
    );
    final List<int>? bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Update artifact download returned no bytes');
    }
    final Directory directory = await Directory.systemTemp.createTemp('openaccounting-update-');
    final File artifact = File('${directory.path}${Platform.pathSeparator}update-artifact');
    await artifact.writeAsBytes(bytes, flush: true);
    _downloadedArtifact = artifact;
    _downloadedUrl = url;
    _verifiedVersion = null;
  }

  @override
  Future<bool> verifySignature(String version, String signature) async {
    // No trust root is shipped yet. Never treat a marker string as a valid
    // signature and never allow an unbound artifact to reach installation.
    _verifiedVersion = null;
    return false;
  }

  @override
  Future<void> installAndRestart() async {
    if (kIsWeb) {
      throw UnsupportedError('Desktop updates are unavailable on web');
    }
    if (_downloadedArtifact == null || _downloadedUrl == null || _verifiedVersion == null) {
      throw StateError('No verified update artifact is ready for installation');
    }
    // Keep this explicit until auto_updater accepts the exact verified file.
    // Calling checkForUpdates here would install an unrelated remote release.
    throw UnsupportedError('Update installation is unavailable until the verified artifact hand-off is configured');
  }
}

class _NoopUpdateBackend implements UpdateBackend {
  @override
  Future<Map<String, dynamic>?> fetchLatestRelease() async => null;

  @override
  Future<void> download(String url, void Function(double) onProgress) async {
    throw UnsupportedError('Update download is unavailable');
  }

  @override
  Future<bool> verifySignature(String version, String signature) async => false;

  @override
  Future<void> installAndRestart() async {
    throw UnsupportedError('Update installation is unavailable');
  }
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
  UpdateInfo? _downloadedInfo;
  UpdateInfo? _verifiedInfo;

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
      final String? url = _artifactUrl(json);
      if (url == null) {
        return null;
      }
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
    _downloadedInfo = null;
    _verifiedInfo = null;
    final Uri? uri = Uri.tryParse(info.url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('Update-Artefakt hat keine sichere HTTPS-Adresse');
    }
    try {
      await _backend.download(info.url, onProgress);
      _downloadedInfo = info;
      final bool ok = await verifySignature(info);
      if (!ok) {
        _downloadedInfo = null;
        throw StateError('Update-Signatur ungültig oder nicht verifizierbar');
      }
      _verifiedInfo = info;
    } catch (_) {
      _downloadedInfo = null;
      _verifiedInfo = null;
      rethrow;
    }
  }

  @override
  Future<bool> verifySignature(UpdateInfo info) async {
    final UpdateInfo? downloaded = _downloadedInfo;
    if (downloaded == null ||
        downloaded.version != info.version ||
        downloaded.url != info.url ||
        downloaded.signature != info.signature ||
        info.signature == null ||
        info.signature!.trim().isEmpty) {
      return false;
    }
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
    if (_verifiedInfo == null) {
      throw StateError('Kein verifiziertes Update zur Installation vorhanden');
    }
    await _backend.installAndRestart();
  }

  @override
  Future<void> dismiss() async {
    final DateTime now = _clock != null ? _clock.call() : DateTime.now();
    _nextCheck = now.add(const Duration(hours: 4));
  }
}

String? _artifactUrl(Map<String, dynamic> json) {
  final dynamic direct = json['browser_download_url'] ?? json['url'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }
  final dynamic assets = json['assets'];
  if (assets is List) {
    for (final dynamic asset in assets) {
      if (asset is Map && asset['browser_download_url'] is String) {
        final String url = (asset['browser_download_url'] as String).trim();
        if (url.isNotEmpty) return url;
      }
    }
  }
  return null;
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
