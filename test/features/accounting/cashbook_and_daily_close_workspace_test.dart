import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/features/accounting/tagesabschluss_creation.dart';
import 'package:openaccounting/features/cashbook/account_date_balance.dart';

void main() {
  testWidgets('test_cashbook_route_displays_a_cashbook_workspace', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase(withOpeningSource: true);
    addTearDown(db.close);

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(locale: const Locale('de'), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/banking');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Kassenbuch'), findsOneWidget);
    await tester.tap(find.text('Kassenbuch'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.queryParameters['view'], 'cashbook');
    expect(find.text('Kassenbuch'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cashbook-movements-unavailable')), findsOneWidget);
    expect(find.text('Wähle Unternehmen, Kassenkonto und Datum, um eine Saldenvorschau anzufordern.'), findsOneWidget);

    await _selectCashbookAccountAndDate(tester);

    expect(find.text('Vollständig'), findsOneWidget);
    expect(find.text('Kassenbestand zum Stichtag'), findsOneWidget);
    expect(
      find.byWidgetPredicate((Widget widget) => widget is Text && RegExp('100[,.]00').hasMatch(widget.data ?? '')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('cashbook-result-unavailable')), findsNothing);
    expect(find.byKey(const ValueKey<String>('daily-close-counted-balance')), findsNothing);
    expect(find.text('Tagesabschluss'), findsOneWidget);
  });

  testWidgets('test_cashbook_route_shows_incomplete_source_as_unavailable', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase(withOpeningSource: false);
    addTearDown(db.close);

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(locale: const Locale('de'), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/banking?view=cashbook');
    await tester.pumpAndSettle();
    await _selectCashbookAccountAndDate(tester);

    expect(find.byKey(const ValueKey<String>('cashbook-result-unavailable')), findsOneWidget);
    expect(
      find.text(
        'Für Unternehmen, Kassenkonto und Datum ist kein vollständiger, verifizierter Kassenbestand verfügbar.',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((Widget widget) => widget is Text && RegExp('0[,.]00').hasMatch(widget.data ?? '')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('cashbook-movements-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('daily-close-counted-balance')), findsNothing);
  });

  testWidgets('test_tagesabschluss_creation', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureOpen();
    await db.executor.runCustom('CREATE TABLE IF NOT EXISTS unternehmen (id INTEGER PRIMARY KEY, name TEXT)');
    await db.executor.runCustom("INSERT INTO unternehmen (id, name) VALUES (1, 'Test GmbH')");
    await db.executor.runInsert(
      'INSERT INTO konten (id, name, kontoart, waehrung, unternehmen_id) VALUES (?, ?, ?, ?, ?)',
      <Object?>[9001, 'Test Kasse', 'Kasse', 'EUR', 1],
    );
    final List<Map<String, Object?>> journalColumns = await db.executor.runSelect(
      'PRAGMA table_info(journal)',
      const <Object?>[],
    );
    if (journalColumns.every((Map<String, Object?> column) => column['name'] != 'is_opening_balance')) {
      await db.executor.runCustom('ALTER TABLE journal ADD COLUMN is_opening_balance INTEGER NOT NULL DEFAULT 0');
    }
    final DateTime today = DateTime.now();
    final String effectiveDate =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final int openingJournalId = await db.executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id, immutable, is_opening_balance) '
      'VALUES (?, ?, ?, ?, ?, 0, 1)',
      <Object?>[effectiveDate, 'Eröffnung Kasse', '100.00', 'Eroeffnung', 9001],
    );
    await db.executor.runInsert(
      'INSERT INTO account_opening_balance_sources '
      '(unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[1, 9001, openingJournalId, effectiveDate, 10000, 'EUR', 'setup-opening:1:9001'],
    );
    addTearDown(db.close);

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(locale: const Locale('de'), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/banking?view=close');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.queryParameters['view'], 'close');
    expect(find.text('Tagesabschluss'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('daily-close-company')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('daily-close-account')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('daily-close-date-picker')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('daily-close-result-unavailable')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('daily-close-company')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test GmbH').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('daily-close-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Kasse').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('daily-close-date-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Vollständig'), findsOneWidget);
    expect(
      find.byWidgetPredicate((Widget widget) => widget is Text && RegExp('100[,.]00').hasMatch(widget.data ?? '')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('daily-close-counted-balance')), findsOneWidget);
  });

  test('prepares only a complete typed balance result', () {
    final CashbookBalanceResult balance = CashbookBalanceResult.available(
      companyId: 'company-1',
      accountId: 'cash-1',
      asOfDate: DateTime(2026, 6, 20),
      balanceCents: 12345,
      currencyCode: 'EUR',
      sourceReference: 'cash-balance:cash-1:2026-06-20',
      sourceReferences: <String>['opening:setup-1', 'posting:cash-in-1'],
    );

    final TagesabschlussDraft? draft = const TagesabschlussCreation().prepare(balance);

    expect(draft, isNotNull);
    expect(draft!.companyId, 'company-1');
    expect(draft.accountId, 'cash-1');
    expect(draft.asOfDate, DateTime(2026, 6, 20));
    expect(draft.expectedBalanceCents, 12345);
    expect(draft.currencyCode, 'EUR');
    expect(draft.sourceReference, 'cash-balance:cash-1:2026-06-20');
    expect(draft.complete, isTrue);
  });
}

Future<AppDatabase> _cashbookDatabase({required bool withOpeningSource}) async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.ensureOpen();
  await db.executor.runCustom('CREATE TABLE IF NOT EXISTS unternehmen (id INTEGER PRIMARY KEY, name TEXT)');
  await db.executor.runCustom("INSERT INTO unternehmen (id, name) VALUES (1, 'Test GmbH')");
  await db.executor.runInsert(
    'INSERT INTO konten (id, name, kontoart, waehrung, unternehmen_id) VALUES (?, ?, ?, ?, ?)',
    <Object?>[9001, 'Test Kasse', 'Kasse', 'EUR', 1],
  );
  if (!withOpeningSource) return db;

  final List<Map<String, Object?>> journalColumns = await db.executor.runSelect(
    'PRAGMA table_info(journal)',
    const <Object?>[],
  );
  if (journalColumns.every((Map<String, Object?> column) => column['name'] != 'is_opening_balance')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN is_opening_balance INTEGER NOT NULL DEFAULT 0');
  }
  final DateTime today = DateTime.now();
  final String effectiveDate =
      '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final int openingJournalId = await db.executor.runInsert(
    'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id, immutable, is_opening_balance) '
    'VALUES (?, ?, ?, ?, ?, 0, 1)',
    <Object?>[effectiveDate, 'Eröffnung Kasse', '100.00', 'Eroeffnung', 9001],
  );
  await db.executor.runInsert(
    'INSERT INTO account_opening_balance_sources '
    '(unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[1, 9001, openingJournalId, effectiveDate, 10000, 'EUR', 'setup-opening:1:9001'],
  );
  return db;
}

Future<void> _selectCashbookAccountAndDate(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('cashbook-company')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test GmbH').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('cashbook-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test Kasse').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('cashbook-date-picker')));
  await tester.pumpAndSettle();
  expect(find.byType(DatePickerDialog), findsOneWidget);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
