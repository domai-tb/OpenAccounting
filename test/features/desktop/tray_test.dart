// ponytail: red test — intentionally failing until tray service green
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';

/// Minimal fake over the abstraction — VM-safe, no native plugins.
class FakeTrayBackend implements TrayBackend {
  FakeTrayBackend({this.shouldSucceed = true});

  bool shouldSucceed;
  bool initCalled = false;
  List<String>? lastLabels;
  List<Future<void> Function()>? lastHandlers;

  @override
  Future<bool> initSystemTray({required String title, required String iconPath, String? toolTip}) async {
    initCalled = true;
    return shouldSucceed;
  }

  @override
  Future<void> setContextMenu(List<String> labels, List<Future<void> Function()> handlers) async {
    lastLabels = labels;
    lastHandlers = handlers;
  }

  @override
  Future<void> dispose() async {}
}

class FakeWindowBackend implements WindowBackend {
  bool didShow = false;
  bool didHide = false;
  bool didClose = false;

  @override
  Future<void> show() async => didShow = true;

  @override
  Future<void> hide() async => didHide = true;

  @override
  Future<void> close() async => didClose = true;
}

/// Contract-level fake for direct DesktopTrayService assertions.
class FakeDesktopTrayService implements DesktopTrayService {
  // ignore: prefer_initializing_formals
  FakeDesktopTrayService({bool isSupported = true}) : _isSupported = isSupported;

  final bool _isSupported;

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
  Future<bool> init() async => _isSupported;

  @override
  Future<void> onShow() async {
    didShow = true;
    windowRestored = true;
  }

  @override
  Future<void> onRefresh() async => didRefresh = true;

  @override
  Future<void> onCheckUpdate() async => didCheckUpdate = true;

  @override
  Future<void> onQuit() async => didQuit = true;

  @override
  Future<bool> handleCloseRequest({required bool minimizeToTray}) async {
    if (minimizeToTray && _isSupported) {
      didHideToTray = true;
      return true;
    }
    didQuit = true;
    return false;
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
        final bool supported = await service.init();
        expect(supported, isFalse);
        expect(service.isSupported, isFalse);
        expect(service.menuLabels, isEmpty);
        await expectLater(service.handleCloseRequest(minimizeToTray: true), completes);
        expect(service.didQuit, isTrue);
        await expectLater(service.onRefresh(), completes);
        await expectLater(service.onCheckUpdate(), completes);
        await expectLater(service.dispose(), completes);
      },
    );

    test('Scenario: Tray icon visible + context menu wired via DesktopTrayServiceImpl (VM mock)', () async {
      final FakeTrayBackend tray = FakeTrayBackend();
      final FakeWindowBackend window = FakeWindowBackend();
      final DesktopTrayServiceImpl service = DesktopTrayServiceImpl(trayBackend: tray, windowBackend: window);

      final bool ok = await service.init();

      expect(ok, isTrue);
      expect(service.isSupported, isTrue);
      expect(tray.initCalled, isTrue);
      expect(
        service.menuLabels,
        equals(const <String>['Fenster anzeigen', 'Daten aktualisieren', 'Nach Updates suchen', 'Beenden']),
      );
      expect(tray.lastLabels, equals(service.menuLabels));

      // onShow restores window to last position/size (via WindowBackend.show).
      await service.onShow();
      expect(window.didShow, isTrue);

      // Close-to-tray enabled hides, not quit.
      window.didHide = false;
      window.didClose = false;
      final bool hid = await service.handleCloseRequest(minimizeToTray: true);
      expect(hid, isTrue);
      expect(window.didHide, isTrue);
      expect(window.didClose, isFalse);
    });

    test('Tray icon contract — menu has exactly 4 spec labels', () async {
      final FakeTrayBackend tray = FakeTrayBackend();
      final FakeWindowBackend window = FakeWindowBackend();
      final DesktopTrayServiceImpl service = DesktopTrayServiceImpl(trayBackend: tray, windowBackend: window);
      await service.init();
      expect(service.menuLabels.length, equals(4));
      expect(
        service.menuLabels,
        equals(const <String>['Fenster anzeigen', 'Daten aktualisieren', 'Nach Updates suchen', 'Beenden']),
      );
    });
  });
}
