import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/core/router/typed_workspace_search.dart';
import 'package:openaccounting/features/desktop/desktop_shortcuts.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';
import 'package:openaccounting/l10n/l10n.dart';

final class _NoopHotkeyBackend implements HotkeyBackend {
  @override
  Future<bool> register(String id, String key, Future<void> Function() handler) async => true;

  @override
  Future<void> unregister(String id) async {}

  @override
  Future<void> unregisterAll() async {}
}

final class _NoopWindowBackend implements WindowBackend {
  @override
  Future<void> show() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> close() async {}
}

final class _RecordingTypedWorkspaceSearchRepository extends TypedWorkspaceSearchRepository {
  _RecordingTypedWorkspaceSearchRepository(super.executor);

  final List<TypedWorkspaceSearchCriteria> searches = <TypedWorkspaceSearchCriteria>[];

  @override
  Future<TypedWorkspaceSearchPage> search(TypedWorkspaceSearchCriteria criteria) async {
    searches.add(criteria);
    return TypedWorkspaceSearchPage(records: const <TypedWorkspaceRecord>[], totalCount: 0, page: 1);
  }
}

Future<({AppDatabase db, int invoiceId, int receiptId, int bankId})> _configuredDatabase() async {
  final AppDatabase db = createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Workspace Search GmbH']);
  final int customerId = await db.executor.runInsert(
    'INSERT INTO kunden (name, firma, strasse, plz, ort) VALUES (?, ?, ?, ?, ?)',
    <Object?>['Alice Example', 'Alice GmbH', 'Weg 1', '10115', 'Berlin'],
  );
  final int supplierId = await db.executor.runInsert('INSERT INTO lieferanten (name, firma) VALUES (?, ?)', <Object?>[
    'Acme Office',
    'Acme GmbH',
  ]);
  final int invoiceId = await db.executor.runInsert(
    'INSERT INTO rechnungen (rechnungsnummer, typ, status, kunde_id, datum, brutto_betrag) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>['INV-A', 'ausgangsrechnung', 'offen', customerId, '2026-01-15', 100],
  );
  await db.executor.runInsert(
    'INSERT INTO rechnungen (rechnungsnummer, typ, status, kunde_id, datum, brutto_betrag) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>['INV-B', 'ausgangsrechnung', 'bezahlt', customerId, '2026-02-01', 120],
  );
  final int receiptId = await db.executor.runInsert(
    'INSERT INTO belege (belegnummer, datum, betrag, lieferant_id, status, beschreibung) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>['REC-A', '2026-02-01', 80, supplierId, 'neu', 'Camera equipment'],
  );
  await db.executor.runInsert(
    'INSERT INTO belege (belegnummer, datum, betrag, lieferant_id, status, beschreibung) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>['REC-B', '2026-02-02', 80, supplierId, 'archiviert', 'Camera equipment'],
  );
  final int accountId = await db.executor.runInsert('INSERT INTO konten (name) VALUES (?)', <Object?>[
    'Workspace Bank',
  ]);
  final int bankId = await db.executor.runInsert(
    'INSERT INTO bank_transaktionen '
    '(konto_id, datum, betrag, verwendungszweck, gegenkonto, gegenkonto_name, status) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[accountId, '2026-02-01', 80, 'Camera supplies', 'DE-ACME', 'Acme GmbH', 'neu'],
  );
  await db.executor.runInsert(
    'INSERT INTO bank_transaktionen '
    '(konto_id, datum, betrag, verwendungszweck, gegenkonto, gegenkonto_name, status) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[accountId, '2026-02-02', 80, 'Camera supplies', 'DE-ACME', 'Acme GmbH', 'archiviert'],
  );
  return (db: db, invoiceId: invoiceId, receiptId: receiptId, bankId: bankId);
}

Widget _app(AppDatabase db, GoRouter router, {TypedWorkspaceSearchRepository? searchRepository}) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    globalSearchShortcutServiceProvider.overrideWithValue(
      DesktopShortcutsServiceImpl(
        hotkeyBackend: _NoopHotkeyBackend(),
        windowBackend: _NoopWindowBackend(),
        navigate: (_) {},
      ),
    ),
    if (searchRepository != null) typedWorkspaceSearchRepositoryProvider.overrideWithValue(searchRepository),
  ],
  child: MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  ),
);

