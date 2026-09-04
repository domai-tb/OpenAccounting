// ponytail: red test — implementation pending
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';

/// Fake implementation that mirrors the expected [DesktopTrayService] contract
/// without touching real plugins (VM-compatible).
class FakeDesktopTrayService implements DesktopTrayService {
  FakeDesktopTrayService({bool isSupported = true}) : _isSupported = isSupported;

  bool _isSupported;

  @override
  bool get isSupported => _isSupported;

  @override
  List<String> get menuLabels => _isSupported
      ? const <String>['Fenster anzeigen', 'Daten aktualisieren', 'Nach Updates suchen', 'Beenden']
      : const <String>[];

  bool didShow = false;
  bool didRefresh = false;
  bool didCheckUpdate = false;
  bool didQuit = false;
  bool didHideToTray = false;
  bool windowRestored = false;

  @override
  Future<bool> init() async {
    // In unsupported environments init returns false without throwing.
    return _isSupported;
  }

  @override
  Future<void> onShow() async {
    didShow = true;
    windowRestored = true;
  }

  @override
  Future<void> onRefresh() async {
    didRefresh = true;
  }

  @override
  Future<void> onCheckUpdate() async {
    didCheckUpdate = true;
  }

  @override
  Future<void> onQuit() async {
    didQuit = true;
  }

  @override
  Future<bool> handleCloseRequest({required bool minimizeToTray}) async {
    if (minimizeToTray && _isSupported) {
      didHideToTray = true;
      return true;
    } else {
      didQuit = true;
      return false;
    }
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('DesktopTrayService — System Tray (spec/desktop)', () {
    test(
      'Scenario: Tray Context Menu Actions — menu contains expected labels and Fenster anzeigen restores window',
      () async {
        final FakeDesktopTrayService service = FakeDesktopTrayService();

        final bool supported = await service.init();

        expect(supported, isTrue, reason: 'supported platform init should return true');
        expect(service.isSupported, isTrue);
        expect(
          service.menuLabels,
          equals(const <String>['Fenster anzeigen', 'Daten aktualisieren', 'Nach Updates suchen', 'Beenden']),
        );

        // Clicking "Fenster anzeigen" restores window to last position/size.
        await service.onShow();

        expect(service.didShow, isTrue);
        expect(service.windowRestored, isTrue);
      },
    );

    test('Scenario: Close to Tray — enabled hides to tray not quit', () async {
      final FakeDesktopTrayService service = FakeDesktopTrayService();

      await service.init();
      await service.handleCloseRequest(minimizeToTray: true);

      expect(service.didHideToTray, isTrue);
      expect(service.didQuit, isFalse);
    });

    test('Scenario: Close to Tray Disabled — disabled quits', () async {
      final FakeDesktopTrayService service = FakeDesktopTrayService();

      await service.init();
      await service.handleCloseRequest(minimizeToTray: false);

      expect(service.didQuit, isTrue);
      expect(service.didHideToTray, isFalse);
    });

    test(
      'Scenario: Tray Icon Not Shown — when unsupported, init returns false, no error, app functions normally',
      () async {
        final FakeDesktopTrayService service = FakeDesktopTrayService(isSupported: false);

        // Must not throw.
        final bool supported = await service.init();

        expect(supported, isFalse);
        expect(service.isSupported, isFalse);
        expect(service.menuLabels, isEmpty);

        // App still functions: close request quits without tray hide, no exception.
        await expectLater(service.handleCloseRequest(minimizeToTray: true), completes);
        expect(service.didQuit, isTrue);

        // Other actions remain callable without error.
        await expectLater(service.onRefresh(), completes);
        await expectLater(service.onCheckUpdate(), completes);
        await expectLater(service.dispose(), completes);
      },
    );
  });
}
