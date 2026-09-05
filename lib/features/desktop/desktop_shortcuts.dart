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

abstract final class DesktopShortcutAccelerators {
  static const String showHide = 'Ctrl+Shift+I';
  static const String newInvoice = 'Ctrl+Shift+N';
  static const String focusSearch = 'Ctrl+F';
  static const String navigateEingang = 'Ctrl+Shift+E';
  static const String newBuchung = '+';
  static const String toggleEinnahme = 'E';
  static const String toggleAusgabe = 'A';
  static const String zoomIn = 'Ctrl+=';
  static const String zoomOut = 'Ctrl+-';
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
      case 'a':
        k = LogicalKeyboardKey.keyA;
        break;
      case '+':
      case 'add':
        k = LogicalKeyboardKey.add;
        break;
      case '=':
        k = LogicalKeyboardKey.equal;
        break;
      case '-':
        k = LogicalKeyboardKey.minus;
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
      final List<bool> registrations = <bool>[
        await _hotkeys.register('showHide', DesktopShortcutAccelerators.showHide, () async => _onShowHide?.call()),
        await _hotkeys.register(
          'newInvoice',
          DesktopShortcutAccelerators.newInvoice,
          () async => _onNewInvoice?.call(),
        ),
        await _hotkeys.register(
          'focusSearch',
          DesktopShortcutAccelerators.focusSearch,
          () async => _onFocusSearch?.call(),
        ),
        await _hotkeys.register(
          'navigateEingang',
          DesktopShortcutAccelerators.navigateEingang,
          () async => _onNavigateEingang?.call(),
        ),
        await _hotkeys.register(
          'newBuchung',
          DesktopShortcutAccelerators.newBuchung,
          () async => _onOpenBuchung?.call(),
        ),
        await _hotkeys.register(
          'toggleEinnahme',
          DesktopShortcutAccelerators.toggleEinnahme,
          () async => _onToggleArt?.call(),
        ),
        await _hotkeys.register(
          'toggleAusgabe',
          DesktopShortcutAccelerators.toggleAusgabe,
          () async => _onToggleArt?.call(),
        ),
        await _hotkeys.register('zoomIn', DesktopShortcutAccelerators.zoomIn, () async {}),
        await _hotkeys.register('zoomOut', DesktopShortcutAccelerators.zoomOut, () async {}),
      ];
      if (registrations.any((bool registered) => !registered)) {
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
