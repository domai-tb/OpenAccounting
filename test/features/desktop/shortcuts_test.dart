import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/desktop_shortcuts.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';

final class FakeHotkeyBackend implements HotkeyBackend {
  FakeHotkeyBackend({this.conflicts = const <String>{}});

  final Set<String> conflicts;
  final Map<String, String> _accelerators = <String, String>{};
  final Map<String, Future<void> Function()> _handlers = <String, Future<void> Function()>{};

  @override
  Future<bool> register(String id, String key, Future<void> Function() handler) async {
    if (conflicts.contains(id)) {
      return false;
    }
    _accelerators[id] = key;
    _handlers[id] = handler;
    return true;
  }

  @override
  Future<void> unregister(String id) async {
    _accelerators.remove(id);
    _handlers.remove(id);
  }

  @override
  Future<void> unregisterAll() async {
    _accelerators.clear();
    _handlers.clear();
  }

  bool isRegistered(String accelerator) => _accelerators.values.contains(accelerator);

  Future<void> invoke(String accelerator) async {
    final String id = _accelerators.entries.firstWhere((entry) => entry.value == accelerator).key;
    await _handlers[id]!();
  }
}

final class FakeWindowBackend implements WindowBackend {
  int showCount = 0;
  int hideCount = 0;

  @override
  Future<void> show() async {
    showCount++;
  }

  @override
  Future<void> hide() async {
    hideCount++;
  }

  @override
  Future<void> close() async {}
}

DesktopShortcutsServiceImpl createService({
  required FakeHotkeyBackend hotkeys,
  required FakeWindowBackend window,
  required List<String> navigatedRoutes,
}) {
  return DesktopShortcutsServiceImpl(hotkeyBackend: hotkeys, windowBackend: window, navigate: navigatedRoutes.add);
}

void main() {
  group('Desktop shortcuts use the production service', () {
    test('registers global show/hide and toggles the injected window', () async {
      final FakeHotkeyBackend hotkeys = FakeHotkeyBackend();
      final FakeWindowBackend window = FakeWindowBackend();
      final List<String> routes = <String>[];
      final DesktopShortcutsServiceImpl service = createService(
        hotkeys: hotkeys,
        window: window,
        navigatedRoutes: routes,
      );

      expect(await service.register(), isTrue);
      expect(hotkeys.isRegistered(DesktopShortcutAccelerators.showHide), isTrue);

      await hotkeys.invoke(DesktopShortcutAccelerators.showHide);
      await hotkeys.invoke(DesktopShortcutAccelerators.showHide);
      expect(window.showCount, 1);
      expect(window.hideCount, 1);
    });

    test('new invoice shortcut shows the window and navigates', () async {
      final FakeHotkeyBackend hotkeys = FakeHotkeyBackend();
      final FakeWindowBackend window = FakeWindowBackend();
      final List<String> routes = <String>[];
      final DesktopShortcutsServiceImpl service = createService(
        hotkeys: hotkeys,
        window: window,
        navigatedRoutes: routes,
      );

      expect(await service.register(), isTrue);
      await hotkeys.invoke(DesktopShortcutAccelerators.newInvoice);

      expect(window.showCount, 1);
      expect(routes, <String>['/invoices/new']);
    });

    test('conflicts fail registration, warn, and unregister the partial set', () async {
      final FakeHotkeyBackend hotkeys = FakeHotkeyBackend(conflicts: <String>{'showHide'});
      final FakeWindowBackend window = FakeWindowBackend();
      final List<String> routes = <String>[];
      final List<String> warnings = <String>[];
      final DesktopShortcutsServiceImpl service = DesktopShortcutsServiceImpl(
        hotkeyBackend: hotkeys,
        windowBackend: window,
        navigate: routes.add,
        onWarning: warnings.add,
      );

      expect(await service.register(), isFalse);
      expect(service.isRegistered, isFalse);
      expect(hotkeys.isRegistered(DesktopShortcutAccelerators.newInvoice), isFalse);
      expect(service.lastWarning, 'Tastenkombination wird bereits von einer anderen Anwendung verwendet');
      expect(warnings, <String>['Tastenkombination wird bereits von einer anderen Anwendung verwendet']);
    });

    test('registers in-app shortcuts and dispatches their production callbacks', () async {
      final FakeHotkeyBackend hotkeys = FakeHotkeyBackend();
      final FakeWindowBackend window = FakeWindowBackend();
      final List<String> routes = <String>[];
      final DesktopShortcutsServiceImpl service = createService(
        hotkeys: hotkeys,
        window: window,
        navigatedRoutes: routes,
      );
      int focusCount = 0;
      int incomingInvoiceCount = 0;
      int bookingCount = 0;
      int artToggleCount = 0;
      service.onFocusSearch = () => focusCount++;
      service.onNavigateEingang = () => incomingInvoiceCount++;
      service.onOpenBuchung = () => bookingCount++;
      service.onToggleArt = () => artToggleCount++;

      expect(await service.register(), isTrue);
      await hotkeys.invoke(DesktopShortcutAccelerators.focusSearch);
      await hotkeys.invoke(DesktopShortcutAccelerators.navigateEingang);
      await hotkeys.invoke(DesktopShortcutAccelerators.newBuchung);
      await hotkeys.invoke(DesktopShortcutAccelerators.toggleEinnahme);
      await hotkeys.invoke(DesktopShortcutAccelerators.toggleAusgabe);
      await hotkeys.invoke(DesktopShortcutAccelerators.zoomIn);
      await hotkeys.invoke(DesktopShortcutAccelerators.zoomOut);

      expect(focusCount, 1);
      expect(incomingInvoiceCount, 1);
      expect(bookingCount, 1);
      expect(artToggleCount, 2);
      expect(hotkeys.isRegistered(DesktopShortcutAccelerators.zoomIn), isTrue);
      expect(hotkeys.isRegistered(DesktopShortcutAccelerators.zoomOut), isTrue);
    });

    test('unregister removes all production registrations', () async {
      final FakeHotkeyBackend hotkeys = FakeHotkeyBackend();
      final FakeWindowBackend window = FakeWindowBackend();
      final DesktopShortcutsServiceImpl service = createService(
        hotkeys: hotkeys,
        window: window,
        navigatedRoutes: <String>[],
      );

      expect(await service.register(), isTrue);
      await service.unregister();

      expect(service.isRegistered, isFalse);
      expect(hotkeys.isRegistered(DesktopShortcutAccelerators.showHide), isFalse);
    });
  });
}
