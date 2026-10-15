import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/l10n/l10n.dart';

Future<GoRouter> _pumpRoute(WidgetTester tester, String location) async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Test GmbH']);
  final GoRouter router = createRouter(db);
  addTearDown(router.dispose);
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: AppScope(
        services: AppServices(db),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  router.go(location);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('test_report_routes_open_a_typed_report_catalog', (WidgetTester tester) async {
    final GoRouter router = await _pumpRoute(tester, '/reports');

    expect(find.byKey(const ValueKey<String>('report-catalog')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('report-catalog-euer')), findsOneWidget);

    router.go('/taxes');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('report-catalog-ustva')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('report-catalog-zm')), findsOneWidget);
  });

  testWidgets('test_report_deep_link_selects_its_typed_owner', (WidgetTester tester) async {
    final GoRouter router = await _pumpRoute(tester, '/taxes?report=zm&month=2025-01');

    expect(router.state.uri.queryParameters['report'], 'zm');
    expect(router.state.uri.queryParameters['month'], '2025-01');
    expect(find.byKey(const ValueKey<String>('report-workspace-zm')), findsOneWidget);
    expect(find.text('2025-01-01 – 2025-02-01'), findsOneWidget);
    expect(find.textContaining('ustg-18a-2026'), findsOneWidget);
  });

  testWidgets('test_missing_or_invalid_report_selection_fails_closed', (WidgetTester tester) async {
    final GoRouter router = await _pumpRoute(tester, '/taxes?report=zm&month=2025-13');

    expect(router.state.uri.queryParameters['month'], '2025-13');
    expect(find.byKey(const ValueKey<String>('report-workspace-invalid')), findsOneWidget);
    expect(find.text('Ungültige Berichtsabfrage'), findsOneWidget);
  });
}
