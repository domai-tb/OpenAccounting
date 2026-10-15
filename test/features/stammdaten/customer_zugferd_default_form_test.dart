import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/master_data_pages.dart';

void main() {
  testWidgets('customer form persists the ZUGFeRD invoice default', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    await db.ensureOpen();
    addTearDown(db.close);

    final GoRouter router = GoRouter(
      initialLocation: '/contacts/new?kind=customer',
      routes: <RouteBase>[
        GoRoute(path: '/contacts/new', builder: (BuildContext context, GoRouterState state) => const ContactFormView()),
        GoRoute(
          path: '/contacts/:id',
          builder: (BuildContext context, GoRouterState state) => ContactFormView(recordId: state.pathParameters['id']),
        ),
      ],
    );
    addTearDown(router.dispose);
    final AppServices services = AppServices(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: AppScope(
          services: services,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Müller GmbH');
    await tester.enterText(fields.at(2), 'Hauptstraße 1');
    await tester.enterText(fields.at(3), '10115');
    await tester.enterText(fields.at(4), 'Berlin');

    final Finder switchFinder = find.byType(SwitchListTile);
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('de'));
    final Finder listScrollable = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(switchFinder, 300, scrollable: listScrollable);
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    expect(find.text(l10n.customerZugferdDefaultTitle), findsOneWidget);
    expect(find.text(l10n.customerZugferdDefaultDescription), findsOneWidget);
    await tester.tap(switchFinder);
    await tester.scrollUntilVisible(find.byIcon(Icons.save_outlined), 300, scrollable: listScrollable);
    await tester.ensureVisible(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    final int customerId = int.parse(router.state.uri.pathSegments.last);
    expect((await services.kunden.findById(customerId))!.zugferdAktiv, isTrue);

    await tester.scrollUntilVisible(switchFinder, 300, scrollable: listScrollable);
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    await tester.tap(switchFinder);
    await tester.scrollUntilVisible(find.byIcon(Icons.save_outlined), 300, scrollable: listScrollable);
    await tester.ensureVisible(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect((await services.kunden.findById(customerId))!.zugferdAktiv, isFalse);
  });
}
