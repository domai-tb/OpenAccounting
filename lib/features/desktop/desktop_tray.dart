import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

const List<String> _kMenuLabels = <String>['Fenster anzeigen', 'Daten aktualisieren', 'Nach Updates suchen', 'Beenden'];

/// Abstraction over system_tray plugin — injectable for VM tests.
abstract class TrayBackend {
  Future<bool> initSystemTray({required String title, required String iconPath, String? toolTip});

  Future<void> setContextMenu(List<String> labels, List<Future<void> Function()> handlers);

  Future<void> dispose();
}

/// Abstraction over window_manager plugin.
abstract class WindowBackend {
  Future<void> show();

  Future<void> hide();

  Future<void> close();
}

/// Real system_tray adapter — VM-safe via try/catch.
class SystemTrayBackend implements TrayBackend {
  SystemTrayBackend({SystemTray? tray}) : _tray = tray ?? SystemTray();

  final SystemTray _tray;

  @override
  Future<bool> initSystemTray({required String title, required String iconPath, String? toolTip}) async {
    try {
      return await _tray.initSystemTray(title: title, iconPath: iconPath, toolTip: toolTip);
    } on MissingPluginException catch (_) {
      return false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setContextMenu(List<String> labels, List<Future<void> Function()> handlers) async {
    try {
      final List<MenuItemBase> items = <MenuItemBase>[];
      for (int i = 0; i < labels.length; i++) {
        final int index = i;
        items.add(
          MenuItem(
            label: labels[index],
            onClicked: () {
              // ignore: discarded_futures — fire and forget from native callback
              handlers[index]();
            },
          ),
        );
      }
      await _tray.setContextMenu(items);
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> dispose() async {
    // system_tray has no explicit dispose; no-op VM-safe.
    return;
  }
}

/// Real window_manager adapter — VM-safe.
class WindowManagerBackend implements WindowBackend {
  @override
  Future<void> show() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> hide() async {
    try {
      await windowManager.hide();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> close() async {
    try {
      await windowManager.close();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }
}

abstract class DesktopTrayService {
  bool get isSupported;

  List<String> get menuLabels;

  Future<bool> init();

  Future<void> onShow();

  Future<void> onRefresh();

  Future<void> onCheckUpdate();

  Future<void> onQuit();

  Future<bool> handleCloseRequest({required bool minimizeToTray});

  Future<void> dispose();
}

class DesktopTrayServiceImpl implements DesktopTrayService {
  DesktopTrayServiceImpl({required TrayBackend trayBackend, required WindowBackend windowBackend})
    : _tray = trayBackend,
      _window = windowBackend;

  final TrayBackend _tray;
  final WindowBackend _window;
  bool _supported = false;

  @override
  bool get isSupported => _supported;

  @override
  List<String> get menuLabels => _supported ? _kMenuLabels : const <String>[];

  @override
  Future<bool> init() async {
    if (kIsWeb) {
      _supported = false;
      return false;
    }
    try {
      final bool ok = await _tray.initSystemTray(title: 'OpenAccounting', iconPath: '', toolTip: 'OpenAccounting');
      if (!ok) {
        _supported = false;
        return false;
      }
      await _tray.setContextMenu(_kMenuLabels, <Future<void> Function()>[onShow, onRefresh, onCheckUpdate, onQuit]);
      _supported = true;
      return true;
    } on MissingPluginException catch (_) {
      _supported = false;
      return false;
    } on PlatformException catch (_) {
      _supported = false;
      return false;
    } catch (_) {
      _supported = false;
      return false;
    }
  }

  @override
  Future<void> onShow() async {
    try {
      await _window.show();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> onRefresh() async {
    return;
  }

  @override
  Future<void> onCheckUpdate() async {
    return;
  }

  @override
  Future<void> onQuit() async {
    try {
      await _window.close();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  @override
  Future<bool> handleCloseRequest({required bool minimizeToTray}) async {
    if (minimizeToTray && _supported) {
      try {
        await _window.hide();
      } on MissingPluginException catch (_) {
        return false;
      } on PlatformException catch (_) {
        return false;
      } catch (_) {
        return false;
      }
      return true;
    }
    try {
      await _window.close();
    } on MissingPluginException catch (_) {
      return false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
    return false;
  }

  @override
  Future<void> dispose() async {
    try {
      await _tray.dispose();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }
}

DesktopTrayService createDesktopTrayService() {
  if (kIsWeb) {
    return DesktopTrayServiceImpl(trayBackend: _UnsupportedTrayBackend(), windowBackend: _NoopWindowBackend());
  }
  return DesktopTrayServiceImpl(trayBackend: SystemTrayBackend(), windowBackend: WindowManagerBackend());
}

class _UnsupportedTrayBackend implements TrayBackend {
  @override
  Future<bool> initSystemTray({required String title, required String iconPath, String? toolTip}) async => false;

  @override
  Future<void> setContextMenu(List<String> labels, List<Future<void> Function()> handlers) async {}

  @override
  Future<void> dispose() async {}
}

class _NoopWindowBackend implements WindowBackend {
  @override
  Future<void> close() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> show() async {}
}
