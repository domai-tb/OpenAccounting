import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/app_router.dart';

/// Typed S/G route state on /taxes (income-tax section 4).
void main() {
  group('Income-tax routes', () {
    Future<AppDatabase> openDb() async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(db.close);
      return db;
    }

    Widget wrapRouter(AppDatabase db, String location, {bool withScope = true}) {
      final GoRouter router = GoRouter(
        initialLocation: location,
        routes: <RouteBase>[
          GoRoute(
            path: '/taxes',
            builder: (BuildContext context, GoRouterState state) {
              const TaxesPage page = TaxesPage();
              if (!withScope) return page;
              return AppScope(services: AppServices(db), child: page);
            },
          ),
        ],
      );
      return ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('test_open_an_s_g_supporting_report', (tester) async {
      final AppDatabase db = await openDb();
      await tester.pumpWidget(wrapRouter(db, '/taxes?view=income-tax-schedules&schedule=g&foo=bar'));
      await tester.pumpAndSettle();
      expect(find.text('Anlage G'), findsOneWidget);
      expect(find.text('Noch nicht verfügbar'), findsOneWidget);
      expect(find.textContaining('Zeitraumvertrag'), findsOneWidget);
    });

    testWidgets('test_report_service_is_unavailable', (tester) async {
      final AppDatabase db = await openDb();
      await tester.pumpWidget(wrapRouter(db, '/taxes?view=income-tax-schedules&schedule=s', withScope: false));
      await tester.pumpAndSettle();
      expect(find.text('Noch nicht verfügbar'), findsWidgets);
      expect(find.text('Anlage S'), findsNothing);
    });
  });
}
