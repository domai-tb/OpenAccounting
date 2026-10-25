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
  testWidgets('test_tagesabschluss_creation', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureOpen();
    await db.executor.runCustom('CREATE TABLE IF NOT EXISTS unternehmen (id INTEGER PRIMARY KEY, name TEXT)');
    await db.executor.runCustom("INSERT INTO unternehmen (name) VALUES ('Test GmbH')");
    addTearDown(db.close);

    final GoRouter router = createRouter(db);
    final CashbookBalanceResult balance = CashbookBalanceResult.available(
      companyId: 'company-1',
      accountId: 'cash-1',
      asOfDate: DateTime(2026, 6, 20, 23, 59, 59, 999, 999),
      balanceCents: 12345,
      currencyCode: 'EUR',
      sourceReference: 'cash-balance:cash-1:2026-06-20',
      sourceReferences: <String>['opening:setup-1', 'posting:cash-in-1'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(locale: const Locale('de'), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/banking?view=close', extra: balance);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.queryParameters['view'], 'close');
    expect(find.text('Tagesabschluss'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text && RegExp(r'^(20\.06\.2026|06/20/2026)$').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
    expect(find.text('cash-1'), findsOneWidget);
    expect(find.text('company-1'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text && RegExp(r'^123[,.]45 EUR$').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('cash-balance:cash-1:2026-06-20'), findsOneWidget);
    expect(find.text('Vollständig'), findsOneWidget);
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
