import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/features/desktop/desktop_shortcuts.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';
import 'package:openaccounting/features/global_search/global_business_search.dart';
import 'package:openaccounting/features/global_search/global_business_search_repository.dart';
import 'package:openaccounting/features/global_search/global_search_entity.dart';
import 'package:openaccounting/l10n/l10n.dart';

final class _RecordingHotkeyBackend implements HotkeyBackend {
  final Map<String, String> _accelerators = <String, String>{};
  final Map<String, Future<void> Function()> _handlers = <String, Future<void> Function()>{};

  @override
  Future<bool> register(String id, String key, Future<void> Function() handler) async {
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

  Future<void> invokeGlobalSearch() async => _handlers['globalSearch']!();
}

final class _FakeWindowBackend implements WindowBackend {
  @override
  Future<void> show() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> close() async {}
}

Future<({AppDatabase db, int invoiceId, int receiptId, int bankTransactionId})> _seedSearchDatabase() async {
  final AppDatabase db = createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Search Test GmbH']);
  final int customerId = await db.executor.runInsert(
    'INSERT INTO kunden (name, firma, strasse, plz, ort, email) VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>['Ada Lovelace', 'Analytical Engines GmbH', 'Rechenweg 1', '10115', 'Berlin', 'private@example.test'],
  );
  final int supplierId = await db.executor.runInsert('INSERT INTO lieferanten (name, firma) VALUES (?, ?)', <Object?>[
    'Grace Hopper',
    'Compiler Systems GmbH',
  ]);
  final int invoiceId = await db.executor.runInsert(
    'INSERT INTO rechnungen (rechnungsnummer, typ, status, kunde_id, datum, brutto_betrag) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>['RE-SEARCH-42', 'ausgangsrechnung', 'offen', customerId, '2026-10-01', 125.50],
  );
  final int receiptId = await db.executor.runInsert(
    'INSERT INTO belege (belegnummer, datum, betrag, lieferant_id, status, beschreibung) VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>['BE-SEARCH-17', '2026-10-02', 24.75, supplierId, 'neu', 'Tastatur Ersatzteil'],
  );
  final int accountId = await db.executor.runInsert('INSERT INTO konten (name) VALUES (?)', <Object?>['Test Bank']);
  final int bankTransactionId = await db.executor.runInsert(
    'INSERT INTO bank_transaktionen '
    '(konto_id, datum, betrag, verwendungszweck, gegenkonto, gegenkonto_name, status) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[accountId, '2026-10-03', -80.25, 'Büromaterial', 'DE001234', 'Paper Office GmbH', 'neu'],
  );
  return (db: db, invoiceId: invoiceId, receiptId: receiptId, bankTransactionId: bankTransactionId);
}

DesktopShortcutsServiceImpl _searchShortcuts(_RecordingHotkeyBackend hotkeys) =>
    DesktopShortcutsServiceImpl(hotkeyBackend: hotkeys, windowBackend: _FakeWindowBackend(), navigate: (_) {});

Widget _routerApp(AppDatabase db, GoRouter router, DesktopShortcutsService service) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    globalSearchShortcutServiceProvider.overrideWithValue(service),
  ],
  child: MaterialApp.router(routerConfig: router),
);

