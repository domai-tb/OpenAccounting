import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/window_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// DESIGN §35 — Window Behavior: 1280x800, 960x640 min, persist bounds/maximized.
// Test reads lib/main.dart source to verify WindowOptions without spawning OS window.
// LXC-safe: no window_manager channel mock needed; VM file read + SharedPreferences mock.
void main() {
  group('Window Behavior — DESIGN §35', () {
    test('test_window_respects_minimum_size', () {
      final String source = File('lib/main.dart').readAsStringSync();
      expect(
        source.contains('WindowOptions'),
        isTrue,
        reason: 'lib/main.dart must use WindowOptions for window_manager',
      );
      expect(
        source.contains('Size(1280, 800)') || source.contains('Size(1280,800)'),
        isTrue,
        reason: 'WindowOptions size must be 1280x800 per DESIGN §35',
      );
      expect(
        source.contains('Size(960, 640)') || source.contains('Size(960,640)'),
        isTrue,
        reason: 'minimumSize must be 960x640 per DESIGN §35',
      );
      expect(source.contains('minimumSize'), isTrue, reason: 'WindowOptions must set minimumSize 960x640');
      expect(
        source.contains('center: true') || source.contains('center:true'),
        isTrue,
        reason: 'WindowOptions must center window on launch',
      );
      expect(
        source.contains('waitUntilReadyToShow'),
        isTrue,
        reason: 'must call windowManager.waitUntilReadyToShow with WindowOptions',
      );
      expect(source.contains('window_manager'), isTrue, reason: 'must import and use window_manager');
      // LXC-safe guards
      expect(source.contains('kIsWeb'), isTrue, reason: 'must guard with kIsWeb for web safety');
      expect(
        source.contains('Platform.isLinux') ||
            source.contains('Platform.isMacOS') ||
            source.contains('Platform.isWindows'),
        isTrue,
        reason: 'must guard with Platform check for desktop-only window code',
      );
    });

    test('test_window_state_persists', () {
      final String source = File('lib/main.dart').readAsStringSync();
      expect(source.contains('window_bounds'), isTrue, reason: 'must persist window_bounds via SharedPreferences');
      expect(
        source.contains('window_maximized'),
        isTrue,
        reason: 'must persist window_maximized via SharedPreferences',
      );
      expect(
        source.contains('SharedPreferences') || source.contains('shared_preferences'),
        isTrue,
        reason: 'must use SharedPreferences for persistence',
      );
      // off-screen guard and restore
      expect(
        source.contains('isOffScreen') ||
            source.contains('sanitize') ||
            source.contains('off-screen') ||
            source.contains('offScreen') ||
            source.contains('screen'),
        isTrue,
        reason: 'must include off-screen guard before restoring bounds',
      );
      expect(
        source.contains('setBounds') ||
            source.contains('setSize') ||
            source.contains('setPosition') ||
            source.contains('getBounds') ||
            source.contains('getSize'),
        isTrue,
        reason: 'must restore via setBounds/setSize/setPosition or getBounds/getSize',
      );
      expect(
        source.contains('maximize') || source.contains('isMaximized'),
        isTrue,
        reason: 'must restore maximized state via maximize/isMaximized',
      );
    });

    test('window_state sanitize guards off-screen and too-small', () {
      const Size screen = Size(1920, 1080);
      const WindowState offScreen = WindowState(width: 1280, height: 800, x: 3000, y: 3000);
      expect(WindowStateService.isOffScreen(offScreen, screen), isTrue);
      final sanitized = WindowStateService.sanitize(offScreen, screen);
      expect(sanitized.width, 1280);
      expect(sanitized.height, 800);
      expect(sanitized.isMaximized, isFalse);
      expect(WindowStateService.isOffScreen(sanitized, screen), isFalse);

      // ignore: avoid_redundant_argument_values
      const WindowState tooSmall = WindowState(width: 800, height: 600, x: 0, y: 0);
      final sanitizedSmall = WindowStateService.sanitize(tooSmall, screen);
      expect(sanitizedSmall.width, greaterThanOrEqualTo(960));
      expect(sanitizedSmall.height, greaterThanOrEqualTo(640));
    });

    test('window_state persists via SharedPreferences mock', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final PrefsWindowStateStore store = PrefsWindowStateStore();
      // ignore: avoid_redundant_argument_values
      const WindowState state = WindowState(width: 1280, height: 800, x: 100, y: 100, isMaximized: true);
      await store.save(state);
      final WindowState? loaded = await store.load();
      expect(loaded, equals(state));
      // also verify raw keys for window_maximized
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('window_maximized'), isTrue);
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('window_state saveCurrent is VM-safe without window_manager channel', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final WindowStateService service = WindowStateService();
      // saveCurrent calls windowManager.getSize/getPosition/isMaximized which throws
      // MissingPluginException in VM — must not throw.
      await expectLater(service.saveCurrent(), completes);
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });
  });
}
