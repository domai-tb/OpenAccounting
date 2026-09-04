// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';

abstract class HotkeyBackend {
  Future<bool> register(String id, String key, Future<void> Function() handler);
  Future<void> unregister(String id);
  Future<void> unregisterAll();
}

class HotkeyManagerBackend implements HotkeyBackend {
  final Map<String, HotKey> _keys = <String, HotKey>{};

  HotKey _buildHotKey(String id, String key) {
    final String normalized = key.toLowerCase();
    final List<HotKeyModifier> mods = <HotKeyModifier>[];
    if (normalized.contains('ctrl')) mods.add(HotKeyModifier.control);
    if (normalized.contains('shift')) mods.add(HotKeyModifier.shift);
    if (normalized.contains('alt')) mods.add(HotKeyModifier.alt);
    if (normalized.contains('meta')) mods.add(HotKeyModifier.meta);
    final String last = key.trim().split('+').last.trim().toLowerCase();
    KeyboardKey k;
    switch (last) {
      case 'i':
        k = LogicalKeyboardKey.keyI;
        break;
      case 'n':
        k = LogicalKeyboardKey.keyN;
        break;
      case 'f':
        k = LogicalKeyboardKey.keyF;
        break;
      case 'e':
        k = LogicalKeyboardKey.keyE;
        break;
      case '+':
      case 'add':
        k = LogicalKeyboardKey.add;
        break;
      default:
        k = LogicalKeyboardKey.keyI;
    }
    return HotKey(identifier: id, key: k, modifiers: mods.isEmpty ? null : mods);
  }

  @override
  Future<bool> register(String id, String key, Future<void> Function() handler) async {
    try {
      final HotKey hk = _buildHotKey(id, key);
      await hotKeyManager.register(hk, keyDownHandler: (HotKey _) async => handler());
      _keys[id] = hk;
      return true;
    } on MissingPluginException catch (_) {
      return false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> unregister(String id) async {
    try {
      final HotKey? hk = _keys.remove(id);
      if (hk != null) await hotKeyManager.unregister(hk);
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> unregisterAll() async {
    try {
      await hotKeyManager.unregisterAll();
      _keys.clear();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }
}

class _UnsupportedHotkeyBackend implements HotkeyBackend {
  @override
  Future<bool> register(String id, String key, Future<void> Function() handler) async => false;
  @override
  Future<void> unregister(String id) async {}
  @override
  Future<void> unregisterAll() async {}
}

abstract class DesktopShortcutsService {
  bool get isRegistered;
  String? get lastWarning;
  Future<bool> register();
  Future<void> unregister();
  void Function()? get onShowHide;
  set onShowHide(void Function()? value);
  void Function()? get onNewInvoice;
  set onNewInvoice(void Function()? value);
  void Function()? get onFocusSearch;
  set onFocusSearch(void Function()? value);
  void Function()? get onNavigateEingang;
  set onNavigateEingang(void Function()? value);
  void Function()? get onOpenBuchung;
  set onOpenBuchung(void Function()? value);
  void Function()? get onToggleArt;
  set onToggleArt(void Function()? value);

  static final LogicalKeySet focusSearchKeySet = LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF);
  static final LogicalKeySet navigateEingangKeySet = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.keyE,
  );
  static final LogicalKeySet openBuchungKeySet = LogicalKeySet(LogicalKeyboardKey.add);
  static final LogicalKeySet toggleEinnahmeKeySet = LogicalKeySet(LogicalKeyboardKey.keyE);
  static final LogicalKeySet toggleAusgabeKeySet = LogicalKeySet(LogicalKeyboardKey.keyA);
  static final LogicalKeySet zoomInKeySet = LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.equal);
  static final LogicalKeySet zoomOutKeySet = LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.minus);
}

class DesktopShortcutsServiceImpl implements DesktopShortcutsService {
  DesktopShortcutsServiceImpl({
    required HotkeyBackend hotkeyBackend,
    required WindowBackend windowBackend,
    required void Function(String route) navigate,
    void Function(String)? onWarning,
  }) : _hotkeys = hotkeyBackend,
       _window = windowBackend,
       _navigate = navigate,
       _onWarning = onWarning {
    _onShowHide = _handleShowHide;
    _onNewInvoice = _handleNewInvoice;
    _onFocusSearch = () {};
    _onNavigateEingang = () {};
    _onOpenBuchung = () {};
    _onToggleArt = () {};
  }

