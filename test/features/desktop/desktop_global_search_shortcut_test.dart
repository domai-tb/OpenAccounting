import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/app/app_shell.dart';
import 'package:openaccounting/features/desktop/desktop_shortcuts.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';
import 'package:openaccounting/l10n/l10n.dart';

final class _RecordingHotkeyBackend implements HotkeyBackend {
  _RecordingHotkeyBackend({this.allowRegistrations = true});

  final bool allowRegistrations;
  final Map<String, String> _accelerators = <String, String>{};
  final Map<String, Future<void> Function()> _handlers = <String, Future<void> Function()>{};

  @override
  Future<bool> register(String id, String key, Future<void> Function() handler) async {
    if (!allowRegistrations) return false;
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

  bool hasAccelerator(String key) => _accelerators.values.contains(key);

  Future<void> invokeAccelerator(String key) async {
    final String id = _accelerators.entries.firstWhere((entry) => entry.value == key).key;
    await _handlers[id]!();
  }
}

final class _FakeWindowBackend implements WindowBackend {
  @override
  Future<void> show() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> close() async {}
}

void main() {
  test('test_global_search_shortcut_registers_and_invokes_one_action', () async {
    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    final DesktopShortcutsServiceImpl service = DesktopShortcutsServiceImpl(
      hotkeyBackend: hotkeys,
      windowBackend: _FakeWindowBackend(),
      navigate: (_) {},
    );
    int opens = 0;
    service.onGlobalSearch = () => opens++;

    expect(await service.register(), isTrue);
    expect(hotkeys.hasAccelerator('Ctrl+K'), isTrue);
    await hotkeys.invokeAccelerator('Ctrl+K');
    expect(opens, 1);
  });

  testWidgets('test_global_search_shortcut_opens_the_palette', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    final DesktopShortcutsServiceImpl service = DesktopShortcutsServiceImpl(
      hotkeyBackend: hotkeys,
      windowBackend: _FakeWindowBackend(),
      navigate: (_) {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [globalSearchShortcutServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppShell(
            location: '/',
            child: Scaffold(body: Text('Current page')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('global_search_button')), findsOneWidget);

    await hotkeys.invokeAccelerator('Ctrl+K');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('global_search_palette')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('test_shortcut_does_not_consume_text_input', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    final DesktopShortcutsServiceImpl service = DesktopShortcutsServiceImpl(
      hotkeyBackend: hotkeys,
      windowBackend: _FakeWindowBackend(),
      navigate: (_) {},
    );
    final TextEditingController input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [globalSearchShortcutServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppShell(
            location: '/',
            child: Scaffold(body: TextField(controller: input, autofocus: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);

    await hotkeys.invokeAccelerator('Ctrl+K');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('global_search_palette')), findsNothing);
    expect(input.text, isEmpty);
  });

  testWidgets('test_shortcut_registration_is_unavailable', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend(allowRegistrations: false);
    final DesktopShortcutsServiceImpl service = DesktopShortcutsServiceImpl(
      hotkeyBackend: hotkeys,
      windowBackend: _FakeWindowBackend(),
      navigate: (_) {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [globalSearchShortcutServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppShell(
            location: '/',
            child: Scaffold(body: Text('Current page')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.isGlobalSearchRegistered, isFalse);
    expect(find.byKey(const ValueKey<String>('global_search_button')), findsOneWidget);
    expect(find.byTooltip('Global search (keyboard shortcut unavailable)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('global_search_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('global_search_palette')), findsOneWidget);
  });
}
