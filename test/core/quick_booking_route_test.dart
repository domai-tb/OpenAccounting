import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/quick_booking/quick_bookings_view.dart';
import 'package:openaccounting/l10n/l10n.dart';

Future<AppDatabase> _configuredDb() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runCustom('CREATE TABLE IF NOT EXISTS unternehmen (id INTEGER PRIMARY KEY, name TEXT)');
  await db.executor.runCustom("INSERT INTO unternehmen (name) VALUES ('Test GmbH')");
  return db;
}

Widget _wrap(GoRouter router, AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: AppScope(
      services: AppServices(db),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  testWidgets('test_quick_booking_view_uses_typed_route_state', (WidgetTester tester) async {
    final AppDatabase db = await _configuredDb();
    addTearDown(db.close);
    final GoRouter router = createRouter(db);

    await tester.pumpWidget(_wrap(router, db));
    await tester.pumpAndSettle();
    router.go('/banking?view=quick-bookings&filter=review&filter=missing');
    await tester.pumpAndSettle();

    expect(find.byType(QuickBookingsView), findsOneWidget);
    expect(router.state.uri.path, '/banking');
    expect(router.state.uri.queryParametersAll['filter'], <String>['review', 'missing']);
  });

  testWidgets('test_database_outage_is_not_an_empty_quick_booking_view', (WidgetTester tester) async {
    final AppDatabase db = await _configuredDb();
    await db.close();
    final GoRouter router = createRouter(db);

    await tester.pumpWidget(_wrap(router, db));
    await tester.pumpAndSettle();
    router.go('/banking?view=quick-bookings&filter=review');
    await tester.pumpAndSettle();

    expect(find.byType(QuickBookingsView), findsOneWidget);
    expect(find.text(appLocalizationsOf(tester.element(find.byType(BankImportPage))).quickBookingEmpty), findsNothing);
    expect(find.byType(AppStatusChip), findsOneWidget);
    expect(find.text('Setup Wizard'), findsNothing);
    expect(router.state.uri.queryParameters['view'], 'quick-bookings');
    expect(router.state.uri.queryParameters['filter'], 'review');
  });

  testWidgets('test_open_quick_bookings_and_return_to_import_state', (WidgetTester tester) async {
    final AppDatabase db = await _configuredDb();
    addTearDown(db.close);
    final GoRouter router = createRouter(db);

    await tester.pumpWidget(_wrap(router, db));
    await tester.pumpAndSettle();
    router.go('/banking?view=import&search=rent&account=checking');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(appLocalizationsOf(tester.element(find.byType(BankImportPage))).sidebarBanking));
    await tester.pumpAndSettle();
    final String quickBookingsTitle = appLocalizationsOf(tester.element(find.byType(BankImportPage)))
        .quickBookingsTitle;
    await tester.tap(find.text(quickBookingsTitle).last);
    await tester.pumpAndSettle();

    expect(find.byType(QuickBookingsView), findsOneWidget);
    expect(router.state.uri.queryParameters['search'], 'rent');
    expect(router.state.uri.queryParameters['account'], 'checking');

    await tester.tap(find.byTooltip(appLocalizationsOf(tester.element(find.byType(BankImportPage))).sidebarBanking));
    await tester.pumpAndSettle();
    final String importTitle = appLocalizationsOf(tester.element(find.byType(BankImportPage))).bankViewImport;
    await tester.tap(find.text(importTitle).last);
    await tester.pumpAndSettle();

    expect(find.byType(QuickBookingsView), findsNothing);
    expect(router.state.uri.queryParameters['view'], 'import');
    expect(router.state.uri.queryParameters['search'], 'rent');
    expect(router.state.uri.queryParameters['account'], 'checking');
  });
}