  final HotkeyBackend _hotkeys;
  final WindowBackend _window;
  final void Function(String route) _navigate;
  final void Function(String)? _onWarning;

  bool _isRegistered = false;
  String? _lastWarning;
  bool _isVisible = false;

  late void Function()? _onShowHide;
  late void Function()? _onNewInvoice;
  late void Function()? _onFocusSearch;
  late void Function()? _onNavigateEingang;
  late void Function()? _onOpenBuchung;
  late void Function()? _onToggleArt;

  @override
  bool get isRegistered => _isRegistered;
  @override
  String? get lastWarning => _lastWarning;
  @override
  void Function()? get onShowHide => _onShowHide;
  @override
  set onShowHide(void Function()? value) => _onShowHide = value;
  @override
  void Function()? get onNewInvoice => _onNewInvoice;
  @override
  set onNewInvoice(void Function()? value) => _onNewInvoice = value;
  @override
  void Function()? get onFocusSearch => _onFocusSearch;
  @override
  set onFocusSearch(void Function()? value) => _onFocusSearch = value;
  @override
  void Function()? get onNavigateEingang => _onNavigateEingang;
  @override
  set onNavigateEingang(void Function()? value) => _onNavigateEingang = value;
  @override
  void Function()? get onOpenBuchung => _onOpenBuchung;
  @override
  set onOpenBuchung(void Function()? value) => _onOpenBuchung = value;
  @override
  void Function()? get onToggleArt => _onToggleArt;
  @override
  set onToggleArt(void Function()? value) => _onToggleArt = value;

  void _handleShowHide() {
    if (_isVisible) {
      // ignore: discarded_futures
      _window.hide();
      _isVisible = false;
    } else {
      // ignore: discarded_futures
      _window.show();
      _isVisible = true;
    }
  }

  void _handleNewInvoice() {
    // ignore: discarded_futures
    _window.show();
    _isVisible = true;
    _navigate('/invoices/new');
  }

  @override
  Future<bool> register() async {
    if (kIsWeb) {
      _lastWarning = null;
      _isRegistered = false;
      return false;
    }
    try {
      final bool a = await _hotkeys.register('showHide', 'Ctrl+Shift+I', () async => _onShowHide?.call());
      final bool b = await _hotkeys.register('newInvoice', 'Ctrl+Shift+N', () async => _onNewInvoice?.call());
      if (!a || !b) {
        _lastWarning = 'Tastenkombination wird bereits von einer anderen Anwendung verwendet';
        _onWarning?.call(_lastWarning!);
        await _hotkeys.unregisterAll();
        _isRegistered = false;
        return false;
      }
      _lastWarning = null;
      _isRegistered = true;
      return true;
    } on MissingPluginException catch (_) {
      _lastWarning = 'Tastenkombination wird bereits von einer anderen Anwendung verwendet';
      _onWarning?.call(_lastWarning!);
      _isRegistered = false;
      return false;
    } on PlatformException catch (_) {
      _lastWarning = 'Tastenkombination wird bereits von einer anderen Anwendung verwendet';
      _onWarning?.call(_lastWarning!);
      _isRegistered = false;
      return false;
    } catch (_) {
      _lastWarning = 'Tastenkombination wird bereits von einer anderen Anwendung verwendet';
      _onWarning?.call(_lastWarning!);
      _isRegistered = false;
      return false;
    }
  }

  @override
  Future<void> unregister() async {
    try {
      await _hotkeys.unregisterAll();
    } on MissingPluginException catch (_) {
      return;
    } on PlatformException catch (_) {
      return;
    } catch (_) {
      return;
    }
    _isRegistered = false;
  }
}

DesktopShortcutsService createDesktopShortcutsService({
  required WindowBackend windowBackend,
  required void Function(String route) navigate,
  void Function(String)? onWarning,
}) {
  if (kIsWeb) {
    return DesktopShortcutsServiceImpl(
      hotkeyBackend: _UnsupportedHotkeyBackend(),
      windowBackend: windowBackend,
      navigate: navigate,
      onWarning: onWarning,
    );
  }
  return DesktopShortcutsServiceImpl(
    hotkeyBackend: HotkeyManagerBackend(),
    windowBackend: windowBackend,
    navigate: navigate,
    onWarning: onWarning,
  );
}
