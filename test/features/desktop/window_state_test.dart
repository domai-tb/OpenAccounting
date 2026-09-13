import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/window_state.dart';

class FakeWindowStateStore implements WindowStateStore {
  WindowState? _state;
  @override
  Future<WindowState?> load() async => _state;
  @override
  Future<void> save(WindowState state) async => _state = state;
}

void main() {
  group('WindowState — equality and defaults', () {
    test('default constructor uses 1200x800', () {
      const WindowState s = WindowState();
      expect(s.width, 1200);
      expect(s.height, 800);
      expect(s.isMaximized, isFalse);
    });

    test('copyWith preserves unmentioned fields', () {
      const WindowState s = WindowState(width: 1400, height: 900, x: 200, y: 100, isMaximized: true);
      final WindowState s2 = s.copyWith(width: 1600);
      expect(s2.width, 1600);
      expect(s2.height, 900);
      expect(s2.x, 200);
      expect(s2.isMaximized, isTrue);
    });

    test('equality compares all fields', () {
      const WindowState a = WindowState(width: 100, height: 200, x: 10, y: 20);
      const WindowState b = WindowState(width: 100, height: 200, x: 10, y: 20);
      const WindowState c = WindowState(width: 100, height: 200, x: 10, y: 30);
      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });

  group('WindowStateService', () {
    test('minimum size constants', () {
      expect(WindowStateService.minWidth, 960);
      expect(WindowStateService.minHeight, 640);
    });

    test('sanitize returns original when within bounds', () {
      const WindowState s = WindowState(width: 1400, height: 900, x: 100, y: 100);
      final WindowState result = WindowStateService.sanitize(s, const Size(1920, 1080));
      expect(result, s);
    });

    test('sanitize returns centered default when too small', () {
      const WindowState s = WindowState(width: 500, height: 400);
      final WindowState result = WindowStateService.sanitize(s, const Size(1920, 1080));
      expect(result.width, 1280);
      expect(result.height, 800);
      expect(result.x, closeTo(320, 1));
      expect(result.y, closeTo(140, 1));
    });

    test('sanitize returns centered default when off-screen', () {
      const WindowState s = WindowState(width: 1400, height: 900, x: -2000, y: -2000);
      final WindowState result = WindowStateService.sanitize(s, const Size(1920, 1080));
      expect(result.width, 1280);
      expect(result.height, 800);
    });

    test('isOffScreen detects fully outside bounds', () {
      const WindowState s = WindowState(width: 1400, height: 900, x: -2000, y: 100);
      expect(WindowStateService.isOffScreen(s, const Size(1920, 1080)), isTrue);
    });

    test('isOffScreen returns false for valid position', () {
      const WindowState s = WindowState(width: 1400, height: 900, x: 100, y: 100);
      expect(WindowStateService.isOffScreen(s, const Size(1920, 1080)), isFalse);
    });

    test('save and load round-trip via fake store', () async {
      final FakeWindowStateStore store = FakeWindowStateStore();
      final WindowStateService service = WindowStateService(store: store);
      const WindowState state = WindowState(width: 1400, height: 900, x: 200, y: 100, isMaximized: true);
      await service.save(state);
      final WindowState? loaded = await store.load();
      expect(loaded, state);
    });
  });
}
