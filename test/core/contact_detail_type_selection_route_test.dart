import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';
import 'package:openaccounting/pages/stammdaten/master_data_pages.dart';
import 'package:openaccounting/pages/stammdaten/master_data_workspaces.dart';
import 'package:openaccounting/pages/stammdaten/master_data_more_pages.dart';

Future<({AppDatabase db, GoRouter router})> _openDetailRoute(
  WidgetTester tester, {
  required String location,
  required Future<void> Function(AppDatabase db) seed,
  AppServices Function(AppDatabase db)? servicesFactory,
}) async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await seed(db);
  addTearDown(db.close);

  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      GoRoute(
        path: '/contacts/:id',
        builder: (BuildContext context, GoRouterState state) => ContactRecordView(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/articles/:id',
        builder: (BuildContext context, GoRouterState state) => ArticleRecordView(id: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: AppScope(
        services: servicesFactory?.call(db) ?? AppServices(db),
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (db: db, router: router);
}

Future<({AppDatabase db, GoRouter router})> _openArticleWorkspace(WidgetTester tester) async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO artikel_gruppen (id, name, beschreibung) VALUES (?, ?, ?)', <Object?>[
    42,
    'Original group',
    'Original description',
  ]);
  await db.executor.runInsert('INSERT INTO artikel (id, bezeichnung) VALUES (?, ?)', <Object?>[42, 'Same-ID item']);
  addTearDown(db.close);

  final GoRouter router = GoRouter(
    initialLocation: '/articles?view=groups',
    routes: <RouteBase>[
      GoRoute(
        path: '/articles',
        builder: (BuildContext context, GoRouterState state) => const ArticlesWorkspaceView(),
        routes: <RouteBase>[
          GoRoute(path: 'new', builder: (BuildContext context, GoRouterState state) => const ArticleFormView()),
          GoRoute(
            path: ':id',
            builder: (BuildContext context, GoRouterState state) => ArticleRecordView(id: state.pathParameters['id']!),
            routes: <RouteBase>[
              GoRoute(
                path: 'edit',
                builder: (BuildContext context, GoRouterState state) =>
                    ArticleFormView(recordId: int.parse(state.pathParameters['id']!)),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: AppScope(
        services: AppServices(db),
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (db: db, router: router);
}

void main() {
  testWidgets('test_contact_type_selection_preserves_other_query_parameters', (WidgetTester tester) async {
    final ({AppDatabase db, GoRouter router}) env = await _openDetailRoute(
      tester,
      location: '/contacts/42?kind=invalid&tab=suppliers&tag=one&tag=two',
      seed: (AppDatabase db) async {},
    );

    final AppLocalizations l10n = lookupAppLocalizations(const Locale('de'));
    expect(find.text(l10n.recordIdLabel('42')), findsOneWidget);
    await tester.tap(find.text(l10n.actionSelectSupplier));
    await tester.pumpAndSettle();

    expect(env.router.state.uri.path, '/contacts/42');
    expect(env.router.state.uri.queryParameters['kind'], 'supplier');
    expect(env.router.state.uri.queryParameters['tab'], 'suppliers');
    expect(env.router.state.uri.queryParametersAll['tag'], <String>['one', 'two']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_missing_contact_discriminator_does_not_query_either_record', (WidgetTester tester) async {
    late final _ContactDetailLookupSpy lookupSpy;
    final ({AppDatabase db, GoRouter router}) env = await _openDetailRoute(
      tester,
      location: '/contacts/42?tab=suppliers&tag=one&tag=two',
      seed: (AppDatabase db) async {
        await db.executor.runInsert(
          'INSERT INTO kunden (id, kundennummer, debitor_nr, anrede, name, strasse, plz, ort, land) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[42, 'K-42', 'D-42', 'Herr', 'Customer-only', 'Street 1', '10115', 'Berlin', 'DE'],
        );
        await db.executor.runInsert(
          'INSERT INTO lieferanten '
          '(id, lieferantennummer, anrede, name, strasse, plz, ort, land) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[42, 'L-42', 'Herr', 'Supplier-only', 'Street 2', '10115', 'Berlin', 'DE'],
        );
      },
      servicesFactory: (AppDatabase db) {
        final AppServices services = AppServices(db);
        lookupSpy = _ContactDetailLookupSpy(kunden: services.kunden, lieferanten: services.lieferanten);
        return _ContactDetailSpyServices(db, lookupSpy);
      },
    );

    final AppLocalizations l10n = lookupAppLocalizations(const Locale('de'));
    expect(find.text(l10n.recordIdLabel('42')), findsOneWidget);
    expect(find.text(l10n.actionSelectCustomer), findsOneWidget);
    expect(find.text(l10n.actionSelectSupplier), findsOneWidget);
    expect(find.textContaining('Customer-only'), findsNothing);
    expect(find.textContaining('Supplier-only'), findsNothing);
    expect(lookupSpy.customerLookups, 0);
    expect(lookupSpy.supplierLookups, 0);
    expect(env.router.state.uri.queryParameters['kind'], isNull);
    expect(env.router.state.uri.queryParameters['tab'], 'suppliers');
    expect(env.router.state.uri.queryParametersAll['tag'], <String>['one', 'two']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_contact_detail_discriminator_selects_the_correct_record_type', (WidgetTester tester) async {
    final ({AppDatabase db, GoRouter router}) env = await _openDetailRoute(
      tester,
      location: '/contacts/42?kind=customer',
      seed: (AppDatabase db) async {
        await db.executor.runInsert(
          'INSERT INTO kunden (id, kundennummer, debitor_nr, anrede, name, strasse, plz, ort, land) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[42, 'K-42', 'D-42', 'Herr', 'Customer-only', 'Street 1', '10115', 'Berlin', 'DE'],
        );
        await db.executor.runInsert(
          'INSERT INTO lieferanten '
          '(id, lieferantennummer, anrede, name, strasse, plz, ort, land) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[42, 'L-42', 'Herr', 'Supplier-only', 'Street 2', '10115', 'Berlin', 'DE'],
        );
      },
    );

    expect(find.textContaining('Customer-only'), findsOneWidget);
    expect(find.textContaining('Supplier-only'), findsNothing);

    env.router.go('/contacts/42?kind=supplier');
    await tester.pumpAndSettle();

    expect(find.textContaining('Supplier-only'), findsOneWidget);
    expect(find.textContaining('Customer-only'), findsNothing);
    expect(env.router.state.uri.queryParameters['kind'], 'supplier');
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_article_and_article_group_routes_use_their_typed_owner', (WidgetTester tester) async {
    final ({AppDatabase db, GoRouter router}) env = await _openDetailRoute(
      tester,
      location: '/articles/42?kind=group',
      seed: (AppDatabase db) async {
        await db.executor.runInsert('INSERT INTO artikel_gruppen (id, name) VALUES (?, ?)', <Object?>[
          42,
          'Group-only',
        ]);
        await db.executor.runInsert('INSERT INTO artikel (id, bezeichnung) VALUES (?, ?)', <Object?>[42, 'Item-only']);
      },
    );

    expect(find.text('Group-only'), findsWidgets);
    expect(find.text('Item-only'), findsNothing);

    env.router.go('/articles/42?kind=item');
    await tester.pumpAndSettle();

    expect(find.text('Item-only'), findsWidgets);
    expect(find.text('Group-only'), findsNothing);
    expect(env.router.state.uri.queryParameters['kind'], 'item');
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_article_group_workspace_supports_create_update_archive_and_restore', (WidgetTester tester) async {
    final ({AppDatabase db, GoRouter router}) env = await _openArticleWorkspace(tester);
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('de'));

    expect(find.text('Original group'), findsOneWidget);
    expect(find.text('Same-ID item'), findsNothing);
    await tester.tap(find.text(l10n.actionCreateGroup));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Created group');
    await tester.enterText(find.byType(TextFormField).last, 'Created description');
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    final List<Map<String, Object?>> created = await env.db.executor.runSelect(
      'SELECT id FROM artikel_gruppen WHERE name = ?',
      <Object?>['Created group'],
    );
    expect(created, hasLength(1));
    final int groupId = created.single['id']! as int;
    expect(env.router.state.uri.path, '/articles/$groupId');
    expect(find.text('Created group'), findsWidgets);

    await tester.tap(find.byTooltip(l10n.actionEdit));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField).first, findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Updated group');
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();
    expect(find.text('Updated group'), findsWidgets);

    await tester.tap(find.byTooltip(l10n.actionArchive));
    await tester.pumpAndSettle();
    expect(env.router.state.uri.toString(), '/articles?view=groups');
    List<Map<String, Object?>> rows = await env.db.executor.runSelect(
      'SELECT aktiv FROM artikel_gruppen WHERE id = ?',
      <Object?>[groupId],
    );
    expect(rows.single['aktiv'], 0);

    await tester.tap(find.text('Updated group'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.actionRestore));
    await tester.pumpAndSettle();
    rows = await env.db.executor.runSelect('SELECT aktiv FROM artikel_gruppen WHERE id = ?', <Object?>[groupId]);
    expect(rows.single['aktiv'], 1);
    expect(tester.takeException(), isNull);
  });
}

class _ContactDetailLookupSpy extends ContactDetailUseCase {
  _ContactDetailLookupSpy({required super.kunden, required super.lieferanten});

  int customerLookups = 0;
  int supplierLookups = 0;

  @override
  Future<Kunde?> customerById(int id) {
    customerLookups += 1;
    return super.customerById(id);
  }

  @override
  Future<Lieferant?> supplierById(int id) {
    supplierLookups += 1;
    return super.supplierById(id);
  }
}

class _ContactDetailSpyServices extends AppServices {
  _ContactDetailSpyServices(super.db, this._contactDetail);

  final ContactDetailUseCase _contactDetail;

  @override
  ContactDetailUseCase get contactDetail => _contactDetail;
}
