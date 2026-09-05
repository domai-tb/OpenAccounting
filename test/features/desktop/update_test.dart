import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/desktop_updater.dart';

final class FakeUpdateBackend implements UpdateBackend {
  FakeUpdateBackend({this.releaseQueue = const <Map<String, dynamic>?>[], this.verifyResult = true});

  final List<Map<String, dynamic>?> releaseQueue;
  final bool verifyResult;
  final List<String> downloadedUrls = <String>[];
  final List<double> progressLog = <double>[];
  final List<String> verifiedVersions = <String>[];
  int fetchCount = 0;
  int installCount = 0;
  int _releaseIndex = 0;

  @override
  Future<Map<String, dynamic>?> fetchLatestRelease() async {
    fetchCount++;
    if (_releaseIndex >= releaseQueue.length) {
      return null;
    }
    return releaseQueue[_releaseIndex++];
  }

  @override
  Future<void> download(String url, void Function(double) onProgress) async {
    downloadedUrls.add(url);
    for (final double progress in <double>[0.25, 0.5, 1]) {
      progressLog.add(progress);
      onProgress(progress);
    }
  }

  @override
  Future<bool> verifySignature(String version, String signature) async {
    verifiedVersions.add(version);
    return verifyResult;
  }

  @override
  Future<void> installAndRestart() async {
    installCount++;
  }
}

void main() {
  group('Desktop updater uses the production service', () {
    test('detects a newer GitHub release', () async {
      final FakeUpdateBackend backend = FakeUpdateBackend(
        releaseQueue: <Map<String, dynamic>?>[
          <String, dynamic>{'tag_name': 'v1.10.0', 'url': 'https://example.com/v1.10.0.zip', 'signature': 'valid'},
        ],
      );
      final DesktopUpdaterService service = DesktopUpdaterServiceImpl(
        backend: backend,
        currentVersion: '1.9.0',
        enabled: true,
      );

      final UpdateInfo? info = await service.checkForUpdate();

      expect(backend.fetchCount, 1);
      expect(info, isNotNull);
      expect(info!.version, 'v1.10.0');
      expect(info.url, 'https://example.com/v1.10.0.zip');
    });

    test('downloads with progress, verifies, and installs', () async {
      final FakeUpdateBackend backend = FakeUpdateBackend(
        releaseQueue: <Map<String, dynamic>?>[
          <String, dynamic>{'tag_name': 'v2.0.0', 'url': 'https://example.com/v2.zip', 'signature': 'valid'},
        ],
      );
      final DesktopUpdaterService service = DesktopUpdaterServiceImpl(
        backend: backend,
        currentVersion: '1.0.0',
        enabled: true,
      );
      final UpdateInfo info = (await service.checkForUpdate())!;
      final List<double> seen = <double>[];

      await service.downloadUpdate(info, seen.add);
      await service.installAndRestart();

      expect(backend.downloadedUrls, <String>['https://example.com/v2.zip']);
      expect(seen, <double>[0.25, 0.5, 1]);
      expect(backend.progressLog, seen);
      expect(backend.verifiedVersions, <String>['v2.0.0']);
      expect(backend.installCount, 1);
    });

    test('dismisses an available update for four hours', () async {
      final DateTime fixedNow = DateTime(2026, 1, 1, 10);
      final DesktopUpdaterService service = DesktopUpdaterServiceImpl(
        backend: FakeUpdateBackend(),
        currentVersion: '1.0.0',
        enabled: true,
        clock: () => fixedNow,
      );

      await service.dismiss();

      expect(service.nextCheck, fixedNow.add(const Duration(hours: 4)));
    });

    test('rejects an update whose signature is invalid', () async {
      final FakeUpdateBackend backend = FakeUpdateBackend(
        releaseQueue: <Map<String, dynamic>?>[
          <String, dynamic>{'tag_name': 'v1.10.0', 'url': 'https://example.com/v1.10.0.zip', 'signature': 'bad-sig'},
        ],
        verifyResult: false,
      );
      final DesktopUpdaterService service = DesktopUpdaterServiceImpl(
        backend: backend,
        currentVersion: '1.9.0',
        enabled: true,
      );
      final UpdateInfo info = (await service.checkForUpdate())!;

      await expectLater(service.downloadUpdate(info, (_) {}), throwsA(isA<StateError>()));
      expect(await service.verifySignature(info), isFalse);
      expect(backend.installCount, 0);
    });

    test('stays silent when the current version is latest', () async {
      final FakeUpdateBackend backend = FakeUpdateBackend(
        releaseQueue: <Map<String, dynamic>?>[
          <String, dynamic>{'tag_name': 'v1.9.0'},
        ],
      );
      final DesktopUpdaterService service = DesktopUpdaterServiceImpl(
        backend: backend,
        currentVersion: '1.9.0',
        enabled: true,
      );

      expect(await service.checkForUpdate(), isNull);
      expect(backend.fetchCount, 1);
    });
  });
}
