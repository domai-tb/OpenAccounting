import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';

final class FakeTrayBackend implements TrayBackend {
  FakeTrayBackend({this.shouldSucceed = true});

  final bool shouldSucceed;
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

final class FakeWindowBackend implements WindowBackend {
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

void main() {
  group('DesktopTrayService uses the production service', () {
    test('initializes the tray, wires the menu, and restores the window', () async {
      final FakeTrayBackend tray = FakeTrayBackend();
      final FakeWindowBackend window = FakeWindowBackend();
      final DesktopTrayServiceImpl service = DesktopTrayServiceImpl(trayBackend: tray, windowBackend: window);

      expect(await service.init(), isTrue);
      expect(service.isSupported, isTrue);
      expect(tray.initCalled, isTrue);
      expect(service.menuLabels, <String>['Fenster anzeigen', 'Daten aktualisieren', 'Nach Updates suchen', 'Beenden']);
      expect(tray.lastLabels, service.menuLabels);
      expect(tray.lastHandlers, hasLength(4));

      await service.onShow();

      expect(window.didShow, isTrue);
    });

    test('close-to-tray hides the window when enabled', () async {
      final FakeWindowBackend window = FakeWindowBackend();
      final DesktopTrayServiceImpl configuredService = DesktopTrayServiceImpl(
        trayBackend: FakeTrayBackend(),
        windowBackend: window,
      );
      await configuredService.init();

      expect(await configuredService.handleCloseRequest(minimizeToTray: true), isTrue);
      expect(window.didHide, isTrue);
      expect(window.didClose, isFalse);
    });

    test('close-to-tray disabled closes the window', () async {
      final FakeWindowBackend window = FakeWindowBackend();
      final DesktopTrayServiceImpl service = DesktopTrayServiceImpl(
        trayBackend: FakeTrayBackend(),
        windowBackend: window,
      );
      await service.init();

      expect(await service.handleCloseRequest(minimizeToTray: false), isFalse);
      expect(window.didClose, isTrue);
      expect(window.didHide, isFalse);
    });

    test('unsupported tray leaves the app usable and closes normally', () async {
      final FakeWindowBackend window = FakeWindowBackend();
      final DesktopTrayServiceImpl service = DesktopTrayServiceImpl(
        trayBackend: FakeTrayBackend(shouldSucceed: false),
        windowBackend: window,
      );

      expect(await service.init(), isFalse);
      expect(service.isSupported, isFalse);
      expect(service.menuLabels, isEmpty);
      expect(await service.handleCloseRequest(minimizeToTray: true), isFalse);
      expect(window.didClose, isTrue);
      await service.onRefresh();
      await service.onCheckUpdate();
      await service.dispose();
    });
  });
}
