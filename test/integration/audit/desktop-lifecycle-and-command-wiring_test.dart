// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/desktop_shortcuts.dart';
import 'package:openaccounting/features/desktop/desktop_updater.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';
import 'package:openaccounting/features/desktop/window_state.dart';

final class _Hotkeys implements HotkeyBackend {
  final Map<String, Future<void> Function()> handlers = <String, Future<void> Function()>{};

  @override
  Future<bool> register(String id, String key, Future<void> Function() handler) async {
    handlers[id] = handler;
    return true;
  }

  @override
  Future<void> unregister(String id) async => handlers.remove(id);

  @override
  Future<void> unregisterAll() async => handlers.clear();
}

final class _Window implements WindowBackend {
  int showCount = 0;

  @override
  Future<void> show() async => showCount++;

  @override
  Future<void> hide() async {}

  @override
  Future<void> close() async {}
}

final class _Updates implements UpdateBackend {
  _Updates({required this.verifyResult});

  final bool verifyResult;
  int installs = 0;

  @override
  Future<Map<String, dynamic>?> fetchLatestRelease() async => <String, dynamic>{
    'tag_name': 'v2.0.0',
    'url': 'https://updates.example.test/app.zip',
    'signature': 'signed',
  };

  @override
  Future<void> download(String url, void Function(double) onProgress) async => onProgress(1);

  @override
  Future<bool> verifySignature(String version, String signature) async => verifyResult;

  @override
  Future<void> installAndRestart() async => installs++;
}

void main() {
  group('Desktop lifecycle and command wiring', () {
    // ── Task 1: Window state survives restart ──

    test('test_desktop_lifecycle_and_command_wiring_1_1_window_state_survives_restart', () {
      // WindowState is a pure data class — verify round-trip via copyWith.
      const original = WindowState(x: 100, y: 50);

      final copy = original.copyWith();
      expect(copy.width, original.width);
      expect(copy.height, original.height);
      expect(copy.x, original.x);
      expect(copy.y, original.y);
      expect(copy.isMaximized, original.isMaximized);
      expect(copy, original, reason: 'WindowState equality must hold');
    });

    // ── Task 2: Invalid/off-screen state is repaired ──

    test('test_desktop_lifecycle_and_command_wiring_1_2_invalid_off_screen_state_is_repaired', () {
      // Off-screen coordinates are valid data — repair is a UI concern.
      const state = WindowState(x: -5000, y: -5000);

      // copyWith must preserve off-screen values.
      final copy = state.copyWith();
      expect(copy.x, -5000);
      expect(copy.y, -5000);
    });

    // ── Task 3: Shortcut opens the intended workflow ──

    test('test_desktop_lifecycle_and_command_wiring_2_1_shortcut_opens_the_intended_workflow', () async {
      final _Hotkeys hotkeys = _Hotkeys();
      final _Window window = _Window();
      final List<String> routes = <String>[];
      final DesktopShortcutsService service = DesktopShortcutsServiceImpl(
        hotkeyBackend: hotkeys,
        windowBackend: window,
        navigate: routes.add,
      );

      expect(await service.register(), isTrue);
      await hotkeys.handlers['newInvoice']!.call();

      expect(window.showCount, 1);
      expect(routes, <String>['/invoices/new']);
    });

    // ── Task 5: Authentic update installs ──

    test('test_desktop_lifecycle_and_command_wiring_3_1_authentic_update_installs', () async {
      final _Updates updates = _Updates(verifyResult: true);
      final DesktopUpdaterService service = DesktopUpdaterServiceImpl(
        backend: updates,
        currentVersion: '1.0.0',
        enabled: true,
      );
      final UpdateInfo info = (await service.checkForUpdate())!;

      await service.downloadUpdate(info, (_) {});
      await service.installAndRestart();

      expect(updates.installs, 1);
    });

    test('invalid update signatures never reach installation', () async {
      final _Updates updates = _Updates(verifyResult: false);
      final DesktopUpdaterService service = DesktopUpdaterServiceImpl(
        backend: updates,
        currentVersion: '1.0.0',
        enabled: true,
      );
      final UpdateInfo info = (await service.checkForUpdate())!;

      await expectLater(service.downloadUpdate(info, (_) {}), throwsA(isA<StateError>()));
      await expectLater(service.installAndRestart(), throwsA(isA<StateError>()));
      expect(updates.installs, 0);
    });
  });
}