void main() {
  test('test_combine_invoice_criteria', () async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    final TypedWorkspaceSearchRepository repository = TypedWorkspaceSearchRepository(fixture.db.executor);

    final TypedWorkspaceSearchPage page = await repository.search(
      TypedWorkspaceSearchCriteria(
        domain: TypedWorkspaceDomain.invoices,
        text: 'Alice',
        dateFrom: DateTime(2026),
        dateTo: DateTime(2026, 1, 31),
        status: 'offen',
        amountFrom: 90,
        amountTo: 110,
      ),
    );

    expect(page.totalCount, 1);
    expect(page.records.single, isA<InvoiceWorkspaceRecord>());
    final InvoiceWorkspaceRecord invoice = page.records.single as InvoiceWorkspaceRecord;
    expect(invoice.id, fixture.invoiceId);
    expect(invoice.number, 'INV-A');
    expect(invoice.grossAmount, 100);
  });

  test('test_combine_receipt_and_banking_criteria', () async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    final TypedWorkspaceSearchRepository repository = TypedWorkspaceSearchRepository(fixture.db.executor);
    final DateTime from = DateTime(2026, 2);
    final DateTime to = DateTime(2026, 2);

    final TypedWorkspaceSearchPage receipts = await repository.search(
      TypedWorkspaceSearchCriteria(
        domain: TypedWorkspaceDomain.receipts,
        text: 'Acme',
        dateFrom: from,
        dateTo: to,
        status: 'neu',
        amountFrom: 80,
        amountTo: 80,
      ),
    );
    final TypedWorkspaceSearchPage transactions = await repository.search(
      TypedWorkspaceSearchCriteria(
        domain: TypedWorkspaceDomain.bankTransactions,
        text: 'Acme',
        dateFrom: from,
        dateTo: to,
        status: 'neu',
        amountFrom: 80,
        amountTo: 80,
      ),
    );

    expect(receipts.totalCount, 1);
    expect(receipts.records.single, isA<ReceiptWorkspaceRecord>());
    expect((receipts.records.single as ReceiptWorkspaceRecord).id, fixture.receiptId);
    expect(transactions.totalCount, 1);
    expect(transactions.records.single, isA<BankTransactionWorkspaceRecord>());
    expect((transactions.records.single as BankTransactionWorkspaceRecord).id, fixture.bankId);
  });

  test('test_invalid_filter_or_query_failure', () async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    final TypedWorkspaceCriteriaParseResult parsed = parseTypedWorkspaceRouteCriteria(
      TypedWorkspaceDomain.invoices,
      <String, String>{'dateFrom': 'not-a-date', 'amountFrom': 'NaN', 'status': 'offen', 'q': 'Alice'},
    );
    expect(parsed.invalidFields, contains(TypedWorkspaceFilterField.dateFrom));
    expect(parsed.invalidFields, contains(TypedWorkspaceFilterField.amountFrom));
    expect(parsed.criteria.status, 'offen');
    expect(parsed.criteria.text, 'Alice');
    expect(parseLocalizedWorkspaceAmount('1.234,50', 'de_DE'), 1234.5);
    expect(parseLocalizedWorkspaceAmount('1,234.50', 'en_US'), 1234.5);
    expect(parseLocalizedWorkspaceAmount('12,345', 'de_DE'), isNull);

    await fixture.db.executor.runCustom('DROP TABLE rechnungen');
    final TypedWorkspaceSearchRepository repository = TypedWorkspaceSearchRepository(fixture.db.executor);
    await expectLater(
      repository.search(const TypedWorkspaceSearchCriteria(domain: TypedWorkspaceDomain.invoices)),
      throwsA(anything),
    );
  });

  test('test_impossible_calendar_date_is_rejected', () {
    final TypedWorkspaceCriteriaParseResult parsed = parseTypedWorkspaceRouteCriteria(
      TypedWorkspaceDomain.invoices,
      <String, String>{'dateFrom': '2026-02-31'},
    );

    expect(parsed.invalidFields, contains(TypedWorkspaceFilterField.dateFrom));
    expect(parsed.criteria.dateFrom, isNull);
  });

  testWidgets('test_clear_one_or_all_filters', (WidgetTester tester) async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(fixture.db, router));
    await tester.pumpAndSettle();
    router.go('/invoices?q=Alice&status=offen&amountFrom=90');
    await tester.pumpAndSettle();

    expect(find.text('Search: Alice'), findsOneWidget);
    expect(find.text('Exact status: offen'), findsOneWidget);
    await tester.tap(find.text('Search: Alice'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters.containsKey('q'), isFalse);
    expect(router.routeInformationProvider.value.uri.queryParameters['status'], 'offen');
    expect(router.routeInformationProvider.value.uri.queryParameters['amountFrom'], '90');

    await tester.ensureVisible(find.text('Clear all filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all filters'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters, isEmpty);
  });

  testWidgets('test_search_keeps_caret_position_after_route_update', (WidgetTester tester) async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(fixture.db, router));
    await tester.pumpAndSettle();
    router.go('/invoices?q=Alice');
    await tester.pumpAndSettle();

    final TextField searchField = tester.widget<TextField>(find.byType(TextField).first);
    final TextEditingController controller = searchField.controller!;
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    controller.selection = const TextSelection.collapsed(offset: 2);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'AlXice', selection: TextSelection.collapsed(offset: 3)),
    );
    await tester.pumpAndSettle();

    expect(controller.selection.baseOffset, 3);
  });

  testWidgets('test_cancelled_filter_edits_are_discarded', (WidgetTester tester) async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(fixture.db, router));
    await tester.pumpAndSettle();
    router.go('/invoices?status=offen');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    final Finder statusField = find.byWidgetPredicate(
      (Widget widget) => widget is TextField && widget.decoration?.labelText == 'Exact status',
    );
    final Finder amountFromField = find.byWidgetPredicate(
      (Widget widget) => widget is TextField && widget.decoration?.labelText == 'Amount from',
    );
    await tester.enterText(statusField, 'bezahlt');
    await tester.enterText(amountFromField, '999');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(statusField).controller!.text, 'offen');
    expect(tester.widget<TextField>(amountFromField).controller!.text, isEmpty);
  });

  testWidgets('test_rapid_workspace_query_changes_only_search_latest_text', (WidgetTester tester) async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    final _RecordingTypedWorkspaceSearchRepository repository = _RecordingTypedWorkspaceSearchRepository(
      fixture.db.executor,
    );
    await tester.pumpWidget(_app(fixture.db, router, searchRepository: repository));
    await tester.pumpAndSettle();
    router.go('/invoices');
    await tester.pumpAndSettle();
    repository.searches.clear();

    final Finder query = find.byType(TextField).first;
    await tester.enterText(query, 'p');
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(query, 'pa');
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(query, 'par');
    await tester.pump(const Duration(milliseconds: 150));

    expect(repository.searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(repository.searches.map((TypedWorkspaceSearchCriteria criteria) => criteria.text), <String>['par']);
  });

  testWidgets('test_filter_editor_reports_invalid_amount', (WidgetTester tester) async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(fixture.db, router));
    await tester.pumpAndSettle();
    router.go('/invoices');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    final Finder minimumAmount = find.byWidgetPredicate(
      (Widget widget) => widget is TextField && widget.decoration?.labelText == 'Amount from',
    );
    await tester.enterText(minimumAmount, 'not money');
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid amount with up to two decimal places.'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.queryParameters, isEmpty);
  });

  testWidgets('test_open_a_selected_bank_transaction', (WidgetTester tester) async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(fixture.db, router));
    await tester.pumpAndSettle();
    router.go('/banking?transactionId=${fixture.bankId}&view=history&importId=7&search=Keep');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('bank_selected_transaction')), findsOneWidget);
    expect(find.text('Acme GmbH'), findsOneWidget);
    expect(find.text('Camera supplies'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.queryParameters['transactionId'], '${fixture.bankId}');
    expect(router.routeInformationProvider.value.uri.queryParameters['view'], 'history');
    expect(router.routeInformationProvider.value.uri.queryParameters['importId'], '7');
    expect(router.routeInformationProvider.value.uri.queryParameters['search'], 'Keep');

    await tester.tap(find.byTooltip('Banking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters['view'], 'transactions');
    expect(router.routeInformationProvider.value.uri.queryParameters['transactionId'], '${fixture.bankId}');
    expect(router.routeInformationProvider.value.uri.queryParameters['importId'], '7');
    expect(router.routeInformationProvider.value.uri.queryParameters['search'], 'Keep');
  });

  testWidgets('test_invalid_or_missing_transaction_selection', (WidgetTester tester) async {
    final fixture = await _configuredDatabase();
    addTearDown(fixture.db.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = createRouter(fixture.db);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(fixture.db, router));
    await tester.pumpAndSettle();

    router.go('/banking?transactionId=invalid&view=history&search=Keep');
    await tester.pumpAndSettle();
    expect(find.text('The transaction link is invalid.'), findsOneWidget);
    expect(find.text('Acme GmbH'), findsNothing);
    expect(router.routeInformationProvider.value.uri.queryParameters['search'], 'Keep');

    router.go('/banking?transactionId=999999&view=history&search=Keep');
    await tester.pumpAndSettle();
    expect(find.text('This bank transaction is not available in the active profile.'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.queryParameters['view'], 'history');
    expect(router.routeInformationProvider.value.uri.queryParameters['search'], 'Keep');
  });
}
