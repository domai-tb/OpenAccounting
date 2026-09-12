import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app.dart';
import 'package:openaccounting/core/app_locale.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/theme/app_theme.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';
import 'package:openaccounting/features/desktop/window_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

DesktopTrayService? _desktopTrayService;
final _WindowPersistenceListener _windowPersistenceListener = _WindowPersistenceListener();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        await _setupWindow();
      } catch (_) {
        // LXC/test safe — never block launch
      }
    }
    try {
      final DesktopTrayService tray = createDesktopTrayService();
      _desktopTrayService = tray;
      unawaited(tray.init().catchError((Object _) => false));
    } catch (_) {
      // unsupported platform — continue without tray
    }
  }
  final profileManager = ProfileManager();
  final activeProfile = await profileManager.getActiveProfile();
  final profileDirectory = profileManager.profileDir(activeProfile);
  await Directory(profileDirectory).create(recursive: true);
  final db = AppDatabase.forProfile(profileDirectory);
  await db.ensureOpen();
  final AppServices services = AppServices(db);
  // Preload theme before runApp to avoid flash — DESIGN §7 System persist.
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? savedTheme = prefs.getString('openaccounting.theme_mode');
  final ThemeMode initialTheme = ThemeMode.values.firstWhere(
    (ThemeMode e) => e.name == savedTheme,
    orElse: () => ThemeMode.system,
  );
  final bool initialPrivacyMode = prefs.getBool('openaccounting.privacy_mode') ?? false;
  final Locale initialLocale = parseAppLocale(prefs.getString(appLocalePreferenceKey));
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(() {
            unawaited(db.close());
          });
          return db;
        }),
        themeModeProvider.overrideWith(() => _PreloadedThemeModeNotifier(initialTheme)),
        appLocaleProvider.overrideWith(() => _PreloadedAppLocaleNotifier(initialLocale)),
        privacyModeProvider.overrideWith(() => _PreloadedPrivacyModeNotifier(initial: initialPrivacyMode)),
        appServicesProvider.overrideWithValue(services),
      ],
      child: AppScope(services: services, child: const OpenAccountingApp()),
    ),
  );
}

class _PreloadedThemeModeNotifier extends ThemeModeNotifier {
  _PreloadedThemeModeNotifier(this._initial);
  final ThemeMode _initial;
  @override
  ThemeMode build() => _initial;
}

class _PreloadedAppLocaleNotifier extends AppLocaleNotifier {
  _PreloadedAppLocaleNotifier(this._initial);
  final Locale _initial;

  @override
  Locale build() => _initial;
}

class _PreloadedPrivacyModeNotifier extends PrivacyModeNotifier {
  _PreloadedPrivacyModeNotifier({required bool initial}) : _initial = initial; // ignore: prefer_initializing_formals
  final bool _initial;

  @override
  bool build() => _initial;
}

Future<void> _setupWindow() async {
  await windowManager.ensureInitialized();
  windowManager.addListener(_windowPersistenceListener);
  const WindowOptions windowOptions = WindowOptions(size: Size(1280, 800), center: true, minimumSize: Size(960, 640));
  if (await _tryRestore(windowOptions)) {
    unawaited(_persistBounds());
    return;
  }
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  unawaited(_persistBounds());
}

Future<bool> _tryRestore(WindowOptions windowOptions) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawBounds = prefs.getString('window_bounds');
    final bool maximized = prefs.getBool('window_maximized') ?? false;
    if (rawBounds == null) {
      return false;
    }
    final List<String> parts = rawBounds.split(',');
    if (parts.length != 4) {
      return false;
    }
    final double? x = double.tryParse(parts[0]);
    final double? y = double.tryParse(parts[1]);
    final double? w = double.tryParse(parts[2]);
    final double? h = double.tryParse(parts[3]);
    if (x == null || y == null || w == null || h == null) {
      return false;
    }
    final WindowState saved = WindowState(width: w, height: h, x: x, y: y, isMaximized: maximized);
    final Size screen = _currentScreenSize();
    if (WindowStateService.isOffScreen(saved, screen)) {
      return false;
    }
    final WindowState sanitized = WindowStateService.sanitize(saved, screen);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setBounds(Rect.fromLTWH(sanitized.x, sanitized.y, sanitized.width, sanitized.height));
      await windowManager.setSize(Size(sanitized.width, sanitized.height));
      await windowManager.setPosition(Offset(sanitized.x, sanitized.y));
      if (sanitized.isMaximized) {
        await windowManager.maximize();
      }
      await windowManager.show();
      await windowManager.focus();
    });
    return true;
  } catch (_) {
    return false;
  }
}

Size _currentScreenSize() {
  try {
    final WidgetsBinding binding = WidgetsBinding.instance;
    final ui.FlutterView? view = binding.platformDispatcher.views.firstOrNull;
    if (view != null) {
      final Size phys = view.physicalSize;
      final double dpr = view.devicePixelRatio;
      if (phys.width > 0 && phys.height > 0 && dpr > 0) {
        return Size(phys.width / dpr, phys.height / dpr);
      }
    }
  } catch (_) {}
  return const Size(1920, 1080);
}

Future<void> _persistBounds() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Rect bounds = await windowManager.getBounds();
    final bool maximized = await windowManager.isMaximized();
    await prefs.setString('window_bounds', '${bounds.left},${bounds.top},${bounds.width},${bounds.height}');
    await prefs.setBool('window_maximized', maximized);
    // off-screen guard verified via isOffScreen on next launch
  } catch (_) {}
}

class _WindowPersistenceListener with WindowListener {
  void _persist() {
    unawaited(_persistBounds());
  }

  @override
  void onWindowClose() {
    _persist();
    final DesktopTrayService? tray = _desktopTrayService;
    if (tray != null) {
      unawaited(tray.dispose());
    }
  }

  @override
  void onWindowMaximize() => _persist();

  @override
  void onWindowUnmaximize() => _persist();

  @override
  void onWindowMoved() => _persist();

  @override
  void onWindowResized() => _persist();
}
