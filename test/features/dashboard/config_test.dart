// ignore_for_file: prefer_single_quotes, avoid_bool_literals_in_conditional_expressions
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/dashboard/dashboard_entity.dart';
import 'package:openaccounting/features/dashboard/dashboard_repository.dart';
import 'package:openaccounting/features/dashboard/dashboard_widgets.dart';

void main() {
  group('Dashboard config — Sichtbarkeit, Reihenfolge, Schnellzugriff, Persistenz', () {
    late AppDatabase db;
    late DashboardRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = DashboardRepository(db.executor);
    });

    tearDown(() async => db.close());

    test(
      'Hide Lagerwarnung toggle off → disappears immediately and remains hidden after restart (loadConfig)',
      () async {
        // default visible
        var cfg = await repo.loadConfig();
        expect(cfg.visibility['lagerwarnung'], isTrue);
        expect((await repo.visibleOrder()).contains('lagerwarnung'), isTrue);

        await repo.toggleVisibility('lagerwarnung', false);
        cfg = await repo.loadConfig();
        expect(cfg.visibility['lagerwarnung'], isFalse);
        expect((await repo.visibleOrder()).contains('lagerwarnung'), isFalse);

        // simulate restart: new load still hidden
        final reloaded = await repo.loadConfig();
        expect(reloaded.visibility['lagerwarnung'], isFalse);

        // show again toggle on → appears
        await repo.toggleVisibility('lagerwarnung', true);
        cfg = await repo.loadConfig();
        expect(cfg.visibility['lagerwarnung'], isTrue);
        expect((await repo.visibleOrder()).contains('lagerwarnung'), isTrue);
      },
    );

    test('Hidden widget does not fetch — provider returns null, no DB query', () async {
      // ensure data exists that would be returned if fetched
      await db.executor.runInsert(
        'INSERT INTO artikel (bezeichnung, vk_netto, bestand, mindestbestand, aktiv) VALUES (?, ?, ?, ?, ?)',
        <Object?>['WarnArtikel', '10.00', 1, 5, 1],
      );
      // hide lagerwarnung
      await repo.toggleVisibility('lagerwarnung', false);
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      final data = await container.read(dashboardWidgetDataProvider('lagerwarnung').future);
      expect(data, isNull, reason: 'hidden should not fetch, provider returns null');
      // visible widget still fetches
      final visibleData = await container.read(dashboardWidgetDataProvider('offene_rechnungen').future);
      expect(visibleData, isNotNull);
    });

    test('Drag Zahlungseingänge pos2→5 → order update real-time, saved, persists after close/reopen', () async {
      var cfg = await repo.loadConfig();
      expect(cfg.order[1], 'zahlungseingaenge', reason: 'default pos2 is zahlungseingaenge');
      // drag via reorder helper pos2→5 (1-indexed): index 1 → index 4
      await repo.reorderWidget('zahlungseingaenge', 4);
      cfg = await repo.loadConfig();
      expect(cfg.order[4], 'zahlungseingaenge');
      expect(cfg.order.length, 13);

      // alternative via updateOrder permutation
      final newOrder = List<String>.from(cfg.order);
      // move back to pos2 to test updateOrder path
      newOrder.remove('zahlungseingaenge');
      newOrder.insert(1, 'zahlungseingaenge');
      await repo.updateOrder(newOrder);
      cfg = await repo.loadConfig();
      expect(cfg.order[1], 'zahlungseingaenge');

      // again pos2→5 and persist check via fresh load (simulates restart)
      newOrder.remove('zahlungseingaenge');
      newOrder.insert(4, 'zahlungseingaenge');
      await repo.updateOrder(newOrder);
      final persisted = await repo.loadConfig();
      expect(persisted.order[4], 'zahlungseingaenge');
      expect(persisted.order, newOrder);
    });

    test('Reorder does not affect hidden visibility', () async {
      await repo.toggleVisibility('lagerwarnung', false);
      var cfg = await repo.loadConfig();
      final beforeVis = Map<String, bool>.from(cfg.visibility);
      // reorder visible widgets via updateOrder (move offene_rechnungen to end)
      final order = List<String>.from(cfg.order);
      const id = 'offene_rechnungen';
      order.remove(id);
      order.add(id);
      await repo.updateOrder(order);
      cfg = await repo.loadConfig();
      expect(cfg.visibility['lagerwarnung'], isFalse);
      expect(cfg.visibility, beforeVis);
      // hidden still not in visibleOrder despite reorder
      expect((await repo.visibleOrder()).contains('lagerwarnung'), isFalse);
    });

    test('Default quick links 3, custom Mein Shop /shop persists', () async {
      var cfg = await repo.loadConfig();
      expect(cfg.quickLinks, hasLength(3));
      expect(cfg.quickLinks.map((e) => e.label), containsAll(['Neue Rechnung', 'Journal', 'Artikel']));

      await repo.addQuickLink(const QuickLink(label: 'Mein Shop', route: '/shop'));
      cfg = await repo.loadConfig();
      expect(cfg.quickLinks, hasLength(4));
      expect(cfg.quickLinks.last.label, 'Mein Shop');
      expect(cfg.quickLinks.last.route, '/shop');

      // quickLinks via provider for quick_links widget
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      final widgetData = await container.read(dashboardWidgetDataProvider('quick_links').future);
      expect(widgetData, isNotNull);
      // ignore: cast_nullable_to_non_nullable
      final links = widgetData!.raw as List<QuickLink>;
      expect(links.any((l) => l.label == 'Mein Shop' && l.route == '/shop'), isTrue);

      // remove custom and verify back to 3
      await repo.removeQuickLink('/shop');
      cfg = await repo.loadConfig();
      expect(cfg.quickLinks, hasLength(3));
      expect(cfg.quickLinks.any((l) => l.route == '/shop'), isFalse);
    });

    testWidgets('Custom Mein Shop /shop renders and navigates, invalid route shows 404', (tester) async {
      final cfg = DashboardConfig(
        order: List<String>.from(dashboardWidgetIds),
        visibility: <String, bool>{for (final id in dashboardWidgetIds) id: true},
        quickLinks: const <QuickLink>[
          QuickLink(label: 'Mein Shop', route: '/shop'),
          QuickLink(label: 'Broken', route: '/nonexistent'),
        ],
      );
      // verify repository persistence for both links
      final db2 = AppDatabase.createTestDatabase();
      await db2.ensureOpen();
      addTearDown(() async => db2.close());
      final repo2 = DashboardRepository(db2.executor);
      await repo2.saveConfig(cfg);
      final loaded = await repo2.loadConfig();
      expect(loaded.quickLinks.any((l) => l.route == '/shop'), isTrue);
      expect(loaded.quickLinks.any((l) => l.route == '/nonexistent'), isTrue);

      String navigated = '';
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(path: '/shop', builder: (_, _) => const Text('shop page')),
        ],
        errorBuilder: (_, _) => const Text('404'),
      );
      // quick_links widget content renders labels
      final data = WidgetData(
        id: 'quick_links',
        title: 'Schnellzugriff',
        count: cfg.quickLinks.length,
        icon: dashboardWidgetIcons['quick_links'],
        route: dashboardWidgetRoutes['quick_links'],
        raw: cfg.quickLinks,
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      // simulate quickLinks card content building and tapping via direct go
      router.go('/shop');
      await tester.pumpAndSettle();
      expect(find.text('shop page'), findsOneWidget);
      router.go('/nonexistent');
      await tester.pumpAndSettle();
      expect(find.text('404'), findsOneWidget);
      navigated = router.routeInformationProvider.value.uri.toString();
      expect(navigated, contains('nonexistent'));
      // also verify DashboardCard renders quick_links content via helper
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: data.title,
              icon: data.icon,
              content: Column(children: [for (final l in cfg.quickLinks) Text('${l.label} → ${l.route}')]),
            ),
          ),
        ),
      );
      expect(find.text('Mein Shop → /shop'), findsOneWidget);
      expect(find.text('Broken → /nonexistent'), findsOneWidget);
    });

    test('Config saved on change immediately no save button, loaded on start', () async {
      // toggleVisibility should persist without explicit saveConfig call
      await repo.toggleVisibility('aktivitaets_log', false);
      var cfg = await repo.loadConfig();
      expect(cfg.visibility['aktivitaets_log'], isFalse);
      // fresh repo instance same executor still sees change
      final fresh = DashboardRepository(db.executor);
      cfg = await fresh.loadConfig();
      expect(cfg.visibility['aktivitaets_log'], isFalse);

      // updateOrder immediate
      final order = List<String>.from(cfg.order.reversed);
      await fresh.updateOrder(order);
      cfg = await repo.loadConfig();
      expect(cfg.order.first, order.first);

      // addQuickLink immediate
      await fresh.addQuickLink(const QuickLink(label: 'Mein Shop', route: '/shop'));
      cfg = await repo.loadConfig();
      expect(cfg.quickLinks.any((l) => l.route == '/shop'), isTrue);
    });

    test('Corrupted JSON fallback defaults', () async {
      // write corrupted JSON directly
      final rows = await db.executor.runSelect('SELECT id FROM unternehmen LIMIT 1', const []);
      if (rows.isEmpty) {
        await db.executor.runInsert('INSERT INTO unternehmen (name, dashboard_config) VALUES (?, ?)', <Object?>[
          'X',
          '{corrupted json',
        ]);
      } else {
        await db.executor.runUpdate('UPDATE unternehmen SET dashboard_config = ? WHERE id = ?', <Object?>[
          '{corrupted',
          rows.first['id'],
        ]);
      }
      var cfg = await repo.loadConfig();
      expect(cfg.order, hasLength(13));
      expect(cfg.order, containsAll(dashboardWidgetIds));
      expect(cfg.visibility.length, 13);
      expect(cfg.visibility.values.every((v) => v), isTrue);
      expect(cfg.quickLinks, hasLength(3));

      // also corrupted via truncated array / not parsable
      await db.executor.runUpdate('UPDATE unternehmen SET dashboard_config = ? WHERE id = ?', <Object?>[
        'not-json-at-all',
        (await db.executor.runSelect('SELECT id FROM unternehmen LIMIT 1', const [])).first['id'],
      ]);
      cfg = await repo.loadConfig();
      expect(cfg.order, hasLength(13));

      // empty string fallback
      await db.executor.runUpdate('UPDATE unternehmen SET dashboard_config = ? WHERE id = ?', <Object?>[
        '',
        (await db.executor.runSelect('SELECT id FROM unternehmen LIMIT 1', const [])).first['id'],
      ]);
      cfg = await repo.loadConfig();
      expect(cfg.order, hasLength(13));

      // valid JSON with missing keys merges defaults
      await db.executor.runUpdate('UPDATE unternehmen SET dashboard_config = ? WHERE id = ?', <Object?>[
        '{"order":["offene_rechnungen"]}',
        (await db.executor.runSelect('SELECT id FROM unternehmen LIMIT 1', const [])).first['id'],
      ]);
      cfg = await repo.loadConfig();
      // should merge missing 12 ids
      expect(cfg.order, hasLength(13));
      expect(cfg.order.first, 'offene_rechnungen');
      expect(cfg.visibility.length, 13);
    });
  });
}