void main() {
  test('test_find_and_open_a_business_record', () async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    final GlobalBusinessSearch search = GlobalBusinessSearch(GlobalBusinessSearchRepository(fixture.db.executor));

    final GlobalBusinessSearchResponse response = await search('RE-SEARCH-42');
    final GlobalBusinessSearchResult invoice = response.results.firstWhere(
      (GlobalBusinessSearchResult result) => result.kind == GlobalSearchRecordKind.invoice,
    );

    expect(invoice.recordId, fixture.invoiceId);
    expect(invoice.route, '/invoices/${fixture.invoiceId}');
    expect(invoice.label, 'RE-SEARCH-42');
    expect(invoice.summary, contains('Analytical Engines GmbH'));
    expect(response.failedSources, isEmpty);
  });

  test('test_find_and_select_a_bank_transaction', () async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    final GlobalBusinessSearch search = GlobalBusinessSearch(GlobalBusinessSearchRepository(fixture.db.executor));

    final GlobalBusinessSearchResponse response = await search('Paper Office');
    final GlobalBusinessSearchResult transaction = response.results.single;

    expect(transaction.kind, GlobalSearchRecordKind.bankTransaction);
    expect(transaction.recordId, fixture.bankTransactionId);
    expect(Uri.parse(transaction.route).path, '/banking');
    expect(Uri.parse(transaction.route).queryParameters['transactionId'], '${fixture.bankTransactionId}');
    expect(transaction.summary, contains('Büromaterial'));
  });

  test('test_search_fails_without_fabricating_records', () async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    await fixture.db.executor.runCustom('DROP TABLE bank_transaktionen');
    final GlobalBusinessSearch search = GlobalBusinessSearch(GlobalBusinessSearchRepository(fixture.db.executor));

    final GlobalBusinessSearchResponse response = await search('Paper Office');

    expect(response.results, isEmpty);
    expect(response.failedSources, contains(GlobalSearchSource.bankTransactions));
  });

  test('test_empty_search_and_unsupported_fields', () async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    final GlobalBusinessSearch search = GlobalBusinessSearch(GlobalBusinessSearchRepository(fixture.db.executor));

    expect((await search('  ')).results, isEmpty);
    expect((await search('private@example.test')).results, isEmpty);
  });

  testWidgets('test_palette_finds_and_opens_a_business_record', (WidgetTester tester) async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    await tester.pumpWidget(_routerApp(fixture.db, router, _searchShortcuts(hotkeys)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('global_search_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('global_search_query')), 'RE-SEARCH-42');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('global_search_result_0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('global_search_result_0')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/invoices/${fixture.invoiceId}');
  });

  testWidgets('test_palette_finds_and_opens_a_bank_transaction', (WidgetTester tester) async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    await tester.pumpWidget(_routerApp(fixture.db, router, _searchShortcuts(hotkeys)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('global_search_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('global_search_query')), 'Paper Office');
    await tester.pumpAndSettle();
    expect(find.text('Paper Office GmbH'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('global_search_result_0')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/banking');
    expect(router.routeInformationProvider.value.uri.queryParameters['transactionId'], '${fixture.bankTransactionId}');
    expect(find.byKey(const ValueKey<String>('bank_selected_transaction')), findsOneWidget);
    expect(find.text('Paper Office GmbH'), findsOneWidget);
  });

  testWidgets('test_search_includes_supported_destination_and_command', (WidgetTester tester) async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    await tester.pumpWidget(_routerApp(fixture.db, router, _searchShortcuts(hotkeys)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('global_search_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('global_search_query')), 'Settings');
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey<String>('global_search_result_0')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');

    await tester.tap(find.byKey(const ValueKey<String>('global_search_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('global_search_query')), 'New invoice');
    await tester.pumpAndSettle();
    expect(find.text('New invoice'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey<String>('global_search_result_0')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/invoices/new');
  });

  testWidgets('test_keyboard_search_preserves_the_current_page', (WidgetTester tester) async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    await tester.pumpWidget(_routerApp(fixture.db, router, _searchShortcuts(hotkeys)));
    await tester.pumpAndSettle();
    router.go('/invoices?typ=ausgangsrechnung&status=offen');
    await tester.pumpAndSettle();
    final Uri before = router.routeInformationProvider.value.uri;

    await hotkeys.invokeGlobalSearch();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('global_search_query')), 'no matching record');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri, before);
    expect(find.byKey(const ValueKey<String>('global_search_palette')), findsNothing);
  });

  testWidgets('test_keyboard_and_assistive_technology_navigation', (WidgetTester tester) async {
    final fixture = await _seedSearchDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final SemanticsHandle semantics = tester.ensureSemantics();
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    await tester.pumpWidget(_routerApp(fixture.db, router, _searchShortcuts(hotkeys)));
    await tester.pumpAndSettle();

    await hotkeys.invokeGlobalSearch();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('global_search_query')), 'RE-SEARCH-42');
    await tester.pumpAndSettle();
    final Finder invoiceResult = find.byKey(const ValueKey<String>('global_search_result_0'));
    expect(invoiceResult, findsOneWidget);
    expect(tester.getSemantics(invoiceResult).label, contains('RE-SEARCH-42'));
    semantics.dispose();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/invoices/${fixture.invoiceId}');
  });

  testWidgets('test_narrow_window_palette', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _RecordingHotkeyBackend hotkeys = _RecordingHotkeyBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [globalSearchShortcutServiceProvider.overrideWithValue(_searchShortcuts(hotkeys))],
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

    await hotkeys.invokeGlobalSearch();
    await tester.pumpAndSettle();

    final Size paletteSize = tester.getSize(find.byKey(const ValueKey<String>('global_search_palette_content')));
    final Rect paletteBounds = tester.getRect(find.byKey(const ValueKey<String>('global_search_palette_content')));
    expect(paletteSize.width, lessThanOrEqualTo(360));
    expect(paletteSize.height, lessThanOrEqualTo(536));
    expect(paletteBounds.left, greaterThanOrEqualTo(0));
    expect(paletteBounds.right, lessThanOrEqualTo(360));
    expect(find.byKey(const ValueKey<String>('global_search_query')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
