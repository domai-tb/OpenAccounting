import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Immutable window geometry persisted across sessions.
@immutable
class WindowState {
  const WindowState({this.width = 1200, this.height = 800, this.x = 0, this.y = 0, this.isMaximized = false});

  final double width;
  final double height;
  final double x;
  final double y;
  final bool isMaximized;

  WindowState copyWith({double? width, double? height, double? x, double? y, bool? isMaximized}) => WindowState(
    width: width ?? this.width,
    height: height ?? this.height,
    x: x ?? this.x,
    y: y ?? this.y,
    isMaximized: isMaximized ?? this.isMaximized,
  );

  @override
  bool operator ==(Object other) =>
      other is WindowState &&
      other.width == width &&
      other.height == height &&
      other.x == x &&
      other.y == y &&
      other.isMaximized == isMaximized;

  @override
  int get hashCode => Object.hash(width, height, x, y, isMaximized);
}

/// Persistence abstraction — injectable for VM tests.
abstract class WindowStateStore {
  Future<WindowState?> load();

  Future<void> save(WindowState state);
}

/// SharedPreferences implementation — VM-safe try/catch.
class PrefsWindowStateStore implements WindowStateStore {
  static const String _kWidth = 'window_width';
  static const String _kHeight = 'window_height';
  static const String _kX = 'window_x';
  static const String _kY = 'window_y';
  static const String _kMaximized = 'window_maximized';

  @override
  Future<WindowState?> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_kWidth) || !prefs.containsKey(_kHeight)) {
        return null;
      }
      final double? w = prefs.getDouble(_kWidth);
      final double? h = prefs.getDouble(_kHeight);
      if (w == null || h == null) {
        return null;
      }
      final double x = prefs.getDouble(_kX) ?? 0;
      final double y = prefs.getDouble(_kY) ?? 0;
      final bool m = prefs.getBool(_kMaximized) ?? false;
      return WindowState(width: w, height: h, x: x, y: y, isMaximized: m);
    } on MissingPluginException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(WindowState state) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kWidth, state.width);
      await prefs.setDouble(_kHeight, state.height);
      await prefs.setDouble(_kX, state.x);
      await prefs.setDouble(_kY, state.y);
      await prefs.setBool(_kMaximized, state.isMaximized);
    } on MissingPluginException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }
}

class WindowStateService {
  WindowStateService({WindowStateStore? store}) : _store = store ?? PrefsWindowStateStore();

  final WindowStateStore _store;

  static const double minWidth = 960;
  static const double minHeight = 640;
  static const double defaultWidth = 1280;
  static const double defaultHeight = 800;

  /// True when window is completely outside [screen].
  static bool isOffScreen(WindowState s, Size screen) {
    if (s.width <= 0 || s.height <= 0) {
      return true;
    }
    // Fully outside bounds.
    if (s.x + s.width < 0 || s.x > screen.width) {
      return true;
    }
    if (s.y + s.height < 0 || s.y > screen.height) {
      return true;
    }
    return false;
  }

  /// Returns centered 1200x800 when off-screen or below minimum, else [s].
  static WindowState sanitize(WindowState s, Size screen) {
    final bool tooSmall = s.width < minWidth || s.height < minHeight;
    if (tooSmall || isOffScreen(s, screen)) {
      final double cx = (screen.width - defaultWidth) / 2;
      final double cy = (screen.height - defaultHeight) / 2;
      return WindowState(width: defaultWidth, x: cx < 0 ? 0 : cx, y: cy < 0 ? 0 : cy);
    }
    return s;
  }

  /// Restore window geometry on launch. VM-safe, never throws.
  Future<void> init() async {
    if (kIsWeb) {
      return;
    }
    try {
      await windowManager.ensureInitialized();
      await windowManager.setMinimumSize(const Size(minWidth, minHeight));
      final WindowState? saved = await _store.load();
      if (saved == null) {
        await windowManager.setSize(const Size(defaultWidth, defaultHeight));
        await windowManager.center();
        return;
      }
      Size screen = const Size(1920, 1080);
      try {
        final WidgetsBinding binding = WidgetsBinding.instance;
        // ignore: avoid_dynamic_calls
        final dynamic view = binding.platformDispatcher.views.firstOrNull;
        if (view != null) {
          // ignore: avoid_dynamic_calls
          final Size phys = view.physicalSize as Size;
          // ignore: avoid_dynamic_calls
          final double dpr = view.devicePixelRatio as double;
          if (phys.width > 0 && phys.height > 0 && dpr > 0) {
            screen = Size(phys.width / dpr, phys.height / dpr);
          }
        }
      } catch (_) {
        // keep fallback
      }
      final WindowState sanitized = sanitize(saved, screen);
      await windowManager.setSize(Size(sanitized.width, sanitized.height));
      if (sanitized.isMaximized) {
        // Set position before maximize so un-maximize restores correctly.
        try {
          await windowManager.setPosition(Offset(sanitized.x, sanitized.y));
        } catch (_) {}
        await windowManager.maximize();
      } else {
        // If sanitization produced centered fallback, center; else restore position.
        if (sanitized != saved) {
          await windowManager.center();
        } else {
          await windowManager.setPosition(Offset(sanitized.x, sanitized.y));
        }
      }
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  Future<void> save(WindowState state) => _store.save(state);

  /// Capture current window bounds + maximized and persist.
  Future<void> saveCurrent() async {
    if (kIsWeb) {
      return;
    }
    try {
      final Size size = await windowManager.getSize();
      final Offset pos = await windowManager.getPosition();
      final bool max = await windowManager.isMaximized();
      await _store.save(WindowState(width: size.width, height: size.height, x: pos.dx, y: pos.dy, isMaximized: max));
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }
}
